import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';

import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { PasswordService } from './password.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { TokenService } from './token.service';

/**
 * Module d'authentification.
 *
 * `JwtModule.register({})` est volontairement vide : les secrets sont fournis
 * à chaque signature par TokenService. Cela permet d'utiliser deux clés
 * distinctes — une pour les jetons d'accès, une pour les jetons de
 * rafraîchissement — là où une configuration globale n'en autoriserait qu'une.
 *
 * PasswordService et TokenService sont exportés : les modules de gestion des
 * comptes en auront besoin pour créer des utilisateurs et révoquer des
 * sessions lors d'une désactivation.
 */
@Module({
  imports: [
    ConfigModule,
    PassportModule.register({ defaultStrategy: 'jwt', session: false }),
    JwtModule.register({}),
  ],
  controllers: [AuthController],
  providers: [AuthService, PasswordService, TokenService, JwtStrategy],
  exports: [AuthService, PasswordService, TokenService],
})
export class AuthModule {}