import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { buildPaginationMeta } from '../../common/dto/pagination.dto';
import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import type {
  FindSundaySchoolDto,
  MarkSundaySchoolDto,
} from './dto/sunday-school.dto';

@Injectable()
export class SundaySchoolService {
  private readonly logger = new Logger(SundaySchoolService.name);

  /** Âge maximum pour l'école du dimanche, selon le guide utilisateur. */
  private static readonly MAX_AGE = 12;

  constructor(private readonly prisma: PrismaService) {}

  // ===========================================================================
  // Enfants éligibles
  // ===========================================================================

  /**
   * Liste des enfants pouvant fréquenter l'école du dimanche.
   *
   * Le filtre porte sur la date de naissance plutôt que sur un âge calculé :
   * PostgreSQL peut alors utiliser l'index, là où un calcul par ligne
   * imposerait un parcours complet de la table.
   *
   * Les membres sans date de naissance sont exclus — impossible de statuer
   * sur leur éligibilité, et les inclure par défaut ferait apparaître des
   * adultes dans la liste.
   */
  async findEligibleChildren(maxAge = SundaySchoolService.MAX_AGE) {
    const earliestBirthday = new Date();
    earliestBirthday.setFullYear(earliestBirthday.getFullYear() - maxAge - 1);

    const children = await this.prisma.member.findMany({
      where: {
        ...NOT_DELETED,
        isActive: true,
        birthday: { gte: earliestBirthday, not: null },
      },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        birthday: true,
        photoUrl: true,
        gender: true,
      },
      orderBy: [{ lastName: 'asc' }, { firstName: 'asc' }],
    });

    return children.map((child) => ({
      ...child,
      age: this.computeAge(child.birthday),
    }));
  }

  // ===========================================================================
  // Présence
  // ===========================================================================

  async findAll(query: FindSundaySchoolDto) {
    const where: Prisma.SundaySchoolAttendanceWhereInput = {
      ...NOT_DELETED,
      ...(query.memberId ? { memberId: query.memberId } : {}),
      ...(query.from || query.to
        ? {
            attendanceDate: {
              ...(query.from ? { gte: new Date(query.from) } : {}),
              ...(query.to ? { lte: new Date(query.to) } : {}),
            },
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.sundaySchoolAttendance.findMany({
        where,
        orderBy: { attendanceDate: 'desc' },
        skip: query.skip,
        take: query.take,
        include: {
          member: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              birthday: true,
              photoUrl: true,
            },
          },
        },
      }),
      this.prisma.sundaySchoolAttendance.count({ where }),
    ]);

    return {
      data: items,
      meta: buildPaginationMeta(total, query.page, query.limit),
    };
  }

  /** Feuille de présence d'une date donnée. */
  async findByDate(attendanceDate: string) {
    const date = new Date(attendanceDate);

    const [children, present] = await Promise.all([
      this.findEligibleChildren(),
      this.prisma.sundaySchoolAttendance.findMany({
        where: { attendanceDate: date, ...NOT_DELETED },
        select: { memberId: true },
      }),
    ]);

    const presentIds = new Set(present.map((entry) => entry.memberId));

    return {
      attendanceDate: date,
      totalPresent: presentIds.size,
      totalEligible: children.length,
      sheet: children.map((child) => ({
        ...child,
        isPresent: presentIds.has(child.id),
      })),
    };
  }

  /**
   * Enregistre la présence d'une session.
   *
   * Le remplacement est total pour la date concernée : les enfants absents de
   * la liste voient leur présence retirée. C'est ce qui permet de corriger une
   * saisie — sans cela, décocher un enfant n'aurait aucun effet.
   */
 /**
   * Enregistre la présence d'une session.
   *
   * Le remplacement est total pour la date concernée : les enfants absents de
   * la liste voient leur présence retirée. C'est ce qui permet de corriger une
   * saisie — sans cela, décocher un enfant n'aurait aucun effet.
   *
   * Comme pour la présence aux cultes, `upsert` est inutilisable : la
   * contrainte d'unicité est un index partiel, invisible pour Prisma.
   */
  async markAttendance(dto: MarkSundaySchoolDto, actorUserId: string) {
    const attendanceDate = new Date(dto.attendanceDate);

    await this.assertChildrenEligible(dto.memberIds);

    const result = await this.prisma.$transaction(async (tx) => {
      // Retrait des présences qui ne figurent plus dans la liste.
      const removed = await tx.sundaySchoolAttendance.updateMany({
        where: {
          attendanceDate,
          memberId: { notIn: dto.memberIds },
          deletedAt: null,
        },
        data: { deletedAt: new Date() },
      });

      const existing = await tx.sundaySchoolAttendance.findMany({
        where: { attendanceDate, memberId: { in: dto.memberIds } },
        select: { id: true, memberId: true },
      });

      const byMember = new Map(existing.map((row) => [row.memberId, row.id]));

      for (const memberId of dto.memberIds) {
        const existingId = byMember.get(memberId);

        if (existingId) {
          await tx.sundaySchoolAttendance.update({
            where: { id: existingId },
            data: { deletedAt: null },
          });
        } else {
          await tx.sundaySchoolAttendance.create({
            data: { memberId, attendanceDate, createdBy: actorUserId },
          });
        }
      }

      return removed.count;
    });

    this.logger.log(
      `École du dimanche du ${dto.attendanceDate} : ` +
        `${dto.memberIds.length} présent(s), ${result} retiré(s)`,
    );

    return {
      message: 'Présence enregistrée.',
      present: dto.memberIds.length,
      removed: result,
    };
  }

  async removeSession(attendanceDate: string) {
    const date = new Date(attendanceDate);

    const result = await this.prisma.sundaySchoolAttendance.updateMany({
      where: { attendanceDate: date, deletedAt: null },
      data: { deletedAt: new Date() },
    });

    if (result.count === 0) {
      throw new NotFoundException({
        message: 'Aucune présence enregistrée à cette date.',
        code: 'SESSION_NOT_FOUND',
      });
    }

    return {
      message: 'Session supprimée.',
      removed: result.count,
    };
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  /**
   * Refuse d'enregistrer un adulte à l'école du dimanche.
   *
   * Sans ce contrôle, une erreur de sélection dans l'interface passerait
   * inaperçue et fausserait durablement les effectifs enfants — une donnée
   * que les églises suivent de près.
   */
  private async assertChildrenEligible(memberIds: string[]): Promise<void> {
    const unique = [...new Set(memberIds)];

    const members = await this.prisma.member.findMany({
      where: { id: { in: unique }, ...NOT_DELETED },
      select: { id: true, firstName: true, lastName: true, birthday: true },
    });

    if (members.length !== unique.length) {
      throw new NotFoundException({
        message: 'Un ou plusieurs membres sont introuvables.',
        code: 'MEMBER_NOT_FOUND',
      });
    }

    const tooOld = members.filter((member) => {
      const age = this.computeAge(member.birthday);
      return age !== null && age > SundaySchoolService.MAX_AGE;
    });

    if (tooOld.length > 0) {
      const names = tooOld
        .map((member) => `${member.firstName} ${member.lastName}`)
        .join(', ');

      throw new BadRequestException({
        message:
          `L'école du dimanche est réservée aux moins de ` +
          `${SundaySchoolService.MAX_AGE + 1} ans. Hors limite : ${names}.`,
        code: 'MEMBER_TOO_OLD_FOR_SUNDAY_SCHOOL',
      });
    }

    const withoutBirthday = members.filter((member) => !member.birthday);

    if (withoutBirthday.length > 0) {
      const names = withoutBirthday
        .map((member) => `${member.firstName} ${member.lastName}`)
        .join(', ');

      throw new BadRequestException({
        message:
          'Une date de naissance est nécessaire pour vérifier l\'éligibilité. ' +
          `Manquante pour : ${names}.`,
        code: 'BIRTHDAY_REQUIRED',
      });
    }
  }

  private computeAge(birthday: Date | null): number | null {
    if (!birthday) return null;

    const today = new Date();
    let age = today.getFullYear() - birthday.getFullYear();

    const monthDiff = today.getMonth() - birthday.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthday.getDate())) {
      age -= 1;
    }

    return age;
  }
}