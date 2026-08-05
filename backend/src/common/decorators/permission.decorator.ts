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
 * @example
 *   @RequirePermission(FEATURES.members, 'create')
 *   @Post()
 *   create(@Body() dto: CreateMemberDto) { ... }
 */
export const RequirePermission = (feature: Feature, action: PermissionAction) =>
  SetMetadata(PERMISSION_KEY, { feature, action } satisfies RequiredPermission);