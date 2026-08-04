import { Global, Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';

import { PushService } from './push.service';
import { RealtimeGateway } from './realtime.gateway';
import { RealtimeService } from './realtime.service';

/**
 * Temps reel et notifications push.
 *
 * Marque @Global : RealtimeService et PushService sont appeles depuis presque
 * tous les modules metier. Les importer un par un obligerait a modifier une
 * quinzaine de fichiers, et creerait des dependances croisees difficiles a
 * suivre.
 *
 * C est la seconde exception a la regle « pas de module global », apres
 * PrismaModule, et pour la meme raison : une preoccupation transversale.
 */
@Global()
@Module({
  imports: [ConfigModule, JwtModule.register({})],
  providers: [RealtimeGateway, RealtimeService, PushService],
  exports: [RealtimeService, PushService],
})
export class RealtimeModule {}