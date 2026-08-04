import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';

import {
  isFinanceLeader,
  type AuthenticatedUser,
} from '../auth/types/auth.types';

/**
 * Restreint l acces aux donnees financieres.
 *
 * Reproduit la fonction PostgreSQL is_finance_leader() : passent les
 * administrateurs, les pasteurs, et les responsables ou adjoints du
 * departement nomme « Finance ».
 *
 * C est la regle d acces la plus stricte du projet, et elle se superpose aux
 * permissions granulaires : accorder le droit « giving » a un responsable ne
 * suffit pas s il n appartient pas au departement Finance. Les mouvements
 * d argent d une eglise ne relevent pas d une simple case a cocher.
 *
 * Le nom du departement fait foi, d ou la protection contre son renommage
 * dans DepartmentsService.
 */
@Injectable()
export class FinanceGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context
      .switchToHttp()
      .getRequest<{ user?: AuthenticatedUser }>();

    const user = request.user;

    if (!user) {
      throw new ForbiddenException({
        message: 'Acces refuse.',
        code: 'FORBIDDEN',
      });
    }

    if (!isFinanceLeader(user)) {
      throw new ForbiddenException({
        message:
          'Les donnees financieres sont reservees aux administrateurs et aux ' +
          'responsables du departement Finance.',
        code: 'FINANCE_ACCESS_DENIED',
      });
    }

    return true;
  }
}