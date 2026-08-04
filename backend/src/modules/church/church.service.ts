import {
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { buildPaginationMeta } from '../../common/dto/pagination.dto';
import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import { MembersService } from '../members/members.service';
import type {
  CreateChurchServiceDto,
  FindAttendanceDto,
  FindChurchServicesDto,
  MarkAttendanceDto,
  UpdateChurchServiceDto,
} from './dto/church.dto';

@Injectable()
export class ChurchService {
  private readonly logger = new Logger(ChurchService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly members: MembersService,
  ) {}

  // ===========================================================================
  // Cultes
  // ===========================================================================

  async findAllServices(query: FindChurchServicesDto) {
    const where: Prisma.ChurchServiceWhereInput = {
      ...NOT_DELETED,
      ...(query.from || query.to
        ? {
            serviceDate: {
              ...(query.from ? { gte: new Date(query.from) } : {}),
              ...(query.to ? { lte: new Date(query.to) } : {}),
            },
          }
        : {}),
      ...(query.search
        ? { name: { contains: query.search, mode: 'insensitive' } }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.churchService.findMany({
        where,
        // Les cultes récents d'abord : c'est celui du jour ou du dimanche
        // précédent que l'on cherche presque toujours.
        orderBy: [{ serviceDate: 'desc' }, { name: 'asc' }],
        skip: query.skip,
        take: query.take,
        include: {
          _count: {
            select: {
              attendances: { where: { deletedAt: null } },
              visitors: { where: { deletedAt: null } },
            },
          },
        },
      }),
      this.prisma.churchService.count({ where }),
    ]);

    return {
      data: items,
      meta: buildPaginationMeta(total, query.page, query.limit),
    };
  }

  /**
   * Détail d'un culte avec sa feuille de présence.
   *
   * Renvoie **tous** les membres actifs, y compris ceux non encore marqués :
   * l'écran de saisie doit afficher la liste complète pour permettre de
   * pointer chacun. Les membres sans enregistrement apparaissent avec
   * `attendanceType: null`.
   */
  async findOneService(id: string) {
    const service = await this.prisma.churchService.findFirst({
      where: { id, ...NOT_DELETED },
      include: {
        creator: {
          select: {
            id: true,
            member: { select: { firstName: true, lastName: true } },
          },
        },
        visitors: {
          where: { deletedAt: null },
          select: {
            id: true,
            firstName: true,
            lastName: true,
            phone: true,
            attendanceType: true,
          },
        },
      },
    });

    if (!service) {
      throw this.serviceNotFound(id);
    }

    const [members, attendances] = await this.prisma.$transaction([
      this.prisma.member.findMany({
        where: { ...NOT_DELETED, isActive: true },
        select: {
          id: true,
          firstName: true,
          lastName: true,
          photoUrl: true,
          birthday: true,
          isNewComer: true,
          mainDepartment: { select: { id: true, name: true } },
        },
        orderBy: [{ lastName: 'asc' }, { firstName: 'asc' }],
      }),
      this.prisma.churchAttendance.findMany({
        where: { churchServiceId: id, ...NOT_DELETED },
        select: {
          memberId: true,
          attendanceType: true,
          specificObservation: true,
        },
      }),
    ]);

    const marked = new Map(attendances.map((entry) => [entry.memberId, entry]));

    return {
      ...service,
      sheet: members.map((member) => {
        const entry = marked.get(member.id);
        return {
          ...member,
          attendanceType: entry?.attendanceType ?? null,
          specificObservation: entry?.specificObservation ?? null,
        };
      }),
      stats: this.computeStats(attendances),
    };
  }

  async createService(dto: CreateChurchServiceDto, actorUserId: string) {
    const serviceDate = new Date(dto.serviceDate);

    await this.assertServiceNameAvailable(serviceDate, dto.name);

    const service = await this.prisma.churchService.create({
      data: { serviceDate, name: dto.name, createdBy: actorUserId },
    });

    this.logger.log(`Culte créé : ${dto.name} du ${dto.serviceDate}`);

    return service;
  }

  async updateService(id: string, dto: UpdateChurchServiceDto) {
    const existing = await this.prisma.churchService.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, serviceDate: true, name: true },
    });

    if (!existing) {
      throw this.serviceNotFound(id);
    }

    const serviceDate = dto.serviceDate
      ? new Date(dto.serviceDate)
      : existing.serviceDate;
    const name = dto.name ?? existing.name;

    const changed =
      serviceDate.getTime() !== existing.serviceDate.getTime() ||
      name !== existing.name;

    if (changed) {
      await this.assertServiceNameAvailable(serviceDate, name, id);
    }

    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.churchService.update({
        where: { id },
        data: { serviceDate, name },
      });

      // `service_date` est dénormalisée sur les présences pour accélérer les
      // filtres par période. Déplacer un culte sans la propager laisserait les
      // rapports mensuels incohérents.
      if (serviceDate.getTime() !== existing.serviceDate.getTime()) {
        await tx.churchAttendance.updateMany({
          where: { churchServiceId: id },
          data: { serviceDate },
        });
      }

      return updated;
    });
  }

  /**
   * Suppression logique d'un culte.
   *
   * Les présences et les visiteurs rattachés sont supprimés en cascade
   * logique : conserver une présence pointant vers un culte invisible
   * fausserait tous les décomptes.
   */
  async removeService(id: string) {
    const service = await this.prisma.churchService.findFirst({
      where: { id, ...NOT_DELETED },
      select: {
        id: true,
        name: true,
        serviceDate: true,
        _count: { select: { attendances: { where: { deletedAt: null } } } },
      },
    });

    if (!service) {
      throw this.serviceNotFound(id);
    }

    const now = new Date();

    await this.prisma.$transaction([
      this.prisma.churchAttendance.updateMany({
        where: { churchServiceId: id, deletedAt: null },
        data: { deletedAt: now },
      }),
      this.prisma.visitor.updateMany({
        where: { churchServiceId: id, deletedAt: null },
        data: { deletedAt: now },
      }),
      this.prisma.churchService.update({
        where: { id },
        data: { deletedAt: now },
      }),
    ]);

    this.logger.log(
      `Culte supprimé : ${service.name} ` +
        `(${service._count.attendances} présence(s) retirée(s))`,
    );

    return { message: 'Culte supprimé.', id };
  }

  // ===========================================================================
  // Présence
  // ===========================================================================

  /**
   * Enregistre la présence en une seule opération.
   *
   * Chaque entrée est créée ou mise à jour : le responsable peut revenir sur
   * sa saisie sans provoquer de doublon. L'ensemble tient dans une
   * transaction — une coupure réseau en cours d'envoi ne doit pas laisser une
   * feuille de présence à moitié remplie.
   */
  /**
   * Enregistre la présence en une seule opération.
   *
   * Chaque entrée est créée ou mise à jour : le responsable peut revenir sur
   * sa saisie sans provoquer de doublon. L'ensemble tient dans une
   * transaction — une coupure réseau en cours d'envoi ne doit pas laisser une
   * feuille de présence à moitié remplie.
   *
   * `upsert` n'est pas utilisable ici : il réclame une contrainte unique
   * déclarée dans le schéma Prisma, alors que la nôtre est un index partiel
   * limité aux lignes vivantes. On recherche donc explicitement la ligne
   * existante avant de décider entre création et mise à jour.
   */
  async markAttendance(
    churchServiceId: string,
    dto: MarkAttendanceDto,
    actorUserId: string,
  ) {
    const service = await this.prisma.churchService.findFirst({
      where: { id: churchServiceId, ...NOT_DELETED },
      select: { id: true, serviceDate: true, name: true },
    });

    if (!service) {
      throw this.serviceNotFound(churchServiceId);
    }

    const memberIds = dto.entries.map((entry) => entry.memberId);
    await this.assertMembersExist(memberIds);

    await this.prisma.$transaction(async (tx) => {
      // Les lignes existantes sont chargées en une requête : interroger la
      // base une fois par membre multiplierait les allers-retours sur une
      // feuille de cinquante personnes.
      const existing = await tx.churchAttendance.findMany({
        where: { churchServiceId, memberId: { in: memberIds } },
        select: { id: true, memberId: true },
      });

      const byMember = new Map(existing.map((row) => [row.memberId, row.id]));

      for (const entry of dto.entries) {
        const existingId = byMember.get(entry.memberId);

        if (existingId) {
          await tx.churchAttendance.update({
            where: { id: existingId },
            data: {
              attendanceType: entry.attendanceType,
              specificObservation: entry.specificObservation ?? null,
              serviceDate: service.serviceDate,
              // Réactive une ligne précédemment supprimée plutôt que d'en
              // créer une seconde.
              deletedAt: null,
            },
          });
        } else {
          await tx.churchAttendance.create({
            data: {
              memberId: entry.memberId,
              churchServiceId,
              serviceDate: service.serviceDate,
              attendanceType: entry.attendanceType,
              specificObservation: entry.specificObservation ?? null,
              createdBy: actorUserId,
            },
          });
        }
      }
    });

    // La graduation est évaluée après coup, hors transaction : elle ne doit
    // pas faire échouer l'enregistrement de la présence, qui est l'opération
    // importante. Seuls les membres réellement présents sont concernés.
    const graduated = await this.runGraduationChecks(
      dto.entries
        .filter((entry) => entry.attendanceType !== 'absent')
        .map((entry) => entry.memberId),
    );

    this.logger.log(
      `Présence enregistrée pour ${service.name} : ${dto.entries.length} entrée(s)`,
    );

    return {
      message: 'Présence enregistrée.',
      recorded: dto.entries.length,
      graduatedMembers: graduated,
    };
  }

  async findAttendance(query: FindAttendanceDto) {
    const where: Prisma.ChurchAttendanceWhereInput = {
      ...NOT_DELETED,
      ...(query.memberId ? { memberId: query.memberId } : {}),
      ...(query.churchServiceId ? { churchServiceId: query.churchServiceId } : {}),
      ...(query.attendanceType ? { attendanceType: query.attendanceType } : {}),
      ...(query.from || query.to
        ? {
            serviceDate: {
              ...(query.from ? { gte: new Date(query.from) } : {}),
              ...(query.to ? { lte: new Date(query.to) } : {}),
            },
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.churchAttendance.findMany({
        where,
        orderBy: { serviceDate: 'desc' },
        skip: query.skip,
        take: query.take,
        include: {
          member: {
            select: { id: true, firstName: true, lastName: true, photoUrl: true },
          },
          churchService: { select: { id: true, name: true, serviceDate: true } },
        },
      }),
      this.prisma.churchAttendance.count({ where }),
    ]);

    return {
      data: items,
      meta: buildPaginationMeta(total, query.page, query.limit),
    };
  }

  /**
   * Membres absents d'un culte donné.
   *
   * Regroupe deux situations que les responsables traitent de la même façon :
   * ceux explicitement marqués absents, et ceux qui n'ont pas été pointés du
   * tout. Pour le suivi pastoral, l'oubli de pointage et l'absence réelle
   * appellent le même geste — vérifier ce qu'il en est.
   */
  async findAbsentees(churchServiceId: string) {
    const service = await this.prisma.churchService.findFirst({
      where: { id: churchServiceId, ...NOT_DELETED },
      select: { id: true, name: true, serviceDate: true },
    });

    if (!service) {
      throw this.serviceNotFound(churchServiceId);
    }

    const present = await this.prisma.churchAttendance.findMany({
      where: {
        churchServiceId,
        attendanceType: { in: ['onsite', 'online'] },
        ...NOT_DELETED,
      },
      select: { memberId: true },
    });

    const presentIds = present.map((entry) => entry.memberId);

    const absentees = await this.prisma.member.findMany({
      where: {
        ...NOT_DELETED,
        isActive: true,
        ...(presentIds.length > 0 ? { id: { notIn: presentIds } } : {}),
      },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        phone: true,
        email: true,
        isNewComer: true,
        mainDepartment: { select: { name: true } },
      },
      orderBy: [{ lastName: 'asc' }, { firstName: 'asc' }],
    });

    return {
      service,
      totalAbsent: absentees.length,
      absentees,
    };
  }

  /** Historique de présence d'un membre, avec son taux d'assiduité. */
  async findMemberHistory(memberId: string, from?: string, to?: string) {
    const member = await this.prisma.member.findFirst({
      where: { id: memberId, ...NOT_DELETED },
      select: { id: true, firstName: true, lastName: true },
    });

    if (!member) {
      throw new NotFoundException({
        message: 'Membre introuvable.',
        code: 'MEMBER_NOT_FOUND',
      });
    }

    const dateFilter = {
      ...(from ? { gte: new Date(from) } : {}),
      ...(to ? { lte: new Date(to) } : {}),
    };

    const [attendances, totalServices] = await this.prisma.$transaction([
      this.prisma.churchAttendance.findMany({
        where: {
          memberId,
          ...NOT_DELETED,
          ...(from || to ? { serviceDate: dateFilter } : {}),
        },
        orderBy: { serviceDate: 'desc' },
        include: {
          churchService: { select: { id: true, name: true, serviceDate: true } },
        },
      }),
      // Dénominateur du taux : le nombre de cultes tenus sur la période, et
      // non le nombre de fois où le membre a été pointé.
      this.prisma.churchService.count({
        where: {
          ...NOT_DELETED,
          ...(from || to ? { serviceDate: dateFilter } : {}),
        },
      }),
    ]);

    const stats = this.computeStats(attendances);
    const present = stats.onsite + stats.online;

    return {
      member,
      totalServices,
      attendances,
      stats: {
        ...stats,
        present,
        attendanceRate:
          totalServices > 0 ? Math.round((present / totalServices) * 100) : 0,
      },
    };
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private computeStats(
    entries: Array<{ attendanceType: string }>,
  ): { onsite: number; online: number; absent: number; total: number } {
    return {
      onsite: entries.filter((entry) => entry.attendanceType === 'onsite').length,
      online: entries.filter((entry) => entry.attendanceType === 'online').length,
      absent: entries.filter((entry) => entry.attendanceType === 'absent').length,
      total: entries.length,
    };
  }

  /**
   * Déclenche la vérification de graduation pour chaque membre présent.
   *
   * Les erreurs sont absorbées : un échec ici ne doit jamais remettre en cause
   * l'enregistrement de la présence, déjà validé.
   */
  private async runGraduationChecks(memberIds: string[]): Promise<string[]> {
    const graduated: string[] = [];

    for (const memberId of memberIds) {
      try {
        const didGraduate = await this.members.checkNewcomerGraduation(memberId);
        if (didGraduate) {
          graduated.push(memberId);
        }
      } catch (error) {
        this.logger.warn(
          `Vérification de graduation impossible pour ${memberId} : ` +
            `${error instanceof Error ? error.message : 'erreur inconnue'}`,
        );
      }
    }

    return graduated;
  }

  private async assertServiceNameAvailable(
    serviceDate: Date,
    name: string,
    excludeId?: string,
  ): Promise<void> {
    const existing = await this.prisma.churchService.findFirst({
      where: {
        serviceDate,
        name: { equals: name, mode: 'insensitive' },
        ...NOT_DELETED,
        ...(excludeId ? { id: { not: excludeId } } : {}),
      },
      select: { id: true },
    });

    if (existing) {
      throw new ConflictException({
        message: `Un culte nommé « ${name} » existe déjà à cette date.`,
        code: 'SERVICE_NAME_DUPLICATE',
      });
    }
  }

  private async assertMembersExist(memberIds: string[]): Promise<void> {
    const unique = [...new Set(memberIds)];

    const found = await this.prisma.member.count({
      where: { id: { in: unique }, ...NOT_DELETED },
    });

    if (found !== unique.length) {
      throw new NotFoundException({
        message:
          'Un ou plusieurs membres de la liste sont introuvables ou supprimés.',
        code: 'MEMBER_NOT_FOUND',
      });
    }
  }

  private serviceNotFound(id: string): NotFoundException {
    return new NotFoundException({
      message: `Aucun culte ne correspond à l'identifiant ${id}.`,
      code: 'CHURCH_SERVICE_NOT_FOUND',
    });
  }
}