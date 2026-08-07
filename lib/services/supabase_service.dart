import '../core/api/api_client.dart';
import '../core/utils/permission_helper.dart';
import 'auth_service.dart';

/// Utilisateur connecté.
///
/// Reproduit la forme de l'objet `User` du SDK Supabase — `.id`, `.email`,
/// `.userMetadata` — pour que les écrans qui le lisent encore continuent de
/// fonctionner sans modification.
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.email,
    this.memberId,
    this.role = 'member',
    this.userMetadata = const {},
  });

  final String id;
  final String email;
  final String? memberId;
  final String role;
  final Map<String, dynamic> userMetadata;
}

/// Couche de compatibilité, transitoire.
///
/// **Ce fichier ne contient plus rien de Supabase** malgré son nom : il est
/// conservé pour que les écrans référençant encore `SupabaseService` compilent
/// pendant la migration.
///
/// L'ancienne version initialisait le SDK Supabase et exposait un client de
/// base de données. Celle-ci s'adosse à l'API : le client parle en routes, pas
/// en tables, et l'identité vient du profil chargé à la connexion.
///
/// **Il doit disparaître.** Chaque écran migré vers `PermissionHelper` ou son
/// service métier cesse d'en dépendre. Une fois qu'aucun fichier ne l'importe,
/// supprime-le ainsi que son export dans `services_index.dart` — ce sera le
/// signe que la migration est réellement terminée.
///
/// Pour vérifier :
/// ```powershell
/// Select-String -Path lib\**\*.dart -Pattern "SupabaseService" -List
/// ```
class SupabaseService {
  SupabaseService._();

  static CurrentUser? _cached;

  /// Client HTTP de l'application.
  ///
  /// **Ne propose pas `.from()`.** L'API expose des routes, pas des tables :
  /// un écran qui construisait ses requêtes doit passer par le service métier
  /// correspondant — `MemberService`, `TaskService`, et ainsi de suite.
  static ApiClient get client => AuthService.client;

  /// Utilisateur connecté, ou `null` avant chargement du profil.
  ///
  /// Différence avec le SDK d'origine : cette valeur est renseignée par
  /// `AuthProvider` après l'appel à `/auth/me`. Elle vaut `null` durant les
  /// premières millisecondes du démarrage, là où Supabase la fournissait dès
  /// la restauration de session.
  ///
  /// Préférer `PermissionHelper.userId`, `.memberId` et `.currentEmail`, plus
  /// explicites et alimentés par la même source.
  static CurrentUser? get currentUser => _cached;

  /// Renseigne l'utilisateur courant depuis le profil.
  ///
  /// Appelé par `AuthProvider` après chaque chargement. Passer par un point
  /// unique garantit que cette valeur ne diverge pas du profil réel.
  static void setCurrentUser(Map<String, dynamic>? profile) {
    if (profile == null) {
      _cached = null;
      return;
    }

    final member = (profile['member'] as Map?)?.cast<String, dynamic>();

    _cached = CurrentUser(
      id: profile['id'] as String? ?? '',
      email: profile['email'] as String? ?? '',
      memberId: profile['member_id'] as String?,
      role: profile['role'] as String? ?? 'member',
      userMetadata: {
        'role': profile['role'],
        'member_id': profile['member_id'],
        if (member != null) ...{
          'first_name': member['first_name'],
          'last_name': member['last_name'],
        },
      },
    );
  }

  /// Efface l'utilisateur courant — à la déconnexion.
  static void clear() => _cached = null;

  static bool get isAuthenticated => _cached != null;

  static String get role => _cached?.role ?? PermissionHelper.role;

  /// Session Supabase — n'existe plus.
  ///
  /// Les jetons sont gérés par `ApiClient`, qui les stocke dans le Keychain ou
  /// le Keystore et les rafraîchit de lui-même. Aucun écran n'a besoin d'y
  /// accéder.
  static Object? get currentSession => null;

  /// Initialisation — sans objet.
  ///
  /// Conservée pour ne pas casser un appel résiduel dans `main.dart`.
  /// L'initialisation réelle se fait via `AuthService.initialize()`.
  static Future<void> initialize({
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) async {
    // Volontairement vide.
  }
}