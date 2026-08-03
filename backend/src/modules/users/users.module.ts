import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

/**
 * Gestion des comptes.
 *
 * AuthModule est importe pour PasswordService (hachage du mot de passe
 * initial) et TokenService (revocation des sessions lors d une desactivation).
 */
@Module({
  imports: [AuthModule],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}