import {
  BadRequestException,
  Injectable,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  DeleteObjectCommand,
  DeleteObjectsCommand,
  GetObjectCommand,
  HeadBucketCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'node:crypto';
import { extname } from 'node:path';

import type { AppConfig } from '../../config/configuration';

export interface StoredFile {
  key: string;
  url: string;
  fileName: string;
  size: number;
  mimeType: string;
}

/**
 * Stockage de fichiers sur S3 (Railway Bucket).
 *
 * Remplace Supabase Storage. Le stockage objet est préférable à un volume
 * attaché : les fichiers sont servis directement, plusieurs instances peuvent
 * écrire en parallèle, et la réplication est assurée par le fournisseur.
 *
 * Deux modes de lecture, selon la configuration :
 *
 *   - **URL publique** — si `S3_PUBLIC_BASE_URL` est défini, les fichiers sont
 *     accessibles directement, sans passer par le backend. C'est le mode
 *     souhaitable pour des photos de membres, chargées par dizaines sur un
 *     écran de liste.
 *   - **URL signée** — sinon, le backend génère à la demande une URL valable
 *     un temps limité. Plus sûr, mais impose un appel préalable par fichier.
 *
 * La clé stockée en base est toujours relative (`members/photos/uuid.jpg`) :
 * elle reste valide si le bucket, la région ou le domaine changent, ce qu'une
 * URL absolue ne permettrait pas sans réécrire toutes les lignes.
 */
@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);

  private client: S3Client | null = null;
  private bucket = '';
  private publicBaseUrl: string | null = null;
  private enabled = false;

  /** Taille maximale acceptée, en octets. */
  private static readonly MAX_SIZE = 10 * 1024 * 1024;

  /** Durée de validité d'une URL signée, en secondes. */
  private static readonly SIGNED_URL_TTL = 3600;

  /**
   * Types acceptés.
   *
   * Liste blanche plutôt que liste noire : autoriser explicitement ce qui est
   * attendu ferme la porte aux formats exécutables, qu'une liste noire
   * laisserait passer dès qu'une extension nouvelle apparaît.
   */
  private static readonly ALLOWED_MIME = new Set([
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/heic',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain',
    'text/csv',
  ]);

  constructor(private readonly config: ConfigService<AppConfig, true>) {}

  onModuleInit(): void {
    const endpoint = process.env.S3_ENDPOINT;
    const accessKeyId = process.env.S3_ACCESS_KEY_ID;
    const secretAccessKey = process.env.S3_SECRET_ACCESS_KEY;
    const bucket = process.env.S3_BUCKET;

    if (!endpoint || !accessKeyId || !secretAccessKey || !bucket) {
      this.logger.warn(
        'Stockage désactivé : variables S3_* incomplètes. ' +
          "L'envoi de fichiers échouera tant qu'elles ne sont pas renseignées.",
      );
      return;
    }

    this.bucket = bucket;
    this.publicBaseUrl = process.env.S3_PUBLIC_BASE_URL?.replace(/\/$/, '') ?? null;

    this.client = new S3Client({
      endpoint,
      region: process.env.S3_REGION ?? 'auto',
      credentials: { accessKeyId, secretAccessKey },
      // Indispensable hors AWS : sans cela, le SDK construit une URL de la
      // forme `https://<bucket>.<endpoint>`, que les fournisseurs compatibles
      // S3 ne reconnaissent pas.
      forcePathStyle: true,
    });

    this.enabled = true;
    this.logger.log(
      `Stockage S3 prêt : ${bucket}` +
        (this.publicBaseUrl ? ' (accès public)' : ' (URL signées)'),
    );

    void this.verifyBucket();
  }

  /**
   * Vérifie l'accès au bucket au démarrage.
   *
   * Purement informatif : un échec ne bloque pas le démarrage, mais fait
   * apparaître le problème dans les logs de déploiement plutôt qu'au premier
   * envoi de fichier par un utilisateur.
   */
  private async verifyBucket(): Promise<void> {
    try {
      await this.client!.send(new HeadBucketCommand({ Bucket: this.bucket }));
    } catch (error) {
      this.logger.warn(
        `Bucket inaccessible (${this.bucket}) : ` +
          `${error instanceof Error ? error.message : 'erreur inconnue'}. ` +
          'Vérifiez les clés et le nom du bucket.',
      );
    }
  }

  // ===========================================================================
  // Écriture
  // ===========================================================================

  /**
   * Envoie un fichier et renvoie sa clé et son URL.
   *
   * Le nom d'origine n'est jamais réutilisé : il pourrait contenir des
   * séquences de traversée, des caractères réservés, ou entrer en collision
   * avec un fichier existant. Un identifiant aléatoire est généré, seule
   * l'extension est conservée.
   */
  async upload(
    file: { buffer: Buffer; originalname: string; mimetype: string; size: number },
    folder: string,
  ): Promise<StoredFile> {
    this.assertEnabled();
    this.assertAcceptable(file);

    const safeFolder = this.sanitizeFolder(folder);
    const extension = this.safeExtension(file.originalname);
    const fileName = `${randomUUID()}${extension}`;
    const key = `${safeFolder}/${fileName}`;

    await this.client!.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: file.buffer,
        ContentType: file.mimetype,
        // Les noms contiennent un UUID et une modification produit un nouveau
        // fichier : le contenu est donc immuable, et un cache long est sans
        // risque.
        CacheControl: 'public, max-age=31536000, immutable',
      }),
    );

    this.logger.log(`Fichier envoyé : ${key} (${file.size} octets)`);

    return {
      key,
      url: await this.resolveUrl(key),
      fileName,
      size: file.size,
      mimeType: file.mimetype,
    };
  }

  // ===========================================================================
  // Lecture
  // ===========================================================================

  /**
   * URL de lecture d'un fichier.
   *
   * Publique et permanente si le bucket l'autorise, signée et temporaire
   * sinon.
   */
  async resolveUrl(key: string): Promise<string> {
    if (this.publicBaseUrl) {
      return `${this.publicBaseUrl}/${key}`;
    }
    return this.createSignedUrl(key);
  }

  /**
   * URL signée, valable une heure par défaut.
   *
   * La signature porte sur la clé et la date d'expiration : l'URL cesse de
   * fonctionner passé ce délai, même si elle a été partagée entre-temps.
   */
  async createSignedUrl(
    key: string,
    expiresIn = StorageService.SIGNED_URL_TTL,
  ): Promise<string> {
    this.assertEnabled();

    return getSignedUrl(
      this.client!,
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
      { expiresIn },
    );
  }

  // ===========================================================================
  // Suppression
  // ===========================================================================

  /**
   * Supprime un fichier.
   *
   * L'absence du fichier n'est pas une erreur : supprimer ce qui n'existe déjà
   * plus aboutit au résultat voulu, et S3 ne signale d'ailleurs pas le cas.
   */
  async remove(key: string): Promise<boolean> {
    if (!this.enabled) return false;

    try {
      await this.client!.send(
        new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
      );
      return true;
    } catch (error) {
      this.logger.warn(
        `Suppression impossible (${key}) : ` +
          `${error instanceof Error ? error.message : 'erreur inconnue'}`,
      );
      return false;
    }
  }

  /**
   * Supprime plusieurs fichiers en un appel.
   *
   * S3 accepte mille clés par requête ; la liste est découpée en conséquence.
   * Un appel par fichier serait bien plus lent sur une suppression de
   * département emportant plusieurs documents.
   */
  async removeMany(keys: string[]): Promise<number> {
    if (!this.enabled || keys.length === 0) return 0;

    let removed = 0;

    for (let i = 0; i < keys.length; i += 1000) {
      const batch = keys.slice(i, i + 1000);

      try {
        const result = await this.client!.send(
          new DeleteObjectsCommand({
            Bucket: this.bucket,
            Delete: { Objects: batch.map((Key) => ({ Key })) },
          }),
        );
        removed += result.Deleted?.length ?? 0;
      } catch (error) {
        this.logger.warn(
          `Suppression groupée partielle : ` +
            `${error instanceof Error ? error.message : 'erreur inconnue'}`,
        );
      }
    }

    return removed;
  }

  /**
   * Extrait la clé depuis une URL complète.
   *
   * Accepte les URL publiques comme les URL signées, dont la partie requête
   * est écartée.
   */
  extractKey(url: string): string | null {
    if (!url) return null;

    // Une clé relative est renvoyée telle quelle.
    if (!url.startsWith('http')) {
      return url.replace(/^\/+/, '');
    }

    try {
      const parsed = new URL(url);
      const path = parsed.pathname.replace(/^\/+/, '');

      // En mode chemin, le bucket précède la clé dans l'URL.
      return path.startsWith(`${this.bucket}/`)
        ? path.slice(this.bucket.length + 1)
        : path;
    } catch {
      return null;
    }
  }

  // ===========================================================================
  // Contrôles
  // ===========================================================================

  private assertEnabled(): void {
    if (!this.enabled) {
      throw new BadRequestException({
        message:
          "Le stockage de fichiers n'est pas configuré sur ce serveur.",
        code: 'STORAGE_NOT_CONFIGURED',
      });
    }
  }

  private assertAcceptable(file: { mimetype: string; size: number }): void {
    if (file.size > StorageService.MAX_SIZE) {
      throw new BadRequestException({
        message: `Le fichier dépasse la taille maximale de ${
          StorageService.MAX_SIZE / (1024 * 1024)
        } Mo.`,
        code: 'FILE_TOO_LARGE',
      });
    }

    if (!StorageService.ALLOWED_MIME.has(file.mimetype)) {
      throw new BadRequestException({
        message: `Type de fichier non autorisé : ${file.mimetype}.`,
        code: 'FILE_TYPE_NOT_ALLOWED',
      });
    }
  }

  /**
   * Nettoie un chemin de dossier.
   *
   * Seuls lettres, chiffres, tirets, soulignés et barres obliques sont
   * conservés. S3 n'a pas de notion de répertoire — la clé est une simple
   * chaîne — mais un nettoyage évite les clés malformées et les caractères
   * qui compliqueraient l'exploration du bucket.
   */
  private sanitizeFolder(folder: string): string {
    const cleaned = folder
      .split('/')
      .map((part) => part.replace(/[^a-zA-Z0-9_-]/g, ''))
      .filter((part) => part.length > 0)
      .join('/');

    return cleaned.length > 0 ? cleaned : 'divers';
  }

  /** Extension nettoyée, limitée à dix caractères. */
  private safeExtension(originalName: string): string {
    const extension = extname(originalName).toLowerCase();
    const cleaned = extension.replace(/[^a-z0-9.]/g, '');
    return cleaned.length > 1 && cleaned.length <= 10 ? cleaned : '';
  }
}