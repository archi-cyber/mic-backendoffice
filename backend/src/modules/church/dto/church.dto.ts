import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { AttendanceType } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  ValidateNested,
} from 'class-validator';

import { PaginationDto } from '../../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

const emptyToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' && value.trim() === '' ? null : value;

// =============================================================================
// Cultes
// =============================================================================

export class CreateChurchServiceDto {
  @ApiProperty({
    example: '2026-08-09',
    description: "N'importe quel jour de la semaine est accepté.",
  })
  @IsDateString({}, { message: 'La date doit être au format AAAA-MM-JJ.' })
  serviceDate!: string;

  @ApiProperty({
    example: 'Culte du matin',
    description:
      'Nom libre mais obligatoire. Plusieurs cultes peuvent avoir lieu le ' +
      'même jour, à condition de porter des noms différents.',
  })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le nom du culte est requis.' })
  @MaxLength(150)
  name!: string;
}

export class UpdateChurchServiceDto extends PartialType(CreateChurchServiceDto) {}

export class FindChurchServicesDto extends PaginationDto {
  @ApiPropertyOptional({ example: '2026-01-01' })
  @IsOptional()
  @IsDateString()
  from?: string;

  @ApiPropertyOptional({ example: '2026-12-31' })
  @IsOptional()
  @IsDateString()
  to?: string;
}

// =============================================================================
// Présence
// =============================================================================

/** Présence d'un membre pour un culte donné. */
export class AttendanceEntryDto {
  @ApiProperty()
  @IsUUID('4', { message: 'Identifiant de membre invalide.' })
  memberId!: string;

  @ApiProperty({ enum: AttendanceType, example: AttendanceType.onsite })
  @IsEnum(AttendanceType, {
    message: 'Le type de présence doit être onsite, online ou absent.',
  })
  attendanceType!: AttendanceType;

  @ApiPropertyOptional({ description: 'Observation propre à ce membre' })
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(500)
  specificObservation?: string | null;
}

/**
 * Marquage groupé de la présence.
 *
 * Les responsables saisissent la feuille de présence en une fois, pour
 * plusieurs dizaines de membres. Envoyer une requête par personne serait
 * inutilisable sur une connexion mobile — d'où ce format par lot.
 */
export class MarkAttendanceDto {
  @ApiProperty({ type: [AttendanceEntryDto] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Au moins une présence doit être fournie.' })
  // Plafond de sécurité : au-delà, la transaction deviendrait trop longue et
  // risquerait d'expirer côté base.
  @ArrayMaxSize(1000, { message: 'Mille présences au maximum par requête.' })
  @ValidateNested({ each: true })
  @Type(() => AttendanceEntryDto)
  entries!: AttendanceEntryDto[];
}

export class FindAttendanceDto extends PaginationDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  memberId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  churchServiceId?: string;

  @ApiPropertyOptional({ enum: AttendanceType })
  @IsOptional()
  @IsEnum(AttendanceType)
  attendanceType?: AttendanceType;

  @ApiPropertyOptional({ example: '2026-01-01' })
  @IsOptional()
  @IsDateString()
  from?: string;

  @ApiPropertyOptional({ example: '2026-12-31' })
  @IsOptional()
  @IsDateString()
  to?: string;
}