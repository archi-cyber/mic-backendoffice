import 'package:flutter/foundation.dart' show debugPrint;

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';

/// Authentification.
///
/// Remplace l'implémentation Supabase. Les signatures publiques sont
/// conservées afin que `AuthProvider` et les écrans existants continuent de
/// fonctionner sans modification — seul l'intérieur change.
///
/// Différence de fond : les jetons ne sont plus gérés par un SDK tiers mais
/// par [ApiClient], qui les stocke dans le Keychain ou le Keystore et les
/// rafraîchit de lui-même.
class AuthService {

  /// Instance partagée, initialisée au démarrage.
  ///
  /// Une seule instance existe : elle porte le verrou de rafraîchissement et
  /// le cache de jetons. En créer plusieurs provoquerait des rafraîchissements
  /// concurrents, que la rotation côté serveur interprète comme une session
  /// compromise.
  static late final ApiClient client;

  static bool _initialized = false;

  /// À appeler une fois dans `main()`, avant `runApp`.
  static void initialize({void Function()? onSessionExpired}) {
    if (_initialized) return;

    client = ApiClient()..onSessionExpired = onSessionExpired;
    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Connexion
  // ---------------------------------------------------------------------------

  /// Connexion par e-mail et mot de passe.
  ///
  /// Renvoie la même structure que l'ancienne implémentation :
  /// `{token, must_change_password, user}`.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? deviceInfo,
  }) async {
    try {
      debugPrint('[AuthService] Connexion : $email');

      final data = await client.post('/auth/login', body: {
        'email': email.trim().toLowerCase(),
        'password': password,
        if (deviceInfo != null) 'deviceInfo': deviceInfo,
      }) as Map<String, dynamic>;

      // Les clés arrivent en snake_case : ApiClient convertit les réponses
      // pour que l'application garde la convention héritée de Supabase.
      await client.tokens.save(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        expiresIn: data['expires_in'] as int? ?? 900,
      );

      final mustChange = data['must_change_password'] as bool? ?? false;

      debugPrint('[AuthService] Connexion réussie. Changement requis : $mustChange');

      return {
        'token': data['access_token'],
        'must_change_password': mustChange,
        'user': data['user'],
      };
    } on ApiException catch (error) {
      debugPrint('[AuthService] Échec : ${error.code}');
      throw Exception(_translate(error));
    }
  }

  /// Profil complet de l'utilisateur connecté.
  ///
  /// Appelé au démarrage pour reconstituer l'état : rôle, fiche membre,
  /// départements et permissions. Ces informations ne sont volontairement pas
  /// mémorisées localement — elles deviendraient obsolètes dès qu'un
  /// administrateur modifie les droits.
  static Future<Map<String, dynamic>> getProfile() async {
    final data = await client.get('/auth/me');
    return (data as Map).cast<String, dynamic>();
  }

  /// Indique si une session existe, sans garantir qu'elle soit encore valide.
  static Future<bool> hasSession() => client.tokens.hasSession();

  // ---------------------------------------------------------------------------
  // Déconnexion
  // ---------------------------------------------------------------------------

  /// Ferme la session courante.
  ///
  /// L'appel serveur peut échouer — appareil hors ligne, jeton déjà invalide.
  /// Les jetons locaux sont effacés dans tous les cas : refuser de déconnecter
  /// quelqu'un parce que le réseau est coupé serait absurde.
  static Future<void> logout() async {
    try {
      final refreshToken = await client.tokens.getRefreshToken();
      if (refreshToken != null) {
        await client.post('/auth/logout', body: {'refreshToken': refreshToken});
      }
    } catch (error) {
      debugPrint('[AuthService] Déconnexion serveur échouée : $error');
    } finally {
      await client.tokens.clear();
    }
  }

  /// Ferme toutes les sessions, sur tous les appareils.
  static Future<void> logoutEverywhere() async {
    try {
      await client.delete('/auth/sessions');
    } finally {
      await client.tokens.clear();
    }
  }

  /// Liste les appareils connectés.
  static Future<List<Map<String, dynamic>>> listSessions() async {
    final data = await client.get('/auth/sessions') as List;
    return data.map((item) => (item as Map).cast<String, dynamic>()).toList();
  }

  // ---------------------------------------------------------------------------
  // Mots de passe
  // ---------------------------------------------------------------------------

  /// Change le mot de passe.
  ///
  /// Le serveur ferme toutes les sessions à cette occasion : si le changement
  /// fait suite à une compromission, laisser les jetons actifs annulerait tout
  /// le bénéfice. L'utilisateur doit donc se reconnecter.
  static Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    try {
      await client.post('/auth/change-password', body: {
        // Facultatif lors du premier changement obligatoire : l'utilisateur
        // vient de saisir le mot de passe par défaut pour se connecter.
        if (currentPassword != null && currentPassword.isNotEmpty)
          'current_password': currentPassword,
        'new_password': newPassword,
      });

      await client.tokens.clear();
    } on ApiException catch (error) {
      throw Exception(_translate(error));
    }
  }

  /// Demande un jeton de réinitialisation.
  ///
  /// La réponse est identique que l'adresse existe ou non : le serveur ne
  /// révèle pas quels comptes sont enregistrés.
  static Future<void> forgotPassword({required String email}) async {
    try {
      await client.post('/auth/forgot-password', body: {
        'email': email.trim().toLowerCase(),
      });
    } on ApiException catch (error) {
      throw Exception(_translate(error));
    }
  }

  static Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      await client.post('/auth/reset-password', body: {
        'email': email.trim().toLowerCase(),
        'token': token,
        'newPassword': newPassword,
      });
    } on ApiException catch (error) {
      throw Exception(_translate(error));
    }
  }

  // ---------------------------------------------------------------------------
  // Traduction des erreurs
  // ---------------------------------------------------------------------------

  /// Convertit un code d'erreur en message affichable.
  ///
  /// La traduction s'appuie sur [ApiException.code], jamais sur le texte du
  /// message : le code est stable, le texte peut changer côté serveur sans
  /// prévenir.
  static String _translate(ApiException error) {
    return switch (error.code) {
      ApiErrorCodes.invalidCredentials =>
        'Adresse e-mail ou mot de passe incorrect.',
      ApiErrorCodes.accountDisabled =>
        'Ce compte a été désactivé. Contactez votre administrateur.',
      ApiErrorCodes.currentPasswordInvalid =>
        'Le mot de passe actuel est incorrect.',
      ApiErrorCodes.resetTokenInvalid =>
        'Jeton invalide ou expiré. Demandez-en un nouveau.',
      ApiErrorCodes.rateLimited =>
        'Trop de tentatives. Patientez une minute avant de réessayer.',
      ApiErrorCodes.networkError =>
        'Impossible de joindre le serveur. Vérifiez votre connexion.',
      ApiErrorCodes.timeout =>
        'Le serveur met trop de temps à répondre. Réessayez.',
      ApiErrorCodes.databaseUnavailable =>
        'Service momentanément indisponible. Réessayez dans un instant.',
      _ => error.message,
    };
  }
}