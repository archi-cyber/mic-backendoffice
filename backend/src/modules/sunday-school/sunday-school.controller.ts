import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequirePermission } from '../../common/decorators/permission.decorator';
import { FEATURES } from '../auth/types/auth.types';
import {
  FindEligibleChildrenDto,
  FindSundaySchoolDto,
  MarkSundaySchoolDto,
} from './dto/sunday-school.dto';
import { SundaySchoolService } from './sunday-school.service';

@ApiTags('sunday-school')
@ApiBearerAuth('access-token')
@Controller('sunday-school')
export class SundaySchoolController {
  constructor(private readonly sundaySchool: SundaySchoolService) {}

  @Get('children')
  @RequirePermission(FEATURES.sundaySchoolAttendance, 'view')
  @ApiOperation({
    summary: 'Enfants eligibles',
    description:
      'Membres de 0 a 12 ans disposant d une date de naissance. Ceux sans ' +
      'date sont exclus : leur eligibilite ne peut pas etre etablie.',
  })
  findChildren(@Query() query: FindEligibleChildrenDto) {
    return this.sundaySchool.findEligibleChildren(query.maxAge);
  }

  @Get()
  @RequirePermission(FEATURES.sundaySchoolAttendance, 'view')
  @ApiOperation({ summary: 'Historique des presences' })
  findAll(@Query() query: FindSundaySchoolDto) {
    return this.sundaySchool.findAll(query);
  }

  @Get('date/:attendanceDate')
  @RequirePermission(FEATURES.sundaySchoolAttendance, 'view')
  @ApiOperation({
    summary: 'Feuille de presence d une date',
    description:
      'Renvoie tous les enfants eligibles avec un indicateur isPresent, ' +
      'pret pour l ecran de saisie. Format de date : AAAA-MM-JJ.',
  })
  findByDate(@Param('attendanceDate') attendanceDate: string) {
    return this.sundaySchool.findByDate(attendanceDate);
  }

  @Post()
  @HttpCode(HttpStatus.OK)
  @RequirePermission(FEATURES.sundaySchoolAttendance, 'create')
  @ApiOperation({
    summary: 'Enregistre la presence d une session',
    description:
      'Remplacement total pour la date : les enfants absents de la liste ' +
      'voient leur presence retiree, ce qui permet de corriger une saisie.',
  })
  markAttendance(
    @Body() dto: MarkSundaySchoolDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.sundaySchool.markAttendance(dto, userId);
  }

  @Delete('date/:attendanceDate')
  @RequirePermission(FEATURES.sundaySchoolAttendance, 'delete')
  @ApiOperation({ summary: 'Supprime toute la session d une date' })
  removeSession(@Param('attendanceDate') attendanceDate: string) {
    return this.sundaySchool.removeSession(attendanceDate);
  }
}