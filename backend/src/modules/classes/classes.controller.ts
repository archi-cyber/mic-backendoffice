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

import { RequirePermission } from '../../common/decorators/permission.decorator';
import { FEATURES } from '../auth/types/auth.types';
import { ClassesService } from './classes.service';
import {
  CreateClassDto,
  EnrollMembersDto,
  FindClassesDto,
  GenerateSessionsDto,
  MarkSessionAttendanceDto,
  UpdateClassDto,
} from './dto/class.dto';

@ApiTags('trainings')
@ApiBearerAuth('access-token')
@Controller('classes')
export class ClassesController {
  constructor(private readonly classes: ClassesService) {}

  @Get()
  @RequirePermission(FEATURES.trainings, 'view')
  @ApiOperation({ summary: 'Liste des formations' })
  findAll(@Query() query: FindClassesDto) {
    return this.classes.findAll(query);
  }

  @Get(':id')
  @RequirePermission(FEATURES.trainings, 'view')
  @ApiOperation({
    summary: 'Detail d une formation',
    description: 'Inclut les inscrits et les seances planifiees.',
  })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.classes.findOne(id);
  }

  @Get(':id/report')
  @RequirePermission(FEATURES.trainings, 'view')
  @ApiOperation({
    summary: 'Taux d assiduite par inscrit',
    description:
      'Le taux rapporte les presences au nombre total de seances de la ' +
      'formation.',
  })
  getReport(@Param('id', ParseUUIDPipe) id: string) {
    return this.classes.getClassReport(id);
  }

  @Post()
  @RequirePermission(FEATURES.trainings, 'create')
  @ApiOperation({ summary: 'Cree une formation' })
  create(@Body() dto: CreateClassDto) {
    return this.classes.create(dto);
  }

  @Patch(':id')
  @RequirePermission(FEATURES.trainings, 'edit')
  @ApiOperation({ summary: 'Modifie une formation' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateClassDto,
  ) {
    return this.classes.update(id, dto);
  }

  @Delete(':id')
  @RequirePermission(FEATURES.trainings, 'delete')
  @ApiOperation({ summary: 'Supprime une formation' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.classes.remove(id);
  }

  // ---------------------------------------------------------------------------
  // Inscriptions
  // ---------------------------------------------------------------------------

  @Post(':id/members')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.trainings, 'edit')
  @ApiOperation({ summary: 'Inscrit des membres' })
  enroll(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: EnrollMembersDto,
  ) {
    return this.classes.enroll(id, dto);
  }

  @Delete(':id/members/:memberId')
  @RequirePermission(FEATURES.trainings, 'edit')
  @ApiOperation({
    summary: 'Retire une inscription',
    description:
      'Les presences deja enregistrees sont conservees : elles attestent ' +
      'd une participation reelle.',
  })
  unenroll(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
  ) {
    return this.classes.unenroll(id, memberId);
  }

  // ---------------------------------------------------------------------------
  // Seances
  // ---------------------------------------------------------------------------

  @Post(':id/sessions/generate')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.trainings, 'create')
  @ApiOperation({
    summary: 'Genere des seances a intervalle regulier',
    description:
      'Les dates deja occupees sont ignorees : relancer la generation pour ' +
      'prolonger un cycle ne provoque pas d erreur.',
  })
  generateSessions(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: GenerateSessionsDto,
  ) {
    return this.classes.generateSessions(id, dto);
  }
}

// =============================================================================

@ApiTags('trainings')
@ApiBearerAuth('access-token')
@Controller('class-sessions')
export class ClassSessionsController {
  constructor(private readonly classes: ClassesService) {}

  @Get(':sessionId')
  @RequirePermission(FEATURES.trainings, 'view')
  @ApiOperation({
    summary: 'Feuille de presence d une seance',
    description:
      'Seuls les inscrits y figurent : une formation a une liste fermee, ' +
      'contrairement au culte.',
  })
  findSession(@Param('sessionId', ParseUUIDPipe) sessionId: string) {
    return this.classes.findSession(sessionId);
  }

  @Post(':sessionId/attendance')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.trainings, 'create')
  @ApiOperation({
    summary: 'Enregistre la presence d une seance',
    description: 'Refuse les membres non inscrits a la formation.',
  })
  markAttendance(
    @Param('sessionId', ParseUUIDPipe) sessionId: string,
    @Body() dto: MarkSessionAttendanceDto,
  ) {
    return this.classes.markSessionAttendance(sessionId, dto);
  }

  @Delete(':sessionId')
  @RequirePermission(FEATURES.trainings, 'delete')
  @ApiOperation({ summary: 'Supprime une seance et ses presences' })
  deleteSession(@Param('sessionId', ParseUUIDPipe) sessionId: string) {
    return this.classes.deleteSession(sessionId);
  }
}