import { createParamDecorator, type ExecutionContext } from '@nestjs/common';

import type { AuthenticatedUser } from '../../modules/auth/types/auth.types';

/**
 * Injecte l'utilisateur authentifié dans un paramètre de contrôleur.
 *
 * Un champ précis peut être demandé, ce qui évite de manipuler l'objet entier
 * quand seul l'identifiant est utile.
 *
 * @example
 *   findMine(@CurrentUser() user: AuthenticatedUser) { ... }
 *   findMine(@CurrentUser('memberId') memberId: string | null) { ... }
 */
export const CurrentUser = createParamDecorator(
  (field: keyof AuthenticatedUser | undefined, context: ExecutionContext) => {
    const request = context
      .switchToHttp()
      .getRequest<{ user?: AuthenticatedUser }>();

    const user = request.user;
    if (!user) {
      return undefined;
    }

    return field ? user[field] : user;
  },
);