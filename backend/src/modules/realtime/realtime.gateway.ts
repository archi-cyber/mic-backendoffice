import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';

import type { AppConfig } from '../../config/configuration';
import { PrismaService } from '../../prisma/prisma.service';
import type { AccessTokenPayload } from '../auth/types/auth.types';
import { RealtimeService } from './realtime.service';
import { ROOMS, type SocketUser } from './realtime.types';

/** Socket enrichie de l'identité authentifiée. */
interface AuthenticatedSocket extends Socket {
  data: { user?: SocketUser };
}

@WebSocketGateway({
  namespace: '/realtime',
  cors: {
    // Le contrôle d'accès repose ici sur le jeton, pas sur l'origine : les
    // clients mobiles n'en envoient pas, et les rejeter couperait iOS et
    // Android. Une connexion sans jeton valide est refusée de toute façon.
    origin: true,
    credentials: true,
  },
  // Autorise la reconnexion automatique du client après une coupure réseau,
  // fréquente en usage mobile.
  pingInterval: 25_000,
  pingTimeout: 20_000,
})
export class RealtimeGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(RealtimeGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService<AppConfig, true>,
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
  ) {}

  afterInit(server: Server): void {
    this.realtime.setServer(server);
  }

  // ===========================================================================
  // Connexion
  // ===========================================================================

  /**
   * Authentifie la connexion et inscrit la socket à ses salons.
   *
   * Le jeton est accepté depuis `auth.token` (méthode recommandée) ou depuis
   * la chaîne de requête, car certains clients ne savent pas envoyer d'objet
   * `auth` au moment du handshake.
   *
   * Une connexion sans jeton valide est fermée immédiatement plutôt que
   * tolérée en lecture seule : un socket anonyme n'aurait accès à aucun salon
   * utile, et le laisser ouvert consommerait des ressources pour rien.
   */
  async handleConnection(client: AuthenticatedSocket): Promise<void> {
    try {
      const token = this.extractToken(client);

      if (!token) {
        this.reject(client, 'Jeton absent.');
        return;
      }

      const payload = await this.jwt.verifyAsync<AccessTokenPayload>(token, {
        secret: this.config.get('jwt.accessSecret', { infer: true }),
      });

      if (payload.typ !== 'access') {
        this.reject(client, 'Type de jeton incorrect.');
        return;
      }

      const user = await this.loadUser(payload.sub);

      if (!user) {
        this.reject(client, 'Compte introuvable ou désactivé.');
        return;
      }

      client.data.user = user;
      await this.joinRooms(client, user);

      this.logger.log(`Connexion : ${user.email}`);

      // Confirme au client que l'authentification a réussi. Sans ce signal,
      // il ne saurait pas distinguer « connecté et authentifié » de
      // « connecté, en attente de rejet ».
      client.emit('connected', {
        userId: user.userId,
        memberId: user.memberId,
        rooms: this.roomsFor(user),
      });
    } catch (error) {
      this.reject(
        client,
        error instanceof Error && error.name === 'TokenExpiredError'
          ? 'Jeton expiré.'
          : 'Authentification échouée.',
      );
    }
  }

  handleDisconnect(client: AuthenticatedSocket): void {
    const user = client.data.user;
    if (user) {
      this.logger.log(`Déconnexion : ${user.email}`);
    }
  }

  // ===========================================================================
  // Messages entrants
  // ===========================================================================

  /**
   * Rejoint le salon d'un culte pour suivre la saisie en direct.
   *
   * Le client s'y inscrit en ouvrant l'écran de pointage, et en sort en le
   * quittant. Inscrire d'office chaque connexion à tous les cultes
   * diffuserait un volume inutile vers des écrans qui n'affichent rien.
   */
  @SubscribeMessage('service:join')
  handleJoinService(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { churchServiceId?: string },
  ): { joined: boolean; room?: string } {
    if (!client.data.user || !data?.churchServiceId) {
      return { joined: false };
    }

    const room = ROOMS.service(data.churchServiceId);
    void client.join(room);

    return { joined: true, room };
  }

  @SubscribeMessage('service:leave')
  handleLeaveService(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() data: { churchServiceId?: string },
  ): { left: boolean } {
    if (!data?.churchServiceId) {
      return { left: false };
    }

    void client.leave(ROOMS.service(data.churchServiceId));
    return { left: true };
  }

  /** Sonde applicative, distincte du ping protocolaire de Socket.IO. */
  @SubscribeMessage('ping')
  handlePing(): { pong: number } {
    return { pong: Date.now() };
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  private extractToken(client: Socket): string | null {
    const fromAuth = (client.handshake.auth as { token?: string } | undefined)
      ?.token;

    if (fromAuth) return fromAuth;

    const fromQuery = client.handshake.query?.token;
    if (typeof fromQuery === 'string') return fromQuery;

    // Dernier recours : en-tête Authorization, utilisé par certains clients.
    const header = client.handshake.headers?.authorization;
    if (typeof header === 'string' && header.startsWith('Bearer ')) {
      return header.slice(7);
    }

    return null;
  }

  /**
   * Recharge l'utilisateur depuis la base.
   *
   * Comme pour les requêtes HTTP, on ne se contente pas du contenu du jeton :
   * un compte désactivé entre-temps ne doit pas conserver une connexion
   * ouverte, potentiellement pendant des heures.
   */
  private async loadUser(userId: string): Promise<SocketUser | null> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        role: true,
        memberId: true,
        isActive: true,
        deletedAt: true,
        member: {
          select: {
            deletedAt: true,
            departmentMembers: { select: { departmentId: true } },
          },
        },
      },
    });

    if (!user || !user.isActive || user.deletedAt !== null) {
      return null;
    }

    if (user.member?.deletedAt) {
      return null;
    }

    return {
      userId: user.id,
      memberId: user.memberId,
      email: user.email,
      role: user.role,
      departmentIds: (user.member?.departmentMembers ?? []).map(
        (row) => row.departmentId,
      ),
    };
  }

  private async joinRooms(
    client: AuthenticatedSocket,
    user: SocketUser,
  ): Promise<void> {
    await client.join(this.roomsFor(user));
  }

  private roomsFor(user: SocketUser): string[] {
    return [
      ROOMS.global,
      ROOMS.user(user.userId),
      ...(user.memberId ? [ROOMS.member(user.memberId)] : []),
      ...user.departmentIds.map((id) => ROOMS.department(id)),
    ];
  }

  private reject(client: Socket, reason: string): void {
    this.logger.debug(`Connexion refusée : ${reason}`);
    client.emit('unauthorized', { message: reason });
    client.disconnect(true);
  }
}