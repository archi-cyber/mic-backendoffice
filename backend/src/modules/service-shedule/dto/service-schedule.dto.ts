import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ServiceScheduleRole } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const emptyToNull = ({ value }: { value: unknown }) =>
  typeof value === 'string' && value.trim() === '' ? null : value;

export class CreateScheduleDto {
  @ApiProperty()
  @IsUUID('4', { message: 'Identifiant de departement invalide.' })
  departmentId!: string;

  @ApiProperty({ example: '2026-08-09' })
  @IsDateString({}, { message: 'La date doit etre au format AAAA-MM-JJ.' })
  serviceDate!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(1000)
  notes?: string | null;
}

export class UpdateScheduleDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Transform(emptyToNull)
  @IsString()
  @MaxLength(1000)
  notes?: string | null;

  @ApiPropertyOptional({ example: '2026-08-16' })
  @IsOptional()
  @IsDateString()
  serviceDate?: string;
}

export class FindSchedulesDto {
  @ApiProperty()
  @IsUUID('4')
  departmentId!: string;

  @ApiPropertyOptional({ default: 200 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(500)
  limit?: number;

  @ApiPropertyOptional({ example: '2026-01-01' })
  @IsOptional()
  @IsDateString()
  from?: string;

  @ApiPropertyOptional({ example: '2026-12-31' })
  @IsOptional()
  @IsDateString()
  to?: string;
}

export class AddAssignmentDto {
  @ApiProperty({
    enum: ServiceScheduleRole,
    description: 'Poste attribue pour ce service',
  })
  @IsEnum(ServiceScheduleRole, { message: 'Poste inconnu.' })
  role!: ServiceScheduleRole;

  @ApiProperty()
  @IsUUID('4', { message: 'Identifiant de membre invalide.' })
  memberId!: string;
}

export class SetAssignmentDoneDto {
  @ApiProperty()
  @IsBoolean()
  isDone!: boolean;
}