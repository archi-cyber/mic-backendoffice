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
import {
  isPrivilegedRole,
  type AuthenticatedUser,
} from '../auth/types/auth.types';
import type {
  CreateAnnouncementDto,
  FindAnnouncementsDto,
  UpdateAnnouncementDto,
} from './dto/communication.dto';
import { NOTIFICATION_TYPES, NotificationsService } from './notifications.service';

@Injectable()
export class AnnouncementsService {
  private readonly logger = new Logger(AnnouncementsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  // ===========================================================================
  // Lecture
  // ===========================================================================

  /**
   * Annonces visibles par l'utilisateur.
   *
   * Trois cas se cumulent : les annonces globales, celles de ses départements,
   * et celles qui le visent nommément. Un administrateur voit tout — il doit
   * pouvoir modérer ce qui est diffusé.
   */
  async findVisible(user: AuthenticatedUser, query: FindAnnouncementsDto) {
    const departmentIds = user.departmentRoles.map((role) => role.departmentId);

    const visibility: Prisma.AnnouncementWhereInput = isPrivilegedRole(user.role)
      ? {}
      : {
          OR: [
            { isGlobal: true },
            ...(departmentIds.length > 0
              ? [{ departmentId: { in: departmentIds } }]
              : []),
            ...(user.memberId
              ? [{ targetMemberIds: { has: user.memberId } }]
              : []),
          ],
        };

    const where: Prisma.AnnouncementWhereInput = {
      ...NOT_DELETED,
      ...visibility,
      ...(query.departmentId ? { departmentId: query.departmentId } : {}),
      ...(query.isGlobal !== undefined ? { isGlobal: query.isGlobal } : {}),
      ...(query.search
        ? {
            AND: [
              {
                OR: [
                  { title: { contains: query.search, mode: 'insensitive' } },
                  { message: { contains: query.search, mode: 'insensitive' } },
                ],
              },
            ],
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.announcement.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: query.skip,
        take: query.take,
        include: {
          department: { select: { id: true, name: true } },
          author: {
            select: {
              id: true,
              member: { select: { firstName: true, lastName: true } },
            },
          },
        },
      }),
      this.prisma.announcement.count({ where }),
    ]);

    return {
      data: items,
      meta: buildPaginationMeta(total, query.page, query.limit),
    };
  }

  async findOne(id: string) {
    const announcement = await this.prisma.announcement.findFirst({
      where: { id, ...NOT_DELETED },
      include: {
        department: { select: { id: true, name: true } },
        author: {
          select: {
            id: true,
            member: { select: { firstName: true, lastName: true } },
          },
        },
      },
    });

    if (!announcement) {
      throw this.notFound(id);
    }

    return announcement;
  }

  // ===========================================================================
  // Écriture
  // ===========================================================================

  /**
   * Publie une annonce et notifie ses destinataires.
   *
   * La notification est envoyée hors transaction : un échec de diffusion ne
   * doit pas empêcher l'annonce d'exister. Elle resterait consultable dans le
   * fil, simplement sans alerte.
   */
  async create(dto: CreateAnnouncementDto, authorUserId: string) {
    const isGlobal = dto.isGlobal ?? true;

    this.assertAudienceValid(isGlobal, dto.departmentId, dto.targetMemberIds);

    if (dto.departmentId) {
      await this.assertDepartmentExists(dto.departmentId);
    }

    const announcement = await this.prisma.announcement.create({
      data: {
        title: dto.title,
        message: dto.message,
        isGlobal,
        departmentId: dto.departmentId ?? null,
        targetMemberIds: dto.targetMemberIds ?? [],
        createdBy: authorUserId,
      },
      include: { department: { select: { id: true, name: true } } },
    });

    const notified = await this.broadcast(announcement.id, {
      isGlobal,
      departmentId: dto.departmentId ?? null,
      targetMemberIds: dto.targetMemberIds ?? [],
      title: dto.title,
      message: dto.message,
    });

    this.logger.log(
      `Annonce publiée : ${dto.title} (${notified} destinataire(s) notifié(s))`,
    );

    return { ...announcement, notifiedCount: notified };
  }

  async update(
    id: string,
    dto: UpdateAnnouncementDto,
    actor: AuthenticatedUser,
  ) {
    const existing = await this.prisma.announcement.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, createdBy: true },
    });

    if (!existing) {
      throw this.notFound(id);
    }

    this.assertIsAuthorOrAdmin(existing.createdBy, actor);

    const { targetMemberIds, ...rest } = dto;

    return this.prisma.announcement.update({
      where: { id },
      data: {
        ...rest,
        ...(targetMemberIds !== undefined ? { targetMemberIds } : {}),
      },
    });
  }

  async remove(id: string, actor: AuthenticatedUser) {
    const existing = await this.prisma.announcement.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, createdBy: true },
    });

    if (!existing) {
      throw this.notFound(id);
    }

    this.assertIsAuthorOrAdmin(existing.createdBy, actor);

    await this.prisma.announcement.update({
      where: { id },
      data: { deletedAt: new Date() },
    });

    return { message: 'Annonce supprimée.', id };
  }

  // ===========================================================================
  // Diffusion
  // ===========================================================================

  /**
   * Détermine les destinataires et crée leurs notifications.
   *
   * Une annonce globale ne crée **pas** une notification par membre : une
   * seule ligne sans destinataire suffit, visible de tous. Créer mille lignes
   * identiques gonflerait la table sans rien apporter.
   */
  private async broadcast(
    announcementId: string,
    audience: {
      isGlobal: boolean;
      departmentId: string | null;
      targetMemberIds: string[];
      title: string;
      message: string;
    },
  ): Promise<number> {
    const payload = {
      type: NOTIFICATION_TYPES.announcement,
      title: audience.title,
      message: audience.message,
      relatedId: announcementId,
      relatedType: 'announcement',
    };

    if (audience.isGlobal) {
      await this.notifications.notify({ ...payload, memberId: null });
      return 0;
    }

    let recipients: string[] = [];

    if (audience.departmentId) {
      const members = await this.prisma.departmentMember.findMany({
        where: {
          departmentId: audience.departmentId,
          member: { ...NOT_DELETED, isActive: true },
        },
        select: { memberId: true },
      });
      recipients = members.map((row) => row.memberId);
    } else {
      recipients = audience.targetMemberIds;
    }

    return this.notifications.notifyMany(recipients, payload);
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  /**
   * Vérifie qu'une annonce non globale a bien un public.
   *
   * Sans destinataire, elle n'apparaîtrait nulle part — un message publié
   * dans le vide, sans que son auteur s'en aperçoive.
   */
  private assertAudienceValid(
    isGlobal: boolean,
    departmentId: string | null | undefined,
    targetMemberIds: string[] | undefined,
  ): void {
    if (isGlobal) return;

    if (!departmentId && !targetMemberIds?.length) {
      throw new BadRequestException({
        message:
          'Une annonce non globale doit viser un département ou une liste de membres.',
        code: 'ANNOUNCEMENT_AUDIENCE_REQUIRED',
      });
    }
  }

  private assertIsAuthorOrAdmin(
    authorUserId: string | null,
    actor: AuthenticatedUser,
  ): void {
    if (authorUserId !== actor.id && !isPrivilegedRole(actor.role)) {
      throw new ForbiddenException({
        message:
          "Seul l'auteur de l'annonce ou un administrateur peut la modifier.",
        code: 'NOT_ANNOUNCEMENT_AUTHOR',
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

  private notFound(id: string): NotFoundException {
    return new NotFoundException({
      message: `Aucune annonce ne correspond à l'identifiant ${id}.`,
      code: 'ANNOUNCEMENT_NOT_FOUND',
    });
  }
}