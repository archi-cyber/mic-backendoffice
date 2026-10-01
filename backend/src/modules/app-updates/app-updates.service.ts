import {
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';

import { StorageService } from '../storage/storage.service';

/**
 * Mises à jour de l'application (OTA).
 *
 * La CI dépose à chaque version, sous `app-releases/latest/`, un manifeste
 * `version.json` et les installateurs qu'il référence (APK, installateur
 * Windows). Ce service les expose au client sans rendre le bucket public.
 */
@Injectable()
export class AppUpdatesService {
  private static readonly PREFIX = 'app-releases/latest';

  private readonly logger = new Logger(AppUpdatesService.name);

  constructor(private readonly storage: StorageService) {}

  /** Manifeste de la dernière version publiée. */
  async getLatestManifest(): Promise<Record<string, unknown>> {
    const url = await this.signedUrl('version.json');

    const response = await fetch(url, {
      headers: { Accept: 'application/json' },
    });
    if (response.status === 404 || response.status === 403) {
      throw this.noRelease();
    }
    if (!response.ok) {
      this.logger.warn(`Manifeste illisible : HTTP ${response.status}`);
      throw new ServiceUnavailableException({
        message: 'Manifeste de mise à jour indisponible.',
        code: 'UPDATE_MANIFEST_UNAVAILABLE',
      });
    }

    try {
      return (await response.json()) as Record<string, unknown>;
    } catch {
      throw new ServiceUnavailableException({
        message: 'Manifeste de mise à jour invalide.',
        code: 'UPDATE_MANIFEST_INVALID',
      });
    }
  }

  /**
   * URL de téléchargement temporaire d'un installateur de la dernière version.
   *
   * Seul un nom de fichier simple est accepté : un chemin permettrait de lire
   * n'importe quel objet du bucket.
   */
  async getAssetUrl(fileName: string): Promise<string> {
    if (!/^[A-Za-z0-9._+-]+$/.test(fileName) || fileName.startsWith('.')) {
      throw new NotFoundException({
        message: 'Fichier introuvable.',
        code: 'UPDATE_ASSET_NOT_FOUND',
      });
    }
    return this.signedUrl(fileName);
  }

  private async signedUrl(fileName: string): Promise<string> {
    try {
      return await this.storage.createSignedUrl(
        `${AppUpdatesService.PREFIX}/${fileName}`,
      );
    } catch (error) {
      this.logger.warn(
        `Stockage indisponible pour les mises à jour : ` +
          `${error instanceof Error ? error.message : error}`,
      );
      throw new ServiceUnavailableException({
        message: 'Stockage des mises à jour indisponible.',
        code: 'UPDATE_STORAGE_UNAVAILABLE',
      });
    }
  }

  private noRelease(): NotFoundException {
    return new NotFoundException({
      message: 'Aucune version publiée.',
      code: 'NO_RELEASE',
    });
  }
}
