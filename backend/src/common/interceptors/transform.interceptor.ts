import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import type { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

export interface ApiResponse<T> {
  data: T;
  meta?: PaginationMeta;
}

/**
 * Marqueur permettant à un service de renvoyer des données paginées.
 *
 * Un service retourne `{ data, meta }`, l'intercepteur reconnaît la forme et
 * la laisse intacte. Toute autre valeur est enveloppée dans `{ data }`.
 */
export interface PaginatedResult<T> {
  data: T[];
  meta: PaginationMeta;
}

const isPaginated = <T>(value: unknown): value is PaginatedResult<T> =>
  typeof value === 'object' &&
  value !== null &&
  'data' in value &&
  'meta' in value &&
  Array.isArray((value as PaginatedResult<T>).data);

/**
 * Enveloppe uniforme des réponses.
 *
 * Toute réponse prend la forme `{ data: ... }`, éventuellement accompagnée de
 * `meta` pour la pagination. Cette régularité simplifie nettement le client
 * Flutter : un seul type générique `ApiResponse<T>` suffit pour désérialiser
 * l'ensemble des endpoints, au lieu d'un traitement au cas par cas.
 */
@Injectable()
export class TransformInterceptor<T>
  implements NestInterceptor<T, ApiResponse<T>>
{
  intercept(
    context: ExecutionContext,
    next: CallHandler<T>,
  ): Observable<ApiResponse<T>> {
    return next.handle().pipe(
      map((payload) => {
        // La sonde de santé doit rester exploitable telle quelle par Railway,
        // qui attend un objet plat et non une enveloppe.
        const path = context.switchToHttp().getRequest<{ url: string }>().url;
        if (path.startsWith('/health')) {
          return payload as unknown as ApiResponse<T>;
        }

        if (isPaginated<T>(payload)) {
          return payload as unknown as ApiResponse<T>;
        }

        return { data: payload };
      }),
    );
  }
}