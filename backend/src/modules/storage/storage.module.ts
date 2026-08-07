import { Global, Module } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';

import { StorageController } from './storage.controller';
import { StorageService } from './storage.service';

/**
 * Stockage de fichiers sur S3.
 *
 * Marque @Global : les modules metier suppriment les fichiers associes a un
 * membre ou un departement lors d une suppression. Les importer un par un
 * n apporterait rien.
 *
 * `memoryStorage` conserve le fichier en memoire avant envoi vers S3. Avec une
 * limite de dix megaoctets, l empreinte reste maitrisee, et cela evite les
 * fichiers temporaires orphelins qu un `diskStorage` laisserait derriere lui
 * en cas d erreur.
 */
@Global()
@Module({
  imports: [
    MulterModule.register({
      storage: memoryStorage(),
      limits: { fileSize: 10 * 1024 * 1024 },
    }),
  ],
  controllers: [StorageController],
  providers: [StorageService],
  exports: [StorageService],
})
export class StorageModule {}