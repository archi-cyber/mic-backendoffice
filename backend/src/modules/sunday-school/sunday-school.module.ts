import { Module } from '@nestjs/common';

import { SundaySchoolController } from './sunday-school.controller';
import { SundaySchoolService } from './sunday-school.service';

@Module({
  controllers: [SundaySchoolController],
  providers: [SundaySchoolService],
  exports: [SundaySchoolService],
})
export class SundaySchoolModule {}