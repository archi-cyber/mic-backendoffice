import { Module } from '@nestjs/common';

import { ClassSessionsController, ClassesController } from './classes.controller';
import { ClassesService } from './classes.service';

@Module({
  controllers: [ClassesController, ClassSessionsController],
  providers: [ClassesService],
  exports: [ClassesService],
})
export class ClassesModule {}