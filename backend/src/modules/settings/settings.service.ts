import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';

/**
 * Paramètres applicatifs.
 *
 * Stockage clé/valeur en JSON, dans `app_settings`. Convient aux réglages
 * peu nombreux et rarement modifiés : cible des notifications
 * d'anniversaire, préférences d'affichage, seuils divers.
 *
 * Ces paramètres sont **communs à toute l'église**, contrairement aux
 * préférences d'appareil qui restent locales. Un réglage stocké ici vaut
 * pour tous, quel que soit le téléphone utilisé.
 */
@Injectable()
export class SettingsService {
  private readonly logger = new Logger(SettingsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Valeur d'un paramètre, ou la valeur par défaut fournie.
   *
   * Renvoyer un repli plutôt que `null` évite à chaque appelant de gérer le
   * cas « paramètre jamais défini », qui est la situation normale au premier
   * démarrage.
   */
  async get(key: string, fallback: unknown = null): Promise<unknown> {
    const setting = await this.prisma.appSetting.findUnique({ where: { key } });
    return setting?.value ?? fallback;
  }

  /** Tous les paramètres, sous forme d'objet. */
  async getAll(): Promise<Record<string, unknown>> {
    const settings = await this.prisma.appSetting.findMany();

    return Object.fromEntries(
      settings.map((setting) => [setting.key, setting.value]),
    );
  }

  /**
   * Enregistre un paramètre.
   *
   * Crée la ligne si elle n'existe pas. La clé est le seul index : deux
   * écritures concurrentes sur la même clé donnent le dernier écrivain
   * gagnant, ce qui convient à des réglages modifiés depuis un écran
   * d'administration.
   */
  async set(key: string, value: unknown) {
    const setting = await this.prisma.appSetting.upsert({
      where: { key },
      update: { value: value as Prisma.InputJsonValue },
      create: { key, value: value as Prisma.InputJsonValue },
    });

    this.logger.log(`Paramètre « ${key} » mis à jour`);

    return setting;
  }

  /** Enregistre plusieurs paramètres en une fois. */
  async setMany(values: Record<string, unknown>) {
    const keys = Object.keys(values);

    await this.prisma.$transaction(
      keys.map((key) =>
        this.prisma.appSetting.upsert({
          where: { key },
          update: { value: values[key] as Prisma.InputJsonValue },
          create: { key, value: values[key] as Prisma.InputJsonValue },
        }),
      ),
    );

    return this.getAll();
  }

  async remove(key: string) {
    await this.prisma.appSetting.deleteMany({ where: { key } });
    return { message: 'Paramètre supprimé.', key };
  }
}