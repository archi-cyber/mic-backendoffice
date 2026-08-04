import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { PenaltiesService } from './penalties.service';

/**
 * Calcul automatique des penalites.
 *
 * Le declenchement a lieu chaque nuit a 2 h : l activite est nulle, et une
 * eventuelle lenteur ne genera personne.
 *
 * Le calcul est idempotent grace a la contrainte d unicite
 * (tache, membre, date). Un double declenchement ne cree aucun doublon, ce
 * qui rend l operation sure meme si plusieurs instances tournent en parallele
 * sur Railway.
 */
@Injectable()
export class PenaltyJob {
  private readonly logger = new Logger(PenaltyJob.name);

  constructor(private readonly penalties: PenaltiesService) {}

  @Cron(CronExpression.EVERY_DAY_AT_2AM, { name: 'daily-penalties' })
  async handleDailyPenalties(): Promise<void> {
    this.logger.log('Calcul quotidien des penalites...');

    try {
      const result = await this.penalties.runDailyPenalties();

      this.logger.log(
        `Termine : ${result.penaltiesCreated} penalite(s) sur ` +
          `${result.overdueTasks} tache(s) en retard.`,
      );
    } catch (error) {
      // Une erreur ici ne doit pas faire tomber le processus : le calcul sera
      // repris demain, ou manuellement via POST /penalties/run.
      this.logger.error(
        `Echec du calcul des penalites : ` +
          `${error instanceof Error ? error.message : 'erreur inconnue'}`,
        error instanceof Error ? error.stack : undefined,
      );
    }
  }
}