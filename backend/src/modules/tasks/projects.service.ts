import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import type {
  CreateProjectDto,
  CreateTagDto,
  UpdateProjectDto,
  UpdateTagDto,
} from './dto/task.dto';

@Injectable()
export class ProjectsService {
  constructor(private readonly prisma: PrismaService) {}

  // ===========================================================================
  // Projets
  // ===========================================================================

  async findAllProjects(departmentId?: string) {
    return this.prisma.project.findMany({
      where: {
        ...NOT_DELETED,
        ...(departmentId ? { departmentId } : {}),
      },
      orderBy: [{ endDate: { sort: 'asc', nulls: 'last' } }, { title: 'asc' }],
      include: {
        department: { select: { id: true, name: true } },
        personInCharge: {
          select: { id: true, firstName: true, lastName: true, photoUrl: true },
        },
        _count: { select: { tasks: { where: { deletedAt: null } } } },
      },
    });
  }

  async findOneProject(id: string) {
    const project = await this.prisma.project.findFirst({
      where: { id, ...NOT_DELETED },
      include: {
        department: { select: { id: true, name: true } },
        personInCharge: {
          select: { id: true, firstName: true, lastName: true, photoUrl: true },
        },
        tasks: {
          where: { deletedAt: null },
          select: {
            id: true,
            title: true,
            status: true,
            priority: true,
            dueDate: true,
          },
          orderBy: { dueDate: { sort: 'asc', nulls: 'last' } },
        },
      },
    });

    if (!project) {
      throw this.projectNotFound(id);
    }

    // Le taux d'avancement est calculé à la lecture plutôt que stocké : le
    // maintenir en base imposerait de le recalculer à chaque changement de
    // statut, avec le risque de le laisser dériver.
    const completed = project.tasks.filter(
      (task) => task.status === 'completed',
    ).length;

    return {
      ...project,
      progress: {
        total: project.tasks.length,
        completed,
        percentage:
          project.tasks.length > 0
            ? Math.round((completed / project.tasks.length) * 100)
            : 0,
      },
    };
  }

  async createProject(dto: CreateProjectDto) {
    await this.assertDepartmentExists(dto.departmentId);

    if (dto.personInChargeId) {
      await this.assertMemberExists(dto.personInChargeId);
    }

    return this.prisma.project.create({
      data: {
        title: dto.title,
        departmentId: dto.departmentId,
        personInChargeId: dto.personInChargeId ?? null,
        endDate: dto.endDate ? new Date(dto.endDate) : null,
        priority: dto.priority ?? 'medium',
        description: dto.description ?? null,
      } as Prisma.ProjectUncheckedCreateInput,
      include: { department: { select: { id: true, name: true } } },
    });
  }

  async updateProject(id: string, dto: UpdateProjectDto) {
    await this.assertProjectExists(id);

    if (dto.departmentId) {
      await this.assertDepartmentExists(dto.departmentId);
    }
    if (dto.personInChargeId) {
      await this.assertMemberExists(dto.personInChargeId);
    }

    const { endDate, ...rest } = dto;

    return this.prisma.project.update({
      where: { id },
      data: {
        ...rest,
        ...(endDate !== undefined
          ? { endDate: endDate ? new Date(endDate) : null }
          : {}),
      } as Prisma.ProjectUncheckedUpdateInput,
    });
  }

  /**
   * Suppression logique d'un projet.
   *
   * Les tâches rattachées ne sont pas supprimées : elles restent à faire, le
   * regroupement disparaît simplement. `projectId` passe à `null` plutôt que
   * de pointer vers un projet invisible.
   */
  async removeProject(id: string) {
    await this.assertProjectExists(id);

    await this.prisma.$transaction([
      this.prisma.task.updateMany({
        where: { projectId: id },
        data: { projectId: null },
      }),
      this.prisma.project.update({
        where: { id },
        data: { deletedAt: new Date() },
      }),
    ]);

    return { message: 'Projet supprimé. Les tâches associées sont conservées.', id };
  }

  // ===========================================================================
  // Étiquettes
  // ===========================================================================

  async findAllTags(departmentId?: string) {
    return this.prisma.tag.findMany({
      where: departmentId ? { departmentId } : {},
      orderBy: { name: 'asc' },
      include: {
        department: { select: { id: true, name: true } },
        _count: { select: { taskTags: true } },
      },
    });
  }

  async createTag(dto: CreateTagDto) {
    await this.assertDepartmentExists(dto.departmentId);

    const existing = await this.prisma.tag.findUnique({
      where: {
        departmentId_name: { departmentId: dto.departmentId, name: dto.name },
      },
      select: { id: true },
    });

    if (existing) {
      throw new ConflictException({
        message: 'Une étiquette porte déjà ce nom dans ce département.',
        code: 'TAG_NAME_TAKEN',
      });
    }

    return this.prisma.tag.create({
      data: {
        name: dto.name,
        departmentId: dto.departmentId,
        color: dto.color ?? null,
      },
    });
  }

  async updateTag(id: string, dto: UpdateTagDto) {
    const tag = await this.prisma.tag.findUnique({
      where: { id },
      select: { id: true, departmentId: true, name: true },
    });

    if (!tag) {
      throw new NotFoundException({
        message: 'Étiquette introuvable.',
        code: 'TAG_NOT_FOUND',
      });
    }

    if (dto.name && dto.name !== tag.name) {
      const duplicate = await this.prisma.tag.findUnique({
        where: {
          departmentId_name: {
            departmentId: dto.departmentId ?? tag.departmentId,
            name: dto.name,
          },
        },
        select: { id: true },
      });

      if (duplicate) {
        throw new ConflictException({
          message: 'Une étiquette porte déjà ce nom dans ce département.',
          code: 'TAG_NAME_TAKEN',
        });
      }
    }

    return this.prisma.tag.update({ where: { id }, data: dto });
  }

  /**
   * Suppression définitive d'une étiquette.
   *
   * Les étiquettes n'ont pas de suppression logique : ce sont de simples
   * libellés sans valeur historique. Les liaisons vers les tâches disparaissent
   * en cascade, ce qui est le comportement attendu — une tâche perd son
   * étiquette, rien de plus.
   */
  async removeTag(id: string) {
    const tag = await this.prisma.tag.findUnique({
      where: { id },
      select: { id: true, name: true },
    });

    if (!tag) {
      throw new NotFoundException({
        message: 'Étiquette introuvable.',
        code: 'TAG_NOT_FOUND',
      });
    }

    await this.prisma.tag.delete({ where: { id } });

    return { message: 'Étiquette supprimée.', id };
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private async assertProjectExists(id: string): Promise<void> {
    const project = await this.prisma.project.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true },
    });

    if (!project) {
      throw this.projectNotFound(id);
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

  private projectNotFound(id: string): NotFoundException {
    return new NotFoundException({
      message: `Aucun projet ne correspond à l'identifiant ${id}.`,
      code: 'PROJECT_NOT_FOUND',
    });
  }
}