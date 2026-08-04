import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { AttendanceStatus } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

import { PaginationDto } from '../../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

const emptyToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' && value.trim() === '' ? null : value;

// =============================================================================

export class CreateClassDto {
  @ApiProperty({ example: 'Ecole des ouvriers' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le nom de la formation est requis.' })
  @MaxLength(150)
  name!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(2000)
  description?: string | null;

  @ApiPropertyOptional({ description: 'Departement organisateur' })
  @IsOptional()
  @Transform(emptyToNull)
  @IsUUID('4')
  departmentId?: string | null;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class UpdateClassDto extends PartialType(CreateClassDto) {}

export class FindClassesDto extends PaginationDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  departmentId?: string;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  isActive?: boolean;
}

// =============================================================================

export class EnrollMembersDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Au moins un membre doit etre inscrit.' })
  @ArrayMaxSize(200)
  @IsUUID('4', { each: true })
  memberIds!: string[];
}

// =============================================================================

/**
 * Generation de seances a intervalle regulier.
 *
 * Les formations de l eglise suivent un rythme hebdomadaire ou bimensuel :
 * generer les seances d avance evite de les creer une par une.
 */
export class GenerateSessionsDto {
  @ApiProperty({ example: 8, description: 'Nombre de seances a creer' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(52, { message: 'Cinquante-deux seances au maximum.' })
  count!: number;

  @ApiProperty({ example: '2026-09-06' })
  @IsDateString({}, { message: 'La date doit etre au format AAAA-MM-JJ.' })
  startDate!: string;

  @ApiPropertyOptional({
    default: 1,
    description: 'Nombre de semaines entre deux seances',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(12)
  weeksBetween?: number;
}

// =============================================================================

export class SessionAttendanceEntryDto {
  @ApiProperty()
  @IsUUID('4')
  memberId!: string;

  @ApiProperty({ enum: AttendanceStatus })
  @IsEnum(AttendanceStatus, {
    message: 'Le statut doit etre present, absent, excused ou late.',
  })
  status!: AttendanceStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(500)
  notes?: string | null;
}

export class MarkSessionAttendanceDto {
  @ApiProperty({ type: [SessionAttendanceEntryDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => SessionAttendanceEntryDto)
  entries!: SessionAttendanceEntryDto[];
}