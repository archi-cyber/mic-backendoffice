import { Controller, Get, Param, Res } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';

import { Public } from '../../common/decorators/public.decorator';
import { AppUpdatesService } from './app-updates.service';

/**
 * Publiques : la vérification de mise à jour a lieu avant toute connexion,
 * y compris sur l'écran de connexion.
 */
@ApiTags('app-updates')
@Controller('app-updates')
export class AppUpdatesController {
  constructor(private readonly updates: AppUpdatesService) {}

  @Public()
  @Get('latest')
  @ApiOperation({ summary: 'Manifeste de la derniere version publiee' })
  getLatest() {
    return this.updates.getLatestManifest();
  }

  @Public()
  @Get('latest/assets/:fileName')
  @ApiOperation({
    summary: 'Telecharge un installateur de la derniere version',
    description: 'Redirige vers une URL signee de courte duree.',
  })
  // Reponse geree a la main : l intercepteur global envelopperait sinon la
  // cible de redirection dans `data`.
  async getAsset(
    @Param('fileName') fileName: string,
    @Res() res: Response,
  ): Promise<void> {
    res.redirect(302, await this.updates.getAssetUrl(fileName));
  }
}
