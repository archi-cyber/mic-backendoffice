import { Module } from '@nestjs/common';

import { CommunicationsModule } from '../communications/communications.module';
import { ServiceSchedulesController } from './service-schedules.controller';
import { ServiceSchedulesService } from './service-schedules.service';

/**
 * Planning de service.
 *
 * CommunicationsModule fournit NotificationsService : chaque membre assigne a
 * un poste recoit une notification.
 */
@Module({
  imports: [CommunicationsModule],
  controllers: [ServiceSchedulesController],
  providers: [ServiceSchedulesService],
  exports: [ServiceSchedulesService],
})
export class ServiceSchedulesModule {}