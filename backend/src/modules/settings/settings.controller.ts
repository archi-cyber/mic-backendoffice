import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Put,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { Roles } from '../../common/decorators/roles.decorator';
import { SettingsService } from './settings.service';

/**
 * Parametres applicatifs.
 *
 * La **lecture** est ouverte a tout utilisateur connecte : ces reglages
 * conditionnent l affichage, et les masquer empecherait l interface de se
 * configurer correctement.
 *
 * L **ecriture** est reservee aux administrateurs : un parametre vaut pour
 * toute l eglise, pas pour un appareil.
 */
@ApiTags('settings')
@ApiBearerAuth('access-token')
@Controller('settings')
export class SettingsController {
  constructor(private readonly settings: SettingsService) {}

  @Get()
  @ApiOperation({ summary: 'Tous les parametres' })
  getAll() {
    return this.settings.getAll();
  }

  @Get(':key')
  @ApiOperation({
    summary: 'Valeur d un parametre',
    description: 'Renvoie null si le parametre n a jamais ete defini.',
  })
  async get(@Param('key') key: string) {
    return { key, value: await this.settings.get(key) };
  }

  @Put(':key')
  @HttpCode(HttpStatus.OK)
  @Roles('admin')
  @ApiOperation({
    summary: 'Enregistre un parametre',
    description: 'Reserve aux administrateurs : le reglage vaut pour tous.',
  })
  set(@Param('key') key: string, @Body() body: { value: unknown }) {
    return this.settings.set(key, body.value);
  }

  @Put()
  @HttpCode(HttpStatus.OK)
  @Roles('admin')
  @ApiOperation({ summary: 'Enregistre plusieurs parametres' })
  setMany(@Body() body: Record<string, unknown>) {
    return this.settings.setMany(body);
  }

  @Delete(':key')
  @Roles('admin')
  @ApiOperation({ summary: 'Supprime un parametre' })
  remove(@Param('key') key: string) {
    return this.settings.remove(key);
  }
}