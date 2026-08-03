import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Req,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import type { Request } from 'express';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { AuthService } from './auth.service';
import {
  ChangePasswordDto,
  ForgotPasswordDto,
  LoginDto,
  RefreshTokenDto,
  ResetPasswordDto,
} from './dto/auth.dto';
import type { SessionContext } from './token.service';
import type { AuthenticatedUser } from './types/auth.types';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  // ---------------------------------------------------------------------------
  // Routes publiques
  // ---------------------------------------------------------------------------

  @Public()
  // Limite stricte : cinq tentatives par minute et par adresse IP. C'est la
  // protection de première ligne contre les attaques par force brute, et elle
  // reste large pour un usage humain normal.
  @Throttle({ strict: { limit: 5, ttl: 60_000 } })
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Connexion par e-mail et mot de passe' })
  @ApiResponse({ status: 200, description: 'Jetons émis' })
  @ApiResponse({ status: 401, description: 'Identifiants incorrects' })
  @ApiResponse({ status: 429, description: 'Trop de tentatives' })
  login(@Body() dto: LoginDto, @Req() request: Request) {
    return this.auth.login(
      dto.email,
      dto.password,
      this.sessionContext(request, dto.deviceInfo),
    );
  }

  @Public()
  @Throttle({ strict: { limit: 20, ttl: 60_000 } })
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Renouvelle le couple de jetons',
    description:
      "L'ancien jeton de rafraîchissement est révoqué dans le même mouvement : " +
      'il ne peut servir qu\'une fois.',
  })
  refresh(@Body() dto: RefreshTokenDto, @Req() request: Request) {
    return this.auth.refresh(dto.refreshToken, this.sessionContext(request));
  }

  @Public()
  @Throttle({ strict: { limit: 3, ttl: 300_000 } })
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Demande un jeton de réinitialisation',
    description:
      "La réponse est identique que l'adresse existe ou non, afin de ne pas " +
      'révéler quels comptes sont enregistrés.',
  })
  forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.auth.requestPasswordReset(dto.email);
  }

  @Public()
  @Throttle({ strict: { limit: 5, ttl: 300_000 } })
  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Définit un nouveau mot de passe via un jeton' })
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto.email, dto.token, dto.newPassword);
  }

  // ---------------------------------------------------------------------------
  // Routes authentifiées
  // ---------------------------------------------------------------------------

  @ApiBearerAuth('access-token')
  @Get('me')
  @ApiOperation({
    summary: 'Profil de l\'utilisateur connecté',
    description:
      'Renvoie le rôle, la fiche membre, les appartenances départementales et ' +
      'les permissions granulaires.',
  })
  getProfile(@CurrentUser() user: AuthenticatedUser) {
    return this.auth.getProfile(user);
  }

  @ApiBearerAuth('access-token')
  @Post('change-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Change le mot de passe',
    description:
      'Ferme toutes les sessions ouvertes : une reconnexion est nécessaire ensuite.',
  })
  changePassword(
    @CurrentUser('id') userId: string,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.auth.changePassword(userId, dto.currentPassword, dto.newPassword);
  }

  @ApiBearerAuth('access-token')
  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Ferme la session courante' })
  logout(@Body() dto: RefreshTokenDto) {
    return this.auth.logout(dto.refreshToken);
  }

  @ApiBearerAuth('access-token')
  @Delete('sessions')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Ferme toutes les sessions',
    description: 'Utile en cas de perte ou de vol d\'un appareil.',
  })
  logoutAll(@CurrentUser('id') userId: string) {
    return this.auth.logoutAll(userId);
  }

  @ApiBearerAuth('access-token')
  @Get('sessions')
  @ApiOperation({ summary: 'Liste les appareils connectés' })
  listSessions(@CurrentUser('id') userId: string) {
    return this.auth.listSessions(userId);
  }

  // ---------------------------------------------------------------------------

  /**
   * Rassemble les informations de traçabilité de la session.
   *
   * `x-forwarded-for` est privilégié : derrière le proxy Railway, l'adresse
   * vue par Express est celle de l'infrastructure, pas celle du client.
   */
  private sessionContext(request: Request, deviceInfo?: string): SessionContext {
    const forwarded = request.headers['x-forwarded-for'];
    const ipAddress =
      (Array.isArray(forwarded) ? forwarded[0] : forwarded)?.split(',')[0]?.trim() ??
      request.ip;

    return {
      deviceInfo: deviceInfo ?? request.headers['user-agent'],
      ipAddress,
    };
  }
}