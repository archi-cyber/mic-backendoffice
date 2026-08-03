import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { PrismaService } from '../../prisma/prisma.service';
import {
  PERMISSION_KEY,
  type RequiredPermission,
} from '../decorators/permission.decorator';
import {
  isPrivilegedRole,
  type AuthenticatedUser,
  type PermissionAction,
} from '../../modules/auth/types/auth.types';

/**
 * Applique les permissions granulaires de la table `leader_access`.
 *
 * C'est le remplacement direct des politiques RLS PostgreSQL. La différence
 * de fond : la base ne décide plus rien, elle exécute. Toute la logique
 * d'autorisation est ici, lisible et testable.
 */
@Injectable()
export class PermissionsGuard implements CanActivate {
  /** Colonne de `leader_access` correspondant à chaque action. */
  private static readonly COLUMN: Record<PermissionAction, 'canView' | 'canCreate' | 'canEdit' | 'canDelete'> = {
    view: 'canView',
    create: 'canCreate',
    edit: 'canEdit',
    delete: 'canDelete',
  };

  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<RequiredPermission>(
      PERMISSION_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!required) {
      return true;
    }

    const request = context.switchToHttp().getRequest<{ user?: AuthenticatedUser }>();
    const user = request.user;

    if (!user) {
      throw new ForbiddenException({ message: 'Accès refusé.', code: 'FORBIDDEN' });
    }

    // Les administrateurs et pasteurs ne sont pas soumis aux permissions
    // granulaires : leur accorder des droits ligne à ligne serait redondant et
    // créerait un risque de les enfermer hors de leur propre application.
    if (isPrivilegedRole(user.role)) {
      return true;
    }

    const access = await this.prisma.leaderAccess.findUnique({
      where: {
        userId_featureName: {
          userId: user.id,
          featureName: required.feature,
        },
      },
      select: {
        canView: true,
        canCreate: true,
        canEdit: true,
        canDelete: true,
        deletedAt: true,
      },
    });

    const column = PermissionsGuard.COLUMN[required.action];

    if (!access || access.deletedAt !== null || !access[column]) {
      throw new ForbiddenException({
        message: `Vous n'avez pas le droit « ${required.action} » sur le module « ${required.feature} ».`,
        code: 'PERMISSION_DENIED',
      });
    }

    return true;
  }
}