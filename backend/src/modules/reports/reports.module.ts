import { Module } from '@nestjs/common';

import { ReportsController } from './reports.controller';
import { ReportsService } from './reports.service';

/**
 * Rapports et agregations.
 *
 * Ce module ne detient aucune donnee propre : il assemble celles des autres.
 * Les requetes y sont souvent ecrites en SQL brut, car les agregations par
 * mois ou par tranche ne s expriment pas avec l API Prisma, et charger
 * l historique en memoire pour le decouper serait couteux.
 */
@Module({
  controllers: [ReportsController],
  providers: [ReportsService],
  exports: [ReportsService],
})
export class ReportsModule {}