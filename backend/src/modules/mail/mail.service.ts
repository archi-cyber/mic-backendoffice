import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import type { AppConfig } from '../../config/configuration';

export interface MailMessage {
  to: string;
  subject: string;
  html: string;
  text?: string;
}

/**
 * Envoi d'e-mails transactionnels.
 *
 * Resend est retenu : configuration en une clé d'API, pas de serveur SMTP à
 * maintenir, et un quota gratuit suffisant pour une église (100 messages par
 * jour). Le fournisseur reste interchangeable — seul `deliver` connaît son API.
 *
 * Entièrement optionnel. Sans `MAIL_API_KEY`, le service se désactive et
 * journalise le contenu qui aurait été envoyé. C'est délibéré : en
 * développement, on veut voir le jeton de réinitialisation sans configurer un
 * fournisseur, et l'application ne doit pas refuser de démarrer parce qu'une
 * clé manque.
 */
@Injectable()
export class MailService implements OnModuleInit {
  private readonly logger = new Logger(MailService.name);

  private apiKey: string | null = null;
  private fromAddress = '';
  private appUrl = '';
  private enabled = false;

  constructor(private readonly config: ConfigService<AppConfig, true>) {}

  onModuleInit(): void {
    this.apiKey = process.env.MAIL_API_KEY ?? null;
    this.fromAddress =
      process.env.MAIL_FROM ?? 'SysteMIC <onboarding@resend.dev>';
    this.appUrl = process.env.APP_PUBLIC_URL ?? 'http://localhost:3000';

    this.enabled = Boolean(this.apiKey);

    if (this.enabled) {
      this.logger.log(`Envoi d'e-mails activé — expéditeur : ${this.fromAddress}`);
    } else {
      this.logger.warn(
        "Envoi d'e-mails désactivé : MAIL_API_KEY absente. " +
          'Les messages seront journalisés au lieu d\'être envoyés.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Messages métier
  // ---------------------------------------------------------------------------

  /**
   * Envoie le jeton de réinitialisation de mot de passe.
   *
   * Le jeton est valable une heure. Il figure en clair dans le message : c'est
   * inévitable, puisque c'est précisément ce que l'utilisateur doit recevoir.
   * Sa durée de vie courte limite la portée d'une boîte compromise.
   */
  async sendPasswordReset(params: {
    to: string;
    firstName: string | null;
    token: string;
  }): Promise<boolean> {
    const greeting = params.firstName ? `Bonjour ${params.firstName},` : 'Bonjour,';

    return this.deliver({
      to: params.to,
      subject: 'Réinitialisation de votre mot de passe — SysteMIC',
      html: this.wrap(`
        <p>${greeting}</p>
        <p>Vous avez demandé la réinitialisation de votre mot de passe.
           Saisissez le code ci-dessous dans l'application :</p>
        <div style="background:#f4f4f5;border-radius:8px;padding:20px;
                    margin:24px 0;text-align:center;">
          <code style="font-size:20px;font-weight:600;letter-spacing:1px;
                       word-break:break-all;">${params.token}</code>
        </div>
        <p><strong>Ce code expire dans une heure.</strong></p>
        <p style="color:#71717a;font-size:14px;">
          Si vous n'êtes pas à l'origine de cette demande, ignorez ce message :
          votre mot de passe reste inchangé.
        </p>
      `),
      text:
        `${greeting}\n\n` +
        `Code de réinitialisation : ${params.token}\n\n` +
        `Ce code expire dans une heure.\n\n` +
        `Si vous n'êtes pas à l'origine de cette demande, ignorez ce message.`,
    });
  }

  /**
   * Annonce la création d'un compte.
   *
   * Le mot de passe provisoire est transmis ici. Il doit être changé à la
   * première connexion — le serveur l'impose.
   */
  async sendAccountCreated(params: {
    to: string;
    firstName: string | null;
    temporaryPassword: string;
  }): Promise<boolean> {
    const greeting = params.firstName ? `Bonjour ${params.firstName},` : 'Bonjour,';

    return this.deliver({
      to: params.to,
      subject: 'Votre compte SysteMIC est prêt',
      html: this.wrap(`
        <p>${greeting}</p>
        <p>Un compte vous a été créé sur SysteMIC, l'application de gestion de
           votre église.</p>
        <table style="margin:24px 0;border-collapse:collapse;">
          <tr>
            <td style="padding:8px 16px 8px 0;color:#71717a;">Identifiant</td>
            <td style="padding:8px 0;font-weight:600;">${params.to}</td>
          </tr>
          <tr>
            <td style="padding:8px 16px 8px 0;color:#71717a;">Mot de passe</td>
            <td style="padding:8px 0;">
              <code style="font-weight:600;">${params.temporaryPassword}</code>
            </td>
          </tr>
        </table>
        <p><strong>Vous devrez choisir un nouveau mot de passe dès votre
           première connexion.</strong></p>
      `),
      text:
        `${greeting}\n\n` +
        `Un compte vous a été créé sur SysteMIC.\n\n` +
        `Identifiant : ${params.to}\n` +
        `Mot de passe provisoire : ${params.temporaryPassword}\n\n` +
        `Vous devrez le changer à la première connexion.`,
    });
  }

  // ---------------------------------------------------------------------------
  // Envoi
  // ---------------------------------------------------------------------------

  /**
   * Transmet le message au fournisseur.
   *
   * Ne lève jamais : un échec d'envoi ne doit pas faire échouer l'opération
   * qui l'a déclenché. Créer un compte reste utile même si l'e-mail de
   * bienvenue n'est pas parti — l'administrateur peut transmettre les
   * identifiants autrement.
   */
  private async deliver(message: MailMessage): Promise<boolean> {
    if (!this.enabled) {
      this.logger.debug(
        `[E-mail non envoyé] À : ${message.to} — ${message.subject}\n` +
          (message.text ?? ''),
      );
      return false;
    }

    try {
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: this.fromAddress,
          to: [message.to],
          subject: message.subject,
          html: message.html,
          text: message.text,
        }),
      });

      if (!response.ok) {
        const detail = await response.text();
        this.logger.warn(
          `Envoi refusé (${response.status}) vers ${message.to} : ${detail}`,
        );
        return false;
      }

      this.logger.log(`E-mail envoyé à ${message.to} — ${message.subject}`);
      return true;
    } catch (error) {
      this.logger.warn(
        `Envoi impossible vers ${message.to} : ` +
          `${error instanceof Error ? error.message : 'erreur inconnue'}`,
      );
      return false;
    }
  }

  /**
   * Gabarit HTML commun.
   *
   * Styles en ligne uniquement : les clients de messagerie ignorent
   * massivement les feuilles de style externes, et Gmail supprime même les
   * balises `<style>` dans certains contextes.
   */
  private wrap(content: string): string {
    return `
<!DOCTYPE html>
<html lang="fr">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="margin:0;padding:0;background:#fafafa;
             font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <div style="max-width:560px;margin:0 auto;padding:32px 24px;">
    <div style="background:#ffffff;border-radius:12px;padding:32px;
                border:1px solid #e4e4e7;">
      <h1 style="margin:0 0 24px;font-size:20px;color:#18181b;">SysteMIC</h1>
      <div style="color:#3f3f46;font-size:15px;line-height:1.6;">
        ${content}
      </div>
    </div>
    <p style="text-align:center;color:#a1a1aa;font-size:12px;margin-top:24px;">
      Message automatique — merci de ne pas y répondre.
    </p>
  </div>
</body>
</html>`;
  }
}