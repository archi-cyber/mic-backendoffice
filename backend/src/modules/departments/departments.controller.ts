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
import { FEATURES, type AuthenticatedUser } from '../auth/types/auth.types';
import { DepartmentsService } from './departments.service';
import {
  AddDepartmentMemberDto,
  CreateDepartmentDto,
  CreateDepartmentReportDto,
  FindDepartmentsDto,
  UpdateDepartmentDto,
  UpdateDepartmentMemberDto,
  UpdateDepartmentReportDto,
} from './dto/department.dto';

@ApiTags('departments')
@ApiBearerAuth('access-token')
@Controller('departments')
export class DepartmentsController {
  constructor(private readonly departments: DepartmentsService) {}

  // ---------------------------------------------------------------------------
  // Departements
  // ---------------------------------------------------------------------------

  @Get()
  @RequirePermission(FEATURES.departments, 'view')
  @ApiOperation({ summary: 'Liste des departements' })
  findAll(@Query() query: FindDepartmentsDto) {
    return this.departments.findAll(query);
  }

  @Get(':id')
  @RequirePermission(FEATURES.departments, 'view')
  @ApiOperation({
    summary: 'Detail d un departement',
    description: 'Inclut la liste des membres avec leurs roles.',
  })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.departments.findOne(id);
  }

  @Post()
  @RequirePermission(FEATURES.departments, 'create')
  @ApiOperation({ summary: 'Cree un departement' })
  create(@Body() dto: CreateDepartmentDto) {
    return this.departments.create(dto);
  }

  @Patch(':id')
  @RequirePermission(FEATURES.departments, 'edit')
  @ApiOperation({
    summary: 'Modifie un departement',
    description:
      'Le departement « Finance » ne peut pas etre renomme : l acces au ' +
      'module financier depend de ce nom.',
  })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateDepartmentDto,
  ) {
    return this.departments.update(id, dto);
  }

  @Delete(':id')
  @RequirePermission(FEATURES.departments, 'delete')
  @ApiOperation({
    summary: 'Supprime un departement',
    description: 'Suppression logique. Les appartenances sont conservees.',
  })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.departments.remove(id);
  }

  // ---------------------------------------------------------------------------
  // Appartenances
  // ---------------------------------------------------------------------------

  @Post(':id/members')
  @RequirePermission(FEATURES.departments, 'edit')
  @ApiOperation({ summary: 'Ajoute un membre au departement' })
  addMember(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AddDepartmentMemberDto,
  ) {
    return this.departments.addMember(id, dto);
  }

  @Patch(':id/members/:memberId')
  @RequirePermission(FEATURES.departments, 'edit')
  @ApiOperation({
    summary: 'Change le role ou le caractere principal',
    description:
      'Promouvoir un rattachement en principal degrade automatiquement le ' +
      'precedent.',
  })
  updateMember(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
    @Body() dto: UpdateDepartmentMemberDto,
  ) {
    return this.departments.updateMember(id, memberId, dto);
  }

  @Delete(':id/members/:memberId')
  @RequirePermission(FEATURES.departments, 'edit')
  @ApiOperation({ summary: 'Retire un membre du departement' })
  removeMember(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
  ) {
    return this.departments.removeMember(id, memberId);
  }

  // ---------------------------------------------------------------------------
  // Rapports
  // ---------------------------------------------------------------------------

  @Get(':id/reports')
  @RequirePermission(FEATURES.reports, 'view')
  @ApiOperation({ summary: 'Rapports d activite du departement' })
  findReports(
    @Param('id', ParseUUIDPipe) id: string,
    @Query('page', new ParseIntPipe({ optional: true })) page?: number,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.departments.findReports(id, page ?? 1, limit ?? 20);
  }

  @Post(':id/reports')
  @RequirePermission(FEATURES.reports, 'create')
  @ApiOperation({ summary: 'Redige un rapport d activite' })
  createReport(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateDepartmentReportDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.departments.createReport(id, dto, userId);
  }

  @Patch('reports/:reportId')
  @RequirePermission(FEATURES.reports, 'edit')
  @ApiOperation({
    summary: 'Modifie un rapport',
    description: 'Reserve a l auteur du rapport ou a un administrateur.',
  })
  updateReport(
    @Param('reportId', ParseUUIDPipe) reportId: string,
    @Body() dto: UpdateDepartmentReportDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.departments.updateReport(reportId, dto, user);
  }

  @Delete('reports/:reportId')
  @RequirePermission(FEATURES.reports, 'delete')
  @ApiOperation({ summary: 'Supprime un rapport' })
  removeReport(
    @Param('reportId', ParseUUIDPipe) reportId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.departments.removeReport(reportId, user);
  }
}