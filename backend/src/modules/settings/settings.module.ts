import { Global, Module } from '@nestjs/common';

import { SettingsController } from './settings.controller';
import { SettingsService } from './settings.service';

/**
 * Parametres applicatifs.
 *
 * Marque @Global : plusieurs modules metier consultent des reglages — cible
 * des notifications, seuils d affichage. Les importer un par un
 * n apporterait rien.
 */
@Global()
@Module({
  controllers: [SettingsController],
  providers: [SettingsService],
  exports: [SettingsService],
})
export class SettingsModule {}