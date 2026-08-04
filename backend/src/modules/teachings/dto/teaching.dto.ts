import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
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

// =============================================================================

export class CreateTeachingDto {
  @ApiProperty({ example: 'La foi qui déplace les montagnes' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le titre est requis.' })
  @MaxLength(255)
  title!: string;

  @ApiProperty({ example: '2026-08-09' })
  @IsDateString({}, { message: 'La date doit être au format AAAA-MM-JJ.' })
  teachingDate!: string;

  @ApiPropertyOptional({ example: 'Pasteur Jean Mbarga' })
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(150)
  speaker?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(5000)
  description?: string | null;

  @ApiPropertyOptional({
    default: true,
    description:
      'Génère les tâches de montage pour le département Média. ' +
      "Désactiver si l'enseignement n'a pas été capté.",
  })
  @IsOptional()
  @IsBoolean()
  generateMediaTasks?: boolean;

  @ApiPropertyOptional({
    default: true,
    description:
      'Alimente la liste des auditeurs depuis la présence au culte de la ' +
      'même date.',
  })
  @IsOptional()
  @IsBoolean()
  syncListeners?: boolean;
}

export class UpdateTeachingDto extends PartialType(CreateTeachingDto) {}

// =============================================================================

export class FindTeachingsDto extends PaginationDto {
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
  @Transform(trim)
  @IsString()
  speaker?: string;
}

// =============================================================================

export class AddListenersDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Au moins un auditeur doit être fourni.' })
  @ArrayMaxSize(500)
  @IsUUID('4', { each: true })
  memberIds!: string[];
}