/**
 * Configuration applicative typée.
 *
 * Toutes les variables d'environnement transitent par ce fichier. Aucun autre
 * module ne doit lire `process.env` directement : cela garantit un point unique
 * de conversion (chaîne -> nombre/booléen/tableau) et facilite les tests.
 *
 * Usage :
 *   constructor(private readonly config: ConfigService<AppConfig, true>) {}
 *   const port = this.config.get('port', { infer: true });
 */

export interface AppConfig {
  nodeEnv: 'development' | 'production' | 'test';
  isProduction: boolean;
  port: number;
  apiPrefix: string;
  logLevel: string;

  database: {
    url: string;
  };

  jwt: {
    accessSecret: string;
    refreshSecret: string;
    accessExpiresIn: string;
    refreshExpiresIn: string;
  };

  auth: {
    defaultUserPassword: string;
    superAdminEmail: string;
    superAdminPassword: string;
  };

  cors: {
    origins: string[];
  };

  throttle: {
    ttl: number;
    limit: number;
  };

  firebase: {
    enabled: boolean;
    projectId?: string;
    clientEmail?: string;
    privateKey?: string;
  };

  business: {
    defaultDailyPenaltyAmount: number;
    blockingThresholdAmount: number;
    teachingTaskDueOffsetDays: number;
    newcomerGraduationAttendances: number;
    newcomerGraduationWindowDays: number;
  };
}

/** Convertit une chaîne d'environnement en entier, avec valeur de repli. */
const toInt = (value: string | undefined, fallback: number): number => {
  const parsed = Number.parseInt(value ?? '', 10);
  return Number.isNaN(parsed) ? fallback : parsed;
};

/** Découpe une liste séparée par des virgules en tableau nettoyé. */
const toList = (value: string | undefined): string[] =>
  (value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item.length > 0);

export default (): AppConfig => {
  const nodeEnv = (process.env.NODE_ENV ?? 'development') as AppConfig['nodeEnv'];

  // Les clés privées Firebase contiennent des retours à la ligne. Stockées dans
  // une variable d'environnement, ils arrivent échappés en "\n" littéral.
  const firebasePrivateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  return {
    nodeEnv,
    isProduction: nodeEnv === 'production',
    port: toInt(process.env.PORT, 3000),
    apiPrefix: process.env.API_PREFIX ?? 'api/v1',
    logLevel: process.env.LOG_LEVEL ?? (nodeEnv === 'production' ? 'info' : 'debug'),

    database: {
      url: process.env.DATABASE_URL as string,
    },

    jwt: {
      accessSecret: process.env.JWT_ACCESS_SECRET as string,
      refreshSecret: process.env.JWT_REFRESH_SECRET as string,
      accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN ?? '15m',
      refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '30d',
    },

    auth: {
      defaultUserPassword: process.env.DEFAULT_USER_PASSWORD ?? 'Password123',
      superAdminEmail: process.env.SUPER_ADMIN_EMAIL ?? 'admin@systemic.church',
      superAdminPassword: process.env.SUPER_ADMIN_PASSWORD ?? 'ChangeMe2026!',
    },

    cors: {
      origins: toList(process.env.CORS_ORIGINS),
    },

    throttle: {
      ttl: toInt(process.env.THROTTLE_TTL, 60),
      limit: toInt(process.env.THROTTLE_LIMIT, 120),
    },

    firebase: {
      enabled: Boolean(
        process.env.FIREBASE_PROJECT_ID &&
          process.env.FIREBASE_CLIENT_EMAIL &&
          firebasePrivateKey,
      ),
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: firebasePrivateKey,
    },

    business: {
      defaultDailyPenaltyAmount: toInt(process.env.DEFAULT_DAILY_PENALTY_AMOUNT, 100),
      blockingThresholdAmount: toInt(process.env.BLOCKING_THRESHOLD_AMOUNT, 3500),
      teachingTaskDueOffsetDays: toInt(process.env.TEACHING_TASK_DUE_OFFSET_DAYS, 10),
      newcomerGraduationAttendances: toInt(process.env.NEWCOMER_GRADUATION_ATTENDANCES, 9),
      newcomerGraduationWindowDays: toInt(process.env.NEWCOMER_GRADUATION_WINDOW_DAYS, 90),
    },
  };
};