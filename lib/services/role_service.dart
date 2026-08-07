import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Rôles et attributs des comptes.
///
/// L'ancienne implémentation manipulait `UserAttributes`, une classe du SDK
/// Supabase servant à modifier e-mail, mot de passe et métadonnées d'un compte
/// d'authentification. Elle n'a plus d'équivalent : ces opérations passent
/// désormais par des routes explicites, avec les contrôles d'accès du serveur.
class RoleService {
  static ApiClient get _client => AuthService.client;

  /// Rôles globaux disponibles.
  ///
  /// Ces valeurs correspondent à l'énumération `UserRole` côté serveur. Les
  /// modifier ici sans changer le schéma provoquerait un rejet à l'écriture.
  static const availableRoles = <String>[
    'admin',
    'pastor',
    'leader',
    'member',
  ];

  /// Rôles au sein d'un département.
  static const departmentRoles = <String>[
    'leader',
    'subleader',
    'member',
  ];

  /// Rôles applicables à une fiche membre.
  static const memberRoles = <String>[
    'admin',
    'leader',
    'member',
    'worker',
    'sympathiser',
  ];

  /// Change le rôle global d'un compte.
  ///
  /// Le serveur ferme les sessions ouvertes : le nouveau rôle prend effet à la
  /// reconnexion, sans laisser d'ambiguïté sur les droits en cours.
  static Future<Map<String, dynamic>> updateUserRole({
    required String userId,
    required String role,
  }) async {
    final data = await _client.patch('/users/$userId', body: {'role': role});
    return (data as Map).cast<String, dynamic>();
  }

  /// Change l'adresse e-mail d'un compte.
  static Future<Map<String, dynamic>> updateUserEmail({
    required String userId,
    required String email,
  }) async {
    final data = await _client.patch('/users/$userId', body: {'email': email});
    return (data as Map).cast<String, dynamic>();
  }

  /// Réinitialise le mot de passe à la valeur par défaut.
  ///
  /// Un administrateur ne choisit pas le mot de passe d'autrui : le compte
  /// reçoit celui par défaut, avec changement obligatoire. Le connaître
  /// rendrait impossible toute imputabilité des actions du compte.
  ///
  /// La réponse contient `temporary_password`, à communiquer au membre.
  static Future<Map<String, dynamic>> resetUserPassword(String userId) async {
    final data = await _client.post('/users/$userId/reset-password');
    return (data as Map).cast<String, dynamic>();
  }

  /// Active ou désactive un compte.
  static Future<Map<String, dynamic>> setUserActive({
    required String userId,
    required bool isActive,
  }) async {
    final data = await _client.patch(
      '/users/$userId/active',
      body: {'is_active': isActive},
    );
    return (data as Map).cast<String, dynamic>();
  }

  /// Rôle global de l'utilisateur connecté.
  static Future<String> getCurrentUserRole() async {
    final profile = await AuthService.getProfile();
    return profile['role'] as String? ?? 'member';
  }

  // ---------------------------------------------------------------------------
  // Super-administrateur
  // ---------------------------------------------------------------------------

  /// Adresse du compte super-administrateur.
  ///
  /// Correspond à `SUPER_ADMIN_EMAIL` du backend, créé par le seed. Elle sert
  /// uniquement à reconnaître ce compte dans l'interface — jamais à lui
  /// accorder des droits, qui viennent du serveur.
  static const String superAdminEmail = 'admin@systemic.church';

  /// Rôle global d'un compte.
  ///
  /// Sans [userId], renvoie celui de l'utilisateur connecté.
  static Future<String> getUserRole([String? userId]) async {
    if (userId == null) {
      final profile = await AuthService.getProfile();
      return profile['role'] as String? ?? 'member';
    }

    final user = await _client.getOne('/users/$userId');
    return user['role'] as String? ?? 'member';
  }

  /// Indique si l'utilisateur connecté est administrateur ou pasteur.
  ///
  /// Vérification d'affichage uniquement : le serveur reste seul juge. Masquer
  /// un bouton inutilisable est plus agréable que de laisser tenter une action
  /// refusée, mais un client modifié contournerait ce test.
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final role = await getUserRole();
      return role == 'admin' || role == 'pastor';
    } catch (_) {
      // En cas d'échec, on refuse : accorder des droits par défaut serait une
      // faille, alors qu'un bouton masqué à tort n'est qu'une gêne.
      return false;
    }
  }

  /// Vérifie que le super-administrateur dispose bien de ses droits.
  ///
  /// L'ancienne implémentation réparait le rôle en base si nécessaire. Cette
  /// correction n'a plus lieu d'être : le serveur garantit la cohérence, et
  /// refuse par ailleurs de désactiver le dernier administrateur actif — le
  /// scénario que cette méthode visait à rattraper ne peut plus se produire.
  ///
  /// Conservée pour compatibilité, elle se contente désormais de vérifier.
  static Future<bool> ensureSuperAdminPrivileges() async {
    try {
      final profile = await AuthService.getProfile();
      final email = (profile['email'] as String? ?? '').toLowerCase();
      final role = profile['role'] as String? ?? 'member';

      if (email != superAdminEmail.toLowerCase()) {
        return false;
      }

      return role == 'admin' || role == 'pastor';
    } catch (_) {
      return false;
    }
  }
}