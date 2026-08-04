import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsOptional,
  IsUUID,
} from 'class-validator';

import { PaginationDto } from '../../../common/dto/pagination.dto';

/**
 * Marquage groupe de la presence a l ecole du dimanche.
 *
 * Seuls les enfants presents sont transmis : contrairement au culte, on ne
 * distingue pas presentiel et distanciel, et l absence se deduit de l absence
 * de ligne.
 */
export class MarkSundaySchoolDto {
  @ApiProperty({ example: '2026-08-09' })
  @IsDateString({}, { message: 'La date doit etre au format AAAA-MM-JJ.' })
  attendanceDate!: string;

  @ApiProperty({
    type: [String],
    description: 'Identifiants des enfants presents',
  })
  @IsArray()
  @ArrayMinSize(1, { message: 'Au moins un enfant doit etre selectionne.' })
  @ArrayMaxSize(500, { message: 'Cinq cents enfants au maximum par requete.' })
  @IsUUID('4', { each: true, message: 'Identifiant de membre invalide.' })
  memberIds!: string[];
}

export class FindSundaySchoolDto extends PaginationDto {
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
  @IsUUID('4')
  memberId?: string;
}

export class FindEligibleChildrenDto {
  @ApiPropertyOptional({
    default: 12,
    description:
      'Age maximum. L ecole du dimanche concerne les enfants de 0 a 12 ans.',
  })
  @IsOptional()
  @Type(() => Number)
  maxAge?: number;
}