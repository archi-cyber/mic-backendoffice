import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Permissions granulaires des responsables.
///
/// Signatures identiques à l'implémentation Supabase.
///
/// Réservé aux administrateurs : accorder des droits ne peut pas relever des
/// permissions elles-mêmes, sous peine de circularité — un responsable
/// pourrait s'attribuer ce qui lui manque.
class LeaderAccessService {
  static ApiClient get _client => AuthService.client;

  /// Les douze modules soumis à permissions.
  ///
  /// Ces clés correspondent à `leader_access.feature_name` côté serveur. Elles
  /// sont figées : les renommer invaliderait les permissions déjà accordées.
  static List<String> getAvailableFeatures() => const [
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

  /// Comptes pouvant recevoir des permissions.
  ///
  /// Les administrateurs et pasteurs sont exclus : ils passent partout, et
  /// leur accorder des droits ligne à ligne créerait une grille trompeuse —
  /// décocher une case ne leur retirerait rien.
  static Future<List<Map<String, dynamic>>> getLeaders() async {
    final users = await _client.getList('/users', query: {
      'is_active': true,
      'limit': 200,
    });

    return users
        .where((user) => user['role'] != 'admin' && user['role'] != 'pastor')
        .toList();
  }

  /// Grille des permissions d'un utilisateur.
  ///
  /// Les douze modules sont toujours renvoyés, y compris ceux sans droit
  /// accordé : l'interface d'administration affiche un tableau complet.
  static Future<List<Map<String, dynamic>>> getLeaderAccess(String userId) =>
      _client.getList('/users/$userId/permissions');

  /// Droits d'un utilisateur sur un module précis.
  static Future<Map<String, dynamic>?> getLeaderFeatureAccess({
    required String userId,
    required String featureName,
  }) async {
    final permissions = await getLeaderAccess(userId);

    for (final permission in permissions) {
      if (permission['feature'] == featureName) return permission;
    }

    return null;
  }

  /// Accorde ou retire des droits sur un module.
  ///
  /// L'API remplace la grille entière : les autres modules sont donc relus et
  /// renvoyés tels quels. Une mise à jour partielle laisserait subsister des
  /// permissions oubliées, invisibles dans une interface qui affiche le
  /// tableau complet.
  static Future<void> setLeaderAccess({
    required String userId,
    required String featureName,
    required bool canView,
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
  }) async {
    final current = await getLeaderAccess(userId);

    final permissions = current.map((permission) {
      if (permission['feature'] != featureName) {
        return {
          'feature': permission['feature'],
          'can_view': permission['can_view'] ?? false,
          'can_create': permission['can_create'] ?? false,
          'can_edit': permission['can_edit'] ?? false,
          'can_delete': permission['can_delete'] ?? false,
        };
      }

      return {
        'feature': featureName,
        'can_view': canView,
        'can_create': canCreate,
        'can_edit': canEdit,
        'can_delete': canDelete,
      };
    }).toList();

    await _client.post(
      '/users/$userId/permissions',
      body: {'permissions': permissions},
    );
  }

  /// Vérifie un droit précis.
  ///
  /// [permission] vaut `view`, `create`, `edit` ou `delete`.
  static Future<bool> hasPermission({
    required String userId,
    required String featureName,
    required String permission,
  }) async {
    final access = await getLeaderFeatureAccess(
      userId: userId,
      featureName: featureName,
    );

    if (access == null) return false;

    return access['can_$permission'] == true;
  }
}