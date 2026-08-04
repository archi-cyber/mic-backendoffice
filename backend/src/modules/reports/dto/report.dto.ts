import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsDateString, IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';

/**
 * Periode d analyse commune a tous les rapports.
 *
 * Sans bornes, la periode couvre l integralite des donnees. C est acceptable
 * pour une eglise dont l historique se compte en annees, pas en millions de
 * lignes.
 */
export class ReportPeriodDto {
  @ApiPropertyOptional({ example: '2026-01-01' })
  @IsOptional()
  @IsDateString({}, { message: 'La date doit etre au format AAAA-MM-JJ.' })
  from?: string;

  @ApiPropertyOptional({ example: '2026-12-31' })
  @IsOptional()
  @IsDateString({}, { message: 'La date doit etre au format AAAA-MM-JJ.' })
  to?: string;
}

// =============================================================================

export class AttendanceReportDto extends ReportPeriodDto {
  @ApiPropertyOptional({
    default: 75,
    description:
      'Seuil de presence, en pourcentage, a partir duquel un membre est ' +
      'considere comme assidu.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  diligentThreshold?: number;

  @ApiPropertyOptional({
    default: 50,
    description: 'Seuil en dessous duquel un membre est considere peu assidu.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  moderateThreshold?: number;

  @ApiPropertyOptional({ description: 'Restreint a un departement' })
  @IsOptional()
  @IsUUID('4')
  departmentId?: string;
}

// =============================================================================

export class NewcomersReportDto extends ReportPeriodDto {
  @ApiPropertyOptional({
    default: 90,
    description:
      'Fenetre de suivi, en jours, sur laquelle la presence des nouveaux ' +
      'venus est mesuree.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(7)
  @Max(365)
  windowDays?: number;
}

// =============================================================================

export class MonthlyReportDto {
  @ApiPropertyOptional({ example: 2026 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(2000)
  @Max(2200)
  year?: number;
}