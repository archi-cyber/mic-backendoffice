import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Prisma, type TeachingTaskType } from '@prisma/client';

import { buildPaginationMeta } from '../../common/dto/pagination.dto';
import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import { PenaltiesService } from '../tasks/penalties.service';
import type {
  AddListenersDto,
  CreateTeachingDto,
  FindTeachingsDto,
  UpdateTeachingDto,
} from './dto/teaching.dto';

/**
 * Formats de montage attendus après chaque enseignement.
 *
 * L'ordre détermine `teachingTaskIndex`, qui sert à retrouver la tâche
 * correspondant à un format donné.
 */
const MEDIA_TASK_FORMATS: Array<{
  type: TeachingTaskType;
  label: string;
}> = [
  { type: 'full', label: 'Montage intégral' },
  { type: 'mid', label: 'Montage format moyen' },
  { type: 'short', label: 'Montage format court' },
];

@Injectable()
export class TeachingsService {
  private readonly logger = new Logger(TeachingsService.name);

  /**
   * Département chargé du montage vidéo.
   *
   * La recherche est insensible à la casse et accepte les deux orthographes
   * courantes. Si aucun ne correspond, les tâches ne sont pas créées et un
   * avertissement est journalisé — mieux vaut un enseignement sans tâches
   * qu'un échec d'enregistrement.
   */
  private static readonly MEDIA_DEPARTMENT_NAMES = ['média', 'media'];

  /** Rôles dont la présence vaut « a suivi l'enseignement ». */
  private static readonly LISTENER_ROLES = ['worker', 'leader', 'admin'] as const;

  constructor(
    private readonly prisma: PrismaService,
    private readonly penalties: PenaltiesService,
  ) {}

  // ===========================================================================
  // Lecture
  // ===========================================================================

  async findAll(query: FindTeachingsDto) {
    const where: Prisma.TeachingWhereInput = {
      ...NOT_DELETED,
      ...(query.speaker
        ? { speaker: { contains: query.speaker, mode: 'insensitive' } }
        : {}),
      ...(query.from || query.to
        ? {
            teachingDate: {
              ...(query.from ? { gte: new Date(query.from) } : {}),
              ...(query.to ? { lte: new Date(query.to) } : {}),
            },
          }
        : {}),
      ...(query.search
        ? {
            OR: [
              { title: { contains: query.search, mode: 'insensitive' } },
              { description: { contains: query.search, mode: 'insensitive' } },
              { speaker: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.teaching.findMany({
        where,
        orderBy: { teachingDate: 'desc' },
        skip: query.skip,
        take: query.take,
        include: {
          _count: {
            select: {
              listeners: { where: { deletedAt: null } },
              tasks: { where: { deletedAt: null } },
            },
          },
        },
      }),
      this.prisma.teaching.count({ where }),
    ]);

    return {
      data: items,
      meta: buildPaginationMeta(total, query.page, query.limit),
    };
  }

  async findOne(id: string) {
    const teaching = await this.prisma.teaching.findFirst({
      where: { id, ...NOT_DELETED },
      include: {
        creator: {
          select: {
            id: true,
            member: { select: { firstName: true, lastName: true } },
          },
        },
        listeners: {
          where: { deletedAt: null },
          select: {
            id: true,
            createdAt: true,
            member: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                photoUrl: true,
                role: true,
              },
            },
          },
        },
        tasks: {
          where: { deletedAt: null },
          select: {
            id: true,
            title: true,
            teachingTaskType: true,
            status: true,
            dueDate: true,
            assignments: {
              select: {
                member: { select: { id: true, firstName: true, lastName: true } },
              },
            },
          },
          orderBy: { teachingTaskIndex: 'asc' },
        },
      },
    });

    if (!teaching) {
      throw this.notFound(id);
    }

    return teaching;
  }

  // ===========================================================================
  // Écriture
  // ===========================================================================

  /**
   * Crée un enseignement et déclenche ses deux automatismes.
   *
   * Les tâches de montage et la synchronisation des auditeurs sont traitées
   * après la création, hors de sa transaction. C'est délibéré : un problème
   * sur l'un de ces automatismes ne doit pas empêcher d'enregistrer
   * l'enseignement lui-même, qui est la donnée durable.
   */
  async create(dto: CreateTeachingDto, actorUserId: string) {
    const teachingDate = new Date(dto.teachingDate);

    const teaching = await this.prisma.teaching.create({
      data: {
        title: dto.title,
        teachingDate,
        speaker: dto.speaker ?? null,
        description: dto.description ?? null,
        createdBy: actorUserId,
      },
    });

    let tasksCreated = 0;
    let listenersAdded = 0;

    if (dto.generateMediaTasks !== false) {
      tasksCreated = await this.generateMediaTasks(teaching.id, teachingDate);
    }

    if (dto.syncListeners !== false) {
      listenersAdded = await this.syncListenersFromAttendance(
        teaching.id,
        teachingDate,
        actorUserId,
      );
    }

    this.logger.log(
      `Enseignement créé : ${teaching.title} ` +
        `(${tasksCreated} tâche(s) média, ${listenersAdded} auditeur(s))`,
    );

    return { ...(await this.findOne(teaching.id)), tasksCreated, listenersAdded };
  }

  async update(id: string, dto: UpdateTeachingDto) {
    const existing = await this.prisma.teaching.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, teachingDate: true },
    });

    if (!existing) {
      throw this.notFound(id);
    }

    const { teachingDate, generateMediaTasks, syncListeners, ...rest } = dto;
    const newDate = teachingDate ? new Date(teachingDate) : existing.teachingDate;

    await this.prisma.$transaction(async (tx) => {
      await tx.teaching.update({
        where: { id },
        data: { ...rest, teachingDate: newDate },
      });

      // Déplacer un enseignement décale l'échéance de ses tâches de montage :
      // les laisser sur l'ancienne date ferait courir des pénalités pour un
      // retard qui n'existe pas.
      if (newDate.getTime() !== existing.teachingDate.getTime()) {
        const settings = await this.penalties.getSettings();
        const dueDate = this.addDays(newDate, settings.teachingTaskDueOffsetDays);

        await tx.task.updateMany({
          where: { teachingId: id, deletedAt: null },
          data: { dueDate },
        });
      }
    });

    return this.findOne(id);
  }

  /**
   * Suppression logique.
   *
   * Les tâches de montage suivent : elles n'ont plus d'objet sans leur
   * enseignement, et les laisser vivantes ferait courir des pénalités pour un
   * travail devenu sans raison d'être.
   */
  async remove(id: string) {
    const teaching = await this.prisma.teaching.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, title: true },
    });

    if (!teaching) {
      throw this.notFound(id);
    }

    const now = new Date();

    await this.prisma.$transaction([
      this.prisma.task.updateMany({
        where: { teachingId: id, deletedAt: null },
        data: { deletedAt: now },
      }),
      this.prisma.teachingListener.updateMany({
        where: { teachingId: id, deletedAt: null },
        data: { deletedAt: now },
      }),
      this.prisma.teaching.update({ where: { id }, data: { deletedAt: now } }),
    ]);

    return { message: 'Enseignement supprimé.', id };
  }

  // ===========================================================================
  // Auditeurs
  // ===========================================================================

  /**
   * Alimente la liste des auditeurs depuis la présence au culte.
   *
   * Seuls les ouvriers, responsables et administrateurs sont retenus : la
   * notion d'auditeur sert au suivi de formation interne, pas au décompte de
   * l'assistance générale.
   *
   * Les personnes marquées absentes sont évidemment exclues.
   */
  async syncListenersFromAttendance(
    teachingId: string,
    teachingDate: Date,
    actorUserId: string,
  ): Promise<number> {
    const attendances = await this.prisma.churchAttendance.findMany({
      where: {
        serviceDate: teachingDate,
        attendanceType: { in: ['onsite', 'online'] },
        ...NOT_DELETED,
        member: {
          ...NOT_DELETED,
          role: { in: [...TeachingsService.LISTENER_ROLES] },
        },
      },
      select: { memberId: true },
      distinct: ['memberId'],
    });

    if (attendances.length === 0) {
      return 0;
    }

    const memberIds = attendances.map((entry) => entry.memberId);

    const existing = await this.prisma.teachingListener.findMany({
      where: { teachingId, memberId: { in: memberIds } },
      select: { id: true, memberId: true, deletedAt: true },
    });

    const byMember = new Map(existing.map((row) => [row.memberId, row]));
    let added = 0;

    for (const memberId of memberIds) {
      const row = byMember.get(memberId);

      if (!row) {
        await this.prisma.teachingListener.create({
          data: { teachingId, memberId, createdBy: actorUserId },
        });
        added += 1;
      } else if (row.deletedAt) {
        // Réactive plutôt que de créer un doublon.
        await this.prisma.teachingListener.update({
          where: { id: row.id },
          data: { deletedAt: null },
        });
        added += 1;
      }
    }

    return added;
  }

  /** Relance manuelle de la synchronisation. */
  async resyncListeners(id: string, actorUserId: string) {
    const teaching = await this.prisma.teaching.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, teachingDate: true },
    });

    if (!teaching) {
      throw this.notFound(id);
    }

    const added = await this.syncListenersFromAttendance(
      id,
      teaching.teachingDate,
      actorUserId,
    );

    return {
      message:
        added > 0
          ? `${added} auditeur(s) ajouté(s) depuis la présence au culte.`
          : 'Aucun nouvel auditeur à ajouter.',
      added,
    };
  }

  async addListeners(id: string, dto: AddListenersDto, actorUserId: string) {
    await this.assertExists(id);

    const found = await this.prisma.member.count({
      where: { id: { in: dto.memberIds }, ...NOT_DELETED },
    });

    if (found !== new Set(dto.memberIds).size) {
      throw new NotFoundException({
        message: 'Un ou plusieurs membres sont introuvables.',
        code: 'MEMBER_NOT_FOUND',
      });
    }

    const existing = await this.prisma.teachingListener.findMany({
      where: { teachingId: id, memberId: { in: dto.memberIds } },
      select: { id: true, memberId: true },
    });

    const known = new Set(existing.map((row) => row.memberId));

    await this.prisma.$transaction(async (tx) => {
      await tx.teachingListener.updateMany({
        where: { teachingId: id, memberId: { in: [...known] } },
        data: { deletedAt: null },
      });

      const toCreate = dto.memberIds.filter((memberId) => !known.has(memberId));

      if (toCreate.length > 0) {
        await tx.teachingListener.createMany({
          data: toCreate.map((memberId) => ({
            teachingId: id,
            memberId,
            createdBy: actorUserId,
          })),
        });
      }
    });

    return this.findOne(id);
  }

  async removeListener(id: string, memberId: string) {
    const listener = await this.prisma.teachingListener.findUnique({
      where: { teachingId_memberId: { teachingId: id, memberId } },
      select: { id: true },
    });

    if (!listener) {
      throw new NotFoundException({
        message: "Ce membre ne figure pas parmi les auditeurs.",
        code: 'LISTENER_NOT_FOUND',
      });
    }

    await this.prisma.teachingListener.update({
      where: { id: listener.id },
      data: { deletedAt: new Date() },
    });

    return { message: 'Auditeur retiré.' };
  }

  // ===========================================================================
  // Tâches de montage
  // ===========================================================================

  /**
   * Crée les trois tâches de montage pour le département Média.
   *
   * L'échéance est calculée depuis la date de l'enseignement, avec le délai
   * configuré (dix jours par défaut).
   *
   * Aucune assignation n'est faite : c'est au responsable du département de
   * répartir le travail. Assigner automatiquement risquerait de charger
   * quelqu'un qui est déjà au-dessus du seuil de pénalités.
   */
  private async generateMediaTasks(
    teachingId: string,
    teachingDate: Date,
  ): Promise<number> {
    const department = await this.prisma.department.findFirst({
      where: {
        ...NOT_DELETED,
        isActive: true,
        OR: TeachingsService.MEDIA_DEPARTMENT_NAMES.map((name) => ({
          name: { equals: name, mode: 'insensitive' as const },
        })),
      },
      select: { id: true, name: true },
    });

    if (!department) {
      this.logger.warn(
        'Département Média introuvable : les tâches de montage ne sont pas ' +
          'créées. Créez un département nommé « Média » pour activer cet ' +
          'automatisme.',
      );
      return 0;
    }

    const settings = await this.penalties.getSettings();
    const dueDate = this.addDays(teachingDate, settings.teachingTaskDueOffsetDays);

    const teaching = await this.prisma.teaching.findUnique({
      where: { id: teachingId },
      select: { title: true },
    });

    await this.prisma.task.createMany({
      data: MEDIA_TASK_FORMATS.map((format, index) => ({
        title: `${format.label} — ${teaching?.title ?? 'enseignement'}`,
        departmentId: department.id,
        teachingId,
        teachingTaskType: format.type,
        teachingTaskIndex: index,
        dueDate,
        priority: 'medium' as const,
        status: 'pending' as const,
      })),
    });

    return MEDIA_TASK_FORMATS.length;
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private addDays(date: Date, days: number): Date {
    const result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
  }

  private async assertExists(id: string): Promise<void> {
    const teaching = await this.prisma.teaching.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true },
    });

    if (!teaching) {
      throw this.notFound(id);
    }
  }

  private notFound(id: string): NotFoundException {
    return new NotFoundException({
      message: `Aucun enseignement ne correspond à l'identifiant ${id}.`,
      code: 'TEACHING_NOT_FOUND',
    });
  }
}