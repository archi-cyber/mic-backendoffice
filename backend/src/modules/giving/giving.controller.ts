import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthenticatedUser } from '../auth/types/auth.types';
import {
  CreateGivingDto,
  FindGivingDto,
  GivingSummaryDto,
  UpdateGivingDto,
} from './dto/giving.dto';
import { FinanceGuard } from './finance.guard';
import { GivingService } from './giving.service';

/**
 * Finances.
 *
 * FinanceGuard s applique a tout le controleur : aucune route financiere n est
 * accessible en dehors des administrateurs et des responsables du departement
 * Finance. La garde vient en supplement des permissions granulaires, et non a
 * leur place.
 */
@ApiTags('giving')
@ApiBearerAuth('access-token')
@UseGuards(FinanceGuard)
@Controller('giving')
export class GivingController {
  constructor(private readonly giving: GivingService) {}

  @Get()
  @ApiOperation({
    summary: 'Liste des mouvements financiers',
    description:
      'Les totaux renvoyes dans meta portent sur l ensemble du filtre, pas ' +
      'sur la page affichee.',
  })
  findAll(@Query() query: FindGivingDto) {
    return this.giving.findAll(query);
  }

  @Get('summary')
  @ApiOperation({
    summary: 'Synthese sur une periode',
    description: 'Totaux et ventilation par categorie.',
  })
  getSummary(@Query() query: GivingSummaryDto) {
    return this.giving.getSummary(query);
  }

  @Get('monthly/:year')
  @ApiOperation({
    summary: 'Ventilation mensuelle d une annee',
    description:
      'Les douze mois sont toujours presents, meme vides : un graphique avec ' +
      'des mois manquants serait trompeur.',
  })
  getMonthly(@Param('year', ParseIntPipe) year: number) {
    return this.giving.getMonthlyBreakdown(year);
  }

  @Get('member/:memberId')
  @ApiOperation({ summary: 'Historique des dons d un membre' })
  getMemberGiving(
    @Param('memberId', ParseUUIDPipe) memberId: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.giving.getMemberGiving(memberId, from, to);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Detail d un mouvement',
    description: 'Le champ isEditable indique si la fenetre de modification est ouverte.',
  })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.giving.findOne(id);
  }

  @Post()
  @ApiOperation({ summary: 'Enregistre un mouvement' })
  create(@Body() dto: CreateGivingDto) {
    return this.giving.create(dto);
  }

  @Patch(':id')
  @ApiOperation({
    summary: 'Modifie un mouvement',
    description:
      'Possible pendant deux jours. Au-dela, reserve aux administrateurs : ' +
      'une ecriture ancienne a probablement ete reportee dans un rapport.',
  })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateGivingDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.giving.update(id, dto, user);
  }

  @Delete(':id')
  @ApiOperation({
    summary: 'Supprime un mouvement',
    description: 'Suppression logique, soumise a la meme fenetre de deux jours.',
  })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.giving.remove(id, user);
  }
}