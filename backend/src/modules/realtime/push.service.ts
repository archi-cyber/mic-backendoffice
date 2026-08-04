import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import type { AppConfig } from '../../config/configuration';
import { PrismaService } from '../../prisma/prisma.service';

export interface PushMessage {
  title: string;
  body: string;
  /** Données transmises au client pour router le clic. */
  data?: Record<string, string>;
}

/**
 * Notifications push (Firebase Cloud Messaging).
 *
 * Entièrement optionnel. Sans les variables `FIREBASE_*`, le service se
 * désactive au démarrage et toutes ses méthodes deviennent des non-opérations.
 * L'application fonctionne normalement — les notifications restent
 * consultables via `GET /notifications` et arrivent en temps réel par
 * Socket.IO tant que l'application est ouverte.
 *
 * Le push n'apporte quelque chose que dans un cas précis : prévenir un
 * utilisateur dont l'application est fermée. C'est utile, mais pas
 * indispensable au fonctionnement.
 *
 * Le paquet `firebase-admin` est chargé dynamiquement : son absence ne doit
 * pas empêcher le backend de démarrer.
 */
@Injectable()
export class PushService implements OnModuleInit {
  private readonly logger = new Logger(PushService.name);

  private enabled = false;
  private messaging: {
    sendEachForMulticast: (message: unknown) => Promise<{
      successCount: number;
      failureCount: number;
      responses: Array<{ success: boolean; error?: { code?: string } }>;
    }>;
  } | null = null;

  constructor(
    private readonly config: ConfigService<AppConfig, true>,
    private readonly prisma: PrismaService,
  ) {}

  async onModuleInit(): Promise<void> {
    const firebase = this.config.get('firebase', { infer: true });

    if (!firebase.enabled) {
      this.logger.log(
        'Notifications push désactivées : variables FIREBASE_* absentes.',
      );
      return;
    }

    try {
      // Import dynamique : sans cela, l'absence du paquet ferait échouer la
      // compilation et le démarrage, alors que la fonctionnalité est optionnelle.
      const { getApps, getApp, initializeApp, cert } =
  await import('firebase-admin/app');

const { getMessaging } =
  await import('firebase-admin/messaging');

const app =
  getApps().length > 0
    ? getApp()
    : initializeApp({
        credential: cert({
          projectId: firebase.projectId,
          clientEmail: firebase.clientEmail,
          privateKey: firebase.privateKey,
        }),
      });

this.messaging = getMessaging(app) as typeof this.messaging;

this.enabled = true;
      this.logger.log('Notifications push activées.');
    } 
    
    catch (error) {
      // Le démarrage se poursuit : une configuration push incorrecte ne doit
      // pas empêcher l'église d'utiliser son application.
      this.logger.warn(
        'Notifications push indisponibles : ' +
          `${error instanceof Error ? error.message : 'erreur inconnue'}. ` +
          "Installez firebase-admin (npm install firebase-admin) et vérifiez " +
          'les variables FIREBASE_*.',
      );
    }
  }

  // ===========================================================================
  // Envoi
  // ===========================================================================

  /**
   * Envoie une notification aux appareils d'un membre.
   *
   * Un membre peut avoir plusieurs appareils enregistrés : téléphone,
   * tablette, navigateur. Tous sont visés.
   */
  async sendToMember(memberId: string, message: PushMessage): Promise<number> {
    if (!this.enabled) return 0;

    const tokens = await this.tokensForMembers([memberId]);
    return this.send(tokens, message);
  }

  async sendToMembers(
    memberIds: string[],
    message: PushMessage,
  ): Promise<number> {
    if (!this.enabled) return 0;

    const tokens = await this.tokensForMembers(memberIds);
    return this.send(tokens, message);
  }

  // ===========================================================================
  // Internes
  // ===========================================================================

  /**
   * Récupère les jetons d'appareil des membres visés.
   *
   * Le passage par `users` est nécessaire : les jetons sont attachés au compte
   * de connexion, pas à la fiche membre. Un membre sans compte n'a donc aucun
   * appareil enregistré, ce qui est cohérent — il ne peut pas se connecter.
   */
  private async tokensForMembers(memberIds: string[]): Promise<string[]> {
    const devices = await this.prisma.userDevice.findMany({
      where: {
        user: {
          memberId: { in: [...new Set(memberIds)] },
          isActive: true,
          deletedAt: null,
        },
      },
      select: { deviceToken: true },
    });

    return devices.map((device) => device.deviceToken);
  }

  private async send(tokens: string[], message: PushMessage): Promise<number> {
    if (!this.messaging || tokens.length === 0) return 0;

    try {
      const response = await this.messaging.sendEachForMulticast({
        tokens,
        notification: { title: message.title, body: message.body },
        data: message.data ?? {},
        android: { priority: 'high' },
        apns: {
          payload: { aps: { sound: 'default', badge: 1 } },
        },
      });

      if (response.failureCount > 0) {
        await this.pruneInvalidTokens(tokens, response.responses);
      }

      return response.successCount;
    } catch (error) {
      this.logger.warn(
        "Echec de l'envoi push : " +
          `${error instanceof Error ? error.message : 'erreur inconnue'}`,
      );
      return 0;
    }
  }

  /**
   * Supprime les jetons rejetés par Firebase.
   *
   * Un jeton devient invalide quand l'application est désinstallée ou que
   * l'utilisateur efface ses données. Les conserver ferait grossir la table
   * indéfiniment et allongerait chaque envoi pour rien.
   */
  private async pruneInvalidTokens(
    tokens: string[],
    responses: Array<{ success: boolean; error?: { code?: string } }>,
  ): Promise<void> {
    const invalid = tokens.filter((_, index) => {
      const response = responses[index];
      if (response?.success) return false;

      const code = response?.error?.code;
      return (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      );
    });

    if (invalid.length === 0) return;

    const result = await this.prisma.userDevice.deleteMany({
      where: { deviceToken: { in: invalid } },
    });

    this.logger.log(`${result.count} jeton(s) d'appareil obsolète(s) supprimé(s).`);
  }
}