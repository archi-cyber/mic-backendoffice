import { Global, Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { MailService } from './mail.service';

/**
 * Envoi d'e-mails.
 *
 * Marqué @Global : AuthModule et UsersModule en dépendent, et d'autres
 * suivront. Comme PrismaModule et RealtimeModule, c'est une préoccupation
 * transversale.
 */
@Global()
@Module({
  imports: [ConfigModule],
  providers: [MailService],
  exports: [MailService],
})
export class MailModule {}