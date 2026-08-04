import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { PrismaService } from '../../prisma/prisma.service';
import { NOTIFICATION_TYPES, NotificationsService } from './notifications.service';

/**
 * Notifications d anniversaire.
 *
 * Declenchee chaque matin a 7 h : assez tot pour que le message soit vu dans
 * la journee, assez tard pour ne pas reveiller les appareils en pleine nuit.
 */
@Injectable()
export class BirthdayJob {
  private readonly logger = new Logger(BirthdayJob.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_7AM, { name: 'birthday-notifications' })
  async handleBirthdays(): Promise<void> {
    try {
      const celebrants = await this.prisma.$queryRaw<
        Array<{ id: string; firstName: string; lastName: string }>
      >`
        SELECT id, first_name AS "firstName", last_name AS "lastName"
        FROM members
        WHERE deleted_at IS NULL
          AND is_active = true
          AND birthday IS NOT NULL
          AND birthday_notifications_opt_out = false
          AND EXTRACT(MONTH FROM birthday) = EXTRACT(MONTH FROM CURRENT_DATE)
          AND EXTRACT(DAY   FROM birthday) = EXTRACT(DAY   FROM CURRENT_DATE)
      `;

      if (celebrants.length === 0) {
        return;
      }

      for (const member of celebrants) {
        // Une notification sans destinataire est visible de toute l assemblee :
        // l anniversaire est une information collective, pas un message prive.
        await this.notifications.notify({
          memberId: null,
          type: NOTIFICATION_TYPES.birthday,
          title: 'Anniversaire',
          message: `Aujourd hui, ${member.firstName} ${member.lastName} fete son anniversaire.`,
          relatedId: member.id,
          relatedType: 'member',
        });
      }

      this.logger.log(
        `${celebrants.length} anniversaire(s) annonce(s) aujourd hui.`,
      );
    } catch (error) {
      this.logger.error(
        `Echec des notifications d anniversaire : ` +
          `${error instanceof Error ? error.message : 'erreur inconnue'}`,
      );
    }
  }

  /**
   * Purge hebdomadaire des notifications lues anciennes.
   *
   * Sans nettoyage, la table croit indefiniment : plusieurs lignes par membre
   * et par semaine.
   */
  @Cron(CronExpression.EVERY_WEEK, { name: 'notifications-purge' })
  async handlePurge(): Promise<void> {
    try {
      await this.notifications.purgeOld();
    } catch (error) {
      this.logger.error(
        `Echec de la purge des notifications : ` +
          `${error instanceof Error ? error.message : 'erreur inconnue'}`,
      );
    }
  }
}