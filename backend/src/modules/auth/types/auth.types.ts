import type { DepartmentRole, UserRole } from '@prisma/client';

/**
 * Modules pouvant faire l'objet de permissions granulaires.
 *
 * Ces clés correspondent à la colonne `leader_access.feature_name` et
 * reprennent exactement celles documentées dans le guide utilisateur. Elles
 * sont figées : les modifier invaliderait les permissions déjà accordées en
 * base.
 */
export const FEATURES = {
  members: 'members',
  departments: 'departments',
  trainings: 'trainings',
  events: 'events',
  tasks: 'tasks',
  reports: 'reports',
  churchAttendance: 'church_attendance',
  sundaySchoolAttendance: 'sunday_school_attendance',
  visitors: 'visitors',
  giving: 'giving',
  chat: 'chat',
  teachings: 'teachings',
} as const;

export type Feature = (typeof FEATURES)[keyof typeof FEATURES];

/** Les quatre actions contrôlables sur un module. */
export type PermissionAction = 'view' | 'create' | 'edit' | 'delete';

/**
 * Utilisateur authentifié, attaché à `request.user` par la stratégie JWT.
 *
 * Volontairement dépourvu du hachage de mot de passe : cet objet transite
 * dans les contrôleurs et pourrait finir sérialisé par mégarde.
 */
export interface AuthenticatedUser {
  id: string;
  email: string;
  role: UserRole;
  memberId: string | null;
  mustChangePassword: boolean;

  /** Appartenances départementales, avec le rôle tenu dans chacune. */
  departmentRoles: Array<{
    departmentId: string;
    departmentName: string;
    role: DepartmentRole;
  }>;
}

/** Contenu du jeton d'accès. */
export interface AccessTokenPayload {
  /** Identifiant de l'utilisateur (`users.id`). */
  sub: string;
  email: string;
  role: UserRole;
  /** Type de jeton — empêche d'utiliser un refresh comme access. */
  typ: 'access';
}

/** Contenu du jeton de rafraîchissement. */
export interface RefreshTokenPayload {
  sub: string;
  /** Identifiant unique du jeton, permettant la révocation ciblée. */
  jti: string;
  typ: 'refresh';
}

/** Couple de jetons renvoyé après une connexion réussie. */
export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  /** Durée de vie du jeton d'accès, en secondes. */
  expiresIn: number;
}

/**
 * Indique si un rôle global confère les pleins pouvoirs.
 *
 * `pastor` est traité comme `admin` : c'est la règle en vigueur dans
 * l'application actuelle, où le pasteur dispose du même accès que
 * l'administrateur système.
 */
export const isPrivilegedRole = (role: UserRole): boolean =>
  role === 'admin' || role === 'pastor';

/**
 * Indique si l'utilisateur est responsable, au sens large.
 *
 * Reproduit la fonction PostgreSQL `is_leader()` : est responsable soit celui
 * dont le rôle global le stipule, soit celui qui dirige un département — même
 * si son rôle global n'est que `member`.
 */
export const isLeader = (user: AuthenticatedUser): boolean => {
  if (isPrivilegedRole(user.role) || user.role === 'leader') {
    return true;
  }
  return user.departmentRoles.some(
    (membership) => membership.role === 'leader' || membership.role === 'subleader',
  );
};

/**
 * Indique si l'utilisateur dirige le département Finance.
 *
 * Reproduit `is_finance_leader()`. La comparaison est insensible à la casse et
 * aux espaces, comme dans l'implémentation SQL d'origine.
 */
export const isFinanceLeader = (user: AuthenticatedUser): boolean => {
  if (isPrivilegedRole(user.role)) {
    return true;
  }
  return user.departmentRoles.some(
    (membership) =>
      membership.departmentName.trim().toLowerCase() === 'finance' &&
      (membership.role === 'leader' || membership.role === 'subleader'),
  );
};