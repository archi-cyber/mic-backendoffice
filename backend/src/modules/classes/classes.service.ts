import {
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { buildPaginationMeta } from '../../common/dto/pagination.dto';
import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import type {
  CreateClassDto,
  EnrollMembersDto,
  FindClassesDto,
  GenerateSessionsDto,
  MarkSessionAttendanceDto,
  UpdateClassDto,
} from './dto/class.dto';

@Injectable()
export class ClassesService {
  private readonly logger = new Logger(ClassesService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ===========================================================================
  // Formations
  // ===========================================================================

  async findAll(query: FindClassesDto) {
    const where: Prisma.ClassWhereInput = {
      ...NOT_DELETED,
      isActive: query.isActive ?? true,
      ...(query.departmentId ? { departmentId: query.departmentId } : {}),
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
      this.prisma.class.findMany({
        where,
        orderBy: { name: 'asc' },
        skip: query.skip,
        take: query.take,
        include: {
          department: { select: { id: true, name: true } },
          _count: { select: { members: true, sessions: true } },
        },
      }),
      this.prisma.class.count({ where }),
    ]);

    return {
      data: items,
      meta: buildPaginationMeta(total, query.page, query.limit),
    };
  }

  async findOne(id: string) {
    const training = await this.prisma.class.findFirst({
      where: { id, ...NOT_DELETED },
      include: {
        department: { select: { id: true, name: true } },
        members: {
          select: {
            id: true,
            enrolledAt: true,
            member: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                photoUrl: true,
              },
            },
          },
        },
        sessions: {
          orderBy: { sessionDate: 'asc' },
          select: {
            id: true,
            sessionDate: true,
            _count: { select: { attendances: true } },
          },
        },
      },
    });

    if (!training) {
      throw this.notFound(id);
    }

    return training;
  }

  async create(dto: CreateClassDto) {
    if (dto.departmentId) {
      await this.assertDepartmentExists(dto.departmentId);
    }

    return this.prisma.class.create({
      data: {
        name: dto.name,
        description: dto.description ?? null,
        departmentId: dto.departmentId ?? null,
        isActive: dto.isActive ?? true,
      } as Prisma.ClassUncheckedCreateInput,
    });
  }

  async update(id: string, dto: UpdateClassDto) {
    await this.assertExists(id);

    if (dto.departmentId) {
      await this.assertDepartmentExists(dto.departmentId);
    }

    return this.prisma.class.update({
      where: { id },
      data: dto as Prisma.ClassUncheckedUpdateInput,
    });
  }

  async remove(id: string) {
    await this.assertExists(id);

    await this.prisma.class.update({
      where: { id },
      data: { deletedAt: new Date(), isActive: false },
    });

    return { message: 'Formation supprimée.', id };
  }

  // ===========================================================================
  // Inscriptions
  // ===========================================================================

  async enroll(id: string, dto: EnrollMembersDto) {
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

    const existing = await this.prisma.classMember.findMany({
      where: { classId: id, memberId: { in: dto.memberIds } },
      select: { memberId: true },
    });

    const known = new Set(existing.map((row) => row.memberId));
    const toCreate = dto.memberIds.filter((memberId) => !known.has(memberId));

    if (toCreate.length > 0) {
      await this.prisma.classMember.createMany({
        data: toCreate.map((memberId) => ({
          classId: id,
          memberId,
          enrolledAt: new Date(),
        })),
      });
    }

    return {
      message: `${toCreate.length} inscription(s) enregistrée(s).`,
      enrolled: toCreate.length,
      alreadyEnrolled: known.size,
    };
  }

  async unenroll(id: string, memberId: string) {
    const enrollment = await this.prisma.classMember.findUnique({
      where: { classId_memberId: { classId: id, memberId } },
      select: { id: true },
    });

    if (!enrollment) {
      throw new NotFoundException({
        message: "Ce membre n'est pas inscrit à cette formation.",
        code: 'NOT_ENROLLED',
      });
    }

    // Les présences déjà enregistrées sont conservées : elles attestent d'une
    // participation réelle, utile pour délivrer une attestation même si la
    // personne a quitté la formation en cours de route.
    await this.prisma.classMember.delete({ where: { id: enrollment.id } });

    return { message: 'Inscription retirée.' };
  }

  // ===========================================================================
  // Séances
  // ===========================================================================

  /**
   * Génère les séances à intervalle régulier.
   *
   * Les dates déjà occupées sont ignorées plutôt que de provoquer une erreur :
   * relancer la génération pour prolonger un cycle est un usage courant, et
   * échouer sur la première collision obligerait à tout recalculer à la main.
   */
  async generateSessions(id: string, dto: GenerateSessionsDto) {
    await this.assertExists(id);

    const weeks = dto.weeksBetween ?? 1;
    const start = new Date(dto.startDate);

    const dates = Array.from({ length: dto.count }, (_, index) => {
      const date = new Date(start);
      date.setDate(date.getDate() + index * weeks * 7);
      return date;
    });

    const existing = await this.prisma.session.findMany({
      where: { classId: id, sessionDate: { in: dates } },
      select: { sessionDate: true },
    });

    const taken = new Set(existing.map((row) => row.sessionDate.getTime()));
    const toCreate = dates.filter((date) => !taken.has(date.getTime()));

    if (toCreate.length > 0) {
      await this.prisma.session.createMany({
        data: toCreate.map((sessionDate) => ({ classId: id, sessionDate })),
      });
    }

    this.logger.log(
      `Formation ${id} : ${toCreate.length} séance(s) créée(s), ` +
        `${taken.size} déjà existante(s).`,
    );

    return {
      message: `${toCreate.length} séance(s) générée(s).`,
      created: toCreate.length,
      skipped: taken.size,
    };
  }

  /** Feuille de présence d'une séance. */
  async findSession(sessionId: string) {
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      include: {
        class: {
          select: {
            id: true,
            name: true,
            members: {
              select: {
                member: {
                  select: {
                    id: true,
                    firstName: true,
                    lastName: true,
                    photoUrl: true,
                  },
                },
              },
            },
          },
        },
        attendances: {
          select: { memberId: true, status: true, notes: true },
        },
      },
    });

    if (!session) {
      throw new NotFoundException({
        message: 'Séance introuvable.',
        code: 'SESSION_NOT_FOUND',
      });
    }

    const marked = new Map(
      session.attendances.map((entry) => [entry.memberId, entry]),
    );

    return {
      id: session.id,
      sessionDate: session.sessionDate,
      class: { id: session.class.id, name: session.class.name },
      // Seuls les inscrits figurent sur la feuille : contrairement au culte,
      // une formation a une liste fermée.
      sheet: session.class.members.map((enrollment) => {
        const entry = marked.get(enrollment.member.id);
        return {
          ...enrollment.member,
          status: entry?.status ?? null,
          notes: entry?.notes ?? null,
        };
      }),
    };
  }

  async deleteSession(sessionId: string) {
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      select: { id: true },
    });

    if (!session) {
      throw new NotFoundException({
        message: 'Séance introuvable.',
        code: 'SESSION_NOT_FOUND',
      });
    }

    // Suppression physique : les séances n'ont pas de colonne deletedAt, et
    // les présences suivent en cascade au niveau de la base.
    await this.prisma.session.delete({ where: { id: sessionId } });

    return { message: 'Séance supprimée.', id: sessionId };
  }

  // ===========================================================================
  // Présence
  // ===========================================================================

  async markSessionAttendance(
    sessionId: string,
    dto: MarkSessionAttendanceDto,
  ) {
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      select: { id: true, classId: true },
    });

    if (!session) {
      throw new NotFoundException({
        message: 'Séance introuvable.',
        code: 'SESSION_NOT_FOUND',
      });
    }

    const memberIds = dto.entries.map((entry) => entry.memberId);

    // Seuls les inscrits peuvent être pointés : accepter n'importe qui
    // fausserait les taux d'assiduité de la formation.
    const enrolled = await this.prisma.classMember.count({
      where: { classId: session.classId, memberId: { in: memberIds } },
    });

    if (enrolled !== new Set(memberIds).size) {
      throw new ConflictException({
        message:
          'Un ou plusieurs membres ne sont pas inscrits à cette formation.',
        code: 'NOT_ENROLLED',
      });
    }

    await this.prisma.$transaction(async (tx) => {
      const existing = await tx.attendance.findMany({
        where: { sessionId, memberId: { in: memberIds } },
        select: { id: true, memberId: true },
      });

      const byMember = new Map(existing.map((row) => [row.memberId, row.id]));

      for (const entry of dto.entries) {
        const existingId = byMember.get(entry.memberId);

        if (existingId) {
          await tx.attendance.update({
            where: { id: existingId },
            data: { status: entry.status, notes: entry.notes ?? null },
          });
        } else {
          await tx.attendance.create({
            data: {
              sessionId,
              memberId: entry.memberId,
              status: entry.status,
              notes: entry.notes ?? null,
            },
          });
        }
      }
    });

    return {
      message: 'Présence enregistrée.',
      recorded: dto.entries.length,
    };
  }

  /** Taux d'assiduité de chaque inscrit sur l'ensemble des séances. */
  async getClassReport(id: string) {
    const training = await this.prisma.class.findFirst({
      where: { id, ...NOT_DELETED },
      include: {
        members: {
          select: {
            member: { select: { id: true, firstName: true, lastName: true } },
          },
        },
        sessions: { select: { id: true, sessionDate: true } },
      },
    });

    if (!training) {
      throw this.notFound(id);
    }

    const sessionIds = training.sessions.map((session) => session.id);

    const attendances =
      sessionIds.length > 0
        ? await this.prisma.attendance.findMany({
            where: { sessionId: { in: sessionIds } },
            select: { memberId: true, status: true },
          })
        : [];

    const totalSessions = training.sessions.length;

    return {
      class: { id: training.id, name: training.name },
      totalSessions,
      members: training.members.map((enrollment) => {
        const own = attendances.filter(
          (entry) => entry.memberId === enrollment.member.id,
        );
        const present = own.filter(
          (entry) => entry.status === 'present' || entry.status === 'late',
        ).length;

        return {
          ...enrollment.member,
          present,
          absent: own.filter((entry) => entry.status === 'absent').length,
          excused: own.filter((entry) => entry.status === 'excused').length,
          attendanceRate:
            totalSessions > 0 ? Math.round((present / totalSessions) * 100) : 0,
        };
      }),
    };
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private async assertExists(id: string): Promise<void> {
    const training = await this.prisma.class.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true },
    });

    if (!training) {
      throw this.notFound(id);
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

  private notFound(id: string): NotFoundException {
    return new NotFoundException({
      message: `Aucune formation ne correspond à l'identifiant ${id}.`,
      code: 'CLASS_NOT_FOUND',
    });
  }
}