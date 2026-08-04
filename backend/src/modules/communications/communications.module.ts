import { Module } from '@nestjs/common';

import { AnnouncementsService } from './announcements.service';
import { BirthdayJob } from './birthday.job';
import {
  AnnouncementsController,
  NotificationsController,
} from './communications.controller';
import { NotificationsService } from './notifications.service';

/**
 * Annonces et notifications.
 *
 * Les deux sont regroupes parce qu ils sont lies : publier une annonce genere
 * une notification pour chaque destinataire. NotificationsService est exporte
 * afin que les autres modules puissent notifier — assignation de tache,
 * rappel, anniversaire.
 */
@Module({
  controllers: [AnnouncementsController, NotificationsController],
  providers: [AnnouncementsService, NotificationsService, BirthdayJob],
  exports: [NotificationsService, AnnouncementsService],
})
export class CommunicationsModule {}