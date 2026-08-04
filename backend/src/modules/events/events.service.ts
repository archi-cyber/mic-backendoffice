import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { buildPaginationMeta } from '../../common/dto/pagination.dto';
import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import type {
  CreateEventDto,
  CreateEventSessionDto,
  FindEventsDto,
  MarkEventAttendanceDto,
  RegisterMembersDto,
  RegisterToEventDto,
  UpdateEventDto,
} from './dto/event.dto';

@Injectable()
export class EventsService {
  private readonly logger = new Logger(EventsService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ===========================================================================
  // Événements
  // ===========================================================================

  async findAll(query: FindEventsDto) {
    const where: Prisma.EventWhereInput = {
      ...NOT_DELETED,
      isActive: query.isActive ?? true,
      ...(query.upcoming
        ? { eventDate: { gte: this.startOfToday() } }
        : query.from || query.to
          ? {
              eventDate: {
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
              { location: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.event.findMany({
        where,
        // Les événements à venir en ordre croissant : c'est le prochain qui
        // intéresse, pas le plus ancien.
        orderBy: { eventDate: query.upcoming ? 'asc' : 'desc' },
        skip: query.skip,
        take: query.take,
        include: {
          _count: { select: { registrations: true, sessions: true } },
        },
      }),
      this.prisma.event.count({ where }),
    ]);

    return {
      data: items,
      meta: buildPaginationMeta(total, query.page, query.limit),
    };
  }

  async findOne(id: string) {
    const event = await this.prisma.event.findFirst({
      where: { id, ...NOT_DELETED },
      include: {
        sessions: {
          orderBy: { sessionDate: 'asc' },
          select: {
            id: true,
            sessionDate: true,
            _count: { select: { attendances: true } },
          },
        },
        registrations: {
          orderBy: { createdAt: 'asc' },
          select: {
            id: true,
            guestName: true,
            guestEmail: true,
            guestPhone: true,
            registeredAt: true,
            member: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                phone: true,
                photoUrl: true,
              },
            },
          },
        },
      },
    });

    if (!event) {
      throw this.notFound(id);
    }

    const memberCount = event.registrations.filter((row) => row.member).length;

    return {
      ...event,
      stats: {
        totalRegistrations: event.registrations.length,
        members: memberCount,
        guests: event.registrations.length - memberCount,
      },
    };
  }

  async create(dto: CreateEventDto) {
    return this.prisma.event.create({
      data: {
        title: dto.title,
        description: dto.description ?? null,
        eventDate: new Date(dto.eventDate),
        eventTime: dto.eventTime ? this.toTime(dto.eventTime) : null,
        location: dto.location ?? null,
        isRepeated: dto.isRepeated ?? false,
        isActive: dto.isActive ?? true,
      },
    });
  }

  async update(id: string, dto: UpdateEventDto) {
    await this.assertExists(id);

    const { eventDate, eventTime, ...rest } = dto;

    return this.prisma.event.update({
      where: { id },
      data: {
        ...rest,
        ...(eventDate !== undefined ? { eventDate: new Date(eventDate) } : {}),
        ...(eventTime !== undefined
          ? { eventTime: eventTime ? this.toTime(eventTime) : null }
          : {}),
      },
    });
  }

  async remove(id: string) {
    await this.assertExists(id);

    await this.prisma.event.update({
      where: { id },
      data: { deletedAt: new Date(), isActive: false },
    });

    return { message: 'Événement supprimé.', id };
  }

  // ===========================================================================
  // Séances
  // ===========================================================================

  async createSession(id: string, dto: CreateEventSessionDto) {
    await this.assertExists(id);

    return this.prisma.eventSession.create({
      data: { eventId: id, sessionDate: new Date(dto.sessionDate) },
    });
  }

  async removeSession(sessionId: string) {
    const session = await this.prisma.eventSession.findUnique({
      where: { id: sessionId },
      select: { id: true },
    });

    if (!session) {
      throw new NotFoundException({
        message: 'Séance introuvable.',
        code: 'EVENT_SESSION_NOT_FOUND',
      });
    }

    await this.prisma.eventSession.delete({ where: { id: sessionId } });

    return { message: 'Séance supprimée.', id: sessionId };
  }

  // ===========================================================================
  // Inscriptions
  // ===========================================================================

  /**
   * Inscrit un membre ou un invité externe.
   *
   * Les deux sont exclusifs : un invité n'a pas de fiche membre, et un membre
   * n'a pas besoin qu'on ressaisisse son nom. Accepter les deux créerait des
   * doublons impossibles à réconcilier lors du décompte.
   */
  async register(id: string, dto: RegisterToEventDto) {
    await this.assertExists(id);

    const hasMember = Boolean(dto.memberId);
    const hasGuest = Boolean(dto.guestName);

    if (hasMember && hasGuest) {
      throw new BadRequestException({
        message:
          "Une inscription concerne soit un membre, soit un invité — pas les deux.",
        code: 'REGISTRATION_TARGET_CONFLICT',
      });
    }

    if (!hasMember && !hasGuest) {
      throw new BadRequestException({
        message: "Indiquez un membre ou le nom d'un invité.",
        code: 'REGISTRATION_TARGET_REQUIRED',
      });
    }

    if (dto.memberId) {
      const member = await this.prisma.member.findFirst({
        where: { id: dto.memberId, ...NOT_DELETED },
        select: { id: true },
      });

      if (!member) {
        throw new NotFoundException({
          message: 'Membre introuvable.',
          code: 'MEMBER_NOT_FOUND',
        });
      }

      const duplicate = await this.prisma.eventRegistration.findFirst({
        where: { eventId: id, memberId: dto.memberId },
        select: { id: true },
      });

      if (duplicate) {
        throw new ConflictException({
          message: 'Ce membre est déjà inscrit à cet événement.',
          code: 'ALREADY_REGISTERED',
        });
      }
    }

    return this.prisma.eventRegistration.create({
      data: {
        eventId: id,
        memberId: dto.memberId ?? null,
        guestName: dto.guestName ?? null,
        guestEmail: dto.guestEmail ?? null,
        guestPhone: dto.guestPhone ?? null,
        registeredAt: new Date(),
      },
      include: {
        member: { select: { id: true, firstName: true, lastName: true } },
      },
    });
  }

  /** Inscription groupée de membres. */
  async registerMembers(id: string, dto: RegisterMembersDto) {
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

    const existing = await this.prisma.eventRegistration.findMany({
      where: { eventId: id, memberId: { in: dto.memberIds } },
      select: { memberId: true },
    });

    const known = new Set(existing.map((row) => row.memberId));
    const toCreate = dto.memberIds.filter((memberId) => !known.has(memberId));

    if (toCreate.length > 0) {
      await this.prisma.eventRegistration.createMany({
        data: toCreate.map((memberId) => ({
          eventId: id,
          memberId,
          registeredAt: new Date(),
        })),
      });
    }

    return {
      message: `${toCreate.length} inscription(s) enregistrée(s).`,
      registered: toCreate.length,
      alreadyRegistered: known.size,
    };
  }

  async unregister(registrationId: string) {
    const registration = await this.prisma.eventRegistration.findUnique({
      where: { id: registrationId },
      select: { id: true },
    });

    if (!registration) {
      throw new NotFoundException({
        message: 'Inscription introuvable.',
        code: 'REGISTRATION_NOT_FOUND',
      });
    }

    await this.prisma.eventRegistration.delete({ where: { id: registrationId } });

    return { message: 'Inscription retirée.' };
  }

  // ===========================================================================
  // Présence
  // ===========================================================================

  async markAttendance(id: string, dto: MarkEventAttendanceDto) {
    await this.assertExists(id);

    if (dto.sessionId) {
      const session = await this.prisma.eventSession.findFirst({
        where: { id: dto.sessionId, eventId: id },
        select: { id: true },
      });

      if (!session) {
        throw new NotFoundException({
          message: "Cette séance n'appartient pas à cet événement.",
          code: 'EVENT_SESSION_NOT_FOUND',
        });
      }
    }

    const memberIds = dto.entries.map((entry) => entry.memberId);

    const found = await this.prisma.member.count({
      where: { id: { in: memberIds }, ...NOT_DELETED },
    });

    if (found !== new Set(memberIds).size) {
      throw new NotFoundException({
        message: 'Un ou plusieurs membres sont introuvables.',
        code: 'MEMBER_NOT_FOUND',
      });
    }

    await this.prisma.$transaction(async (tx) => {
      const existing = await tx.eventAttendance.findMany({
        where: {
          eventId: id,
          sessionId: dto.sessionId ?? null,
          memberId: { in: memberIds },
        },
        select: { id: true, memberId: true },
      });

      const byMember = new Map(existing.map((row) => [row.memberId, row.id]));

      for (const entry of dto.entries) {
        const existingId = byMember.get(entry.memberId);

        if (existingId) {
          await tx.eventAttendance.update({
            where: { id: existingId },
            data: { status: entry.status, notes: entry.notes ?? null },
          });
        } else {
          await tx.eventAttendance.create({
            data: {
              eventId: id,
              sessionId: dto.sessionId ?? null,
              memberId: entry.memberId,
              status: entry.status,
              notes: entry.notes ?? null,
            },
          });
        }
      }
    });

    return { message: 'Présence enregistrée.', recorded: dto.entries.length };
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  /**
   * Convertit « 18:30 » en valeur exploitable par la colonne TIME.
   *
   * PostgreSQL n'attend que l'heure ; la partie date est ignorée. On utilise
   * une date de référence fixe pour éviter toute dérive liée au fuseau.
   */
  private toTime(value: string): Date {
    return new Date(`1970-01-01T${value}:00.000Z`);
  }

  private startOfToday(): Date {
    const date = new Date();
    date.setUTCHours(0, 0, 0, 0);
    return date;
  }

  private async assertExists(id: string): Promise<void> {
    const event = await this.prisma.event.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true },
    });

    if (!event) {
      throw this.notFound(id);
    }
  }

  private notFound(id: string): NotFoundException {
    return new NotFoundException({
      message: `Aucun événement ne correspond à l'identifiant ${id}.`,
      code: 'EVENT_NOT_FOUND',
    });
  }
}