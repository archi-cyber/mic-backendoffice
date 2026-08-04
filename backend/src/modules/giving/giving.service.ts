import {
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { buildPaginationMeta } from '../../common/dto/pagination.dto';
import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import { isPrivilegedRole, type AuthenticatedUser } from '../auth/types/auth.types';
import type {
  CreateGivingDto,
  FindGivingDto,
  GivingSummaryDto,
  UpdateGivingDto,
} from './dto/giving.dto';

@Injectable()
export class GivingService {
  private readonly logger = new Logger(GivingService.name);

  /**
   * Délai pendant lequel un mouvement reste modifiable, en jours.
   *
   * Passé ce délai, seul un administrateur peut intervenir. Une écriture
   * comptable ancienne a probablement été reportée dans un rapport ou un
   * rapprochement : la modifier sans trace romprait la piste d'audit.
   */
  private static readonly EDIT_WINDOW_DAYS = 2;

  constructor(private readonly prisma: PrismaService) {}

  // ===========================================================================
  // Lecture
  // ===========================================================================

  async findAll(query: FindGivingDto) {
    const where: Prisma.GivingWhereInput = {
      ...NOT_DELETED,
      ...(query.type ? { type: query.type } : {}),
      ...(query.tag ? { tag: query.tag } : {}),
      ...(query.memberId ? { memberId: query.memberId } : {}),
      ...(query.from || query.to
        ? {
            date: {
              ...(query.from ? { gte: new Date(query.from) } : {}),
              ...(query.to ? { lte: new Date(query.to) } : {}),
            },
          }
        : {}),
      ...(query.search
        ? {
            OR: [
              { giverName: { contains: query.search, mode: 'insensitive' } },
              { notes: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total, totals] = await Promise.all([
      this.prisma.giving.findMany({
        where,
        orderBy: { date: 'desc' },
        skip: query.skip,
        take: query.take,
        include: {
          member: { select: { id: true, firstName: true, lastName: true } },
        },
      }),
      this.prisma.giving.count({ where }),
      // Les totaux portent sur l'ensemble du filtre, pas sur la page affichée :
      // un trésorier consultant la page 2 doit voir le total réel, pas celui
      // des vingt lignes sous ses yeux.
      this.prisma.giving.groupBy({
        by: ['type'],
        where,
        _sum: { amount: true },
        orderBy: { type: 'asc' },
      }),
    ]);

    const received = this.sumFor(totals, 'receiving');
    const spent = this.sumFor(totals, 'expense');

    return {
      data: items.map((row) => this.serialize(row)),
      meta: {
        ...buildPaginationMeta(total, query.page, query.limit),
        totals: { received, spent, net: received - spent },
      },
    };
  }

  async findOne(id: string) {
    const giving = await this.prisma.giving.findFirst({
      where: { id, ...NOT_DELETED },
      include: {
        member: { select: { id: true, firstName: true, lastName: true } },
      },
    });

    if (!giving) {
      throw this.notFound(id);
    }

    return {
      ...this.serialize(giving),
      isEditable: this.isWithinEditWindow(giving.createdAt),
    };
  }

  // ===========================================================================
  // Écriture
  // ===========================================================================

  async create(dto: CreateGivingDto) {
    if (dto.memberId) {
      await this.assertMemberExists(dto.memberId);
    }

    const giving = await this.prisma.giving.create({
      data: {
        giverName: dto.giverName,
        memberId: dto.memberId ?? null,
        amount: new Prisma.Decimal(dto.amount),
        tag: dto.tag,
        type: dto.type,
        date: dto.date ? new Date(dto.date) : new Date(),
        notes: dto.notes ?? null,
      } as Prisma.GivingUncheckedCreateInput,
      include: {
        member: { select: { id: true, firstName: true, lastName: true } },
      },
    });

    this.logger.log(
      `Mouvement enregistré : ${dto.type} ${dto.amount} frs (${dto.tag})`,
    );

    return this.serialize(giving);
  }

  /**
   * Modifie un mouvement.
   *
   * Au-delà de deux jours, l'opération est réservée aux administrateurs.
   * Cette fenêtre laisse la place à la correction d'une erreur de saisie tout
   * en protégeant les écritures déjà consolidées.
   */
  async update(id: string, dto: UpdateGivingDto, actor: AuthenticatedUser) {
    const existing = await this.prisma.giving.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, createdAt: true },
    });

    if (!existing) {
      throw this.notFound(id);
    }

    this.assertCanModify(existing.createdAt, actor);

    if (dto.memberId) {
      await this.assertMemberExists(dto.memberId);
    }

    const { amount, date, ...rest } = dto;

    const updated = await this.prisma.giving.update({
      where: { id },
      data: {
        ...rest,
        ...(amount !== undefined ? { amount: new Prisma.Decimal(amount) } : {}),
        ...(date !== undefined ? { date: new Date(date) } : {}),
      } as Prisma.GivingUncheckedUpdateInput,
      include: {
        member: { select: { id: true, firstName: true, lastName: true } },
      },
    });

    return this.serialize(updated);
  }

  async remove(id: string, actor: AuthenticatedUser) {
    const existing = await this.prisma.giving.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, createdAt: true, amount: true, type: true },
    });

    if (!existing) {
      throw this.notFound(id);
    }

    this.assertCanModify(existing.createdAt, actor);

    await this.prisma.giving.update({
      where: { id },
      data: { deletedAt: new Date() },
    });

    this.logger.log(
      `Mouvement supprimé : ${existing.type} ${existing.amount.toString()} frs`,
    );

    return { message: 'Mouvement supprimé.', id };
  }

  // ===========================================================================
  // Synthèses
  // ===========================================================================

  /**
   * Synthèse sur une période : totaux, ventilation par catégorie et par mois.
   */
  async getSummary(query: GivingSummaryDto) {
    const where: Prisma.GivingWhereInput = {
      ...NOT_DELETED,
      ...(query.from || query.to
        ? {
            date: {
              ...(query.from ? { gte: new Date(query.from) } : {}),
              ...(query.to ? { lte: new Date(query.to) } : {}),
            },
          }
        : {}),
    };

    // Les deux agrégations sont lancées séparément plutôt que via
    // `$transaction([...])` : le tableau fait perdre à Prisma le typage précis
    // de `_count`, qui redevient une union `true | objet` inexploitable.
    // Une transaction n'apporte de toute façon rien ici — rien n'est modifié.
    const [byType, byTag] = await Promise.all([
      this.prisma.giving.groupBy({
        by: ['type'],
        where,
        _sum: { amount: true },
        _count: { _all: true },
        orderBy: { type: 'asc' },
      }),
      this.prisma.giving.groupBy({
        by: ['tag', 'type'],
        where,
        _sum: { amount: true },
        _count: { _all: true },
        orderBy: [{ tag: 'asc' }, { type: 'asc' }],
      }),
    ]);

    const received = this.sumFor(byType, 'receiving');
    const spent = this.sumFor(byType, 'expense');

    return {
      period: { from: query.from ?? null, to: query.to ?? null },
      totals: {
        received,
        spent,
        net: received - spent,
        transactionCount: byType.reduce(
          (sum, row) => sum + (row._count?._all ?? 0),
          0,
        ),
      },
      byCategory: byTag.map((row) => ({
        tag: row.tag,
        type: row.type,
        total: Number(row._sum?.amount ?? 0),
        count: row._count?._all ?? 0,
      })),
    };
  }

  /**
   * Ventilation mensuelle d'une année.
   *
   * Le regroupement par mois est fait en SQL : Prisma ne sait pas grouper sur
   * une expression dérivée d'une colonne date, et charger l'année entière en
   * mémoire pour la découper serait coûteux dès quelques milliers de lignes.
   */
  async getMonthlyBreakdown(year: number) {
    const rows = await this.prisma.$queryRaw<
      Array<{ month: number; type: string; total: string; count: bigint }>
    >`
      SELECT
        EXTRACT(MONTH FROM date)::int AS month,
        type::text                     AS type,
        SUM(amount)::text              AS total,
        COUNT(*)                       AS count
      FROM giving
      WHERE deleted_at IS NULL
        AND EXTRACT(YEAR FROM date) = ${year}
      GROUP BY month, type
      ORDER BY month ASC
    `;

    // Les douze mois sont toujours présents, même vides : un graphique avec
    // des mois manquants serait trompeur à la lecture.
    const months = Array.from({ length: 12 }, (_, index) => {
      const monthNumber = index + 1;
      const monthRows = rows.filter((row) => row.month === monthNumber);

      const received = Number(
        monthRows.find((row) => row.type === 'receiving')?.total ?? 0,
      );
      const spent = Number(
        monthRows.find((row) => row.type === 'expense')?.total ?? 0,
      );

      return {
        month: monthNumber,
        received,
        spent,
        net: received - spent,
        transactionCount: monthRows.reduce(
          (sum, row) => sum + Number(row.count),
          0,
        ),
      };
    });

    return {
      year,
      months,
      yearTotals: {
        received: months.reduce((sum, month) => sum + month.received, 0),
        spent: months.reduce((sum, month) => sum + month.spent, 0),
      },
    };
  }

  /** Historique des dons d'un membre. */
  async getMemberGiving(memberId: string, from?: string, to?: string) {
    await this.assertMemberExists(memberId);

    const where: Prisma.GivingWhereInput = {
      memberId,
      ...NOT_DELETED,
      ...(from || to
        ? {
            date: {
              ...(from ? { gte: new Date(from) } : {}),
              ...(to ? { lte: new Date(to) } : {}),
            },
          }
        : {}),
    };

    const [items, aggregate] = await Promise.all([
      this.prisma.giving.findMany({ where, orderBy: { date: 'desc' } }),
      this.prisma.giving.aggregate({
        where: { ...where, type: 'receiving' },
        _sum: { amount: true },
        _count: true,
      }),
    ]);

    return {
      memberId,
      totalGiven: Number(aggregate._sum.amount ?? 0),
      transactionCount: aggregate._count,
      records: items.map((row) => this.serialize(row)),
    };
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  /**
   * Convertit le Decimal Prisma en nombre.
   *
   * Sérialisé tel quel, un Decimal partirait en JSON sous forme d'objet
   * inexploitable par le client Flutter.
   */
  private serialize<T extends { amount: Prisma.Decimal }>(row: T) {
    return { ...row, amount: Number(row.amount) };
  }

  private sumFor(
    rows: Array<{ type: string; _sum?: { amount: Prisma.Decimal | null } }>,
    type: string,
  ): number {
    return Number(rows.find((row) => row.type === type)?._sum?.amount ?? 0);
  }

  private isWithinEditWindow(createdAt: Date): boolean {
    const elapsed = Date.now() - createdAt.getTime();
    return elapsed <= GivingService.EDIT_WINDOW_DAYS * 24 * 60 * 60 * 1_000;
  }

  private assertCanModify(createdAt: Date, actor: AuthenticatedUser): void {
    if (this.isWithinEditWindow(createdAt) || isPrivilegedRole(actor.role)) {
      return;
    }

    throw new ForbiddenException({
      message:
        `Ce mouvement date de plus de ${GivingService.EDIT_WINDOW_DAYS} jours. ` +
        'Seul un administrateur peut encore le modifier.',
      code: 'GIVING_EDIT_WINDOW_CLOSED',
    });
  }

  private async assertMemberExists(id: string): Promise<void> {
    const member = await this.prisma.member.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true },
    });

    if (!member) {
      throw new NotFoundException({
        message: 'Membre introuvable.',
        code: 'MEMBER_NOT_FOUND',
      });
    }
  }

  private notFound(id: string): NotFoundException {
    return new NotFoundException({
      message: `Aucun mouvement ne correspond à l'identifiant ${id}.`,
      code: 'GIVING_NOT_FOUND',
    });
  }
}