import {
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import { NOTIFICATION_TYPES, NotificationsService } from '../communications/notifications.service';
import type {
  AddAssignmentDto,
  CreateScheduleDto,
  FindSchedulesDto,
  UpdateScheduleDto,
} from './dto/service-schedule.dto';

/**
 * Planning de service — typiquement l'équipe média.
 *
 * Chaque planning couvre une date et un département, et répartit cinq postes :
 * projection, captation, cadreur principal, cadreur secondaire, photographe.
 */
@Injectable()
export class ServiceSchedulesService {
  private readonly logger = new Logger(ServiceSchedulesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  // ===========================================================================
  // Plannings
  // ===========================================================================

  async findAll(query: FindSchedulesDto) {
    const where: Prisma.ServiceScheduleWhereInput = {
      departmentId: query.departmentId,
      ...(query.from || query.to
        ? {
            serviceDate: {
              ...(query.from ? { gte: new Date(query.from) } : {}),
              ...(query.to ? { lte: new Date(query.to) } : {}),
            },
          }
        : {}),
    };

    return this.prisma.serviceSchedule.findMany({
      where,
      // Les plannings à venir d'abord : c'est le prochain service qui
      // intéresse, pas celui d'il y a six mois.
      orderBy: { serviceDate: 'desc' },
      take: query.limit ?? 200,
      include: {
        assignments: {
          include: {
            member: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                photoUrl: true,
                phone: true,
              },
            },
          },
        },
        creator: {
          select: {
            id: true,
            member: { select: { firstName: true, lastName: true } },
          },
        },
      },
    });
  }

  async findOne(id: string) {
    const schedule = await this.prisma.serviceSchedule.findUnique({
      where: { id },
      include: {
        department: { select: { id: true, name: true } },
        assignments: {
          include: {
            member: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                photoUrl: true,
                phone: true,
              },
            },
          },
        },
      },
    });

    if (!schedule) {
      throw this.notFound(id);
    }

    return schedule;
  }

  /**
   * Crée un planning.
   *
   * Un seul planning par département et par date : la contrainte d'unicité du
   * schéma l'impose, et deux plannings concurrents pour le même service
   * laisseraient l'équipe sans savoir lequel fait foi.
   */
  async create(dto: CreateScheduleDto, actorUserId: string) {
    const serviceDate = new Date(dto.serviceDate);

    const existing = await this.prisma.serviceSchedule.findUnique({
      where: {
        departmentId_serviceDate: {
          departmentId: dto.departmentId,
          serviceDate,
        },
      },
      select: { id: true },
    });

    if (existing) {
      throw new ConflictException({
        message: 'Un planning existe déjà pour ce département à cette date.',
        code: 'SCHEDULE_ALREADY_EXISTS',
      });
    }

    const schedule = await this.prisma.serviceSchedule.create({
      data: {
        departmentId: dto.departmentId,
        serviceDate,
        notes: dto.notes ?? null,
        createdBy: actorUserId,
      },
      include: { assignments: true },
    });

    this.logger.log(`Planning créé pour le ${dto.serviceDate}`);

    return schedule;
  }

  async update(id: string, dto: UpdateScheduleDto) {
    await this.assertExists(id);

    return this.prisma.serviceSchedule.update({
      where: { id },
      data: {
        ...(dto.notes !== undefined ? { notes: dto.notes } : {}),
        ...(dto.serviceDate !== undefined
          ? { serviceDate: new Date(dto.serviceDate) }
          : {}),
      },
    });
  }

  async remove(id: string) {
    await this.assertExists(id);

    // Suppression physique : les assignations suivent en cascade. Un planning
    // n'a pas de valeur historique une fois le service passé, contrairement à
    // une présence ou un don.
    await this.prisma.serviceSchedule.delete({ where: { id } });

    return { message: 'Planning supprimé.', id };
  }

  // ===========================================================================
  // Assignations
  // ===========================================================================

  /**
   * Attribue un poste à un membre.
   *
   * Le membre assigné est notifié : sans cela, il découvrirait son service en
   * arrivant, ou pas du tout.
   */
  async addAssignment(
    scheduleId: string,
    dto: AddAssignmentDto,
    serviceDateLabel?: string,
  ) {
    const schedule = await this.prisma.serviceSchedule.findUnique({
      where: { id: scheduleId },
      select: { id: true, serviceDate: true },
    });

    if (!schedule) {
      throw this.notFound(scheduleId);
    }

    const duplicate = await this.prisma.serviceScheduleAssignment.findUnique({
      where: {
        scheduleId_role_memberId: {
          scheduleId,
          role: dto.role,
          memberId: dto.memberId,
        },
      },
      select: { id: true },
    });

    if (duplicate) {
      throw new ConflictException({
        message: 'Ce membre occupe déjà ce poste sur ce planning.',
        code: 'ASSIGNMENT_ALREADY_EXISTS',
      });
    }

    const assignment = await this.prisma.serviceScheduleAssignment.create({
      data: { scheduleId, role: dto.role, memberId: dto.memberId },
      include: {
        member: { select: { id: true, firstName: true, lastName: true } },
      },
    });

    const label =
      serviceDateLabel ?? schedule.serviceDate.toISOString().slice(0, 10);

    await this.notifications.notify({
      memberId: dto.memberId,
      type: NOTIFICATION_TYPES.eventReminder,
      title: 'Nouveau service programmé',
      message: `Vous êtes assigné au poste « ${dto.role} » pour le service du ${label}.`,
      relatedId: scheduleId,
      relatedType: 'service_schedule',
    });

    return assignment;
  }

  async removeAssignment(assignmentId: string) {
    const assignment = await this.prisma.serviceScheduleAssignment.findUnique({
      where: { id: assignmentId },
      select: { id: true },
    });

    if (!assignment) {
      throw new NotFoundException({
        message: 'Assignation introuvable.',
        code: 'ASSIGNMENT_NOT_FOUND',
      });
    }

    await this.prisma.serviceScheduleAssignment.delete({
      where: { id: assignmentId },
    });

    return { message: 'Assignation retirée.' };
  }

  /** Marque un poste comme assuré, ou revient dessus. */
  async setAssignmentDone(assignmentId: string, isDone: boolean) {
    const assignment = await this.prisma.serviceScheduleAssignment.findUnique({
      where: { id: assignmentId },
      select: { id: true },
    });

    if (!assignment) {
      throw new NotFoundException({
        message: 'Assignation introuvable.',
        code: 'ASSIGNMENT_NOT_FOUND',
      });
    }

    return this.prisma.serviceScheduleAssignment.update({
      where: { id: assignmentId },
      data: { isDone },
      include: {
        member: { select: { id: true, firstName: true, lastName: true } },
      },
    });
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private async assertExists(id: string): Promise<void> {
    const schedule = await this.prisma.serviceSchedule.findUnique({
      where: { id },
      select: { id: true },
    });

    if (!schedule) {
      throw this.notFound(id);
    }
  }

  private notFound(id: string): NotFoundException {
    return new NotFoundException({
      message: `Aucun planning ne correspond à l'identifiant ${id}.`,
      code: 'SCHEDULE_NOT_FOUND',
    });
  }
}