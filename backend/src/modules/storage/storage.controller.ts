import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';

import { StorageService } from './storage.service';

@ApiTags('storage')
@ApiBearerAuth('access-token')
@Controller('storage')
export class StorageController {
  constructor(private readonly storage: StorageService) {}

  /**
   * Envoie un fichier.
   *
   * [folder] range le fichier par domaine : `members/photos`,
   * `departments/<id>`. Le chemin est nettoye cote serveur.
   */
  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
        folder: { type: 'string', example: 'members/photos' },
      },
    },
  })
  @ApiOperation({
    summary: 'Envoie un fichier',
    description:
      'Dix megaoctets maximum. Types acceptes : images, PDF, documents ' +
      'bureautiques. Le nom d origine n est jamais reutilise : un identifiant ' +
      'aleatoire est genere, seule l extension est conservee.',
  })
  upload(
    @UploadedFile() file: Express.Multer.File,
    @Query('folder') folder?: string,
  ) {
    return this.storage.upload(file, folder ?? 'divers');
  }

  /**
   * URL de lecture d un fichier.
   *
   * Renvoie une URL publique si le bucket l autorise, signee et temporaire
   * sinon. Utile quand seule la cle est connue — celle stockee en base.
   */
  @Get('url')
  @ApiOperation({ summary: 'URL de lecture d un fichier' })
  async getUrl(
    @Query('key') key: string,
    @Query('expiresIn') expiresIn?: string,
  ) {
    const ttl = expiresIn ? Number.parseInt(expiresIn, 10) : undefined;

    return {
      key,
      url: ttl
        ? await this.storage.createSignedUrl(key, ttl)
        : await this.storage.resolveUrl(key),
    };
  }

  /**
   * Supprime un fichier.
   *
   * L absence du fichier n est pas une erreur : le resultat voulu est atteint.
   */
  @Delete()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Supprime un fichier' })
  async remove(@Query('key') key: string) {
    const removed = await this.storage.remove(key);

    return {
      message: removed ? 'Fichier supprime.' : 'Fichier deja absent.',
      removed,
    };
  }

  /** Supprime plusieurs fichiers en un appel. */
  @Post('delete-many')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Supprime plusieurs fichiers' })
  async removeMany(@Body() body: { keys: string[] }) {
    const removed = await this.storage.removeMany(body.keys ?? []);
    return { message: `${removed} fichier(s) supprime(s).`, removed };
  }
}