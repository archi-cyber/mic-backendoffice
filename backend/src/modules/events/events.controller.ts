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
import {
  CreateEventDto,
  CreateEventSessionDto,
  FindEventsDto,
  MarkEventAttendanceDto,
  RegisterMembersDto,
  RegisterToEventDto,
  UpdateEventDto,
} from './dto/event.dto';
import { EventsService } from './events.service';

@ApiTags('events')
@ApiBearerAuth('access-token')
@Controller('events')
export class EventsController {
  constructor(private readonly events: EventsService) {}

  @Get()
  @RequirePermission(FEATURES.events, 'view')
  @ApiOperation({
    summary: 'Liste des evenements',
    description:
      'Avec upcoming=true, seuls les evenements a venir sont renvoyes, en ' +
      'ordre chronologique croissant.',
  })
  findAll(@Query() query: FindEventsDto) {
    return this.events.findAll(query);
  }

  @Get(':id')
  @RequirePermission(FEATURES.events, 'view')
  @ApiOperation({
    summary: 'Detail d un evenement',
    description: 'Inclut les seances, les inscriptions et un decompte.',
  })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.events.findOne(id);
  }

  @Post()
  @RequirePermission(FEATURES.events, 'create')
  @ApiOperation({ summary: 'Cree un evenement' })
  create(@Body() dto: CreateEventDto) {
    return this.events.create(dto);
  }

  @Patch(':id')
  @RequirePermission(FEATURES.events, 'edit')
  @ApiOperation({ summary: 'Modifie un evenement' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateEventDto,
  ) {
    return this.events.update(id, dto);
  }

  @Delete(':id')
  @RequirePermission(FEATURES.events, 'delete')
  @ApiOperation({ summary: 'Supprime un evenement' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.events.remove(id);
  }

  // ---------------------------------------------------------------------------
  // Seances
  // ---------------------------------------------------------------------------

  @Post(':id/sessions')
  @RequirePermission(FEATURES.events, 'create')
  @ApiOperation({
    summary: 'Ajoute une seance',
    description: 'Pour les evenements se deroulant sur plusieurs creneaux.',
  })
  createSession(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateEventSessionDto,
  ) {
    return this.events.createSession(id, dto);
  }

  @Delete('sessions/:sessionId')
  @RequirePermission(FEATURES.events, 'delete')
  @ApiOperation({ summary: 'Supprime une seance' })
  removeSession(@Param('sessionId', ParseUUIDPipe) sessionId: string) {
    return this.events.removeSession(sessionId);
  }

  // ---------------------------------------------------------------------------
  // Inscriptions
  // ---------------------------------------------------------------------------

  @Post(':id/registrations')
  @RequirePermission(FEATURES.events, 'create')
  @ApiOperation({
    summary: 'Inscrit un membre ou un invite',
    description:
      'Les deux sont exclusifs : un invite n a pas de fiche membre, et un ' +
      'membre n a pas besoin qu on ressaisisse son nom.',
  })
  register(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RegisterToEventDto,
  ) {
    return this.events.register(id, dto);
  }

  @Post(':id/registrations/bulk')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.events, 'create')
  @ApiOperation({ summary: 'Inscrit plusieurs membres a la fois' })
  registerMembers(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RegisterMembersDto,
  ) {
    return this.events.registerMembers(id, dto);
  }

  @Delete('registrations/:registrationId')
  @RequirePermission(FEATURES.events, 'delete')
  @ApiOperation({ summary: 'Retire une inscription' })
  unregister(
    @Param('registrationId', ParseUUIDPipe) registrationId: string,
  ) {
    return this.events.unregister(registrationId);
  }

  // ---------------------------------------------------------------------------
  // Presence
  // ---------------------------------------------------------------------------

  @Post(':id/attendance')
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.events, 'create')
  @ApiOperation({
    summary: 'Enregistre la presence a un evenement',
    description:
      'sessionId est facultatif : absent, la presence porte sur l evenement ' +
      'dans son ensemble.',
  })
  markAttendance(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: MarkEventAttendanceDto,
  ) {
    return this.events.markAttendance(id, dto);
  }
}