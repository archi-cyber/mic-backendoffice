import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import type { UserRole } from '@prisma/client';
import { createHash, randomUUID } from 'node:crypto';

import type { AppConfig } from '../../config/configuration';
import { PrismaService } from '../../prisma/prisma.service';
import type {
  AccessTokenPayload,
  RefreshTokenPayload,
  TokenPair,
} from './types/auth.types';

export interface SessionContext {
  deviceInfo?: string;
  ipAddress?: string;
}

@Injectable()
export class TokenService {
  private readonly logger = new Logger(TokenService.name);

  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    private readonly config: ConfigService<AppConfig, true>,
  ) {}

  // ---------------------------------------------------------------------------
  // Émission
  // ---------------------------------------------------------------------------

  /**
   * Émet un couple accès + rafraîchissement et enregistre la session.
   */
  async issueTokenPair(
    user: { id: string; email: string; role: UserRole },
    context: SessionContext = {},
  ): Promise<TokenPair> {
    const accessSecret = this.config.get('jwt.accessSecret', { infer: true });
    const refreshSecret = this.config.get('jwt.refreshSecret', { infer: true });
    const accessExpiresIn = this.config.get('jwt.accessExpiresIn', { infer: true });
    const refreshExpiresIn = this.config.get('jwt.refreshExpiresIn', { infer: true });

    const accessPayload: AccessTokenPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      typ: 'access',
    };

    const jti = randomUUID();
    const refreshPayload: RefreshTokenPayload = {
      sub: user.id,
      jti,
      typ: 'refresh',
    };

   const [accessToken, refreshToken] = await Promise.all([
      this.jwt.signAsync(accessPayload, {
        secret: accessSecret,
        // Converti en secondes : `expiresIn` n'accepte pas un `string`
        // générique, mais un nombre est toujours valide.
        expiresIn: this.durationToSeconds(accessExpiresIn),
      }),
      this.jwt.signAsync(refreshPayload, {
        secret: refreshSecret,
        expiresIn: this.durationToSeconds(refreshExpiresIn),
      }),
    ]);

    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: this.hashToken(refreshToken),
        deviceInfo: context.deviceInfo?.slice(0, 255),
        ipAddress: context.ipAddress,
        expiresAt: this.expiryFromDuration(refreshExpiresIn),
      },
    });

    return {
      accessToken,
      refreshToken,
      expiresIn: this.durationToSeconds(accessExpiresIn),
    };
  }

  // ---------------------------------------------------------------------------
  // Rotation
  // ---------------------------------------------------------------------------

  /**
   * Échange un jeton de rafraîchissement contre un couple neuf.
   *
   * La rotation est systématique : l'ancien jeton est révoqué au moment même
   * où le nouveau est émis. Un jeton intercepté ne vaut donc qu'une seule
   * utilisation.
   *
   * Si un jeton déjà révoqué est présenté, toutes les sessions de
   * l'utilisateur sont invalidées. Cette réaction peut paraître brutale, mais
   * la situation ne laisse guère d'alternative : soit un attaquant réutilise
   * un jeton volé, soit le véritable utilisateur présente un jeton qu'un
   * attaquant a déjà consommé. Dans les deux cas, une reconnexion s'impose.
   */
  async rotate(
    refreshToken: string,
    context: SessionContext = {},
  ): Promise<TokenPair> {
    const payload = await this.verifyRefreshToken(refreshToken);
    const tokenHash = this.hashToken(refreshToken);

    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      select: {
        id: true,
        userId: true,
        revokedAt: true,
        expiresAt: true,
        user: {
          select: {
            id: true,
            email: true,
            role: true,
            isActive: true,
            deletedAt: true,
          },
        },
      },
    });

    if (!stored) {
      throw new UnauthorizedException({
        message: 'Session inconnue. Veuillez vous reconnecter.',
        code: 'REFRESH_TOKEN_UNKNOWN',
      });
    }

    if (stored.revokedAt) {
      this.logger.warn(
        `Réutilisation d'un jeton révoqué détectée pour l'utilisateur ${stored.userId}. ` +
          'Révocation de toutes ses sessions.',
      );
      await this.revokeAllForUser(stored.userId);

      throw new UnauthorizedException({
        message: 'Session compromise. Toutes vos sessions ont été fermées.',
        code: 'REFRESH_TOKEN_REUSED',
      });
    }

    if (stored.expiresAt.getTime() <= Date.now()) {
      throw new UnauthorizedException({
        message: 'Session expirée. Veuillez vous reconnecter.',
        code: 'REFRESH_TOKEN_EXPIRED',
      });
    }

    const user = stored.user;
    if (!user.isActive || user.deletedAt !== null) {
      throw new UnauthorizedException({
        message: 'Ce compte a été désactivé.',
        code: 'ACCOUNT_DISABLED',
      });
    }

    if (payload.sub !== user.id) {
      throw new UnauthorizedException({
        message: 'Jeton incohérent.',
        code: 'REFRESH_TOKEN_MISMATCH',
      });
    }

    // La révocation de l'ancien jeton et l'émission du nouveau forment une
    // seule transaction : une coupure entre les deux laisserait l'utilisateur
    // sans session valide.
    return this.prisma.$transaction(async () => {
      await this.prisma.refreshToken.update({
        where: { id: stored.id },
        data: { revokedAt: new Date() },
      });

      return this.issueTokenPair(user, context);
    });
  }

  // ---------------------------------------------------------------------------
  // Révocation
  // ---------------------------------------------------------------------------

  /** Ferme la session correspondant à un jeton donné (déconnexion). */
  async revoke(refreshToken: string): Promise<void> {
    const tokenHash = this.hashToken(refreshToken);

    await this.prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  /** Ferme toutes les sessions d'un utilisateur, sur tous ses appareils. */
  async revokeAllForUser(userId: string): Promise<number> {
    const result = await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });

    return result.count;
  }

  /**
   * Supprime les jetons expirés ou révoqués depuis plus de trente jours.
   *
   * Appelé par une tâche planifiée : sans purge, la table grossirait
   * indéfiniment, un enregistrement par connexion et par appareil.
   */
  async purgeExpired(): Promise<number> {
    const threshold = new Date(Date.now() - 30 * 24 * 60 * 60 * 1_000);

    const result = await this.prisma.refreshToken.deleteMany({
      where: {
        OR: [
          { expiresAt: { lt: new Date() } },
          { revokedAt: { lt: threshold } },
        ],
      },
    });

    if (result.count > 0) {
      this.logger.log(`${result.count} jeton(s) de rafraîchissement purgé(s).`);
    }

    return result.count;
  }

  /** Liste les sessions actives, pour affichage dans les paramètres. */
  async listActiveSessions(userId: string) {
    return this.prisma.refreshToken.findMany({
      where: {
        userId,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      select: {
        id: true,
        deviceInfo: true,
        ipAddress: true,
        createdAt: true,
        expiresAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ---------------------------------------------------------------------------
  // Utilitaires internes
  // ---------------------------------------------------------------------------

  private async verifyRefreshToken(token: string): Promise<RefreshTokenPayload> {
    try {
      const payload = await this.jwt.verifyAsync<RefreshTokenPayload>(token, {
        secret: this.config.get('jwt.refreshSecret', { infer: true }),
      });

      if (payload.typ !== 'refresh') {
        throw new Error('type incorrect');
      }

      return payload;
    } catch {
      throw new UnauthorizedException({
        message: 'Jeton de rafraîchissement invalide.',
        code: 'REFRESH_TOKEN_INVALID',
      });
    }
  }

  /**
   * Empreinte SHA-256 du jeton.
   *
   * Le jeton lui-même n'est jamais stocké : une fuite de la table ne
   * permettrait pas d'usurper une session. SHA-256 suffit ici, contrairement
   * aux mots de passe — un JWT est déjà une valeur aléatoire de haute entropie,
   * insensible aux attaques par dictionnaire. Un hachage déterministe est par
   * ailleurs nécessaire pour retrouver la ligne par égalité.
   */
  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  /** Convertit « 15m », « 30d », « 12h » en secondes. */
  private durationToSeconds(duration: string): number {
    const match = /^(\d+)([smhd])$/.exec(duration.trim());
    if (!match) {
      return 900; // 15 minutes par défaut
    }

    const value = Number.parseInt(match[1], 10);
    const multiplier = { s: 1, m: 60, h: 3_600, d: 86_400 }[match[2]] ?? 60;

    return value * multiplier;
  }

  private expiryFromDuration(duration: string): Date {
    return new Date(Date.now() + this.durationToSeconds(duration) * 1_000);
  }
}