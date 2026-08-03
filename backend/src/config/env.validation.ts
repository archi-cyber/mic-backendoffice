import * as Joi from 'joi';

/**
 * Validation des variables d'environnement au démarrage.
 *
 * NestJS applique ce schéma avant l'instanciation du moindre module. Une
 * variable manquante ou aberrante arrête l'application immédiatement, avec un
 * message explicite — plutôt que de laisser le serveur démarrer et échouer
 * plus tard sur une requête utilisateur.
 *
 * C'est particulièrement important sur Railway : un secret JWT oublié doit se
 * voir dans les logs de déploiement, pas en production trois jours plus tard.
 */
export const envValidationSchema = Joi.object({
  // --- Application ---
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),
  PORT: Joi.number().port().default(3000),
  API_PREFIX: Joi.string().default('api/v1'),
  LOG_LEVEL: Joi.string()
    .valid('fatal', 'error', 'warn', 'info', 'debug', 'trace')
    .default('info'),

  // --- Base de données ---
  DATABASE_URL: Joi.string()
    .uri({ scheme: ['postgresql', 'postgres'] })
    .required()
    .messages({
      'any.required':
        'DATABASE_URL est obligatoire. Sur Railway, utiliser ${{Postgres.DATABASE_URL}}.',
      'string.uri':
        'DATABASE_URL doit être une URL PostgreSQL valide (postgresql://...).',
    }),

  // --- Authentification ---
  // 32 caractères minimum : en dessous, un secret JWT devient attaquable
  // par force brute sur du matériel courant.
  JWT_ACCESS_SECRET: Joi.string().min(32).required().messages({
    'string.min': 'JWT_ACCESS_SECRET doit faire au moins 32 caractères.',
  }),
  JWT_REFRESH_SECRET: Joi.string()
    .min(32)
    .required()
    .invalid(Joi.ref('JWT_ACCESS_SECRET'))
    .messages({
      'string.min': 'JWT_REFRESH_SECRET doit faire au moins 32 caractères.',
      'any.invalid':
        'JWT_REFRESH_SECRET doit être différent de JWT_ACCESS_SECRET. ' +
        'Un secret partagé permettrait d\'utiliser un jeton de rafraîchissement comme jeton d\'accès.',
    }),
  JWT_ACCESS_EXPIRES_IN: Joi.string().default('15m'),
  JWT_REFRESH_EXPIRES_IN: Joi.string().default('30d'),

  DEFAULT_USER_PASSWORD: Joi.string().min(8).default('Password123'),
  SUPER_ADMIN_EMAIL: Joi.string().email().default('admin@systemic.church'),
  SUPER_ADMIN_PASSWORD: Joi.string().min(8).default('ChangeMe2026!'),

  // --- CORS ---
  CORS_ORIGINS: Joi.string().allow('').default(''),

  // --- Limitation de débit ---
  THROTTLE_TTL: Joi.number().positive().default(60),
  THROTTLE_LIMIT: Joi.number().positive().default(120),

  // --- Firebase (optionnel : vide = notifications push désactivées) ---
  FIREBASE_PROJECT_ID: Joi.string().allow('').optional(),
  FIREBASE_CLIENT_EMAIL: Joi.string().allow('').optional(),
  FIREBASE_PRIVATE_KEY: Joi.string().allow('').optional(),

  // --- Règles métier ---
  DEFAULT_DAILY_PENALTY_AMOUNT: Joi.number().min(0).default(100),
  BLOCKING_THRESHOLD_AMOUNT: Joi.number().min(0).default(3500),
  TEACHING_TASK_DUE_OFFSET_DAYS: Joi.number().min(0).default(10),
  NEWCOMER_GRADUATION_ATTENDANCES: Joi.number().min(1).default(9),
  NEWCOMER_GRADUATION_WINDOW_DAYS: Joi.number().min(1).default(90),
});