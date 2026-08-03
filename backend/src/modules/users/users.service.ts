import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';

import { buildPaginationMeta } from '../../common/dto/pagination.dto';
import type { AppConfig } from '../../config/configuration';
import { NOT_DELETED, PrismaService } from '../../prisma/prisma.service';
import { PasswordService } from '../auth/password.service';
import { TokenService } from '../auth/token.service';
import { FEATURES } from '../auth/types/auth.types';
import type {
  CreateUserAccountDto,
  FindUsersDto,
  SetPermissionsDto,
  UpdateUserDto,
} from './dto/user.dto';

const USER_SELECT = {
  id: true,
  email: true,
  phone: true,
  role: true,
  memberId: true,
  isActive: true,
  mustChangePassword: true,
  lastLoginAt: true,
  createdAt: true,
  member: {
    select: { id: true, firstName: true, lastName: true, photoUrl: true },
  },
} satisfies Prisma.UserSelect;

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordService,
    private readonly tokens: TokenService,
    private readonly config: ConfigService<AppConfig, true>,
  ) {}

  // ===========================================================================
  // Comptes
  // ===========================================================================

  async findAll(query: FindUsersDto) {
    const where: Prisma.UserWhereInput = {
      ...NOT_DELETED,
      isActive: query.isActive ?? true,
      ...(query.role ? { role: query.role } : {}),
      ...(query.search
        ? {
            OR: [
              { email: { contains: query.search, mode: 'insensitive' } },
              {
                member: {
                  OR: [
                    { firstName: { contains: query.search, mode: 'insensitive' } },
                    { lastName: { contains: query.search, mode: 'insensitive' } },
                  ],
                },
              },
            ],
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({
        where,
        select: USER_SELECT,
        orderBy: { createdAt: 'desc' },
        skip: query.skip,
        take: query.take,
      }),
      this.prisma.user.count({ where }),
    ]);

    return { data: items, meta: buildPaginationMeta(total, query.page, query.limit) };
  }

  async findOne(id: string) {
    const user = await this.prisma.user.findFirst({
      where: { id, ...NOT_DELETED },
      select: {
        ...USER_SELECT,
        leaderAccess: {
          where: { deletedAt: null },
          select: {
            featureName: true,
            canView: true,
            canCreate: true,
            canEdit: true,
            canDelete: true,
          },
        },
      },
    });

    if (!user) {
      throw this.notFound(id);
    }

    return user;
  }

  /**
   * Crée un compte de connexion pour un membre.
   *
   * Le mot de passe initial est celui défini par configuration, avec
   * changement obligatoire. Le nouvel utilisateur n'a par défaut **aucune**
   * permission : l'administrateur doit les accorder explicitement. Ce choix
   * suit le principe du moindre privilège — un compte créé par erreur ne
   * donne accès à rien.
   */
  async createAccount(dto: CreateUserAccountDto) {
    const member = await this.prisma.member.findFirst({
      where: { id: dto.memberId, ...NOT_DELETED },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        user: { select: { id: true } },
      },
    });

    if (!member) {
      throw new NotFoundException({
        message: 'Membre introuvable.',
        code: 'MEMBER_NOT_FOUND',
      });
    }

    // La relation est de un à un : un membre ne peut pas avoir deux comptes.
    if (member.user) {
      throw new ConflictException({
        message: 'Ce membre dispose déjà d\'un compte de connexion.',
        code: 'MEMBER_ALREADY_HAS_ACCOUNT',
      });
    }

    const emailTaken = await this.prisma.user.findUnique({
      where: { email: dto.email },
      select: { id: true },
    });

    if (emailTaken) {
      throw new ConflictException({
        message: 'Cette adresse e-mail est déjà utilisée par un autre compte.',
        code: 'EMAIL_TAKEN',
      });
    }

    const defaultPassword = this.config.get('auth.defaultUserPassword', {
      infer: true,
    });

    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        phone: dto.phone,
        role: dto.role ?? 'member',
        memberId: dto.memberId,
        passwordHash: await this.passwords.hash(defaultPassword),
        mustChangePassword: true,
        isActive: true,
      },
      select: USER_SELECT,
    });

    this.logger.log(
      `Compte créé pour ${member.firstName} ${member.lastName} (${dto.email})`,
    );

    return {
      ...user,
      // Communiqué une seule fois, à la création : l'administrateur doit le
      // transmettre au membre. Il n'est jamais renvoyé par la suite.
      temporaryPassword: defaultPassword,
    };
  }

  async update(id: string, dto: UpdateUserDto) {
    const user = await this.prisma.user.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, email: true, role: true },
    });

    if (!user) {
      throw this.notFound(id);
    }

    if (dto.email && dto.email !== user.email) {
      const taken = await this.prisma.user.findUnique({
        where: { email: dto.email },
        select: { id: true },
      });

      if (taken) {
        throw new ConflictException({
          message: 'Cette adresse e-mail est déjà utilisée.',
          code: 'EMAIL_TAKEN',
        });
      }
    }

    const updated = await this.prisma.user.update({
      where: { id },
      data: dto,
      select: USER_SELECT,
    });

    // Un changement de rôle modifie les droits en profondeur. Les sessions
    // sont fermées pour que le nouveau rôle prenne effet à la reconnexion,
    // sans laisser d'ambiguïté sur les droits en cours.
    if (dto.role && dto.role !== user.role) {
      await this.tokens.revokeAllForUser(id);
      this.logger.log(`Rôle modifié pour ${user.email} : ${user.role} → ${dto.role}`);
    }

    return updated;
  }

  /**
   * Active ou désactive un compte.
   *
   * La désactivation ferme immédiatement toutes les sessions : sans cela, un
   * jeton d'accès resterait valide jusqu'à quinze minutes après la coupure.
   */
  async setActive(id: string, isActive: boolean, actorUserId: string) {
    if (id === actorUserId && !isActive) {
      throw new BadRequestException({
        message: 'Vous ne pouvez pas désactiver votre propre compte.',
        code: 'CANNOT_DEACTIVATE_SELF',
      });
    }

    const user = await this.prisma.user.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, email: true, role: true },
    });

    if (!user) {
      throw this.notFound(id);
    }

    await this.assertNotLastAdmin(user.id, user.role, isActive);

    const updated = await this.prisma.user.update({
      where: { id },
      data: { isActive },
      select: USER_SELECT,
    });

    if (!isActive) {
      const closed = await this.tokens.revokeAllForUser(id);
      this.logger.log(
        `Compte désactivé : ${user.email} (${closed} session(s) fermée(s))`,
      );
    }

    return updated;
  }

  /**
   * Réinitialise le mot de passe à la valeur par défaut.
   *
   * Utilisé quand un membre a perdu l'accès à son adresse e-mail et ne peut
   * donc pas suivre la procédure autonome.
   */
  async forcePasswordReset(id: string) {
    const user = await this.prisma.user.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, email: true },
    });

    if (!user) {
      throw this.notFound(id);
    }

    const defaultPassword = this.config.get('auth.defaultUserPassword', {
      infer: true,
    });

    await this.prisma.user.update({
      where: { id },
      data: {
        passwordHash: await this.passwords.hash(defaultPassword),
        mustChangePassword: true,
        passwordResetToken: null,
        passwordResetExpiresAt: null,
      },
    });

    await this.tokens.revokeAllForUser(id);

    this.logger.log(`Mot de passe réinitialisé par un administrateur : ${user.email}`);

    return {
      message: 'Mot de passe réinitialisé.',
      temporaryPassword: defaultPassword,
    };
  }

  async remove(id: string, actorUserId: string) {
    if (id === actorUserId) {
      throw new BadRequestException({
        message: 'Vous ne pouvez pas supprimer votre propre compte.',
        code: 'CANNOT_DELETE_SELF',
      });
    }

    const user = await this.prisma.user.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true, email: true, role: true },
    });

    if (!user) {
      throw this.notFound(id);
    }

    await this.assertNotLastAdmin(user.id, user.role, false);

    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id },
        data: { deletedAt: new Date(), isActive: false },
      });

      await tx.refreshToken.updateMany({
        where: { userId: id, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    });

    this.logger.log(`Compte supprimé : ${user.email}`);

    return { message: 'Compte supprimé.', id };
  }

  // ===========================================================================
  // Permissions granulaires
  // ===========================================================================

  async getPermissions(userId: string) {
    await this.assertExists(userId);

    const rows = await this.prisma.leaderAccess.findMany({
      where: { userId, deletedAt: null },
      select: {
        featureName: true,
        canView: true,
        canCreate: true,
        canEdit: true,
        canDelete: true,
      },
    });

    const granted = new Map(rows.map((row) => [row.featureName, row]));

    // La grille complète est renvoyée, y compris les modules sans droits :
    // l'interface d'administration affiche un tableau à douze lignes et a
    // besoin de connaître l'état de chacune.
    return Object.values(FEATURES).map((feature) => {
      const row = granted.get(feature);
      return {
        feature,
        canView: row?.canView ?? false,
        canCreate: row?.canCreate ?? false,
        canEdit: row?.canEdit ?? false,
        canDelete: row?.canDelete ?? false,
      };
    });
  }

  /**
   * Remplace intégralement les permissions d'un utilisateur.
   *
   * Les modules absents de la liste voient leurs droits révoqués. Une
   * transaction garantit qu'aucun état intermédiaire n'est observable :
   * l'utilisateur ne peut jamais se retrouver avec la moitié de ses droits.
   */
  async setPermissions(userId: string, dto: SetPermissionsDto, actorUserId: string) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, ...NOT_DELETED },
      select: { id: true, email: true, role: true },
    });

    if (!user) {
      throw this.notFound(userId);
    }

    // Accorder des permissions à un administrateur n'a pas de sens : il passe
    // déjà partout. Le laisser faire créerait une grille trompeuse, laissant
    // croire que révoquer une case retirerait un accès.
    if (user.role === 'admin' || user.role === 'pastor') {
      throw new BadRequestException({
        message:
          'Les administrateurs et pasteurs disposent de tous les droits : ' +
          'les permissions granulaires ne s\'appliquent pas à eux.',
        code: 'PERMISSIONS_NOT_APPLICABLE',
      });
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.leaderAccess.deleteMany({ where: { userId } });

      const withAnyRight = dto.permissions.filter(
        (permission) =>
          permission.canView ||
          permission.canCreate ||
          permission.canEdit ||
          permission.canDelete,
      );

      if (withAnyRight.length > 0) {
        await tx.leaderAccess.createMany({
          data: withAnyRight.map((permission) => ({
            userId,
            featureName: permission.feature,
            canView: permission.canView,
            canCreate: permission.canCreate,
            canEdit: permission.canEdit,
            canDelete: permission.canDelete,
            createdBy: actorUserId,
          })),
        });
      }
    });

    this.logger.log(`Permissions mises à jour pour ${user.email}`);

    return this.getPermissions(userId);
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  /**
   * Empêche de supprimer ou désactiver le dernier administrateur.
   *
   * Sans ce garde-fou, une fausse manœuvre rendrait l'application
   * inadministrable : plus personne ne pourrait créer de compte, accorder des
   * droits, ni réactiver quoi que ce soit. La seule issue serait une
   * intervention directe en base.
   */
  private async assertNotLastAdmin(
    userId: string,
    role: string,
    willRemainActive: boolean,
  ): Promise<void> {
    if (willRemainActive) return;
    if (role !== 'admin' && role !== 'pastor') return;

    const remaining = await this.prisma.user.count({
      where: {
        id: { not: userId },
        role: { in: ['admin', 'pastor'] },
        isActive: true,
        ...NOT_DELETED,
      },
    });

    if (remaining === 0) {
      throw new BadRequestException({
        message:
          'Impossible : ce compte est le dernier administrateur actif. ' +
          'Désignez un autre administrateur au préalable.',
        code: 'LAST_ADMIN',
      });
    }
  }

  private async assertExists(id: string): Promise<void> {
    const user = await this.prisma.user.findFirst({
      where: { id, ...NOT_DELETED },
      select: { id: true },
    });

    if (!user) {
      throw this.notFound(id);
    }
  }

  private notFound(id: string): NotFoundException {
    return new NotFoundException({
      message: `Aucun compte ne correspond à l'identifiant ${id}.`,
      code: 'USER_NOT_FOUND',
    });
  }
}