import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { Request, Response } from 'express';

import type { ApiErrorResponse } from './all-exceptions.filter';

/**
 * Traduction des erreurs Prisma en réponses HTTP.
 *
 * Sans ce filtre, une violation de contrainte d'unicité produirait une 500 —
 * alors qu'il s'agit d'une erreur du client, à laquelle il peut réagir. Le
 * message technique de Prisma est également remplacé par un texte
 * compréhensible, car il expose sinon les noms de colonnes et de contraintes
 * de la base.
 */
@Catch(
  Prisma.PrismaClientKnownRequestError,
  Prisma.PrismaClientValidationError,
  Prisma.PrismaClientInitializationError,
)
export class PrismaExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(PrismaExceptionFilter.name);

  catch(
    exception:
      | Prisma.PrismaClientKnownRequestError
      | Prisma.PrismaClientValidationError
      | Prisma.PrismaClientInitializationError,
    host: ArgumentsHost,
  ): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const { status, message, code } = this.translate(exception);

    this.logger.error(
      `${request.method} ${request.url} → Prisma ${code} : ${exception.message.split('\n').pop()}`,
    );

    const body: ApiErrorResponse = {
      statusCode: status,
      error: HttpStatus[status] ?? 'Error',
      message,
      code,
      timestamp: new Date().toISOString(),
      path: request.url,
    };

    response.status(status).json(body);
  }

  private translate(exception: Error): {
    status: number;
    message: string;
    code: string;
  } {
    if (exception instanceof Prisma.PrismaClientInitializationError) {
      return {
        status: HttpStatus.SERVICE_UNAVAILABLE,
        message: 'La base de données est momentanément indisponible.',
        code: 'DATABASE_UNAVAILABLE',
      };
    }

    if (exception instanceof Prisma.PrismaClientValidationError) {
      return {
        status: HttpStatus.BAD_REQUEST,
        message: 'Requête invalide : les données transmises sont incohérentes.',
        code: 'INVALID_QUERY',
      };
    }

    // Codes documentés : https://www.prisma.io/docs/reference/api-reference/error-reference
    const known = exception as Prisma.PrismaClientKnownRequestError;

    switch (known.code) {
      case 'P2002': {
        // Violation de contrainte d'unicité. `meta.target` liste les colonnes
        // concernées, ce qui permet un message précis.
        const fields = this.targetFields(known);
        return {
          status: HttpStatus.CONFLICT,
          message: fields.length
            ? `Une entrée existe déjà avec cette valeur pour : ${fields.join(', ')}.`
            : 'Une entrée identique existe déjà.',
          code: 'DUPLICATE_ENTRY',
        };
      }

      case 'P2003':
        return {
          status: HttpStatus.BAD_REQUEST,
          message: 'Référence invalide : l\'élément lié est introuvable.',
          code: 'FOREIGN_KEY_VIOLATION',
        };

      case 'P2025':
        return {
          status: HttpStatus.NOT_FOUND,
          message: 'L\'élément demandé est introuvable.',
          code: 'NOT_FOUND',
        };

      case 'P2014':
        return {
          status: HttpStatus.CONFLICT,
          message:
            'Cette opération romprait une relation existante entre deux enregistrements.',
          code: 'RELATION_VIOLATION',
        };

      case 'P2000':
        return {
          status: HttpStatus.BAD_REQUEST,
          message: 'Une valeur transmise dépasse la longueur autorisée.',
          code: 'VALUE_TOO_LONG',
        };

      case 'P2024':
        return {
          status: HttpStatus.SERVICE_UNAVAILABLE,
          message: 'Le serveur est momentanément saturé. Réessayez dans un instant.',
          code: 'CONNECTION_POOL_TIMEOUT',
        };

      default:
        return {
          status: HttpStatus.INTERNAL_SERVER_ERROR,
          message: 'Erreur lors de l\'accès aux données.',
          code: `PRISMA_${known.code ?? 'UNKNOWN'}`,
        };
    }
  }

  /** Extrait la liste des colonnes visées par une contrainte d'unicité. */
  private targetFields(error: Prisma.PrismaClientKnownRequestError): string[] {
    const target = error.meta?.target;

    if (Array.isArray(target)) {
      return target.map(String);
    }
    if (typeof target === 'string') {
      return [target];
    }
    return [];
  }
}