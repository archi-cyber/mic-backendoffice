import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { buildPaginationMeta } from '../../common/dto/pagination.dto';
import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import type {
  AssignTaskDto,
  CreateTaskDto,
  FindTasksDto,
  SetTaskTagsDto,
  UpdateTaskDto,
} from './dto/task.dto';
import { PenaltiesService } from './penalties.service';

const TASK_INCLUDE = {
  department: { select: { id: true, name: true } },
  member: { select: { id: true, firstName: true, lastName: true } },
  project: { select: { id: true, title: true } },
  assignments: {
    select: {
      id: true,
      status: true,
      assignedAt: true,
      member: {
        select: { id: true, firstName: true, lastName: true, photoUrl: true },
      },
    },
  },
  tags: {
    select: { tag: { select: { id: true, name: true, color: true } } },
  },
} satisfies Prisma.TaskInclude;

@Injectable()
export class TasksService {
  private readonly logger = new Logger(TasksService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly penalties: PenaltiesService,
  ) {}

  // ===========================================================================
  // Lecture
  // ===========================================================================

  async findAll(query: FindTasksDto) {
    const where = this.buildWhere(query);

    const [items, total] = await this.prisma.$transaction([
      this.prisma.task.findMany({
        where,
        include: TASK_INCLUDE,
        orderBy: query.orderBy
          ? { [query.orderBy]: query.order }
          : // Les échéances les plus proches d'abord ; les tâches sans date
            // en dernier, faute de repère pour les classer.
            [{ dueDate: { sort: 'asc', nulls: 'last' } }, { createdAt: 'desc' }],
        skip: query.skip,
        take: query.take,
      }),
      this.prisma.task.count({ where }),
    ]);

    return {
      data: items.map((task) => this.flattenTags(task)),
      meta: buildPaginationMeta(total, query.page, query.limit),
    };
  }

  async findOne(id: string) {
    const task = await this.prisma.task.findFirst({
      where: { id, ...NOT_DELETED },
      include: {
        ...TASK_INCLUDE,
        penalties: {
          orderBy: { penaltyDate: 'desc' },
          select: { id: true, memberId: true, penaltyDate: true, amount: true },
        },
      },
    });

    if (!task) {
      throw this.notFound(id);
    }

    return this.flattenTags(task);
  }

  /** Tâches assignées à un membre, tous départements confondus. */
  async findByAssignee(memberId: string, query: FindTasksDto) {
    return this.findAll({ ...query, assigneeId: memberId } as FindTasksDto);
  }

  // ===========================================================================
  // Écriture
  // ===========================================================================

  async create(dto: CreateTaskDto) {
    this.assertOwnerExclusive(dto);

    if (dto.departmentId) {
      await this.assertDepartmentExists(dto.departmentId);
    }
    if (dto.projectId) {
      await this.assertProjectExists(dto.projectId);
    }
    if (dto.assigneeIds?.length) {
      await this.assertCanAssign(dto.assigneeIds);
    }
    if (dto.tagIds?.length) {
      await this.assertTagsBelongToDepartment(dto.tagIds, dto.departmentId);
    }

    const task = await this.prisma.$transaction(async (tx) => {
      const created = await tx.task.create({
        data: {
          title: dto.title,
          description: dto.description ?? null,
          departmentId: dto.departmentId ?? null,
          memberId: dto.memberId ?? null,
          projectId: dto.projectId ?? null,
          dueDate: dto.dueDate ? new Date(dto.dueDate) : null,
          priority: dto.priority ?? 'medium',
          status: dto.status ?? 'pending',
          penaltyAmountPerDay: dto.penaltyAmountPerDay ?? null,
        } as Prisma.TaskUncheckedCreateInput,
      });

      if (dto.assigneeIds?.length) {
        await tx.taskAssignment.createMany({
          data: dto.assigneeIds.map((memberId) => ({
            taskId: created.id,
            memberId,
          })),
        });
      }

      if (dto.tagIds?.length) {
        await tx.taskTag.createMany({
          data: dto.tagIds.map((tagId) => ({ taskId: created.id, tagId })),
        });
      }

      return created;
    });

    this.logger.log(`Tâche créée : ${task.title}`);

    return this.findOne(task.id);
  }

  async update(id: string, dto: UpdateTaskDto) {
    const existing = await this.prisma.task.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, departmentId: true, memberId: true, status: true },
    });

    if (!existing) {
      throw this.notFound(id);
    }

    // L'exclusivité département / membre doit rester vraie après fusion des
    // valeurs existantes et des modifications demandées.
    const merged = {
      departmentId:
        dto.departmentId !== undefined ? dto.departmentId : existing.departmentId,
      memberId: dto.memberId !== undefined ? dto.memberId : existing.memberId,
    };
    this.assertOwnerExclusive(merged);

    if (dto.projectId) {
      await this.assertProjectExists(dto.projectId);
    }

    const { assigneeIds, tagIds, dueDate, ...rest } = dto;

    await this.prisma.task.update({
      where: { id },
      data: {
        ...rest,
        ...(dueDate !== undefined
          ? { dueDate: dueDate ? new Date(dueDate) : null }
          : {}),
      } as Prisma.TaskUncheckedUpdateInput,
    });

    return this.findOne(id);
  }

  /**
   * Archive une tâche.
   *
   * L'archivage arrête l'accumulation des pénalités sans effacer celles déjà
   * dues. C'est le geste par lequel un responsable acte qu'une tâche n'a plus
   * lieu d'être suivie — sans pour autant annuler ce qui a été constaté.
   */
  async archive(id: string) {
    await this.assertExists(id);

    const task = await this.prisma.task.update({
      where: { id },
      data: { archivedAt: new Date() },
      select: { id: true, title: true, archivedAt: true },
    });

    this.logger.log(`Tâche archivée : ${task.title}`);

    return task;
  }

  async unarchive(id: string) {
    await this.assertExists(id);

    return this.prisma.task.update({
      where: { id },
      data: { archivedAt: null },
      select: { id: true, title: true, archivedAt: true },
    });
  }

  async remove(id: string) {
    await this.assertExists(id);

    await this.prisma.task.update({
      where: { id },
      data: { deletedAt: new Date() },
    });

    return { message: 'Tâche supprimée.', id };
  }

  // ===========================================================================
  // Assignation
  // ===========================================================================

  /**
   * Assigne la tâche à un ou plusieurs membres.
   *
   * Les membres dont le solde de pénalités atteint le seuil sont refusés.
   * C'est le mécanisme voulu par l'église : accumuler des retards impayés
   * suspend la réception de nouvelles responsabilités.
   */
  async assign(id: string, dto: AssignTaskDto) {
    await this.assertExists(id);
    await this.assertCanAssign(dto.memberIds);

    const existing = await this.prisma.taskAssignment.findMany({
      where: { taskId: id, memberId: { in: dto.memberIds } },
      select: { memberId: true },
    });

    const alreadyAssigned = new Set(existing.map((row) => row.memberId));
    const toCreate = dto.memberIds.filter((memberId) => !alreadyAssigned.has(memberId));

    if (toCreate.length > 0) {
      await this.prisma.taskAssignment.createMany({
        data: toCreate.map((memberId) => ({ taskId: id, memberId })),
      });
    }

    return this.findOne(id);
  }

  async unassign(id: string, memberId: string) {
    const assignment = await this.prisma.taskAssignment.findUnique({
      where: { taskId_memberId: { taskId: id, memberId } },
      select: { id: true },
    });

    if (!assignment) {
      throw new NotFoundException({
        message: "Ce membre n'est pas assigné à cette tâche.",
        code: 'NOT_ASSIGNED',
      });
    }

    // Les pénalités déjà constatées sont conservées : elles sanctionnent un
    // retard qui a réellement eu lieu. Les effacer en retirant l'assignation
    // ouvrirait une échappatoire évidente.
    await this.prisma.taskAssignment.delete({ where: { id: assignment.id } });

    return { message: 'Assignation retirée.' };
  }

  // ===========================================================================
  // Étiquettes
  // ===========================================================================

  async setTags(id: string, dto: SetTaskTagsDto) {
    const task = await this.prisma.task.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, departmentId: true },
    });

    if (!task) {
      throw this.notFound(id);
    }

    if (dto.tagIds.length > 0) {
      await this.assertTagsBelongToDepartment(dto.tagIds, task.departmentId);
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.taskTag.deleteMany({ where: { taskId: id } });

      if (dto.tagIds.length > 0) {
        await tx.taskTag.createMany({
          data: dto.tagIds.map((tagId) => ({ taskId: id, tagId })),
        });
      }
    });

    return this.findOne(id);
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private buildWhere(query: FindTasksDto): Prisma.TaskWhereInput {
    const where: Prisma.TaskWhereInput = { ...NOT_DELETED };

    if (!query.includeArchived) {
      where.archivedAt = null;
    }

    if (query.departmentId) where.departmentId = query.departmentId;
    if (query.projectId) where.projectId = query.projectId;
    if (query.status) where.status = query.status;
    if (query.priority) where.priority = query.priority;

    if (query.assigneeId) {
      where.assignments = { some: { memberId: query.assigneeId } };
    }

    if (query.tagId) {
      where.tags = { some: { tagId: query.tagId } };
    }

    if (query.overdue) {
      where.dueDate = { lt: new Date() };
      where.status = { in: ['pending', 'in_progress'] };
    } else if (query.dueFrom || query.dueTo) {
      where.dueDate = {
        ...(query.dueFrom ? { gte: new Date(query.dueFrom) } : {}),
        ...(query.dueTo ? { lte: new Date(query.dueTo) } : {}),
      };
    }

    if (query.search) {
      where.OR = [
        { title: { contains: query.search, mode: 'insensitive' } },
        { description: { contains: query.search, mode: 'insensitive' } },
      ];
    }

    return where;
  }

  /** Aplatit la table de liaison des étiquettes pour simplifier le client. */
  private flattenTags<T extends { tags: Array<{ tag: unknown }> }>(task: T) {
    return { ...task, tags: task.tags.map((entry) => entry.tag) };
  }

  /**
   * Impose qu'une tâche relève soit d'un département, soit d'une personne.
   *
   * La base porte déjà cette contrainte, mais la vérifier ici produit un
   * message intelligible plutôt qu'une erreur de contrainte PostgreSQL.
   */
  private assertOwnerExclusive(dto: {
    departmentId?: string | null;
    memberId?: string | null;
  }): void {
    const hasDepartment = Boolean(dto.departmentId);
    const hasMember = Boolean(dto.memberId);

    if (hasDepartment && hasMember) {
      throw new BadRequestException({
        message:
          'Une tâche relève soit d\'un département, soit d\'un membre — pas des deux.',
        code: 'TASK_OWNER_CONFLICT',
      });
    }

    if (!hasDepartment && !hasMember) {
      throw new BadRequestException({
        message: 'Une tâche doit être rattachée à un département ou à un membre.',
        code: 'TASK_OWNER_REQUIRED',
      });
    }
  }

  /**
   * Vérifie que les membres visés peuvent recevoir une tâche.
   *
   * Le refus est explicite et nomme les personnes concernées avec leur solde :
   * un message générique laisserait le responsable sans moyen d'agir.
   */
  private async assertCanAssign(memberIds: string[]): Promise<void> {
    const unique = [...new Set(memberIds)];

    const members = await this.prisma.member.findMany({
      where: { id: { in: unique }, ...NOT_DELETED },
      select: { id: true, firstName: true, lastName: true },
    });

    if (members.length !== unique.length) {
      throw new NotFoundException({
        message: 'Un ou plusieurs membres sont introuvables.',
        code: 'MEMBER_NOT_FOUND',
      });
    }

    const balances = await this.penalties.getBalances(unique);

    const blocked = members
      .map((member) => ({ member, balance: balances.get(member.id) }))
      .filter((entry) => entry.balance?.isBlocked);

    if (blocked.length > 0) {
      const details = blocked
        .map(
          (entry) =>
            `${entry.member.firstName} ${entry.member.lastName} ` +
            `(${entry.balance?.balance} frs)`,
        )
        .join(', ');

      throw new ForbiddenException({
        message:
          'Assignation impossible : solde de pénalités trop élevé pour ' +
          `${details}. Enregistrez un versement au préalable.`,
        code: 'PENALTY_THRESHOLD_EXCEEDED',
      });
    }
  }

  private async assertTagsBelongToDepartment(
    tagIds: string[],
    departmentId: string | null | undefined,
  ): Promise<void> {
    if (!departmentId) {
      throw new BadRequestException({
        message:
          'Les étiquettes appartiennent à un département : la tâche doit y ' +
          'être rattachée.',
        code: 'TASK_DEPARTMENT_REQUIRED_FOR_TAGS',
      });
    }

    const count = await this.prisma.tag.count({
      where: { id: { in: [...new Set(tagIds)] }, departmentId },
    });

    if (count !== new Set(tagIds).size) {
      throw new BadRequestException({
        message:
          'Une ou plusieurs étiquettes n\'appartiennent pas au département ' +
          'de cette tâche.',
        code: 'TAG_DEPARTMENT_MISMATCH',
      });
    }
  }

  private async assertDepartmentExists(id: string): Promise<void> {
    const department = await this.prisma.department.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true },
    });

    if (!department) {
      throw new NotFoundException({
        message: 'Département introuvable.',
        code: 'DEPARTMENT_NOT_FOUND',
      });
    }
  }

  private async assertProjectExists(id: string): Promise<void> {
    const project = await this.prisma.project.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true },
    });

    if (!project) {
      throw new NotFoundException({
        message: 'Projet introuvable.',
        code: 'PROJECT_NOT_FOUND',
      });
    }
  }

  private async assertExists(id: string): Promise<void> {
    const task = await this.prisma.task.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true },
    });

    if (!task) {
      throw this.notFound(id);
    }
  }

  private notFound(id: string): NotFoundException {
    return new NotFoundException({
      message: `Aucune tâche ne correspond à l'identifiant ${id}.`,
      code: 'TASK_NOT_FOUND',
    });
  }
}