import { Injectable, Logger } from '@nestjs/common';
import type { Server } from 'socket.io';

import {
  EVENTS,
  ROOMS,
  type AnnouncementPayload,
  type AttendanceUpdatedPayload,
  type PenaltyUpdatedPayload,
  type TaskAssignedPayload,
} from './realtime.types';

/**
 * Diffusion des événements temps réel.
 *
 * Séparé de la passerelle pour deux raisons. D'abord, les autres modules
 * peuvent l'injecter sans dépendre de Socket.IO ni créer de cycle avec la
 * passerelle. Ensuite, il reste utilisable avant que le serveur WebSocket ne
 * soit prêt : chaque méthode vérifie la présence du serveur et se contente de
 * ne rien faire s'il est absent.
 *
 * Ce dernier point est important : une diffusion ratée ne doit jamais faire
 * échouer l'opération métier qui l'a déclenchée. Enregistrer une présence
 * compte plus que prévenir les autres écrans.
 */
@Injectable()
export class RealtimeService {
  private readonly logger = new Logger(RealtimeService.name);
  private server: Server | null = null;

  /** Appelé par la passerelle à son initialisation. */
  setServer(server: Server): void {
    this.server = server;
    this.logger.log('Serveur Socket.IO prêt.');
  }

  // ===========================================================================
  // Notifications
  // ===========================================================================

  /**
   * Notifie un membre.
   *
   * `memberId` nul signifie une notification destinée à toute l'assemblée :
   * elle part alors dans le salon global.
   */
  notifyMember(memberId: string | null, notification: unknown): void {
    if (memberId === null) {
      this.emit(ROOMS.global, EVENTS.notificationNew, notification);
      return;
    }
    this.emit(ROOMS.member(memberId), EVENTS.notificationNew, notification);
  }

  notifyMembers(memberIds: string[], notification: unknown): void {
    for (const memberId of new Set(memberIds)) {
      this.emit(ROOMS.member(memberId), EVENTS.notificationNew, notification);
    }
  }

  // ===========================================================================
  // Présence
  // ===========================================================================

  /**
   * Signale une modification de présence aux autres saisisseurs.
   *
   * C'est le cas d'usage principal du temps réel dans cette application :
   * plusieurs responsables pointent le même culte simultanément. Sans
   * diffusion, chacun travaillerait sur une vue figée et écraserait le travail
   * des autres sans s'en apercevoir.
   */
  attendanceUpdated(payload: AttendanceUpdatedPayload): void {
    this.emit(
      ROOMS.service(payload.churchServiceId),
      EVENTS.attendanceUpdated,
      payload,
    );
  }

  // ===========================================================================
  // Tâches
  // ===========================================================================

  taskAssigned(payload: TaskAssignedPayload): void {
    for (const memberId of new Set(payload.assignedMemberIds)) {
      this.emit(ROOMS.member(memberId), EVENTS.taskAssigned, payload);
    }
  }

  taskUpdated(departmentId: string | null, task: unknown): void {
    if (!departmentId) return;
    this.emit(ROOMS.department(departmentId), EVENTS.taskUpdated, task);
  }

  penaltyUpdated(payload: PenaltyUpdatedPayload): void {
    this.emit(ROOMS.member(payload.memberId), EVENTS.penaltyUpdated, payload);
  }

  // ===========================================================================
  // Annonces
  // ===========================================================================

  announcementPublished(
    payload: AnnouncementPayload,
    targetMemberIds: string[] = [],
  ): void {
    if (payload.isGlobal) {
      this.emit(ROOMS.global, EVENTS.announcementNew, payload);
      return;
    }

    if (payload.departmentId) {
      this.emit(
        ROOMS.department(payload.departmentId),
        EVENTS.announcementNew,
        payload,
      );
      return;
    }

    for (const memberId of new Set(targetMemberIds)) {
      this.emit(ROOMS.member(memberId), EVENTS.announcementNew, payload);
    }
  }

  // ===========================================================================
  // Utilitaires
  // ===========================================================================

  /** Nombre de connexions actives — utile pour la supervision. */
  async countConnections(): Promise<number> {
    if (!this.server) return 0;
    const sockets = await this.server.fetchSockets();
    return sockets.length;
  }

  /**
   * Émission unitaire, tolérante à l'absence de serveur.
   *
   * Toute erreur est journalisée puis absorbée : la diffusion est un confort,
   * jamais une condition de réussite.
   */
  private emit(room: string, event: string, payload: unknown): void {
    if (!this.server) {
      this.logger.debug(
        `Diffusion ignorée (serveur non initialisé) : ${event} → ${room}`,
      );
      return;
    }

    try {
      this.server.to(room).emit(event, payload);
    } catch (error) {
      this.logger.warn(
        `Diffusion impossible vers ${room} : ` +
          `${error instanceof Error ? error.message : 'erreur inconnue'}`,
      );
    }
  }
}