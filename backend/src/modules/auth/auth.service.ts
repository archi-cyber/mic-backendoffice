import {
  BadRequestException,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, randomBytes } from 'node:crypto';

import type { AppConfig } from '../../config/configuration';
import { PrismaService } from '../../prisma/prisma.service';
import { PasswordService } from './password.service';
import { TokenService, type SessionContext } from './token.service';
import type { AuthenticatedUser, TokenPair } from './types/auth.types';

export interface LoginResult extends TokenPair {
  user: {
    id: string;
    email: string;
    role: string;
    memberId: string | null;
    firstName: string | null;
    lastName: string | null;
  };
  mustChangePassword: boolean;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  /** Durée de validité d'un jeton de réinitialisation. */
  private static readonly RESET_TOKEN_TTL_MS = 60 * 60 * 1_000;

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordService,
    private readonly tokens: TokenService,
    private readonly config: ConfigService<AppConfig, true>,
  ) {}

  // ---------------------------------------------------------------------------
  // Connexion
  // ---------------------------------------------------------------------------

  async login(
    email: string,
    password: string,
    context: SessionContext = {},
  ): Promise<LoginResult> {
    const user = await this.prisma.user.findUnique({
      where: { email },
      select: {
        id: true,
        email: true,
        role: true,
        memberId: true,
        isActive: true,
        deletedAt: true,
        passwordHash: true,
        mustChangePassword: true,
        member: { select: { firstName: true, lastName: true, deletedAt: true } },
      },
    });

    // Compte inexistant : on consomme malgré tout le temps d'une vérification
    // pour ne pas révéler, par la durée de la réponse, quelles adresses sont
    // enregistrées.
    if (!user || user.deletedAt !== null) {
      await this.passwords.verifyDummy(password);
      throw this.invalidCredentials();
    }

    const passwordValid = await this.passwords.verify(user.passwordHash, password);
    if (!passwordValid) {
      throw this.invalidCredentials();
    }

    // Le compte désactivé n'est signalé qu'APRÈS validation du mot de passe :
    // l'annoncer plus tôt permettrait d'énumérer les comptes existants sans en
    // connaître le mot de passe.
    if (!user.isActive) {
      throw new UnauthorizedException({
        message: 'Ce compte a été désactivé. Contactez votre administrateur.',
        code: 'ACCOUNT_DISABLED',
      });
    }

    if (user.member?.deletedAt) {
      throw new UnauthorizedException({
        message: 'La fiche membre associée à ce compte a été supprimée.',
        code: 'MEMBER_DELETED',
      });
    }

    // Le mot de passe distribué par défaut impose un changement immédiat.
    const usingDefaultPassword =
      password === this.config.get('auth.defaultUserPassword', { infer: true });

    const mustChangePassword = user.mustChangePassword || usingDefaultPassword;

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        lastLoginAt: new Date(),
        ...(mustChangePassword !== user.mustChangePassword
          ? { mustChangePassword }
          : {}),
        // Renforcement transparent si les paramètres Argon2 ont évolué depuis
        // la création du compte.
        ...(this.passwords.needsRehash(user.passwordHash)
          ? { passwordHash: await this.passwords.hash(password) }
          : {}),
      },
    });

    const tokenPair = await this.tokens.issueTokenPair(user, context);

    this.logger.log(`Connexion réussie : ${user.email}`);

    return {
      ...tokenPair,
      mustChangePassword,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        memberId: user.memberId,
        firstName: user.member?.firstName ?? null,
        lastName: user.member?.lastName ?? null,
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  async refresh(refreshToken: string, context: SessionContext = {}): Promise<TokenPair> {
    return this.tokens.rotate(refreshToken, context);
  }

  async logout(refreshToken: string): Promise<{ message: string }> {
    await this.tokens.revoke(refreshToken);
    return { message: 'Déconnexion effectuée.' };
  }

  async logoutAll(userId: string): Promise<{ message: string; sessionsClosed: number }> {
    const count = await this.tokens.revokeAllForUser(userId);
    return {
      message: 'Toutes vos sessions ont été fermées.',
      sessionsClosed: count,
    };
  }

  async listSessions(userId: string) {
    return this.tokens.listActiveSessions(userId);
  }

  // ---------------------------------------------------------------------------
  // Profil
  // ---------------------------------------------------------------------------

  /**
   * Renvoie le profil complet de l'utilisateur connecté.
   *
   * Le client Flutter appelle cette route au démarrage pour reconstituer son
   * état (rôle, permissions, département) sans avoir à mémoriser ces
   * informations localement — où elles pourraient devenir obsolètes.
   */
  async getProfile(user: AuthenticatedUser) {
    const [record, permissions] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: user.id },
        select: {
          id: true,
          email: true,
          phone: true,
          role: true,
          memberId: true,
          mustChangePassword: true,
          lastLoginAt: true,
          createdAt: true,
          member: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              photoUrl: true,
              role: true,
              departmentId: true,
            },
          },
        },
      }),
      this.prisma.leaderAccess.findMany({
        where: { userId: user.id, deletedAt: null },
        select: {
          featureName: true,
          canView: true,
          canCreate: true,
          canEdit: true,
          canDelete: true,
        },
      }),
    ]);

    return {
      ...record,
      departmentRoles: user.departmentRoles,
      permissions: Object.fromEntries(
        permissions.map((permission) => [
          permission.featureName,
          {
            view: permission.canView,
            create: permission.canCreate,
            edit: permission.canEdit,
            delete: permission.canDelete,
          },
        ]),
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // Mots de passe
  // ---------------------------------------------------------------------------

  async changePassword(
    userId: string,
    currentPassword: string,
    newPassword: string,
  ): Promise<{ message: string }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, passwordHash: true },
    });

    if (!user) {
      throw new UnauthorizedException({
        message: 'Compte introuvable.',
        code: 'USER_NOT_FOUND',
      });
    }

    const valid = await this.passwords.verify(user.passwordHash, currentPassword);
    if (!valid) {
      throw new BadRequestException({
        message: 'Le mot de passe actuel est incorrect.',
        code: 'CURRENT_PASSWORD_INVALID',
      });
    }

    if (currentPassword === newPassword) {
      throw new BadRequestException({
        message: "Le nouveau mot de passe doit différer de l'actuel.",
        code: 'PASSWORD_UNCHANGED',
      });
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash: await this.passwords.hash(newPassword),
        mustChangePassword: false,
        passwordResetToken: null,
        passwordResetExpiresAt: null,
      },
    });

    // Toutes les autres sessions sont fermées : si le mot de passe a été
    // changé parce qu'il était compromis, laisser les jetons existants actifs
    // annulerait tout le bénéfice de l'opération.
    await this.tokens.revokeAllForUser(userId);

    this.logger.log(`Mot de passe modifié pour l'utilisateur ${userId}`);

    return {
      message: 'Mot de passe modifié. Veuillez vous reconnecter.',
    };
  }

  /**
   * Émet un jeton de réinitialisation.
   *
   * La réponse est identique que l'adresse existe ou non : révéler qu'un
   * compte est associé à une adresse donnée constitue une fuite d'information.
   *
   * L'envoi de l'e-mail n'est pas encore implémenté. En développement, le
   * jeton est renvoyé dans la réponse pour permettre les tests ; ce
   * comportement est strictement conditionné à `NODE_ENV`.
   */
  async requestPasswordReset(email: string): Promise<{ message: string; token?: string }> {
    const genericResponse = {
      message:
        'Si un compte existe pour cette adresse, un lien de réinitialisation vient d\'être envoyé.',
    };

    const user = await this.prisma.user.findUnique({
      where: { email },
      select: { id: true, isActive: true, deletedAt: true },
    });

    if (!user || !user.isActive || user.deletedAt !== null) {
      return genericResponse;
    }

    // Le jeton brut part par e-mail ; seule son empreinte est conservée.
    const rawToken = randomBytes(32).toString('base64url');
    const tokenHash = createHash('sha256').update(rawToken).digest('hex');

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordResetToken: tokenHash,
        passwordResetExpiresAt: new Date(Date.now() + AuthService.RESET_TOKEN_TTL_MS),
      },
    });

    this.logger.log(`Jeton de réinitialisation émis pour ${email}`);

    const isProduction = this.config.get('isProduction', { infer: true });

    return isProduction ? genericResponse : { ...genericResponse, token: rawToken };
  }

  async resetPassword(
    email: string,
    token: string,
    newPassword: string,
  ): Promise<{ message: string }> {
    const tokenHash = createHash('sha256').update(token).digest('hex');

    const user = await this.prisma.user.findUnique({
      where: { email },
      select: {
        id: true,
        passwordResetToken: true,
        passwordResetExpiresAt: true,
        isActive: true,
        deletedAt: true,
      },
    });

    const invalid = new BadRequestException({
      message: 'Jeton invalide ou expiré. Veuillez refaire une demande.',
      code: 'RESET_TOKEN_INVALID',
    });

    if (
      !user ||
      user.deletedAt !== null ||
      !user.isActive ||
      !user.passwordResetToken ||
      user.passwordResetToken !== tokenHash
    ) {
      throw invalid;
    }

    if (!user.passwordResetExpiresAt || user.passwordResetExpiresAt.getTime() < Date.now()) {
      throw invalid;
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash: await this.passwords.hash(newPassword),
        mustChangePassword: false,
        passwordResetToken: null,
        passwordResetExpiresAt: null,
      },
    });

    await this.tokens.revokeAllForUser(user.id);

    this.logger.log(`Mot de passe réinitialisé pour ${email}`);

    return { message: 'Mot de passe réinitialisé. Vous pouvez vous connecter.' };
  }

  // ---------------------------------------------------------------------------

  private invalidCredentials(): UnauthorizedException {
    return new UnauthorizedException({
      message: 'Adresse e-mail ou mot de passe incorrect.',
      code: 'INVALID_CREDENTIALS',
    });
  }
}