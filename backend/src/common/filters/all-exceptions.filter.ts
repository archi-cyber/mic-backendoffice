import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Request, Response } from 'express';

/**
 * Structure d'erreur renvoyée au client Flutter.
 *
 * Le champ `code` est le point important : il est stable et lisible par
 * machine. Le client peut ainsi afficher un message traduit en français,
 * anglais ou espagnol sans analyser le texte anglais de `message`, qui reste
 * destiné aux développeurs et aux journaux.
 */
export interface ApiErrorResponse {
  statusCode: number;
  error: string;
  message: string | string[];
  code: string;
  timestamp: string;
  path: string;
}

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const { status, message, error, code } = this.parse(exception);

    // Les erreurs serveur méritent une trace complète ; les erreurs client
    // (400-499) sont attendues et n'encombrent les logs qu'en niveau debug.
    if (status >= HttpStatus.INTERNAL_SERVER_ERROR) {
      this.logger.error(
        `${request.method} ${request.url} → ${status} : ${JSON.stringify(message)}`,
        exception instanceof Error ? exception.stack : undefined,
      );
    } else {
      this.logger.debug(
        `${request.method} ${request.url} → ${status} : ${JSON.stringify(message)}`,
      );
    }

    const body: ApiErrorResponse = {
      statusCode: status,
      error,
      message,
      code,
      timestamp: new Date().toISOString(),
      path: request.url,
    };

    response.status(status).json(body);
  }

  private parse(exception: unknown): {
    status: number;
    message: string | string[];
    error: string;
    code: string;
  } {
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const payload = exception.getResponse();

      // Les erreurs de ValidationPipe arrivent sous forme d'objet contenant un
      // tableau `message` : on le conserve tel quel pour que le client puisse
      // signaler précisément quel champ est en cause.
      if (typeof payload === 'object' && payload !== null) {
        const record = payload as Record<string, unknown>;
        return {
          status,
          message: (record.message as string | string[]) ?? exception.message,
          error: (record.error as string) ?? this.statusText(status),
          code: (record.code as string) ?? this.defaultCode(status),
        };
      }

      return {
        status,
        message: String(payload),
        error: this.statusText(status),
        code: this.defaultCode(status),
      };
    }

    // Toute exception non maîtrisée devient une 500 générique. Le message réel
    // part dans les journaux, jamais dans la réponse : une trace de pile
    // exposée renseignerait un attaquant sur la structure interne.
    return {
      status: HttpStatus.INTERNAL_SERVER_ERROR,
      message: 'Une erreur interne est survenue.',
      error: 'Internal Server Error',
      code: 'INTERNAL_ERROR',
    };
  }

  private statusText(status: number): string {
    return (
      {
        400: 'Bad Request',
        401: 'Unauthorized',
        403: 'Forbidden',
        404: 'Not Found',
        409: 'Conflict',
        422: 'Unprocessable Entity',
        429: 'Too Many Requests',
      }[status] ?? 'Error'
    );
  }

  private defaultCode(status: number): string {
    return (
      {
        400: 'VALIDATION_ERROR',
        401: 'UNAUTHORIZED',
        403: 'FORBIDDEN',
        404: 'NOT_FOUND',
        409: 'CONFLICT',
        422: 'UNPROCESSABLE',
        429: 'RATE_LIMITED',
      }[status] ?? 'INTERNAL_ERROR'
    );
  }
}