import { Global, Module } from '@nestjs/common';

import { PrismaService } from './prisma.service';

/**
 * Module d'accès à la base de données.
 *
 * Marqué `@Global` : PrismaService est injectable dans n'importe quel module
 * sans réimporter PrismaModule à chaque fois. C'est l'exception raisonnable à
 * la règle « pas de module global » — l'accès aux données est transversal, et
 * l'alternative serait de répéter l'import dans les 25 modules métier.
 *
 * Une seule instance de PrismaClient existe dans l'application : ouvrir
 * plusieurs clients multiplierait les pools de connexions et saturerait
 * rapidement la limite PostgreSQL de Railway.
 */
@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}