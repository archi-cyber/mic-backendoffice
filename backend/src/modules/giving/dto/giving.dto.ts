import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { GivingTag, GivingType } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';

import { PaginationDto } from '../../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

const emptyToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' && value.trim() === '' ? null : value;

// =============================================================================

export class CreateGivingDto {
  @ApiProperty({
    example: 'Jean Dupont',
    description:
      'Nom du donateur. Obligatoire meme pour un membre : il figure tel quel ' +
      'sur les recus, et un membre supprime ne doit pas rendre le mouvement ' +
      'anonyme.',
  })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le nom du donateur est requis.' })
  @MaxLength(150)
  giverName!: string;

  @ApiPropertyOptional({
    description: 'Membre associe, si le donateur en est un',
  })
  @IsOptional()
  @Transform(emptyToNull)
  @IsUUID('4', { message: 'Identifiant de membre invalide.' })
  memberId?: string | null;

  @ApiProperty({ example: 25000.5, description: 'Montant, en francs' })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 }, {
    message: 'Le montant accepte deux decimales au maximum.',
  })
  @Min(0.01, { message: 'Le montant doit etre superieur a zero.' })
  // Plafond de securite contre les erreurs de saisie : un zero de trop est
  // vite arrive, et une ligne aberrante fausse toute la comptabilite.
  @Max(999_999_999.99)
  amount!: number;

  @ApiProperty({ enum: GivingTag, example: GivingTag.tithe })
  @IsEnum(GivingTag, { message: 'Categorie inconnue.' })
  tag!: GivingTag;

  @ApiProperty({
    enum: GivingType,
    description: 'receiving pour une entree, expense pour une sortie',
  })
  @IsEnum(GivingType, { message: 'Le type doit etre receiving ou expense.' })
  type!: GivingType;

  @ApiPropertyOptional({ example: '2026-08-09' })
  @IsOptional()
  @IsDateString({}, { message: 'La date doit etre au format AAAA-MM-JJ.' })
  date?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(1000)
  notes?: string | null;
}

export class UpdateGivingDto extends PartialType(CreateGivingDto) {}

// =============================================================================

export class FindGivingDto extends PaginationDto {
  @ApiPropertyOptional({ enum: GivingType })
  @IsOptional()
  @IsEnum(GivingType)
  type?: GivingType;

  @ApiPropertyOptional({ enum: GivingTag })
  @IsOptional()
  @IsEnum(GivingTag)
  tag?: GivingTag;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  memberId?: string;

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

export class GivingSummaryDto {
  @ApiPropertyOptional({ example: '2026-01-01' })
  @IsOptional()
  @IsDateString()
  from?: string;

  @ApiPropertyOptional({ example: '2026-12-31' })
  @IsOptional()
  @IsDateString()
  to?: string;

  @ApiPropertyOptional({
    example: 2026,
    description: 'Annee pour la ventilation mensuelle',
  })
  @IsOptional()
  @Type(() => Number)
  @Min(2000)
  @Max(2200)
  year?: number;
}