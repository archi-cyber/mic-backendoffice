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
  ConvertVisitorDto,
  CreateVisitorDto,
  FindVisitorsDto,
  UpdateVisitorDto,
} from './dto/visitor.dto';
import { VisitorsService } from './visitors.service';

@ApiTags('visitors')
@ApiBearerAuth('access-token')
@Controller('visitors')
export class VisitorsController {
  constructor(private readonly visitors: VisitorsService) {}

  @Get()
  @RequirePermission(FEATURES.visitors, 'view')
  @ApiOperation({ summary: 'Liste des visiteurs' })
  findAll(@Query() query: FindVisitorsDto) {
    return this.visitors.findAll(query);
  }

  @Get(':id')
  @RequirePermission(FEATURES.visitors, 'view')
  @ApiOperation({ summary: 'Detail d un visiteur' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.visitors.findOne(id);
  }

  @Post()
  @RequirePermission(FEATURES.visitors, 'create')
  @ApiOperation({
    summary: 'Enregistre un visiteur',
    description:
      'Le rattachement a un culte est facultatif : une visite peut avoir lieu ' +
      'en dehors d un service.',
  })
  create(@Body() dto: CreateVisitorDto, @CurrentUser('id') userId: string) {
    return this.visitors.create(dto, userId);
  }

  @Patch(':id')
  @RequirePermission(FEATURES.visitors, 'edit')
  @ApiOperation({ summary: 'Modifie un visiteur' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateVisitorDto,
  ) {
    return this.visitors.update(id, dto);
  }

  @Delete(':id')
  @RequirePermission(FEATURES.visitors, 'delete')
  @ApiOperation({ summary: 'Supprime un visiteur' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.visitors.remove(id);
  }

  @Post(':id/convert')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.members, 'create')
  @ApiOperation({
    summary: 'Convertit le visiteur en membre',
    description:
      'Cree la fiche membre a partir des coordonnees du visiteur, puis ' +
      'supprime ce dernier pour eviter un doublon. Requiert le droit de creer ' +
      'des membres, et non celui de gerer les visiteurs.',
  })
  convert(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ConvertVisitorDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.visitors.convertToMember(id, dto, userId);
  }
}