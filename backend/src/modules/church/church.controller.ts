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
import { ChurchService } from './church.service';
import {
  CreateChurchServiceDto,
  FindAttendanceDto,
  FindChurchServicesDto,
  MarkAttendanceDto,
  UpdateChurchServiceDto,
} from './dto/church.dto';

@ApiTags('church-attendance')
@ApiBearerAuth('access-token')
@Controller('church-services')
export class ChurchController {
  constructor(private readonly church: ChurchService) {}

  // ---------------------------------------------------------------------------
  // Cultes
  // ---------------------------------------------------------------------------

  @Get()
  @RequirePermission(FEATURES.churchAttendance, 'view')
  @ApiOperation({
    summary: 'Liste des cultes',
    description: 'Filtrable par periode. Inclut le decompte des presences.',
  })
  findAll(@Query() query: FindChurchServicesDto) {
    return this.church.findAllServices(query);
  }

  @Get(':id')
  @RequirePermission(FEATURES.churchAttendance, 'view')
  @ApiOperation({
    summary: 'Detail d un culte avec sa feuille de presence',
    description:
      'Renvoie tous les membres actifs, y compris ceux non encore pointes ' +
      '(attendanceType a null). C est la liste complete de saisie.',
  })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.church.findOneService(id);
  }

  @Post()
  @RequirePermission(FEATURES.churchAttendance, 'create')
  @ApiOperation({
    summary: 'Cree un culte',
    description:
      'Le couple date + nom doit etre unique. Plusieurs cultes le meme jour ' +
      'sont possibles avec des noms differents.',
  })
  create(
    @Body() dto: CreateChurchServiceDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.church.createService(dto, userId);
  }

  @Patch(':id')
  @RequirePermission(FEATURES.churchAttendance, 'edit')
  @ApiOperation({
    summary: 'Modifie un culte',
    description:
      'Changer la date propage la mise a jour sur toutes les presences liees.',
  })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateChurchServiceDto,
  ) {
    return this.church.updateService(id, dto);
  }

  @Delete(':id')
  @RequirePermission(FEATURES.churchAttendance, 'delete')
  @ApiOperation({
    summary: 'Supprime un culte',
    description:
      'Suppression logique. Les presences et visiteurs rattaches sont ' +
      'retires en cascade.',
  })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.church.removeService(id);
  }

  // ---------------------------------------------------------------------------
  // Presence
  // ---------------------------------------------------------------------------

  @Post(':id/attendance')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.churchAttendance, 'create')
  @ApiOperation({
    summary: 'Enregistre la presence en une fois',
    description:
      'Chaque entree est creee ou mise a jour. Declenche automatiquement la ' +
      'verification de graduation des nouveaux venus.',
  })
  markAttendance(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: MarkAttendanceDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.church.markAttendance(id, dto, userId);
  }

  @Get(':id/absentees')
  @RequirePermission(FEATURES.churchAttendance, 'view')
  @ApiOperation({
    summary: 'Membres absents d un culte',
    description:
      'Regroupe les absents declares et ceux jamais pointes : dans les deux ' +
      'cas, un suivi pastoral s impose.',
  })
  findAbsentees(@Param('id', ParseUUIDPipe) id: string) {
    return this.church.findAbsentees(id);
  }
}

// =============================================================================

@ApiTags('church-attendance')
@ApiBearerAuth('access-token')
@Controller('church-attendance')
export class ChurchAttendanceController {
  constructor(private readonly church: ChurchService) {}

  @Get()
  @RequirePermission(FEATURES.churchAttendance, 'view')
  @ApiOperation({
    summary: 'Recherche transversale dans les presences',
    description: 'Filtrable par membre, culte, type et periode.',
  })
  findAll(@Query() query: FindAttendanceDto) {
    return this.church.findAttendance(query);
  }

  @Get('member/:memberId')
  @RequirePermission(FEATURES.churchAttendance, 'view')
  @ApiOperation({
    summary: 'Historique et taux d assiduite d un membre',
    description:
      'Le taux rapporte les presences au nombre de cultes tenus sur la ' +
      'periode, pas au nombre de pointages.',
  })
  findMemberHistory(
    @Param('memberId', ParseUUIDPipe) memberId: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.church.findMemberHistory(memberId, from, to);
  }
}