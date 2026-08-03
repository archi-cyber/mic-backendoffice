import { SetMetadata } from '@nestjs/common';

import type { Feature, PermissionAction } from '../../modules/auth/types/auth.types';

export const PERMISSION_KEY = 'permission';

export interface RequiredPermission {
  feature: Feature;
  action: PermissionAction;
}

/**
 * Exige une permission granulaire sur un module.
 *
 * Remplace les politiques RLS de PostgreSQL : là où la base vérifiait
 * `is_leader()` avant chaque lecture, c'est désormais `PermissionsGuard` qui
 * consulte la table `leader_access`.
 *
 * Les administrateurs et pasteurs contournent systématiquement cette
 * vérification.
 *
 * @example
 *   @RequirePermission(FEATURES.members, 'create')
 *   @Post()
 *   create(@Body() dto: CreateMemberDto) { ... }
 */
export const RequirePermission = (feature: Feature, action: PermissionAction) =>
  SetMetadata(PERMISSION_KEY, { feature, action } satisfies RequiredPermission);