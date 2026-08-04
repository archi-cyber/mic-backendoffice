import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { AttendanceStatus } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  ValidateIf,
  ValidateNested,
} from 'class-validator';

import { PaginationDto } from '../../../common/dto/pagination.dto';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

const emptyToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' && value.trim() === '' ? null : value;

// =============================================================================

export class CreateEventDto {
  @ApiProperty({ example: 'Convention annuelle' })
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Le titre est requis.' })
  @MaxLength(255)
  title!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(2000)
  description?: string | null;

  @ApiProperty({ example: '2026-12-25' })
  @IsDateString({}, { message: 'La date doit etre au format AAAA-MM-JJ.' })
  eventDate!: string;

  @ApiPropertyOptional({ example: '18:30' })
  @IsOptional()
  @Transform(emptyToNull)
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, {
    message: 'L heure doit etre au format HH:MM.',
  })
  eventTime?: string | null;

  @ApiPropertyOptional({ example: 'Salle principale' })
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(255)
  location?: string | null;

  @ApiPropertyOptional({ default: false, description: 'Evenement recurrent' })
  @IsOptional()
  @IsBoolean()
  isRepeated?: boolean;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class UpdateEventDto extends PartialType(CreateEventDto) {}

export class FindEventsDto extends PaginationDto {
  @ApiPropertyOptional({ example: '2026-01-01' })
  @IsOptional()
  @IsDateString()
  from?: string;

  @ApiPropertyOptional({ example: '2026-12-31' })
  @IsOptional()
  @IsDateString()
  to?: string;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  isActive?: boolean;

  @ApiPropertyOptional({ description: 'Uniquement les evenements a venir' })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  upcoming?: boolean;
}

// =============================================================================

export class CreateEventSessionDto {
  @ApiProperty({ example: '2026-12-25T18:30:00Z' })
  @IsDateString()
  sessionDate!: string;
}

// =============================================================================

/**
 * Inscription a un evenement.
 *
 * Soit un membre, soit un invite externe — jamais les deux. La contrainte
 * existe en base ; la verifier ici produit un message intelligible.
 */
export class RegisterToEventDto {
  @ApiPropertyOptional({ description: 'Membre inscrit' })
  @ValidateIf((dto: RegisterToEventDto) => !dto.guestName)
  @IsOptional()
  @Transform(emptyToNull)
  @IsUUID('4')
  memberId?: string | null;

  @ApiPropertyOptional({ description: 'Nom de l invite externe' })
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(150)
  guestName?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsEmail({}, { message: 'Adresse e-mail invalide.' })
  guestEmail?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(30)
  guestPhone?: string | null;
}

export class RegisterMembersDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @IsUUID('4', { each: true })
  memberIds!: string[];
}

// =============================================================================

export class EventAttendanceEntryDto {
  @ApiProperty()
  @IsUUID('4')
  memberId!: string;

  @ApiProperty({ enum: AttendanceStatus })
  @IsEnum(AttendanceStatus)
  status!: AttendanceStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(500)
  notes?: string | null;
}

export class MarkEventAttendanceDto {
  @ApiPropertyOptional({
    description:
      'Seance concernee. Absent pour un evenement sans decoupage en seances.',
  })
  @IsOptional()
  @Transform(emptyToNull)
  @IsUUID('4')
  sessionId?: string | null;

  @ApiProperty({ type: [EventAttendanceEntryDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(1000)
  @ValidateNested({ each: true })
  @Type(() => EventAttendanceEntryDto)
  entries!: EventAttendanceEntryDto[];
}