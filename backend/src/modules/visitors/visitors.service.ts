import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { buildPaginationMeta } from '../../common/dto/pagination.dto';
import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import type {
  ConvertVisitorDto,
  CreateVisitorDto,
  FindVisitorsDto,
  UpdateVisitorDto,
} from './dto/visitor.dto';

@Injectable()
export class VisitorsService {
  private readonly logger = new Logger(VisitorsService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ===========================================================================
  // Lecture
  // ===========================================================================

  async findAll(query: FindVisitorsDto) {
    const where: Prisma.VisitorWhereInput = {
      ...NOT_DELETED,
      ...(query.churchServiceId ? { churchServiceId: query.churchServiceId } : {}),
      ...(query.from || query.to
        ? {
            visitDate: {
              ...(query.from ? { gte: new Date(query.from) } : {}),
              ...(query.to ? { lte: new Date(query.to) } : {}),
            },
          }
        : {}),
      ...(query.search
        ? {
            OR: [
              { firstName: { contains: query.search, mode: 'insensitive' } },
              { lastName: { contains: query.search, mode: 'insensitive' } },
              { phone: { contains: query.search } },
              { email: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.visitor.findMany({
        where,
        orderBy: { visitDate: 'desc' },
        skip: query.skip,
        take: query.take,
        include: {
          churchService: { select: { id: true, name: true, serviceDate: true } },
        },
      }),
      this.prisma.visitor.count({ where }),
    ]);

    return {
      data: items,
      meta: buildPaginationMeta(total, query.page, query.limit),
    };
  }

  async findOne(id: string) {
    const visitor = await this.prisma.visitor.findFirst({
      where: { id, ...NOT_DELETED },
      include: {
        churchService: { select: { id: true, name: true, serviceDate: true } },
        creator: {
          select: {
            id: true,
            member: { select: { firstName: true, lastName: true } },
          },
        },
      },
    });

    if (!visitor) {
      throw this.notFound(id);
    }

    return visitor;
  }

  // ===========================================================================
  // Écriture
  // ===========================================================================

  async create(dto: CreateVisitorDto, actorUserId: string) {
    if (dto.churchServiceId) {
      await this.assertServiceExists(dto.churchServiceId);
    }

    const visitor = await this.prisma.visitor.create({
      data: {
        firstName: dto.firstName,
        lastName: dto.lastName,
        email: dto.email ?? null,
        phone: dto.phone ?? null,
        address: dto.address ?? null,
        visitDate: dto.visitDate ? new Date(dto.visitDate) : new Date(),
        churchServiceId: dto.churchServiceId ?? null,
        attendanceType: dto.attendanceType ?? 'onsite',
        notes: dto.notes ?? null,
        createdBy: actorUserId,
      },
    });

    this.logger.log(`Visiteur enregistré : ${dto.firstName} ${dto.lastName}`);

    return visitor;
  }

  async update(id: string, dto: UpdateVisitorDto) {
    await this.assertExists(id);

    if (dto.churchServiceId) {
      await this.assertServiceExists(dto.churchServiceId);
    }

    const { visitDate, ...rest } = dto;

    return this.prisma.visitor.update({
      where: { id },
      data: {
        ...rest,
        ...(visitDate !== undefined ? { visitDate: new Date(visitDate) } : {}),
      },
    });
  }

  async remove(id: string) {
    await this.assertExists(id);

    await this.prisma.visitor.update({
      where: { id },
      data: { deletedAt: new Date() },
    });

    return { message: 'Visiteur supprimé.', id };
  }

  // ===========================================================================
  // Conversion en membre
  // ===========================================================================

  /**
   * Transforme un visiteur en membre.
   *
   * Le visiteur est supprimé logiquement au profit de la fiche membre : le
   * conserver produirait un doublon, la même personne apparaissant dans deux
   * listes et faussant les statistiques de fréquentation.
   *
   * Les présences déjà enregistrées sous forme de visiteur ne sont pas
   * reportées — elles restent attachées au culte, mais ne rejoignent pas
   * l'historique du membre. Faire autrement supposerait de créer des lignes
   * de présence rétroactives, ce qui modifierait des décomptes déjà publiés
   * dans des rapports.
   */
  async convertToMember(
    id: string,
    dto: ConvertVisitorDto,
    actorUserId: string,
  ) {
    const visitor = await this.prisma.visitor.findFirst({
      where: { id, ...NOT_DELETED },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        email: true,
        phone: true,
        address: true,
        visitDate: true,
      },
    });

    if (!visitor) {
      throw this.notFound(id);
    }

    if (dto.departmentId) {
      await this.assertDepartmentExists(dto.departmentId);
    }

    const isNewComer = dto.isNewComer ?? true;

    const member = await this.prisma.$transaction(async (tx) => {
      const created = await tx.member.create({
        data: {
          firstName: visitor.firstName,
          lastName: visitor.lastName,
          email: visitor.email,
          phone: visitor.phone,
          address: visitor.address,
          birthday: dto.birthday ? new Date(dto.birthday) : null,
          departmentId: dto.departmentId ?? null,
          isNewComer,
          // La date d'arrivée reprend celle de la première visite : c'est elle
          // qui fait foi pour la fenêtre de suivi de quatre-vingt-dix jours.
          newcomerJoinDate: isNewComer ? visitor.visitDate : null,
          newcomerIntention: isNewComer ? 'wants_to_stay' : null,
          isActive: true,
        } as Prisma.MemberUncheckedCreateInput,
      });

      if (dto.departmentId) {
        await tx.departmentMember.create({
          data: {
            departmentId: dto.departmentId,
            memberId: created.id,
            role: 'member',
            isMain: true,
          },
        });
      }

      if (isNewComer) {
        await tx.newComer.create({
          data: {
            memberId: created.id,
            firstName: created.firstName,
            lastName: created.lastName,
            email: created.email,
            phone: created.phone,
            newcomerJoinDate: visitor.visitDate,
            newcomerIntention: 'wants_to_stay',
            createdBy: actorUserId,
          },
        });
      }

      await tx.visitor.update({
        where: { id },
        data: { deletedAt: new Date() },
      });

      return created;
    });

    this.logger.log(
      `Visiteur converti en membre : ${member.firstName} ${member.lastName}`,
    );

    return {
      message: 'Visiteur converti en membre.',
      member,
    };
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private async assertExists(id: string): Promise<void> {
    const visitor = await this.prisma.visitor.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true },
    });

    if (!visitor) {
      throw this.notFound(id);
    }
  }

  private async assertServiceExists(churchServiceId: string): Promise<void> {
    const service = await this.prisma.churchService.findFirst({
      where: { id: churchServiceId, ...NOT_DELETED },
      select: { id: true },
    });

    if (!service) {
      throw new NotFoundException({
        message: 'Culte introuvable.',
        code: 'CHURCH_SERVICE_NOT_FOUND',
      });
    }
  }

  private async assertDepartmentExists(departmentId: string): Promise<void> {
    const department = await this.prisma.department.findFirst({
      where: { id: departmentId, ...NOT_DELETED },
      select: { id: true },
    });

    if (!department) {
      throw new NotFoundException({
        message: 'Département introuvable.',
        code: 'DEPARTMENT_NOT_FOUND',
      });
    }
  }

  private notFound(id: string): NotFoundException {
    return new NotFoundException({
      message: `Aucun visiteur ne correspond à l'identifiant ${id}.`,
      code: 'VISITOR_NOT_FOUND',
    });
  }
}