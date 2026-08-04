import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermission } from '../../common/decorators/permission.decorator';
import { FEATURES } from '../auth/types/auth.types';
import {
  AddListenersDto,
  CreateTeachingDto,
  FindTeachingsDto,
  UpdateTeachingDto,
} from './dto/teaching.dto';
import { TeachingsService } from './teachings.service';

@ApiTags('teachings')
@ApiBearerAuth('access-token')
@Controller('teachings')
export class TeachingsController {
  constructor(private readonly teachings: TeachingsService) {}

  @Get()
  @RequirePermission(FEATURES.teachings, 'view')
  @ApiOperation({ summary: 'Liste des enseignements' })
  findAll(@Query() query: FindTeachingsDto) {
    return this.teachings.findAll(query);
  }

  @Get(':id')
  @RequirePermission(FEATURES.teachings, 'view')
  @ApiOperation({
    summary: 'Detail d un enseignement',
    description: 'Inclut les auditeurs et les taches de montage generees.',
  })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.teachings.findOne(id);
  }

  @Post()
  @RequirePermission(FEATURES.teachings, 'create')
  @ApiOperation({
    summary: 'Cree un enseignement',
    description:
      'Declenche deux automatismes : creation de trois taches de montage ' +
      'pour le departement Media, et synchronisation des auditeurs depuis la ' +
      'presence au culte de la meme date. Les deux sont desactivables.',
  })
  create(@Body() dto: CreateTeachingDto, @CurrentUser('id') userId: string) {
    return this.teachings.create(dto, userId);
  }

  @Patch(':id')
  @RequirePermission(FEATURES.teachings, 'edit')
  @ApiOperation({
    summary: 'Modifie un enseignement',
    description:
      'Changer la date decale l echeance des taches de montage associees.',
  })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateTeachingDto,
  ) {
    return this.teachings.update(id, dto);
  }

  @Delete(':id')
  @RequirePermission(FEATURES.teachings, 'delete')
  @ApiOperation({
    summary: 'Supprime un enseignement',
    description: 'Les taches de montage et les auditeurs suivent.',
  })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.teachings.remove(id);
  }

  // ---------------------------------------------------------------------------
  // Auditeurs
  // ---------------------------------------------------------------------------

  @Post(':id/listeners/sync')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.teachings, 'edit')
  @ApiOperation({
    summary: 'Resynchronise les auditeurs',
    description:
      'Reprend la presence au culte de la date de l enseignement. Utile si ' +
      'la feuille de presence a ete completee apres coup.',
  })
  resyncListeners(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.teachings.resyncListeners(id, userId);
  }

  @Post(':id/listeners')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.teachings, 'edit')
  @ApiOperation({ summary: 'Ajoute des auditeurs manuellement' })
  addListeners(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AddListenersDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.teachings.addListeners(id, dto, userId);
  }

  @Delete(':id/listeners/:memberId')
  @RequirePermission(FEATURES.teachings, 'edit')
  @ApiOperation({ summary: 'Retire un auditeur' })
  removeListener(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
  ) {
    return this.teachings.removeListener(id, memberId);
  }
}