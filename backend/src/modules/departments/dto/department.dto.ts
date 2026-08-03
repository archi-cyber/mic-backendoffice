import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { DepartmentRole } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';

import { PaginationDto } from '../../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

const emptyToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' && value.trim() === '' ? null : value;

// =============================================================================

export class CreateDepartmentDto {
  @ApiProperty({ example: 'Média' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le nom du département est requis.' })
  @MaxLength(100)
  name!: string;

  @ApiPropertyOptional()
  @IsOptional() @Transform(emptyToNull) @IsString() @MaxLength(500)
  description?: string | null;

  // --- Documents de référence (trois emplacements) ---

  @ApiPropertyOptional() @IsOptional() @Transform(emptyToNull) @IsString() @MaxLength(500)
  document1Url?: string | null;
  @ApiPropertyOptional() @IsOptional() @Transform(emptyToNull) @IsString() @MaxLength(255)
  document1Name?: string | null;

  @ApiPropertyOptional() @IsOptional() @Transform(emptyToNull) @IsString() @MaxLength(500)
  document2Url?: string | null;
  @ApiPropertyOptional() @IsOptional() @Transform(emptyToNull) @IsString() @MaxLength(255)
  document2Name?: string | null;

  @ApiPropertyOptional() @IsOptional() @Transform(emptyToNull) @IsString() @MaxLength(500)
  document3Url?: string | null;
  @ApiPropertyOptional() @IsOptional() @Transform(emptyToNull) @IsString() @MaxLength(255)
  document3Name?: string | null;

  @ApiPropertyOptional({
    description:
      'Pénalité journalière propre au département, en francs. Prend le pas ' +
      'sur la valeur globale, mais cède devant une valeur définie sur la tâche.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  taskPenaltyAmount?: number | null;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class UpdateDepartmentDto extends PartialType(CreateDepartmentDto) {}

// =============================================================================

export class FindDepartmentsDto extends PaginationDto {
  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  isActive?: boolean;

  @ApiPropertyOptional({
    description: 'Inclut le décompte des membres et des projets',
    default: false,
  })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  withCounts?: boolean;
}

// =============================================================================

export class AddDepartmentMemberDto {
  @ApiProperty()
  @IsUUID('4', { message: 'Identifiant de membre invalide.' })
  memberId!: string;

  @ApiPropertyOptional({ enum: DepartmentRole, default: DepartmentRole.member })
  @IsOptional()
  @IsEnum(DepartmentRole)
  role?: DepartmentRole;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isMain?: boolean;
}

export class UpdateDepartmentMemberDto {
  @ApiPropertyOptional({ enum: DepartmentRole })
  @IsOptional()
  @IsEnum(DepartmentRole)
  role?: DepartmentRole;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isMain?: boolean;
}

// =============================================================================

/**
 * Rapport d'activité.
 *
 * Les cinq premiers champs sont obligatoires : c'est le canevas retenu par
 * l'église, et le rendre facultatif produirait des rapports inexploitables.
 */
export class CreateDepartmentReportDto {
  @ApiProperty({ example: 'Rapport mensuel — janvier 2026' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le titre est requis.' })
  @MaxLength(255)
  title!: string;

  @ApiProperty()
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Les objectifs définis sont requis.' })
  definedObjectives!: string;

  @ApiProperty()
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Les points positifs sont requis.' })
  positivePoints!: string;

  @ApiProperty()
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Les difficultés rencontrées sont requises.' })
  difficultiesEncountered!: string;

  @ApiProperty()
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Les suggestions sont requises.' })
  suggestions!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  comments?: string | null;
}

export class UpdateDepartmentReportDto extends PartialType(
  CreateDepartmentReportDto,
) {}