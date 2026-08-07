import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Comptes de connexion et permissions granulaires.
///
/// Tout ce module est **réservé aux administrateurs**. Le confier aux
/// permissions granulaires serait circulaire : un responsable pourrait
/// s'attribuer les droits qui lui manquent.
class UserService {

  static ApiClient get _client => AuthService.client;

  /// Les douze modules soumis à permissions.
  ///
  /// Ces clés correspondent à `leader_access.feature_name` côté serveur. Elles
  /// sont figées : les modifier invaliderait les permissions déjà accordées.
  static const features = <String>[
    'members',
    'departments',
    'trainings',
    'events',
    'tasks',
    'reports',
    'church_attendance',
    'sunday_school_attendance',
    'visitors',
    'giving',
    'chat',
    'teachings',
  ];

  // ---------------------------------------------------------------------------
  // Comptes
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getUsers({
    int page = 1,
    int limit = 20,
    String? search,
    String? role,
    bool? isActive,
  }) {
    return _client.getList('/users', query: {
        'page': page,
        'limit': limit,
        'search': search,
        'role': role,
        'isActive': isActive,
      });
  }

  /// Détail d'un compte, permissions incluses.
  static Future<Map<String, dynamic>> getUserById(String id) async {
    final data = await _client.get('/users/$id');
    return (data as Map).cast<String, dynamic>();
  }

  /// Crée un compte pour un membre existant.
  ///
  /// Aucun mot de passe n'est demandé : le compte reçoit le mot de passe par
  /// défaut avec changement obligatoire. La réponse contient
  /// `temporaryPassword`, à communiquer au membre — il n'est jamais renvoyé
  /// par la suite.
  ///
  /// Le nouveau compte n'a **aucune** permission : elles doivent être
  /// accordées explicitement.
  static Future<Map<String, dynamic>> createAccount({
    required String memberId,
    required String email,
    String role = 'member',
    String? phone,
  }) async {
    final data = await _client.post('/users', body: {
      'memberId': memberId,
      'email': email,
      'role': role,
      if (phone != null) 'phone': phone,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Modifie un compte.
  ///
  /// Un changement de rôle ferme les sessions ouvertes : le nouveau rôle prend
  /// effet à la reconnexion, sans ambiguïté sur les droits en cours.
  static Future<Map<String, dynamic>> updateUser(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final data = await _client.patch('/users/$id', body: updates);
    return (data as Map).cast<String, dynamic>();
  }

  /// Active ou désactive un compte.
  ///
  /// La désactivation ferme immédiatement toutes les sessions. Le serveur
  /// refuse de désactiver le dernier administrateur actif — code `LAST_ADMIN`.
  static Future<Map<String, dynamic>> setActive({
    required String userId,
    required bool isActive,
  }) async {
    final data = await _client.patch(
      '/users/$userId/active',
      body: {'isActive': isActive},
    );
    return (data as Map).cast<String, dynamic>();
  }

  /// Réinitialise le mot de passe à la valeur par défaut.
  ///
  /// Utile quand le membre n'a plus accès à son adresse e-mail et ne peut donc
  /// pas suivre la procédure autonome. La réponse contient
  /// `temporaryPassword`.
  static Future<Map<String, dynamic>> forcePasswordReset(String userId) async {
    final data = await _client.post('/users/$userId/reset-password');
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteUser(String id) async {
    await _client.delete('/users/$id');
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Grille complète des permissions.
  ///
  /// Les douze modules sont toujours renvoyés, y compris ceux sans droit
  /// accordé : l'interface d'administration affiche un tableau complet.
  static Future<List<Map<String, dynamic>>> getPermissions(String userId) async {
    final data = await _client.get('/users/$userId/permissions');
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Remplace intégralement les permissions.
  ///
  /// Les modules absents de la liste voient leurs droits **révoqués**. Une
  /// mise à jour partielle laisserait subsister des permissions oubliées,
  /// invisibles dans l'interface qui affiche la grille complète.
  ///
  /// Format de chaque entrée :
  /// `{'feature': 'members', 'canView': true, 'canCreate': false,
  ///   'canEdit': false, 'canDelete': false}`
  static Future<List<Map<String, dynamic>>> setPermissions({
    required String userId,
    required List<Map<String, dynamic>> permissions,
  }) async {
    final data = await _client.post(
      '/users/$userId/permissions',
      body: {'permissions': permissions},
    );
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }
}