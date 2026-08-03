import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import { IsEnum, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export enum SortOrder {
  asc = 'asc',
  desc = 'desc',
}

/**
 * Paramètres de pagination communs à toutes les listes.
 *
 * Hérité par les DTO de filtrage spécifiques :
 *   export class FindMembersDto extends PaginationDto { ... }
 */
export class PaginationDto {
  @ApiPropertyOptional({ minimum: 1, default: 1, description: 'Numéro de page' })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: 'page doit être un entier' })
  @Min(1, { message: 'page doit être supérieur ou égal à 1' })
  page: number = 1;

  @ApiPropertyOptional({
    minimum: 1,
    maximum: 200,
    default: 20,
    description: 'Nombre d\'éléments par page',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt({ message: 'limit doit être un entier' })
  @Min(1)
  // Plafond volontaire : sans limite haute, un client pourrait demander
  // 100 000 lignes et saturer la mémoire du serveur comme celle de l'appareil.
  @Max(200, { message: 'limit ne peut pas dépasser 200' })
  limit: number = 20;

  @ApiPropertyOptional({ description: 'Champ de tri' })
  @IsOptional()
  @IsString()
  orderBy?: string;

  @ApiPropertyOptional({ enum: SortOrder, default: SortOrder.desc })
  @IsOptional()
  @IsEnum(SortOrder)
  order: SortOrder = SortOrder.desc;

  @ApiPropertyOptional({ description: 'Recherche textuelle libre' })
  @IsOptional()
  @IsString()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  search?: string;

  /** Décalage calculé pour Prisma (`skip`). */
  get skip(): number {
    return (this.page - 1) * this.limit;
  }

  /** Nombre d'éléments demandés (`take`). */
  get take(): number {
    return this.limit;
  }
}

/**
 * Construit le bloc `meta` attendu par le client.
 */
export const buildPaginationMeta = (
  total: number,
  page: number,
  limit: number,
) => ({
  page,
  limit,
  total,
  totalPages: Math.max(1, Math.ceil(total / limit)),
});