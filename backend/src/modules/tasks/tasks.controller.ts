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
import { Roles } from '../../common/decorators/roles.decorator';
import { FEATURES } from '../auth/types/auth.types';
import {
  AssignTaskDto,
  CreateProjectDto,
  CreateTagDto,
  CreateTaskDto,
  FindTasksDto,
  RecordPaymentDto,
  RemindPendingDto,
  RunPenaltiesDto,
  SetTaskTagsDto,
  UpdatePenaltySettingsDto,
  UpdateProjectDto,
  UpdateTagDto,
  UpdateTaskDto,
} from './dto/task.dto';
import { PenaltiesService } from './penalties.service';
import { ProjectsService } from './projects.service';
import { TasksService } from './tasks.service';

// =============================================================================
// TACHES
// =============================================================================

@ApiTags('tasks')
@ApiBearerAuth('access-token')
@Controller('tasks')
export class TasksController {
  constructor(private readonly tasks: TasksService) {}

  @Get()
  @RequirePermission(FEATURES.tasks, 'view')
  @ApiOperation({
    summary: 'Liste des taches',
    description:
      'Les taches archivees sont exclues par defaut. Filtres : departement, ' +
      'assigne, projet, etiquette, statut, priorite, retard, echeance.',
  })
  findAll(@Query() query: FindTasksDto) {
    return this.tasks.findAll(query);
  }

  @Get('mine')
  @RequirePermission(FEATURES.tasks, 'view')
  @ApiOperation({
    summary: 'Mes taches',
    description: 'Taches assignees au membre lie au compte connecte.',
  })
  findMine(
    @CurrentUser('memberId') memberId: string | null,
    @Query() query: FindTasksDto,
  ) {
    if (!memberId) {
      return { data: [], meta: { page: 1, limit: 0, total: 0, totalPages: 1 } };
    }
    return this.tasks.findByAssignee(memberId, query);
  }

  @Get(':id')
  @RequirePermission(FEATURES.tasks, 'view')
  @ApiOperation({ summary: 'Detail d une tache avec ses penalites' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.tasks.findOne(id);
  }

  @Post()
  @RequirePermission(FEATURES.tasks, 'create')
  @ApiOperation({
    summary: 'Cree une tache',
    description:
      'Une tache releve soit d un departement, soit d un membre. Les ' +
      'assignes dont le solde de penalites atteint le seuil sont refuses.',
  })
  create(@Body() dto: CreateTaskDto) {
    return this.tasks.create(dto);
  }

  @Patch(':id')
  @RequirePermission(FEATURES.tasks, 'edit')
  @ApiOperation({ summary: 'Modifie une tache' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateTaskDto,
  ) {
    return this.tasks.update(id, dto);
  }

  @Post(':id/archive')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.tasks, 'edit')
  @ApiOperation({
    summary: 'Archive une tache',
    description:
      'Arrete l accumulation des penalites sans effacer celles deja dues.',
  })
  archive(@Param('id', ParseUUIDPipe) id: string) {
    return this.tasks.archive(id);
  }

  @Post(':id/unarchive')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.tasks, 'edit')
  @ApiOperation({ summary: 'Sort une tache des archives' })
  unarchive(@Param('id', ParseUUIDPipe) id: string) {
    return this.tasks.unarchive(id);
  }

  @Delete(':id')
  @RequirePermission(FEATURES.tasks, 'delete')
  @ApiOperation({ summary: 'Supprime une tache' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.tasks.remove(id);
  }

  @Post(':id/assign')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.tasks, 'edit')
  @ApiOperation({
    summary: 'Assigne la tache a des membres',
    description:
      'Refuse les membres dont le solde de penalites atteint le seuil ' +
      'bloquant, en les nommant avec leur solde.',
  })
  assign(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AssignTaskDto,
  ) {
    return this.tasks.assign(id, dto);
  }

  @Delete(':id/assign/:memberId')
  @RequirePermission(FEATURES.tasks, 'edit')
  @ApiOperation({
    summary: 'Retire une assignation',
    description:
      'Les penalites deja constatees sont conservees : elles sanctionnent ' +
      'un retard qui a eu lieu.',
  })
  unassign(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
  ) {
    return this.tasks.unassign(id, memberId);
  }


  @Post('remind-pending')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.tasks, 'edit')
  @ApiOperation({
    summary: 'Rappelle toutes les taches en attente',
    description:
      'Une notification par membre, pas par tache : quelqu un ayant cinq ' +
      'taches en retard recoit un recapitulatif, pas cinq messages.',
  })
  remindAllPending(@Body() dto: RemindPendingDto) {
    return this.tasks.remindAllPending(dto.departmentId);
  }

  @Post(':id/remind')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.tasks, 'edit')
  @ApiOperation({
    summary: 'Envoie un rappel aux assignes',
    description:
      'Refuse les taches terminees, annulees ou archivees : insister sur un ' +
      'travail deja fait decredibilise les notifications.',
  })
  remind(@Param('id', ParseUUIDPipe) id: string) {
    return this.tasks.remind(id);
  }

  @Post(':id/tags')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.tasks, 'edit')
  @ApiOperation({
    summary: 'Remplace les etiquettes de la tache',
    description:
      'Les etiquettes doivent appartenir au departement de la tache.',
  })
  setTags(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetTaskTagsDto,
  ) {
    return this.tasks.setTags(id, dto);
  }
}

// =============================================================================
// PROJETS ET ETIQUETTES
// =============================================================================

@ApiTags('tasks')
@ApiBearerAuth('access-token')
@Controller('projects')
export class ProjectsController {
  constructor(private readonly projects: ProjectsService) {}

  @Get()
  @RequirePermission(FEATURES.tasks, 'view')
  @ApiOperation({ summary: 'Liste des projets' })
  findAll(@Query('departmentId') departmentId?: string) {
    return this.projects.findAllProjects(departmentId);
  }

  @Get(':id')
  @RequirePermission(FEATURES.tasks, 'view')
  @ApiOperation({
    summary: 'Detail d un projet',
    description: 'Inclut ses taches et un taux d avancement calcule.',
  })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.projects.findOneProject(id);
  }

  @Post()
  @RequirePermission(FEATURES.tasks, 'create')
  @ApiOperation({ summary: 'Cree un projet' })
  create(@Body() dto: CreateProjectDto) {
    return this.projects.createProject(dto);
  }

  @Patch(':id')
  @RequirePermission(FEATURES.tasks, 'edit')
  @ApiOperation({ summary: 'Modifie un projet' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateProjectDto,
  ) {
    return this.projects.updateProject(id, dto);
  }

  @Delete(':id')
  @RequirePermission(FEATURES.tasks, 'delete')
  @ApiOperation({
    summary: 'Supprime un projet',
    description: 'Les taches associees sont conservees, sans regroupement.',
  })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.projects.removeProject(id);
  }
}

@ApiTags('tasks')
@ApiBearerAuth('access-token')
@Controller('tags')
export class TagsController {
  constructor(private readonly projects: ProjectsService) {}

  @Get()
  @RequirePermission(FEATURES.tasks, 'view')
  @ApiOperation({ summary: 'Liste des etiquettes' })
  findAll(@Query('departmentId') departmentId?: string) {
    return this.projects.findAllTags(departmentId);
  }

  @Post()
  @RequirePermission(FEATURES.tasks, 'create')
  @ApiOperation({
    summary: 'Cree une etiquette',
    description: 'Le nom doit etre unique au sein du departement.',
  })
  create(@Body() dto: CreateTagDto) {
    return this.projects.createTag(dto);
  }

  @Patch(':id')
  @RequirePermission(FEATURES.tasks, 'edit')
  @ApiOperation({ summary: 'Modifie une etiquette' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateTagDto,
  ) {
    return this.projects.updateTag(id, dto);
  }

  @Delete(':id')
  @RequirePermission(FEATURES.tasks, 'delete')
  @ApiOperation({
    summary: 'Supprime une etiquette',
    description:
      'Suppression definitive : une etiquette est un libelle sans valeur ' +
      'historique. Les taches concernees la perdent simplement.',
  })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.projects.removeTag(id);
  }
}

// =============================================================================
// PENALITES
// =============================================================================

@ApiTags('tasks')
@ApiBearerAuth('access-token')
@Controller('penalties')
export class PenaltiesController {
  constructor(private readonly penalties: PenaltiesService) {}

  @Get('settings')
  @RequirePermission(FEATURES.tasks, 'view')
  @ApiOperation({ summary: 'Parametres des penalites' })
  getSettings() {
    return this.penalties.getSettings();
  }

  @Patch('settings')
  @Roles('admin')
  @ApiOperation({
    summary: 'Modifie les parametres',
    description: 'Reserve aux administrateurs.',
  })
  updateSettings(@Body() dto: UpdatePenaltySettingsDto) {
    return this.penalties.updateSettings(dto);
  }

  @Get('balances')
  @RequirePermission(FEATURES.tasks, 'view')
  @ApiOperation({
    summary: 'Soldes impayes',
    description: 'Membres ayant un solde superieur a zero, par ordre decroissant.',
  })
  findUnpaid() {
    return this.penalties.findUnpaidBalances();
  }

  @Get('member/:memberId')
  @RequirePermission(FEATURES.tasks, 'view')
  @ApiOperation({
    summary: 'Detail des penalites d un membre',
    description: 'Penalites, versements et solde courant.',
  })
  findMember(@Param('memberId', ParseUUIDPipe) memberId: string) {
    return this.penalties.findMemberPenalties(memberId);
  }

  @Post('member/:memberId/payment')
  @HttpCode(HttpStatus.CREATED)
  @RequirePermission(FEATURES.tasks, 'edit')
  @ApiOperation({
    summary: 'Enregistre un versement',
    description:
      'Reduit le solde. Un membre repasse sous le seuil peut a nouveau ' +
      'recevoir des taches.',
  })
  recordPayment(
    @Param('memberId', ParseUUIDPipe) memberId: string,
    @Body() dto: RecordPaymentDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.penalties.recordPayment(memberId, dto, userId);
  }

  @Post('run')
  @HttpCode(HttpStatus.OK)
  @Roles('admin')
  @ApiOperation({
    summary: 'Declenche le calcul des penalites',
    description:
      'Normalement automatique chaque nuit. Cette route permet de rattraper ' +
      'une journee manquee. L operation est idempotente : relancer sur une ' +
      'date deja traitee ne cree aucun doublon.',
  })
  run(@Body() dto: RunPenaltiesDto) {
    return this.penalties.runDailyPenalties(
      dto.date ? new Date(dto.date) : new Date(),
    );
  }
}