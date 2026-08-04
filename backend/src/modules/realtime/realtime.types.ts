import type { UserRole } from '@prisma/client';

/**
 * Salons Socket.IO.
 *
 * Un salon regroupe les connexions concernees par un meme flux. Emettre vers
 * un salon plutot que vers chaque socket evite d avoir a tenir soi-meme la
 * liste des destinataires — Socket.IO s en charge, y compris quand un meme
 * utilisateur est connecte depuis plusieurs appareils.
 */
export const ROOMS = {
  /** Un utilisateur, tous ses appareils confondus. */
  user: (userId: string) => `user:${userId}`,
  /** Un membre — distinct de l utilisateur, car les notifications ciblent le membre. */
  member: (memberId: string) => `member:${memberId}`,
  /** Les membres d un departement. */
  department: (departmentId: string) => `department:${departmentId}`,
  /** Les personnes saisissant la presence d un meme culte. */
  service: (churchServiceId: string) => `service:${churchServiceId}`,
  /** Tous les utilisateurs connectes. */
  global: 'global',
} as const;

/**
 * Evenements emis par le serveur.
 *
 * Ces noms sont un contrat avec le client Flutter : les renommer casserait
 * les ecouteurs deja en place. En ajouter est sans risque.
 */
export const EVENTS = {
  notificationNew: 'notification:new',
  attendanceUpdated: 'attendance:updated',
  taskAssigned: 'task:assigned',
  taskUpdated: 'task:updated',
  announcementNew: 'announcement:new',
  penaltyUpdated: 'penalty:updated',
  memberUpdated: 'member:updated',
} as const;

/** Identite attachee a chaque connexion authentifiee. */
export interface SocketUser {
  userId: string;
  memberId: string | null;
  email: string;
  role: UserRole;
  departmentIds: string[];
}

// =============================================================================
// Charges utiles
// =============================================================================

export interface AttendanceUpdatedPayload {
  churchServiceId: string;
  memberId: string;
  attendanceType: 'onsite' | 'online' | 'absent';
  /** Auteur de la modification, pour que son propre client puisse l ignorer. */
  updatedBy: string;
}

export interface TaskAssignedPayload {
  taskId: string;
  title: string;
  dueDate: string | null;
  assignedMemberIds: string[];
}

export interface AnnouncementPayload {
  announcementId: string;
  title: string;
  message: string;
  isGlobal: boolean;
  departmentId: string | null;
}

export interface PenaltyUpdatedPayload {
  memberId: string;
  balance: number;
  isBlocked: boolean;
}