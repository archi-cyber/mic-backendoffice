import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  IsArray,
  IsNotEmpty,
  IsBoolean,
  IsEmail,
  IsEnum,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  ValidateNested,
} from 'class-validator';

import { PaginationDto } from '../../../common/dto/pagination.dto';
import { FEATURES, type Feature } from '../../auth/types/auth.types';

const FEATURE_KEYS = Object.values(FEATURES);

const trimLower = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toLowerCase() : value;

// =============================================================================

/**
 * Création d'un compte de connexion pour un membre existant.
 *
 * Aucun mot de passe n'est demandé : le compte reçoit le mot de passe par
 * défaut avec obligation de le changer. Laisser un administrateur choisir le
 * mot de passe d'autrui signifierait qu'il le connaît — ce qui rend
 * impossible toute imputabilité des actions du compte.
 */
export class CreateUserAccountDto {
  @ApiProperty({ description: 'Membre auquel rattacher le compte' })
  @IsUUID('4', { message: 'Identifiant de membre invalide.' })
  memberId!: string;

  @ApiProperty({ example: 'responsable@eglise.org' })
  @Transform(trimLower)
  @IsEmail({}, { message: 'Adresse e-mail invalide.' })
  email!: string;

  @ApiPropertyOptional({ enum: UserRole, default: UserRole.member })
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;
}

// =============================================================================

export class UpdateUserDto {
  @ApiPropertyOptional({ enum: UserRole })
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(trimLower)
  @IsEmail({}, { message: 'Adresse e-mail invalide.' })
  email?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;
}

// =============================================================================

export class SetUserActiveDto {
  @ApiProperty({
    description:
      'Désactiver un compte ferme immédiatement toutes ses sessions ouvertes.',
  })
  @IsBoolean()
  isActive!: boolean;
}

// =============================================================================

export class FindUsersDto extends PaginationDto {
  @ApiPropertyOptional({ enum: UserRole })
  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  isActive?: boolean;
}

// =============================================================================

/** Droits accordés sur un module. */
export class FeaturePermissionDto {
  @ApiProperty({
    enum: FEATURE_KEYS,
    example: FEATURES.members,
    description: 'Clé du module concerné',
  })
  @IsIn(FEATURE_KEYS, { message: 'Module inconnu.' })
  feature!: Feature;

  @ApiProperty({ default: false })
  @IsBoolean()
  canView!: boolean;

  @ApiProperty({ default: false })
  @IsBoolean()
  canCreate!: boolean;

  @ApiProperty({ default: false })
  @IsBoolean()
  canEdit!: boolean;

  @ApiProperty({ default: false })
  @IsBoolean()
  canDelete!: boolean;
}

/**
 * Mise à jour groupée des permissions d'un utilisateur.
 *
 * Le remplacement est global : les modules absents de la liste voient leurs
 * droits révoqués. C'est délibéré — une mise à jour partielle laisserait
 * subsister des permissions oubliées, invisibles dans l'interface qui affiche
 * la grille complète.
 */
export class SetPermissionsDto {
  @ApiProperty({ type: [FeaturePermissionDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => FeaturePermissionDto)
  permissions!: FeaturePermissionDto[];
}

// =============================================================================
// APPAREILS
// =============================================================================

export class RegisterDeviceDto {
  @ApiProperty({ description: 'Jeton FCM de l\'appareil' })
  @IsString()
  @IsNotEmpty({ message: 'Le jeton d\'appareil est requis.' })
  @MaxLength(512)
  deviceToken!: string;

  @ApiPropertyOptional({ enum: ['ios', 'android', 'web'] })
  @IsOptional()
  @IsIn(['ios', 'android', 'web'], { message: 'Plateforme inconnue.' })
  platform?: 'ios' | 'android' | 'web';
}