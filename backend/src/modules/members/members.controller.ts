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
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermission } from '../../common/decorators/permission.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { FEATURES } from '../auth/types/auth.types';
import {
  AddToDepartmentDto,
  CreateMemberDto,
  FindMembersDto,
  UpdateMemberDto,
} from './dto/member.dto';
import { MembersService } from './members.service';

@ApiTags('members')
@ApiBearerAuth('access-token')
@Controller('members')
export class MembersController {
  constructor(private readonly members: MembersService) {}

  // ---------------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------------

  @Get()
  @RequirePermission(FEATURES.members, 'view')
  @ApiOperation({
    summary: 'Liste paginee des membres',
    description:
      'Filtres disponibles : role, departement, statut, nouveau venu, ' +
      'genre, profession, tranche d age, presence d un compte.',
  })
  findAll(@Query() query: FindMembersDto) {
    return this.members.findAll(query);
  }

  @Get('birthdays')
  @RequirePermission(FEATURES.members, 'view')
  @ApiOperation({
    summary: 'Anniversaires a venir',
    description:
      'Exclut les membres ayant desactive les notifications d anniversaire.',
  })
  findBirthdays(
    @Query('days', new ParseIntPipe({ optional: true })) days?: number,
  ) {
    return this.members.findUpcomingBirthdays(days ?? 30);
  }

  @Get(':id')
  @RequirePermission(FEATURES.members, 'view')
  @ApiOperation({
    summary: 'Fiche complete d un membre',
    description:
      'Inclut les departements, le compte associe et quelques compteurs.',
  })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.members.findOne(id);
  }

  // ---------------------------------------------------------------------------
  // Ecriture
  // ---------------------------------------------------------------------------

  @Post()
  @RequirePermission(FEATURES.members, 'create')
  @ApiOperation({
    summary: 'Cree un membre',
    description:
      'Une intention « just_passing » est refusee : ces personnes relevent ' +
      'des visiteurs.',
  })
  create(@Body() dto: CreateMemberDto, @CurrentUser('id') userId: string) {
    return this.members.create(dto, userId);
  }

  @Patch(':id')
  @RequirePermission(FEATURES.members, 'edit')
  @ApiOperation({ summary: 'Modifie un membre' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateMemberDto,
  ) {
    return this.members.update(id, dto);
  }

  @Delete(':id')
  @RequirePermission(FEATURES.members, 'delete')
  @ApiOperation({
    summary: 'Supprime un membre',
    description:
      'Suppression logique. Le compte de connexion associe est desactive et ' +
      'ses sessions sont fermees.',
  })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.members.remove(id);
  }

  @Post(':id/restore')
  @Roles('admin')
  @ApiOperation({
    summary: 'Restaure un membre supprime',
    description: 'Reserve aux administrateurs.',
  })
  restore(@Param('id', ParseUUIDPipe) id: string) {
    return this.members.restore(id);
  }

  // ---------------------------------------------------------------------------
  // Departements
  // ---------------------------------------------------------------------------

  @Post(':id/departments')
  @RequirePermission(FEATURES.members, 'edit')
  @ApiOperation({
    summary: 'Rattache le membre a un departement',
    description:
      'Marquer le rattachement comme principal degrade automatiquement ' +
      'l ancien departement principal.',
  })
  addToDepartment(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AddToDepartmentDto,
  ) {
    return this.members.addToDepartment(id, dto);
  }

  @Delete(':id/departments/:departmentId')
  @RequirePermission(FEATURES.members, 'edit')
  @ApiOperation({ summary: 'Retire le membre d un departement' })
  removeFromDepartment(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('departmentId', ParseUUIDPipe) departmentId: string,
  ) {
    return this.members.removeFromDepartment(id, departmentId);
  }
}