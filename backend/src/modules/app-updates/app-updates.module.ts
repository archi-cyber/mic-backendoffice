import { Module } from '@nestjs/common';

import { AppUpdatesController } from './app-updates.controller';
import { AppUpdatesService } from './app-updates.service';

/** Mises à jour OTA ; StorageService est fourni par le module global. */
@Module({
  controllers: [AppUpdatesController],
  providers: [AppUpdatesService],
})
export class AppUpdatesModule {}
