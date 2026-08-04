import { Module } from '@nestjs/common';

import { PenaltiesService } from './penalties.service';
import { PenaltyJob } from './penalty.job';
import { ProjectsService } from './projects.service';
import {
  PenaltiesController,
  ProjectsController,
  TagsController,
  TasksController,
} from './tasks.controller';
import { TasksService } from './tasks.service';

/**
 * Taches, projets, etiquettes et penalites.
 *
 * Ces quatre domaines sont regroupes parce qu ils sont indissociables : une
 * penalite naît d une tache en retard, une etiquette n existe que pour
 * classer des taches, un projet n est qu un regroupement de taches. Les
 * separer multiplierait les dependances croisees sans gain de clarte.
 */
@Module({
  controllers: [
    TasksController,
    ProjectsController,
    TagsController,
    PenaltiesController,
  ],
  providers: [TasksService, ProjectsService, PenaltiesService, PenaltyJob],
  exports: [TasksService, PenaltiesService],
})
export class TasksModule {}