import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { buildPaginationMeta } from '../../common/dto/pagination.dto';
import { PrismaService } from '../../prisma/prisma.service';
import type {
  FindNotificationsDto,
  MarkNotificationsReadDto,
} from './dto/communication.dto';

/**
 * Types de notification émis par l'application.
 *
 * Ces clés sont figées : le client Flutter s'en sert pour choisir l'icône et
 * la destination du clic. En ajouter est sans risque, en renommer casserait
 * l'affichage des notifications déjà en base.
 */
export const NOTIFICATION_TYPES = {
  taskAssigned: 'task_assigned',
  taskReminder: 'task_reminder',
  taskOverdue: 'task_overdue',
  penaltyThreshold: 'penalty_threshold',
  announcement: 'announcement',
  birthday: 'birthday',
  eventReminder: 'event_reminder',
} as const;

export type NotificationType =
  (typeof NOTIFICATION_TYPES)[keyof typeof NOTIFICATION_TYPES];

export interface CreateNotificationInput {
  memberId: string | null;
  type: NotificationType;
  title: string;
  message: string;
  relatedId?: string | null;
  relatedType?: string | null;
  scheduledFor?: Date | null;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ===========================================================================
  // Émission
  // ===========================================================================

  /** Crée une notification pour un destinataire. */
  async notify(input: CreateNotificationInput) {
    return this.prisma.notification.create({
      data: {
        memberId: input.memberId,
        type: input.type,
        title: input.title,
        message: input.message,
        relatedId: input.relatedId ?? null,
        relatedType: input.relatedType ?? null,
        scheduledFor: input.scheduledFor ?? null,
      },
    });
  }

  /**
   * Crée la même notification pour plusieurs destinataires.
   *
   * `createMany` insère en une requête. Boucler sur `notify` pour une annonce
   * touchant trois cents membres produirait trois cents allers-retours.
   */
  async notifyMany(
    memberIds: string[],
    input: Omit<CreateNotificationInput, 'memberId'>,
  ): Promise<number> {
    const unique = [...new Set(memberIds)];

    if (unique.length === 0) {
      return 0;
    }

    const result = await this.prisma.notification.createMany({
      data: unique.map((memberId) => ({
        memberId,
        type: input.type,
        title: input.title,
        message: input.message,
        relatedId: input.relatedId ?? null,
        relatedType: input.relatedType ?? null,
        scheduledFor: input.scheduledFor ?? null,
      })),
    });

    return result.count;
  }

  // ===========================================================================
  // Lecture
  // ===========================================================================

  /**
   * Notifications d'un membre.
   *
   * Les notifications sans destinataire (`memberId` nul) sont incluses : ce
   * sont les messages destinés à toute l'assemblée.
   */
  async findForMember(memberId: string, query: FindNotificationsDto) {
    const where: Prisma.NotificationWhereInput = {
      OR: [{ memberId }, { memberId: null }],
      ...(query.isRead !== undefined ? { isRead: query.isRead } : {}),
      ...(query.type ? { type: query.type } : {}),
    };

    const [items, total, unread] = await this.prisma.$transaction([
      this.prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: query.skip,
        take: query.take,
      }),
      this.prisma.notification.count({ where }),
      this.prisma.notification.count({
        where: { OR: [{ memberId }, { memberId: null }], isRead: false },
      }),
    ]);

    return {
      data: items,
      meta: {
        ...buildPaginationMeta(total, query.page, query.limit),
        unreadCount: unread,
      },
    };
  }

  async countUnread(memberId: string): Promise<number> {
    return this.prisma.notification.count({
      where: { OR: [{ memberId }, { memberId: null }], isRead: false },
    });
  }

  // ===========================================================================
  // Lecture / suppression
  // ===========================================================================

  async markAsRead(memberId: string, dto: MarkNotificationsReadDto) {
    const where: Prisma.NotificationWhereInput = {
      memberId,
      isRead: false,
      ...(dto.notificationIds?.length
        ? { id: { in: dto.notificationIds } }
        : {}),
    };

    const result = await this.prisma.notification.updateMany({
      where,
      data: { isRead: true, readAt: new Date() },
    });

    return {
      message: `${result.count} notification(s) marquée(s) comme lue(s).`,
      updated: result.count,
      unreadCount: await this.countUnread(memberId),
    };
  }

  async remove(id: string, memberId: string) {
    const notification = await this.prisma.notification.findFirst({
      where: { id, memberId },
      select: { id: true },
    });

    // La condition sur `memberId` empêche de supprimer la notification d'un
    // autre : sans elle, connaître un identifiant suffirait.
    if (!notification) {
      throw new NotFoundException({
        message: 'Notification introuvable.',
        code: 'NOTIFICATION_NOT_FOUND',
      });
    }

    await this.prisma.notification.delete({ where: { id } });

    return { message: 'Notification supprimée.', id };
  }

  /**
   * Purge les notifications lues de plus de quatre-vingt-dix jours.
   *
   * Sans nettoyage, la table croît indéfiniment — plusieurs lignes par membre
   * et par semaine. Les non lues sont épargnées : leur ancienneté ne les rend
   * pas moins pertinentes pour celui qui ne les a pas vues.
   */
  async purgeOld(): Promise<number> {
    const threshold = new Date(Date.now() - 90 * 24 * 60 * 60 * 1_000);

    const result = await this.prisma.notification.deleteMany({
      where: { isRead: true, createdAt: { lt: threshold } },
    });

    if (result.count > 0) {
      this.logger.log(`${result.count} notification(s) purgée(s).`);
    }

    return result.count;
  }
}