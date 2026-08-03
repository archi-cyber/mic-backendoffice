import { Controller, Get, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';

import { Public } from './common/decorators/public.decorator';
import { PrismaService } from './prisma/prisma.service';

/**
 * Sonde de santé.
 *
 * Railway interroge cette route pour décider si un déploiement est réussi.
 * Elle est exclue de deux mécanismes distincts, qu'il ne faut pas confondre :
 *
 *   - du préfixe /api/v1, via `setGlobalPrefix({ exclude: [...] })` dans main.ts ;
 *   - de l'authentification, via le décorateur `@Public()` ci-dessous.
 *
 * Le second est indispensable : un vérificateur de santé automatique ne
 * possède aucun jeton. Sans `@Public()`, Railway recevrait un 401 et
 * conclurait que le service est en panne, alors qu'il fonctionne.
 *
 * `@Public()` sur la classe couvre toutes ses routes.
 *
 * La réponse ne divulgue aucune information exploitable (version de base,
 * schéma, noms d'hôtes) : cette route est publique par nature.
 */
@ApiExcludeController()
@Public()
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Vérification légère — le processus répond-il ?
   */
  @Get()
  @HttpCode(HttpStatus.OK)
  check() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: Math.floor(process.uptime()),
    };
  }

  /**
   * Vérification approfondie — la base est-elle joignable ?
   *
   * Renvoie 503 si PostgreSQL ne répond pas, ce qui permet à Railway
   * d'interrompre un déploiement défectueux plutôt que de router du trafic
   * vers une instance incapable de servir la moindre requête.
   */
  @Get('ready')
  async readiness() {
    const databaseUp = await this.prisma.isHealthy();

    if (!databaseUp) {
      return {
        statusCode: HttpStatus.SERVICE_UNAVAILABLE,
        status: 'unavailable',
        checks: { database: 'down' },
        timestamp: new Date().toISOString(),
      };
    }

    return {
      status: 'ok',
      checks: { database: 'up' },
      timestamp: new Date().toISOString(),
    };
  }
}