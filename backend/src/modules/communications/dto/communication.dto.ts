import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  ValidateIf,
} from 'class-validator';

import { PaginationDto } from '../../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

const emptyToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' && value.trim() === '' ? null : value;

// =============================================================================
// ANNONCES
// =============================================================================

export class CreateAnnouncementDto {
  @ApiProperty({ example: 'Changement d horaire' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le titre est requis.' })
  @MaxLength(255)
  title!: string;

  @ApiProperty({ example: 'Le culte de dimanche commencera a 9 h.' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le message est requis.' })
  @MaxLength(5000)
  message!: string;

  @ApiPropertyOptional({
    default: true,
    description:
      'Annonce visible de tous. Si false, precisez un departement ou une ' +
      'liste de membres.',
  })
  @IsOptional()
  @IsBoolean()
  isGlobal?: boolean;

  @ApiPropertyOptional({ description: 'Annonce reservee a un departement' })
  @IsOptional()
  @Transform(emptyToNull)
  @IsUUID('4', { message: 'Identifiant de departement invalide.' })
  departmentId?: string | null;

  @ApiPropertyOptional({
    type: [String],
    description: 'Membres destinataires, pour une annonce ciblee',
  })
  // La liste n est exigee que si l annonce n est ni globale ni departementale.
  @ValidateIf(
    (dto: CreateAnnouncementDto) =>
      dto.isGlobal === false && !dto.departmentId,
  )
  @IsArray()
  @ArrayMinSize(1, {
    message:
      'Une annonce non globale doit viser un departement ou des membres.',
  })
  @ArrayMaxSize(1000)
  @IsUUID('4', { each: true })
  @IsOptional()
  targetMemberIds?: string[];
}

export class UpdateAnnouncementDto extends PartialType(CreateAnnouncementDto) {}

export class FindAnnouncementsDto extends PaginationDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID('4')
  departmentId?: string;

  @ApiPropertyOptional({ description: 'Uniquement les annonces globales' })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  isGlobal?: boolean;
}

// =============================================================================
// NOTIFICATIONS
// =============================================================================

export class FindNotificationsDto extends PaginationDto {
  @ApiPropertyOptional({ description: 'Filtre sur les notifications non lues' })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  isRead?: boolean;

  @ApiPropertyOptional({ example: 'task_assigned' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  type?: string;
}

export class MarkNotificationsReadDto {
  @ApiPropertyOptional({
    type: [String],
    description:
      'Notifications a marquer comme lues. Omettre pour tout marquer.',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(500)
  @IsUUID('4', { each: true })
  notificationIds?: string[];
}