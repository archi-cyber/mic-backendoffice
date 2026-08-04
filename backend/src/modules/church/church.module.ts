import { Module } from '@nestjs/common';

import { MembersModule } from '../members/members.module';
import { ChurchAttendanceController, ChurchController } from './church.controller';
import { ChurchService } from './church.service';

/**
 * Cultes et presence.
 *
 * MembersModule est importe pour MembersService, dont depend la verification
 * de graduation des nouveaux venus declenchee apres chaque pointage.
 */
@Module({
  imports: [MembersModule],
  controllers: [ChurchController, ChurchAttendanceController],
  providers: [ChurchService],
  exports: [ChurchService],
})
export class ChurchModule {}