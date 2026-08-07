import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { buildPaginationMeta } from '../../common/dto/pagination.dto';
import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import {
  isPrivilegedRole,
  type AuthenticatedUser,
} from '../auth/types/auth.types';
import type {
  AddDepartmentMemberDto,
  CreateDepartmentDto,
  CreateDepartmentReportDto,
  FindDepartmentsDto,
  UpdateDepartmentDto,
  UpdateDepartmentMemberDto,
  UpdateDepartmentReportDto,
} from './dto/department.dto';

@Injectable()
export class DepartmentsService {
  private readonly logger = new Logger(DepartmentsService.name);

  /**
   * Département dont le nom conditionne l'accès aux données financières.
   *
   * La comparaison reprend celle de l'ancienne fonction SQL
   * `is_finance_leader()` : insensible à la casse et aux espaces.
   */
  private static readonly FINANCE_DEPARTMENT = 'finance';

  constructor(private readonly prisma: PrismaService) {}

  // ===========================================================================
  // Départements
  // ===========================================================================

  async findAll(query: FindDepartmentsDto) {
    const where: Prisma.DepartmentWhereInput = {
      ...NOT_DELETED,
      isActive: query.isActive ?? true,
      ...(query.search
        ? {
            OR: [
              { name: { contains: query.search, mode: 'insensitive' } },
              { description: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.department.findMany({
        where,
        orderBy: query.orderBy
          ? { [query.orderBy]: query.order }
          : { name: 'asc' },
        skip: query.skip,
        take: query.take,
        // Les responsables sont inclus d'office : la liste des départements
        // les affiche systématiquement, et les charger séparément imposerait
        // une requête par département.
        include: {
          departmentMembers: {
            where: { role: { in: ['leader', 'subleader'] } },
            select: {
              role: true,
              member: {
                select: { id: true, firstName: true, lastName: true },
              },
            },
          },
          ...(query.withCounts
            ? {
                _count: {
                  select: {
                    departmentMembers: true,
                    projects: true,
                    tasks: { where: { deletedAt: null } },
                  },
                },
              }
            : {}),
        },
      }),
      this.prisma.department.count({ where }),
    ]);

    return {
      data: items,
      meta: buildPaginationMeta(total, query.page, query.limit),
    };
  }

  async findOne(id: string) {
    const department = await this.prisma.department.findFirst({
      where: { id, ...NOT_DELETED },
      include: {
        departmentMembers: {
          // Les responsables d'abord, puis les adjoints, puis les membres :
          // c'est l'ordre attendu à l'affichage d'un organigramme.
          orderBy: [{ role: 'asc' }, { createdAt: 'asc' }],
          select: {
            id: true,
            role: true,
            isMain: true,
            createdAt: true,
            member: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                phone: true,
                email: true,
                photoUrl: true,
                isActive: true,
              },
            },
          },
        },
        _count: {
          select: {
            projects: true,
            tasks: { where: { deletedAt: null } },
            reports: { where: { deletedAt: null } },
          },
        },
      },
    });

    if (!department) {
      throw this.notFound(id);
    }

    return department;
  }

  async create(dto: CreateDepartmentDto) {
    await this.assertNameAvailable(dto.name);

    const department = await this.prisma.department.create({ data: dto });

    this.logger.log(`Département créé : ${department.name}`);

    return department;
  }

  async update(id: string, dto: UpdateDepartmentDto) {
    const existing = await this.prisma.department.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, name: true },
    });

    if (!existing) {
      throw this.notFound(id);
    }

    if (dto.name && dto.name !== existing.name) {
      await this.assertNameAvailable(dto.name, id);
      this.assertFinanceNotRenamed(existing.name, dto.name);
    }

    return this.prisma.department.update({ where: { id }, data: dto });
  }

  /**
   * Suppression logique d'un département.
   *
   * Les appartenances sont conservées : elles documentent l'historique
   * d'affectation. En revanche, tout membre dont c'était le département
   * principal se retrouve sans rattachement — d'où la remise à zéro de
   * `members.department_id`, faute de quoi la fiche pointerait vers un
   * département invisible.
   */
  async remove(id: string) {
    const department = await this.prisma.department.findFirst({
      where: { id, ...NOT_DELETED },
      select: {
        id: true,
        name: true,
        _count: { select: { departmentMembers: true } },
      },
    });

    if (!department) {
      throw this.notFound(id);
    }

    this.assertFinanceNotDeleted(department.name);

    await this.prisma.$transaction(async (tx) => {
      await tx.department.update({
        where: { id },
        data: { deletedAt: new Date(), isActive: false },
      });

      await tx.member.updateMany({
        where: { departmentId: id },
        data: { departmentId: null },
      });
    });

    this.logger.log(
      `Département supprimé : ${department.name} ` +
        `(${department._count.departmentMembers} appartenance(s) conservée(s))`,
    );

    return { message: 'Département supprimé.', id };
  }

  // ===========================================================================
  // Appartenances
  // ===========================================================================

  async addMember(departmentId: string, dto: AddDepartmentMemberDto) {
    await this.assertExists(departmentId);
    await this.assertMemberExists(dto.memberId);

    const duplicate = await this.prisma.departmentMember.findUnique({
      where: {
        departmentId_memberId: { departmentId, memberId: dto.memberId },
      },
      select: { id: true },
    });

    if (duplicate) {
      throw new ConflictException({
        message: 'Ce membre appartient déjà à ce département.',
        code: 'ALREADY_IN_DEPARTMENT',
      });
    }

    return this.prisma.$transaction(async (tx) => {
      if (dto.isMain) {
        await this.demoteCurrentMain(tx, dto.memberId);
        await tx.member.update({
          where: { id: dto.memberId },
          data: { departmentId },
        });
      }

      return tx.departmentMember.create({
        data: {
          departmentId,
          memberId: dto.memberId,
          role: dto.role ?? 'member',
          isMain: dto.isMain ?? false,
        },
        include: {
          member: {
            select: { id: true, firstName: true, lastName: true, photoUrl: true },
          },
        },
      });
    });
  }

  async updateMember(
    departmentId: string,
    memberId: string,
    dto: UpdateDepartmentMemberDto,
  ) {
    const membership = await this.prisma.departmentMember.findUnique({
      where: { departmentId_memberId: { departmentId, memberId } },
      select: { id: true, isMain: true },
    });

    if (!membership) {
      throw new NotFoundException({
        message: "Ce membre n'appartient pas à ce département.",
        code: 'NOT_IN_DEPARTMENT',
      });
    }

    return this.prisma.$transaction(async (tx) => {
      // Promotion en département principal : l'unicité impose de dégrader
      // l'ancien avant d'écrire le nouveau, sinon l'index partiel rejette
      // l'opération.
      if (dto.isMain === true && !membership.isMain) {
        await this.demoteCurrentMain(tx, memberId);
        await tx.member.update({
          where: { id: memberId },
          data: { departmentId },
        });
      }

      if (dto.isMain === false && membership.isMain) {
        await tx.member.update({
          where: { id: memberId },
          data: { departmentId: null },
        });
      }

      return tx.departmentMember.update({
        where: { id: membership.id },
        data: {
          ...(dto.role !== undefined ? { role: dto.role } : {}),
          ...(dto.isMain !== undefined ? { isMain: dto.isMain } : {}),
        },
        include: {
          member: { select: { id: true, firstName: true, lastName: true } },
        },
      });
    });
  }

  async removeMember(departmentId: string, memberId: string) {
    const membership = await this.prisma.departmentMember.findUnique({
      where: { departmentId_memberId: { departmentId, memberId } },
      select: { id: true, isMain: true, role: true },
    });

    if (!membership) {
      throw new NotFoundException({
        message: "Ce membre n'appartient pas à ce département.",
        code: 'NOT_IN_DEPARTMENT',
      });
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.departmentMember.delete({ where: { id: membership.id } });

      if (membership.isMain) {
        await tx.member.update({
          where: { id: memberId },
          data: { departmentId: null },
        });
      }
    });

    // Retirer un responsable est une opération sensible : elle peut priver le
    // département de toute direction, et retire au passage l'accès Finance si
    // c'était le cas.
    if (membership.role === 'leader') {
      this.logger.warn(
        `Responsable retiré du département ${departmentId} : vérifier qu'un ` +
          'autre responsable est en place.',
      );
    }

    return { message: 'Membre retiré du département.' };
  }

  // ===========================================================================
  // Rapports
  // ===========================================================================

  async findReports(departmentId: string, page = 1, limit = 20) {
    await this.assertExists(departmentId);

    const where: Prisma.DepartmentReportWhereInput = {
      departmentId,
      ...NOT_DELETED,
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.departmentReport.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: {
          author: {
            select: {
              id: true,
              email: true,
              member: { select: { firstName: true, lastName: true } },
            },
          },
        },
      }),
      this.prisma.departmentReport.count({ where }),
    ]);

    return { data: items, meta: buildPaginationMeta(total, page, limit) };
  }

  async createReport(
    departmentId: string,
    dto: CreateDepartmentReportDto,
    authorUserId: string,
  ) {
    await this.assertExists(departmentId);

    return this.prisma.departmentReport.create({
      data: { ...dto, departmentId, createdBy: authorUserId },
      include: {
        author: {
          select: {
            id: true,
            member: { select: { firstName: true, lastName: true } },
          },
        },
      },
    });
  }

  /**
   * Modification d'un rapport.
   *
   * Seul l'auteur peut modifier son rapport — ou un administrateur. Un rapport
   * d'activité engage celui qui le signe : permettre à un tiers de le réécrire
   * lui ferait endosser des propos qui ne sont pas les siens.
   */
  async updateReport(
    reportId: string,
    dto: UpdateDepartmentReportDto,
    actor: AuthenticatedUser,
  ) {
    const report = await this.prisma.departmentReport.findFirst({
      where: { id: reportId, ...NOT_DELETED },
      select: { id: true, createdBy: true },
    });

    if (!report) {
      throw new NotFoundException({
        message: 'Rapport introuvable.',
        code: 'REPORT_NOT_FOUND',
      });
    }

    this.assertCanEditReport(report.createdBy, actor);

    return this.prisma.departmentReport.update({
      where: { id: reportId },
      data: dto,
    });
  }

  async removeReport(reportId: string, actor: AuthenticatedUser) {
    const report = await this.prisma.departmentReport.findFirst({
      where: { id: reportId, ...NOT_DELETED },
      select: { id: true, createdBy: true },
    });

    if (!report) {
      throw new NotFoundException({
        message: 'Rapport introuvable.',
        code: 'REPORT_NOT_FOUND',
      });
    }

    this.assertCanEditReport(report.createdBy, actor);

    await this.prisma.departmentReport.update({
      where: { id: reportId },
      data: { deletedAt: new Date() },
    });

    return { message: 'Rapport supprimé.', id: reportId };
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  /** Retire le drapeau « principal » de l'appartenance courante, s'il y en a une. */
  private async demoteCurrentMain(
    tx: Prisma.TransactionClient,
    memberId: string,
  ): Promise<void> {
    await tx.departmentMember.updateMany({
      where: { memberId, isMain: true },
      data: { isMain: false },
    });
  }

  private assertCanEditReport(
    authorUserId: string,
    actor: AuthenticatedUser,
  ): void {
    if (authorUserId !== actor.id && !isPrivilegedRole(actor.role)) {
      throw new ForbiddenException({
        message: 'Seul l\'auteur du rapport ou un administrateur peut le modifier.',
        code: 'NOT_REPORT_AUTHOR',
      });
    }
  }

  /**
   * Interdit de renommer le département Finance.
   *
   * L'accès au module financier repose sur ce nom exact. Le renommer
   * couperait silencieusement l'accès aux trésoriers, sans message d'erreur
   * nulle part — un incident très difficile à diagnostiquer.
   */
  private assertFinanceNotRenamed(currentName: string, newName: string): void {
    const isFinance =
      currentName.trim().toLowerCase() === DepartmentsService.FINANCE_DEPARTMENT;

    if (isFinance && newName.trim().toLowerCase() !== DepartmentsService.FINANCE_DEPARTMENT) {
      throw new BadRequestException({
        message:
          'Le département « Finance » ne peut pas être renommé : l\'accès au ' +
          'module financier dépend de ce nom.',
        code: 'FINANCE_DEPARTMENT_PROTECTED',
      });
    }
  }

  private assertFinanceNotDeleted(name: string): void {
    if (name.trim().toLowerCase() === DepartmentsService.FINANCE_DEPARTMENT) {
      throw new BadRequestException({
        message:
          'Le département « Finance » ne peut pas être supprimé : seuls les ' +
          'administrateurs auraient alors accès aux données financières.',
        code: 'FINANCE_DEPARTMENT_PROTECTED',
      });
    }
  }

  private async assertNameAvailable(name: string, excludeId?: string): Promise<void> {
    const existing = await this.prisma.department.findFirst({
      where: {
        name: { equals: name, mode: 'insensitive' },
        ...NOT_DELETED,
        ...(excludeId ? { id: { not: excludeId } } : {}),
      },
      select: { id: true },
    });

    if (existing) {
      throw new ConflictException({
        message: 'Un département porte déjà ce nom.',
        code: 'DEPARTMENT_NAME_TAKEN',
      });
    }
  }

  private async assertExists(id: string): Promise<void> {
    const department = await this.prisma.department.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true },
    });

    if (!department) {
      throw this.notFound(id);
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

  private notFound(id: string): NotFoundException {
    return new NotFoundException({
      message: `Aucun département ne correspond à l'identifiant ${id}.`,
      code: 'DEPARTMENT_NOT_FOUND',
    });
  }
}