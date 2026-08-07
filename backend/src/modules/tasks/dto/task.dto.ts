import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { TaskPriority, TaskStatus } from '@prisma/client';
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
// TÂCHES
// =============================================================================

export class CreateTaskDto {
  @ApiProperty({ example: 'Préparer la sonorisation du culte' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le titre de la tâche est requis.' })
  @MaxLength(255)
  title!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(2000)
  description?: string | null;

  @ApiPropertyOptional({
    description:
      'Département propriétaire. Exclusif avec memberId : une tâche relève ' +
      'soit d\'un département, soit d\'une personne.',
  })
  // Le champ n'est validé que si aucun membre n'est désigné.
  @ValidateIf((dto: CreateTaskDto) => !dto.memberId)
  @IsOptional()
  @Transform(emptyToNull)
  @IsUUID('4', { message: 'Identifiant de département invalide.' })
  departmentId?: string | null;

  @ApiPropertyOptional({
    description: 'Tâche personnelle. Exclusif avec departmentId.',
  })
  @IsOptional()
  @Transform(emptyToNull)
  @IsUUID('4', { message: 'Identifiant de membre invalide.' })
  memberId?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsUUID('4')
  projectId?: string | null;

  @ApiPropertyOptional({ example: '2026-08-20' })
  @IsOptional()
  @IsDateString({}, { message: 'La date doit être au format AAAA-MM-JJ.' })
  dueDate?: string | null;

  @ApiPropertyOptional({ enum: TaskPriority, default: TaskPriority.medium })
  @IsOptional()
  @IsEnum(TaskPriority)
  priority?: TaskPriority;

  @ApiPropertyOptional({ enum: TaskStatus, default: TaskStatus.pending })
  @IsOptional()
  @IsEnum(TaskStatus)
  status?: TaskStatus;

  @ApiPropertyOptional({
    description:
      'Pénalité journalière propre à cette tâche, en francs. Prend le pas ' +
      'sur le montant du département et sur le montant global.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  penaltyAmountPerDay?: number | null;

  @ApiPropertyOptional({ type: [String], description: 'Membres assignés' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsUUID('4', { each: true })
  assigneeIds?: string[];

  @ApiPropertyOptional({ type: [String], description: 'Étiquettes' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsUUID('4', { each: true })
  tagIds?: string[];
}

export class UpdateTaskDto extends PartialType(CreateTaskDto) {}

export class FindTasksDto extends PaginationDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  departmentId?: string;

  @ApiPropertyOptional({ description: 'Tâches assignées à ce membre' })
  @IsOptional()
  @IsUUID('4')
  assigneeId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  projectId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  tagId?: string;

  @ApiPropertyOptional({ enum: TaskStatus })
  @IsOptional()
  @IsEnum(TaskStatus)
  status?: TaskStatus;

  @ApiPropertyOptional({ enum: TaskPriority })
  @IsOptional()
  @IsEnum(TaskPriority)
  priority?: TaskPriority;

  @ApiPropertyOptional({ description: 'Uniquement les tâches en retard' })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  overdue?: boolean;

  @ApiPropertyOptional({
    default: false,
    description: 'Inclut les tâches archivées, exclues par défaut',
  })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  includeArchived?: boolean;

  @ApiPropertyOptional({ example: '2026-08-01' })
  @IsOptional()
  @IsDateString()
  dueFrom?: string;

  @ApiPropertyOptional({ example: '2026-08-31' })
  @IsOptional()
  @IsDateString()
  dueTo?: string;
}

export class AssignTaskDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Au moins un membre doit être assigné.' })
  @ArrayMaxSize(50)
  @IsUUID('4', { each: true })
  memberIds!: string[];
}

export class SetTaskTagsDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayMaxSize(20)
  @IsUUID('4', { each: true })
  tagIds!: string[];
}

// =============================================================================
// PROJETS
// =============================================================================

export class CreateProjectDto {
  @ApiProperty({ example: 'Rénovation de la salle principale' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le titre du projet est requis.' })
  @MaxLength(255)
  title!: string;

  @ApiProperty()
  @IsUUID('4', { message: 'Identifiant de département invalide.' })
  departmentId!: string;

  @ApiPropertyOptional({ description: 'Responsable du projet' })
  @IsOptional()
  @Transform(emptyToNull)
  @IsUUID('4')
  personInChargeId?: string | null;

  @ApiPropertyOptional({ example: '2026-12-31' })
  @IsOptional()
  @IsDateString()
  endDate?: string | null;

  @ApiPropertyOptional({ enum: TaskPriority, default: TaskPriority.medium })
  @IsOptional()
  @IsEnum(TaskPriority)
  priority?: TaskPriority;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(2000)
  description?: string | null;
}

export class UpdateProjectDto extends PartialType(CreateProjectDto) {}

// =============================================================================
// ÉTIQUETTES
// =============================================================================

export class CreateTagDto {
  @ApiProperty({ example: 'Urgent' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: "Le nom de l'étiquette est requis." })
  @MaxLength(50)
  name!: string;

  @ApiProperty()
  @IsUUID('4', { message: 'Identifiant de département invalide.' })
  departmentId!: string;

  @ApiPropertyOptional({ example: '#E53935', description: 'Couleur au format hexadécimal' })
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(20)
  color?: string | null;
}

export class UpdateTagDto extends PartialType(CreateTagDto) {}

// =============================================================================
// PÉNALITÉS
// =============================================================================

export class RecordPaymentDto {
  @ApiProperty({ example: 1500, description: 'Montant versé, en francs' })
  @Type(() => Number)
  @IsInt({ message: 'Le montant doit être un entier.' })
  @Min(1, { message: 'Le montant doit être supérieur à zéro.' })
  amount!: number;

  @ApiPropertyOptional({ description: 'Note libre sur le versement' })
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(500)
  note?: string | null;
}

export class UpdatePenaltySettingsDto {
  @ApiPropertyOptional({
    description: 'Montant journalier appliqué à défaut, en francs',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  defaultDailyPenaltyAmount?: number;

  @ApiPropertyOptional({
    description:
      "Solde à partir duquel un membre ne peut plus recevoir de tâche",
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  blockingThresholdAmount?: number;

  @ApiPropertyOptional({
    description: 'Délai accordé aux tâches de montage après un enseignement',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  teachingTaskDueOffsetDays?: number;
}

export class RunPenaltiesDto {
  @ApiPropertyOptional({
    example: '2026-08-03',
    description:
      'Date de calcul. Par défaut aujourd\'hui. Permet de rattraper une ' +
      'journée manquée.',
  })
  @IsOptional()
  @IsDateString()
  date?: string;
}

// =============================================================================
// RAPPELS
// =============================================================================

export class RemindPendingDto {
  @ApiPropertyOptional({
    description:
      'Restreint le rappel a un departement. Absent, toutes les taches en ' +
      'attente sont concernees.',
  })
  @IsOptional()
  @Transform(emptyToNull)
  @IsUUID('4', { message: 'Identifiant de departement invalide.' })
  departmentId?: string;
}