import { Controller, Get, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';

import { PrismaService } from './prisma/prisma.service';

/**
 * Sonde de santé.
 *
 * Railway interroge cette route pour décider si un déploiement est réussi.
 * Elle est volontairement exclue du préfixe /api/v1 et de l'authentification :
 * un vérificateur de santé ne possède pas de jeton.
 *
 * La réponse ne divulgue aucune information exploitable (version de base,
 * schéma, noms d'hôtes) : cette route est publique par nature.
 */
@ApiExcludeController()
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