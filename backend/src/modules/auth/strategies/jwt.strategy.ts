import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

import type { AppConfig } from '../../../config/configuration';
import { PrismaService } from '../../../prisma/prisma.service';
import type {
  AccessTokenPayload,
  AuthenticatedUser,
} from '../types/auth.types';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService<AppConfig, true>,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get('jwt.accessSecret', { infer: true }),
    });
  }

  /**
   * Recharge l'utilisateur à chaque requête.
   *
   * On pourrait se contenter du contenu du jeton et éviter cet appel à la
   * base. Le coût d'une requête indexée est cependant faible au regard de ce
   * qu'il apporte : un compte désactivé, supprimé ou dont le rôle a changé
   * perd ses droits immédiatement, sans attendre l'expiration du jeton.
   *
   * Sans cette vérification, révoquer l'accès d'un responsable laisserait son
   * jeton valide jusqu'à quinze minutes — inacceptable dans le cas d'un
   * départ conflictuel ou d'un appareil volé.
   */
  async validate(payload: AccessTokenPayload): Promise<AuthenticatedUser> {
    if (payload.typ !== 'access') {
      throw new UnauthorizedException({
        message: 'Type de jeton incorrect.',
        code: 'INVALID_TOKEN_TYPE',
      });
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: {
        id: true,
        email: true,
        role: true,
        memberId: true,
        isActive: true,
        deletedAt: true,
        mustChangePassword: true,
        member: {
          select: {
            deletedAt: true,
            departmentMembers: {
              select: {
                departmentId: true,
                role: true,
                department: { select: { name: true, isActive: true } },
              },
            },
          },
        },
      },
    });

    if (!user || user.deletedAt !== null) {
      throw new UnauthorizedException({
        message: 'Compte introuvable.',
        code: 'USER_NOT_FOUND',
      });
    }

    if (!user.isActive) {
      throw new UnauthorizedException({
        message: 'Ce compte a été désactivé.',
        code: 'ACCOUNT_DISABLED',
      });
    }

    // Un membre supprimé logiquement entraîne la perte d'accès : le compte
    // n'a plus de fiche associée, donc plus de rattachement à l'église.
    if (user.member?.deletedAt) {
      throw new UnauthorizedException({
        message: 'La fiche membre associée à ce compte a été supprimée.',
        code: 'MEMBER_DELETED',
      });
    }

    const departmentRoles = (user.member?.departmentMembers ?? [])
      // Les départements désactivés ne confèrent plus aucun privilège.
      .filter((membership) => membership.department.isActive)
      .map((membership) => ({
        departmentId: membership.departmentId,
        departmentName: membership.department.name,
        role: membership.role,
      }));

    return {
      id: user.id,
      email: user.email,
      role: user.role,
      memberId: user.memberId,
      mustChangePassword: user.mustChangePassword,
      departmentRoles,
    };
  }
}