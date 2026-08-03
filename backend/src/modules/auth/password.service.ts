import { Injectable, Logger } from '@nestjs/common';
import * as argon2 from 'argon2';

/**
 * Hachage et vérification des mots de passe.
 *
 * Argon2id est retenu plutôt que bcrypt : il résiste aux attaques par
 * matériel dédié (GPU, ASIC) grâce à son coût mémoire, là où bcrypt ne
 * contraint que le processeur. C'est la recommandation actuelle de l'OWASP.
 */
@Injectable()
export class PasswordService {
  private readonly logger = new Logger(PasswordService.name);

  /**
   * Paramètres alignés sur les recommandations OWASP 2024.
   *
   * 19 Mio de mémoire et 2 itérations placent le coût d'un hachage autour de
   * 50 ms sur un serveur courant — imperceptible à la connexion, mais
   * suffisant pour rendre une attaque par dictionnaire non rentable.
   */
  private static readonly OPTIONS: argon2.Options = {
    type: argon2.argon2id,
    memoryCost: 19_456,
    timeCost: 2,
    parallelism: 1,
  };

  /**
   * Hachage factice, utilisé quand l'adresse e-mail est inconnue.
   *
   * Sans lui, une connexion avec un e-mail inexistant répondrait
   * instantanément, tandis qu'un e-mail valide prendrait 50 ms. Cet écart
   * mesurable permettrait d'énumérer les comptes existants. On vérifie donc
   * toujours un hachage, réel ou non.
   */
  private dummyHash: string | null = null;

  async hash(plainPassword: string): Promise<string> {
    return argon2.hash(plainPassword, PasswordService.OPTIONS);
  }

  async verify(hash: string, plainPassword: string): Promise<boolean> {
    try {
      return await argon2.verify(hash, plainPassword);
    } catch (error) {
      // Un hachage corrompu ou d'un autre format ne doit pas faire échouer la
      // requête : on refuse simplement l'authentification.
      this.logger.warn(
        `Vérification impossible : ${error instanceof Error ? error.message : 'format inattendu'}`,
      );
      return false;
    }
  }

  /**
   * Consomme le même temps qu'une vérification réelle, sans en être une.
   */
  async verifyDummy(plainPassword: string): Promise<void> {
    this.dummyHash ??= await this.hash('mot-de-passe-inexistant');
    await this.verify(this.dummyHash, plainPassword);
  }

  /**
   * Signale qu'un hachage a été produit avec des paramètres obsolètes.
   *
   * Permet de renforcer progressivement la sécurité : lors d'une connexion
   * réussie, un hachage ancien peut être régénéré de façon transparente.
   */
  needsRehash(hash: string): boolean {
    try {
      return argon2.needsRehash(hash, PasswordService.OPTIONS);
    } catch {
      return true;
    }
  }
}