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
  AddAssignmentDto,
  CreateScheduleDto,
  FindSchedulesDto,
  SetAssignmentDoneDto,
  UpdateScheduleDto,
} from './dto/service-schedule.dto';
import { ServiceSchedulesService } from './service-schedules.service';

@ApiTags('service-schedules')
@ApiBearerAuth('access-token')
@Controller('service-schedules')
export class ServiceSchedulesController {
  constructor(private readonly schedules: ServiceSchedulesService) {}

  @Get()
  @RequirePermission(FEATURES.departments, 'view')
  @ApiOperation({
    summary: 'Plannings d un departement',
    description: 'Du plus recent au plus ancien, avec les postes attribues.',
  })
  findAll(@Query() query: FindSchedulesDto) {
    return this.schedules.findAll(query);
  }

  @Get(':id')
  @RequirePermission(FEATURES.departments, 'view')
  @ApiOperation({ summary: 'Detail d un planning' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.schedules.findOne(id);
  }

  @Post()
  @RequirePermission(FEATURES.departments, 'create')
  @ApiOperation({
    summary: 'Cree un planning',
    description:
      'Un seul planning par departement et par date : deux plannings ' +
      'concurrents laisseraient l equipe sans savoir lequel fait foi.',
  })
  create(
    @Body() dto: CreateScheduleDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.schedules.create(dto, userId);
  }

  @Patch(':id')
  @RequirePermission(FEATURES.departments, 'edit')
  @ApiOperation({ summary: 'Modifie les notes ou la date' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateScheduleDto,
  ) {
    return this.schedules.update(id, dto);
  }

  @Delete(':id')
  @RequirePermission(FEATURES.departments, 'delete')
  @ApiOperation({ summary: 'Supprime un planning et ses assignations' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.schedules.remove(id);
  }

  // ---------------------------------------------------------------------------
  // Assignations
  // ---------------------------------------------------------------------------

  @Post(':id/assignments')
  @RequirePermission(FEATURES.departments, 'edit')
  @ApiOperation({
    summary: 'Attribue un poste a un membre',
    description:
      'Le membre est notifie : sans cela, il decouvrirait son service en ' +
      'arrivant, ou pas du tout.',
  })
  addAssignment(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AddAssignmentDto,
    @Query('serviceDateLabel') serviceDateLabel?: string,
  ) {
    return this.schedules.addAssignment(id, dto, serviceDateLabel);
  }

  @Delete('assignments/:assignmentId')
  @RequirePermission(FEATURES.departments, 'edit')
  @ApiOperation({ summary: 'Retire une assignation' })
  removeAssignment(
    @Param('assignmentId', ParseUUIDPipe) assignmentId: string,
  ) {
    return this.schedules.removeAssignment(assignmentId);
  }

  @Patch('assignments/:assignmentId/done')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.departments, 'edit')
  @ApiOperation({ summary: 'Marque un poste comme assure' })
  setAssignmentDone(
    @Param('assignmentId', ParseUUIDPipe) assignmentId: string,
    @Body() dto: SetAssignmentDoneDto,
  ) {
    return this.schedules.setAssignmentDone(assignmentId, dto.isDone);
  }
}