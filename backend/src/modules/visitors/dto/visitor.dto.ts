import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { AttendanceType } from '@prisma/client';
import { Transform } from 'class-transformer';
import {
  IsDateString,
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

import { PaginationDto } from '../../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

const emptyToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' && value.trim() === '' ? null : value;

const trimLowerOrNull = ({ value }: { value: unknown }) => {
  if (typeof value !== 'string') return value;
  const cleaned = value.trim();
  return cleaned === '' ? null : cleaned.toLowerCase();
};

// =============================================================================

export class CreateVisitorDto {
  @ApiProperty({ example: 'Marie' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le prenom est requis.' })
  @MaxLength(100)
  firstName!: string;

  @ApiProperty({ example: 'Ngo' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le nom est requis.' })
  @MaxLength(100)
  lastName!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trimLowerOrNull)
  @IsEmail({}, { message: 'Adresse e-mail invalide.' })
  email?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(30)
  phone?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(255)
  address?: string | null;

  @ApiPropertyOptional({ example: '2026-08-09' })
  @IsOptional()
  @IsDateString({}, { message: 'La date doit etre au format AAAA-MM-JJ.' })
  visitDate?: string;

  @ApiPropertyOptional({
    description: 'Culte auquel la personne a assiste, si applicable',
  })
  @IsOptional()
  @Transform(emptyToNull)
  @IsUUID('4', { message: 'Identifiant de culte invalide.' })
  churchServiceId?: string | null;

  @ApiPropertyOptional({ enum: AttendanceType, default: AttendanceType.onsite })
  @IsOptional()
  @IsEnum(AttendanceType)
  attendanceType?: AttendanceType;

  @ApiPropertyOptional({ description: 'Observations sur la visite' })
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(1000)
  notes?: string | null;
}

export class UpdateVisitorDto extends PartialType(CreateVisitorDto) {}

// =============================================================================

export class FindVisitorsDto extends PaginationDto {
  @ApiPropertyOptional({ example: '2026-01-01' })
  @IsOptional()
  @IsDateString()
  from?: string;

  @ApiPropertyOptional({ example: '2026-12-31' })
  @IsOptional()
  @IsDateString()
  to?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  churchServiceId?: string;
}

// =============================================================================

/**
 * Conversion d un visiteur en membre.
 *
 * Les coordonnees du visiteur sont reprises telles quelles ; seuls les champs
 * fournis ici les completent ou les remplacent.
 */
export class ConvertVisitorDto {
  @ApiPropertyOptional({
    example: '1995-03-20',
    description: 'Date de naissance, si elle a pu etre recueillie',
  })
  @IsOptional()
  @IsDateString()
  birthday?: string;

  @ApiPropertyOptional({ description: 'Departement principal' })
  @IsOptional()
  @Transform(emptyToNull)
  @IsUUID('4')
  departmentId?: string | null;

  @ApiPropertyOptional({
    default: true,
    description:
      'Enregistre la personne comme nouveau venu, ce qui declenche le suivi ' +
      'sur quatre-vingt-dix jours.',
  })
  @IsOptional()
  isNewComer?: boolean;
}