import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma, PrismaClient } from '@prisma/client';

import type { AppConfig } from '../config/configuration';

/**
 * Modèles disposant d'une colonne `deletedAt`.
 *
 * Ces tables ne sont jamais purgées : on marque la date de suppression et on
 * exclut la ligne des lectures. Cela préserve l'historique (présences, dons,
 * rapports) — indispensable pour une comptabilité d'église auditable.
 */
export const SOFT_DELETE_MODELS = [
  'User',
  'Member',
  'NewComer',
  'Visitor',
  'Department',
  'DepartmentReport',
  'ChurchService',
  'ChurchAttendance',
  'SundaySchoolAttendance',
  'Teaching',
  'TeachingListener',
  'Class',
  'Event',
  'Project',
  'Task',
  'Giving',
  'Announcement',
  'LeaderAccess',
] as const;

/**
 * Filtre à insérer dans tout `where` de lecture.
 *
 * Convention du projet : chaque requête sur un modèle « soft delete » ajoute
 * explicitement ce filtre. Le choix de l'explicite plutôt qu'un filtrage
 * automatique global est délibéré — un filtre invisible rend incompréhensibles
 * les cas où l'on veut justement les lignes supprimées (rapports d'audit,
 * restauration, détection de doublons).
 *
 * @example
 *   this.prisma.member.findMany({ where: { ...NOT_DELETED, isActive: true } })
 */
export const NOT_DELETED = { deletedAt: null } as const;

@Injectable()
export class PrismaService
  extends PrismaClient<Prisma.PrismaClientOptions, 'query' | 'warn' | 'error'>
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(PrismaService.name);

  /** Nombre de tentatives de connexion au démarrage. */
  private static readonly MAX_CONNECTION_ATTEMPTS = 5;

  /** Délai de base entre deux tentatives (ms), doublé à chaque échec. */
  private static readonly RETRY_BASE_DELAY_MS = 1_000;

  constructor(private readonly config: ConfigService<AppConfig, true>) {
    const isProduction = config.get('isProduction', { infer: true });

    super({
      datasources: {
        db: { url: config.get('database.url', { infer: true }) },
      },
      // En développement, on trace chaque requête pour repérer les N+1.
      // En production, seuls les avertissements et erreurs sont émis.
      log: isProduction
        ? [
            { emit: 'event', level: 'warn' },
            { emit: 'event', level: 'error' },
          ]
        : [
            { emit: 'event', level: 'query' },
            { emit: 'event', level: 'warn' },
            { emit: 'event', level: 'error' },
          ],
      errorFormat: isProduction ? 'minimal' : 'pretty',
    });

    this.registerLogHandlers(isProduction);
  }

  // ---------------------------------------------------------------------------
  // Cycle de vie
  // ---------------------------------------------------------------------------

  async onModuleInit(): Promise<void> {
    await this.connectWithRetry();
  }

  async onModuleDestroy(): Promise<void> {
    this.logger.log('Fermeture du pool de connexions PostgreSQL…');
    await this.$disconnect();
  }

  /**
   * Connexion avec réessais et attente exponentielle.
   *
   * Sur Railway, le service backend et la base démarrent en parallèle. Le
   * backend est régulièrement prêt avant que PostgreSQL n'accepte les
   * connexions : sans réessai, le conteneur planterait au boot et Railway
   * enchaînerait les redémarrages en boucle.
   */
  private async connectWithRetry(): Promise<void> {
    const maxAttempts = PrismaService.MAX_CONNECTION_ATTEMPTS;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await this.$connect();
        this.logger.log('Connexion PostgreSQL établie.');
        await this.logDatabaseIdentity();
        return;
      } catch (error) {
        const isLastAttempt = attempt === maxAttempts;
        const message = error instanceof Error ? error.message : String(error);

        if (isLastAttempt) {
          this.logger.error(
            `Connexion PostgreSQL impossible après ${maxAttempts} tentatives : ${message}`,
          );
          throw error;
        }

        const delay = PrismaService.RETRY_BASE_DELAY_MS * 2 ** (attempt - 1);
        this.logger.warn(
          `Connexion PostgreSQL échouée (tentative ${attempt}/${maxAttempts}). ` +
            `Nouvel essai dans ${delay} ms.`,
        );
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
  }

  /**
   * Trace la base réellement atteinte.
   *
   * Ce contrôle a une valeur opérationnelle concrète : il rend visible, dès le
   * démarrage, le cas où l'application pointe vers une autre base que prévu.
   * Une erreur de configuration silencieuse de ce type peut coûter des heures
   * de diagnostic.
   */
  private async logDatabaseIdentity(): Promise<void> {
    try {
      const [row] = await this.$queryRaw<
        { database: string; host: string | null }[]
      >`SELECT current_database() AS database, inet_server_addr()::text AS host`;

      this.logger.log(
        `Base active : ${row?.database ?? 'inconnue'} sur ${row?.host ?? 'hôte local'}`,
      );
    } catch {
      // Purement informatif : ne doit jamais empêcher le démarrage.
      this.logger.debug("Identité de la base non déterminable.");
    }
  }

  // ---------------------------------------------------------------------------
  // Journalisation
  // ---------------------------------------------------------------------------

  private registerLogHandlers(isProduction: boolean): void {
    this.$on('error', (event) => {
      this.logger.error(event.message);
    });

    this.$on('warn', (event) => {
      this.logger.warn(event.message);
    });

    if (!isProduction) {
      this.$on('query', (event) => {
        // Seules les requêtes lentes sont signalées : tracer l'intégralité du
        // trafic SQL noierait les logs et masquerait les vrais problèmes.
        if (event.duration >= 200) {
          this.logger.warn(
            `Requête lente (${event.duration} ms) : ${event.query}`,
          );
        } else {
          this.logger.debug(`${event.duration} ms — ${event.query}`);
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------

  /**
   * Vérifie que la base répond. Utilisé par la sonde de santé `/health`.
   */
  async isHealthy(): Promise<boolean> {
    try {
      await this.$queryRaw`SELECT 1`;
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Vide toutes les tables — réservé aux tests automatisés.
   *
   * La garde sur `NODE_ENV` est délibérément stricte : cette méthode détruit
   * l'intégralité des données. Elle refuse de s'exécuter ailleurs qu'en test.
   */
  async truncateAllTables(): Promise<void> {
    if (this.config.get('nodeEnv', { infer: true }) !== 'test') {
      throw new Error(
        'truncateAllTables() est réservé à l\'environnement de test.',
      );
    }

    const tables = await this.$queryRaw<{ tablename: string }[]>`
      SELECT tablename FROM pg_tables
      WHERE schemaname = 'public' AND tablename NOT LIKE '_prisma%'
    `;

    const list = tables.map((t) => `"public"."${t.tablename}"`).join(', ');
    if (list.length > 0) {
      await this.$executeRawUnsafe(`TRUNCATE TABLE ${list} CASCADE;`);
    }
  }
}