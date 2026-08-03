import { SetMetadata } from '@nestjs/common';
import type { UserRole } from '@prisma/client';

export const ROLES_KEY = 'roles';

/**
 * Restreint une route à certains rôles globaux.
 *
 * `pastor` est automatiquement admis partout où `admin` est requis :
 * `RolesGuard` applique cette équivalence, il est donc inutile de lister les
 * deux.
 *
 * @example
 *   @Roles('admin')
 *   @Delete(':id')
 *   remove(@Param('id') id: string) { ... }
 */
export const Roles = (...roles: UserRole[]) => SetMetadata(ROLES_KEY, roles);