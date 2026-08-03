import {
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';

import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import type { AuthenticatedUser } from '../../modules/auth/types/auth.types';

/**
 * Vérifie la présence et la validité du jeton d'accès.
 *
 * Enregistrée globalement dans `AppModule` : toute route est protégée sauf
 * mention contraire via `@Public()`.
 */
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private readonly reflector: Reflector) {
    super();
  }

  canActivate(context: ExecutionContext) {
    // `getAllAndOverride` consulte d'abord la méthode, puis la classe :
    // un contrôleur entier peut être public, avec des exceptions par route.
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    return super.canActivate(context);
  }

  /**
   * Uniformise les messages d'échec.
   *
   * Passport distingue « jeton absent », « signature invalide » et « jeton
   * expiré ». Seule l'expiration est renvoyée distinctement, car le client
   * doit savoir qu'il lui faut rafraîchir plutôt que redemander un mot de
   * passe. Les autres cas partagent un message générique : détailler
   * renseignerait un attaquant sur l'état de son jeton forgé.
   */
  handleRequest<TUser = AuthenticatedUser>(
    err: unknown,
    user: TUser | false,
    info: unknown,
  ): TUser {
    if (err || !user) {
      const reason = (info as { name?: string } | undefined)?.name;

      if (reason === 'TokenExpiredError') {
        throw new UnauthorizedException({
          message: "Le jeton d'accès a expiré.",
          code: 'TOKEN_EXPIRED',
        });
      }

      throw new UnauthorizedException({
        message: 'Authentification requise.',
        code: 'UNAUTHORIZED',
      });
    }

    return user;
  }
}