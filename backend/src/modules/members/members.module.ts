import { Module } from '@nestjs/common';

import { MembersController } from './members.controller';
import { MembersService } from './members.service';

/**
 * Module des membres.
 *
 * MembersService est exporte : le module de presence aux cultes l appellera
 * apres chaque enregistrement pour declencher la graduation eventuelle des
 * nouveaux venus.
 */
@Module({
  controllers: [MembersController],
  providers: [MembersService],
  exports: [MembersService],
})
export class MembersModule {}