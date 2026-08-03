import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { UserRole } from '@prisma/client';

import { ROLES_KEY } from '../decorators/roles.decorator';
import {
  isPrivilegedRole,
  type AuthenticatedUser,
} from '../../modules/auth/types/auth.types';

/**
 * Contrôle le rôle global de l'utilisateur.
 *
 * Deuxième maillon de la chaîne, après `JwtAuthGuard` : l'identité est déjà
 * établie, il s'agit ici du niveau de privilège.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<UserRole[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    // Aucune contrainte de rôle : la décision revient à PermissionsGuard.
    if (!required || required.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest<{ user?: AuthenticatedUser }>();
    const user = request.user;

    if (!user) {
      throw new ForbiddenException({
        message: 'Accès refusé.',
        code: 'FORBIDDEN',
      });
    }

    // Un administrateur ou un pasteur passe partout. Cette équivalence évite
    // d'avoir à écrire @Roles('admin', 'pastor') sur chaque route — et surtout
    // d'oublier 'pastor' quelque part, ce qui priverait le pasteur d'un accès
    // qui lui revient.
    if (isPrivilegedRole(user.role)) {
      return true;
    }

    if (required.includes(user.role)) {
      return true;
    }

    throw new ForbiddenException({
      message: "Votre rôle ne permet pas d'effectuer cette action.",
      code: 'INSUFFICIENT_ROLE',
    });
  }
}