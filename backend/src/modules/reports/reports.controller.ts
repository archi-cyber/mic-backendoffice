import { Controller, Get, Param, ParseUUIDPipe, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermission } from '../../common/decorators/permission.decorator';
import { FEATURES } from '../auth/types/auth.types';
import {
  AttendanceReportDto,
  NewcomersReportDto,
  ReportPeriodDto,
} from './dto/report.dto';
import { ReportsService } from './reports.service';

@ApiTags('reports')
@ApiBearerAuth('access-token')
@Controller('reports')
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  // ---------------------------------------------------------------------------
  // Tableau de bord
  // ---------------------------------------------------------------------------

  @Get('dashboard')
  @ApiOperation({
    summary: 'Vue d ensemble',
    description:
      'Effectifs, taches ouvertes, prochains evenements et seances, ' +
      'anniversaires du mois. Aucune permission particuliere : ces chiffres ' +
      'sont ceux de l ecran d accueil, visibles de tous.',
  })
  getDashboard() {
    return this.reports.getDashboard();
  }

  // ---------------------------------------------------------------------------
  // Presence
  // ---------------------------------------------------------------------------

  @Get('attendance')
  @RequirePermission(FEATURES.reports, 'view')
  @ApiOperation({
    summary: 'Rapport de presence par membre',
    description:
      'Le taux rapporte les presences au nombre de cultes TENUS sur la ' +
      'periode. Un membre jamais pointe apparait donc a zero : pour le suivi ' +
      'pastoral, l oubli de pointage et l absence appellent le meme geste.',
  })
  getAttendanceReport(@Query() query: AttendanceReportDto) {
    return this.reports.getAttendanceReport(query);
  }

  @Get('attendance/trend')
  @RequirePermission(FEATURES.reports, 'view')
  @ApiOperation({
    summary: 'Frequentation culte par culte',
    description:
      'Ordre chronologique, format directement exploitable pour un graphique ' +
      'd evolution. Inclut le decompte des visiteurs.',
  })
  getAttendanceTrend(@Query() query: ReportPeriodDto) {
    return this.reports.getAttendanceTrend(query);
  }

  // ---------------------------------------------------------------------------
  // Nouveaux venus
  // ---------------------------------------------------------------------------

  @Get('newcomers')
  @RequirePermission(FEATURES.reports, 'view')
  @ApiOperation({
    summary: 'Suivi des nouveaux venus',
    description:
      'Signale ceux qui decrochent via le drapeau atRisk : plus de trente ' +
      'jours sans presence, ou aucune presence du tout.',
  })
  getNewcomersReport(@Query() query: NewcomersReportDto) {
    return this.reports.getNewcomersReport(query);
  }

  // ---------------------------------------------------------------------------
  // Rapports individuels
  // ---------------------------------------------------------------------------

  @Get('member/:memberId')
  @RequirePermission(FEATURES.reports, 'view')
  @ApiOperation({
    summary: 'Bilan complet d un membre',
    description:
      'Presence, dons, taches, penalites et formations. Les dons sont ' +
      'reduits a un total, sans detail par mouvement.',
  })
  getMemberReport(
    @Param('memberId', ParseUUIDPipe) memberId: string,
    @Query() query: ReportPeriodDto,
  ) {
    return this.reports.getMemberReport(memberId, query);
  }

  @Get('me')
  @ApiOperation({
    summary: 'Mon propre bilan',
    description:
      'Accessible sans permission : chacun peut consulter ses propres ' +
      'chiffres.',
  })
  getMyReport(
    @CurrentUser('memberId') memberId: string | null,
    @Query() query: ReportPeriodDto,
  ) {
    if (!memberId) {
      return { message: 'Aucune fiche membre associee a ce compte.' };
    }
    return this.reports.getMemberReport(memberId, query);
  }

  @Get('department/:departmentId')
  @RequirePermission(FEATURES.reports, 'view')
  @ApiOperation({
    summary: 'Bilan d activite d un departement',
    description: 'Effectifs, taches, projets et rapports rediges.',
  })
  getDepartmentReport(
    @Param('departmentId', ParseUUIDPipe) departmentId: string,
    @Query() query: ReportPeriodDto,
  ) {
    return this.reports.getDepartmentReport(departmentId, query);
  }
}