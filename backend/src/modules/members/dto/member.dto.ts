import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import {
  DepartmentRole,
  Gender,
  MaritalStatus,
  MemberRole,
  NewcomerIntention,
  Profession,
} from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  ValidateIf,
} from 'class-validator';

import { PaginationDto } from '../../../common/dto/pagination.dto';

// -----------------------------------------------------------------------------
// Transformations
// -----------------------------------------------------------------------------
//
// class-transformer n'applique qu'UN SEUL décorateur @Transform par propriété.
// Empiler @Transform(emptyToNull) puis @Transform(trimLower) ne fonctionne
// donc pas : seul le dernier déclaré s'exécute. Chaque combinaison utile est
// écrite comme une fonction unique.
// -----------------------------------------------------------------------------

/** Retire les espaces de début et de fin. */
const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

/** Convertit une chaîne vide en `null` — un champ vidé doit effacer la valeur. */
const emptyToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' && value.trim() === '' ? null : value;

/**
 * Nettoie, met en minuscules, et convertit le vide en `null`.
 *
 * Sans la mise en minuscules, `Jean@Test.org` et `jean@test.org` seraient
 * traités comme deux adresses distinctes — la vérification d'unicité
 * laisserait passer un doublon.
 */
const trimLowerOrNull = ({ value }: { value: unknown }) => {
  if (typeof value !== 'string') return value;
  const cleaned = value.trim();
  return cleaned === '' ? null : cleaned.toLowerCase();
};

/** Nettoie et convertit le vide en `null`. */
const trimOrNull = ({ value }: { value: unknown }) => {
  if (typeof value !== 'string') return value;
  const cleaned = value.trim();
  return cleaned === '' ? null : cleaned;
};

// =============================================================================

export class CreateMemberDto {
  @ApiProperty({ example: 'Jean' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le prénom est requis.' })
  @MaxLength(100)
  firstName!: string;

  @ApiProperty({ example: 'Dupont' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le nom est requis.' })
  @MaxLength(100)
  lastName!: string;

  @ApiPropertyOptional({ example: 'jean.dupont@exemple.org' })
  @IsOptional()
  @Transform(trimLowerOrNull)
  @IsEmail({}, { message: 'Adresse e-mail invalide.' })
  email?: string | null;

  @ApiPropertyOptional({ example: '+237690123456' })
  @IsOptional()
  @Transform(trimOrNull)
  @IsString()
  @MaxLength(30)
  phone?: string | null;

  @ApiPropertyOptional({
    example: '1990-05-14',
    description:
      "Date de naissance au format ISO. Requise pour l'école du dimanche, " +
      "qui s'appuie sur l'âge pour identifier les enfants.",
  })
  @IsOptional()
  @IsDateString({}, { message: 'La date de naissance doit être au format AAAA-MM-JJ.' })
  birthday?: string | null;

  // --- Adresse ---

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(255)
  address?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(100)
  city?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(100)
  state?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(20)
  zipCode?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(100)
  country?: string | null;

  @ApiPropertyOptional({ description: 'Quartier de résidence' })
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(100)
  quarter?: string | null;

  // --- Profil professionnel ---

  @ApiPropertyOptional({ enum: Profession })
  @IsOptional()
  @Transform(emptyToNull)
  @IsEnum(Profession, { message: 'Profession non reconnue.' })
  profession?: Profession | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(100)
  levelOfStudy?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(150)
  sectorOfStudies?: string | null;

  @ApiPropertyOptional({
    description:
      "Domaine d'activité — attendu pour les profils « demandeur d'emploi » " +
      'et « travailleur ».',
  })
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(150)
  domainOfActivity?: string | null;

  @ApiPropertyOptional({ type: [String], example: ['Comptabilité', 'Sonorisation'] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20, { message: 'Vingt compétences au maximum.' })
  @IsString({ each: true })
  keySkills?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(255)
  lastDiplomas?: string | null;

  // --- Informations personnelles ---

  @ApiPropertyOptional({ enum: Gender })
  @IsOptional()
  @Transform(emptyToNull)
  @IsEnum(Gender)
  gender?: Gender | null;

  @ApiPropertyOptional({ enum: MaritalStatus })
  @IsOptional()
  @Transform(emptyToNull)
  @IsEnum(MaritalStatus)
  maritalStatus?: MaritalStatus | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(500)
  photoUrl?: string | null;

  // --- Appartenance ---

  @ApiPropertyOptional({ enum: MemberRole, default: MemberRole.member })
  @IsOptional()
  @IsEnum(MemberRole)
  role?: MemberRole;

  @ApiPropertyOptional({ description: 'Département principal' })
  @IsOptional()
  @Transform(emptyToNull)
  @IsUUID('4', { message: 'Identifiant de département invalide.' })
  departmentId?: string | null;

  // --- Suivi nouveau venu ---

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isNewComer?: boolean;

  @ApiPropertyOptional({ example: '2026-01-12' })
  @IsOptional()
  @IsDateString()
  newcomerJoinDate?: string | null;

  @ApiPropertyOptional({
    enum: NewcomerIntention,
    description:
      "« just_passing » est refusé ici : une personne de passage relève des " +
      'visiteurs, pas des membres.',
  })
  // Le champ n'est validé que si la personne est marquée comme nouveau venu.
  @ValidateIf((dto: CreateMemberDto) => dto.isNewComer === true)
  @IsOptional()
  @Transform(emptyToNull)
  @IsEnum(NewcomerIntention)
  newcomerIntention?: NewcomerIntention | null;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  birthdayNotificationsOptOut?: boolean;
}

// =============================================================================

/**
 * Tous les champs deviennent optionnels.
 *
 * `PartialType` conserve les règles de validation : un champ fourni reste
 * contrôlé, un champ absent est simplement ignoré.
 */
export class UpdateMemberDto extends PartialType(CreateMemberDto) {}

// =============================================================================

export class FindMembersDto extends PaginationDto {
  @ApiPropertyOptional({ enum: MemberRole })
  @IsOptional()
  @IsEnum(MemberRole)
  role?: MemberRole;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  departmentId?: string;

  @ApiPropertyOptional({ default: true, description: 'Filtre sur les membres actifs' })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  isActive?: boolean;

  @ApiPropertyOptional({ description: 'Uniquement les nouveaux venus' })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  isNewComer?: boolean;

  @ApiPropertyOptional({ enum: NewcomerIntention })
  @IsOptional()
  @IsEnum(NewcomerIntention)
  newcomerIntention?: NewcomerIntention;

  @ApiPropertyOptional({ enum: Gender })
  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @ApiPropertyOptional({ enum: Profession })
  @IsOptional()
  @IsEnum(Profession)
  profession?: Profession;

  @ApiPropertyOptional({
    description: 'Âge minimum, calculé depuis la date de naissance',
  })
  @IsOptional()
  @Type(() => Number)
  minAge?: number;

  @ApiPropertyOptional({ description: 'Âge maximum' })
  @IsOptional()
  @Type(() => Number)
  maxAge?: number;

  @ApiPropertyOptional({ description: "Membres disposant d'un compte de connexion" })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  hasAccount?: boolean;
}

// =============================================================================

export class AddToDepartmentDto {
  @ApiProperty()
  @IsUUID('4', { message: 'Identifiant de département invalide.' })
  departmentId!: string;

  @ApiPropertyOptional({ enum: DepartmentRole, default: DepartmentRole.member })
  @IsOptional()
  @IsEnum(DepartmentRole)
  role?: DepartmentRole;

  @ApiPropertyOptional({
    default: false,
    description:
      "Département principal. Un membre ne peut en avoir qu'un : " +
      "l'ancien est automatiquement dégradé.",
  })
  @IsOptional()
  @IsBoolean()
  isMain?: boolean;
}