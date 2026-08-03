import { Logger, ValidationPipe, VersioningType } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import compression from 'compression';
import helmet from 'helmet';

import { AppModule } from './app.module';
import type { AppConfig } from './config/configuration';

async function bootstrap(): Promise<void> {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule, {
    // Les logs de démarrage sont mis en mémoire tampon jusqu'à ce que le
    // logger applicatif soit disponible : rien n'est perdu en cas d'échec
    // pendant l'initialisation.
    bufferLogs: true,
  });

  const config = app.get(ConfigService<AppConfig, true>);
  const isProduction = config.get('isProduction', { infer: true });
  const port = config.get('port', { infer: true });
  const apiPrefix = config.get('apiPrefix', { infer: true });
  const corsOrigins = config.get('cors.origins', { infer: true });

  // ---------------------------------------------------------------------------
  // Sécurité
  // ---------------------------------------------------------------------------

  app.use(
    helmet({
      // L'API ne sert pas de HTML : la politique de sécurité de contenu n'a
      // pas d'objet et gênerait l'interface Swagger.
      contentSecurityPolicy: false,
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );

  app.use(compression());

  // ---------------------------------------------------------------------------
  // CORS
  // ---------------------------------------------------------------------------

  app.enableCors({
    origin: (
      origin: string | undefined,
      callback: (error: Error | null, allow?: boolean) => void,
    ) => {
      // Requêtes sans origine : applications mobiles, curl, tests serveur.
      // Elles ne relèvent pas du modèle de sécurité CORS, qui protège les
      // navigateurs — les bloquer casserait les clients iOS et Android.
      if (!origin) {
        return callback(null, true);
      }

      // En développement, tout localhost est accepté : Flutter Web choisit un
      // port différent à chaque lancement.
      if (!isProduction && /^https?:\/\/localhost(:\d+)?$/.test(origin)) {
        return callback(null, true);
      }

      if (corsOrigins.includes(origin)) {
        return callback(null, true);
      }

      return callback(new Error(`Origine non autorisée par CORS : ${origin}`), false);
    },
    credentials: true,
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept-Language'],
    maxAge: 86_400,
  });

  // ---------------------------------------------------------------------------
  // Routage et validation
  // ---------------------------------------------------------------------------

  app.setGlobalPrefix(apiPrefix, {
    exclude: ['health', 'health/ready'],
  });

  app.useGlobalPipes(
    new ValidationPipe({
      // Retire les propriétés absentes du DTO. Un client qui enverrait
      // `{ role: "admin" }` sur une mise à jour de profil verrait le champ
      // ignoré plutôt qu'appliqué.
      whitelist: true,
      // Rejette explicitement au lieu d'ignorer silencieusement : le client
      // est informé de son erreur.
      forbidNonWhitelisted: true,
      // Convertit les types primitifs (paramètres d'URL en nombres, etc.).
      transform: true,
      transformOptions: { enableImplicitConversion: true },
      // En production, on masque la valeur reçue dans le message d'erreur pour
      // éviter de renvoyer des données sensibles dans les logs du client.
      disableErrorMessages: false,
      validationError: { target: false, value: !isProduction },
    }),
  );

  // Permet l'arrêt propre : Prisma ferme son pool avant que le conteneur
  // ne soit tué par Railway lors d'un redéploiement.
  app.enableShutdownHooks();

  // ---------------------------------------------------------------------------
  // Documentation OpenAPI
  // ---------------------------------------------------------------------------

  if (!isProduction) {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('SysteMIC API')
      .setDescription(
        "API de gestion d'église — membres, présences, tâches, finances et rapports.",
      )
      .setVersion('1.0')
      .addBearerAuth(
        {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: "Jeton d'accès obtenu via POST /auth/login",
        },
        'access-token',
      )
      .addTag('auth', 'Authentification et sessions')
      .addTag('members', 'Fiches membres')
      .addTag('departments', 'Départements et responsables')
      .addTag('church-attendance', 'Présence aux cultes')
      .addTag('tasks', 'Tâches, projets et pénalités')
      .addTag('giving', 'Finances')
      .addTag('reports', 'Rapports et statistiques')
      .build();

    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup(`${apiPrefix}/docs`, app, document, {
      swaggerOptions: {
        // Conserve le jeton entre deux rechargements de la page :
        // évite de se reconnecter à chaque test manuel.
        persistAuthorization: true,
        tagsSorter: 'alpha',
        operationsSorter: 'alpha',
      },
    });

    logger.log(`Documentation disponible sur /${apiPrefix}/docs`);
  }

  // ---------------------------------------------------------------------------
  // Démarrage
  // ---------------------------------------------------------------------------

  // '0.0.0.0' est requis sur Railway : écouter sur 127.0.0.1 rendrait le
  // service inaccessible depuis l'extérieur du conteneur.
  await app.listen(port, '0.0.0.0');

  logger.log(`SysteMIC API démarrée sur le port ${port}`);
  logger.log(`Environnement : ${config.get('nodeEnv', { infer: true })}`);
  logger.log(`Préfixe des routes : /${apiPrefix}`);
}

void bootstrap();