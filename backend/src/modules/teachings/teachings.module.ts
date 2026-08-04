import { Module } from '@nestjs/common';

import { TasksModule } from '../tasks/tasks.module';
import { TeachingsController } from './teachings.controller';
import { TeachingsService } from './teachings.service';

/**
 * Enseignements.
 *
 * TasksModule est importe pour PenaltiesService, qui fournit le delai
 * applique aux taches de montage (teachingTaskDueOffsetDays).
 */
@Module({
  imports: [TasksModule],
  controllers: [TeachingsController],
  providers: [TeachingsService],
  exports: [TeachingsService],
})
export class TeachingsModule {}