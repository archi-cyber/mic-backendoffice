import 'package:flutter/foundation.dart';

import '../../services/auth_service.dart';

/// Vérification des permissions.
///
/// L'API publique est inchangée — `canView`, `canCreate`, `canEdit`,
/// `canDelete`, `isAdminOrPastor`, `getPermissions` — afin que les écrans
/// existants continuent de fonctionner sans modification.
///
/// L'intérieur, en revanche, change du tout au tout. L'ancienne version
/// déclenchait **quatre à six requêtes réseau par vérification** : rôle de
/// l'utilisateur, appartenance départementale, puis consultation de
/// `leader_access`. Un écran vérifiant quatre droits déclenchait donc jusqu'à
/// vingt-quatre allers-retours avant de s'afficher.
///
/// Le backend renvoie maintenant l'ensemble des permissions dans `/auth/me`.
/// Elles sont chargées une fois, gardées en mémoire, et chaque vérification
/// devient une simple lecture — sans réseau.
///
/// Les méthodes restent `Future` malgré tout : les rendre synchrones
/// obligerait à modifier tous les appelants, pour un gain nul.
class PermissionHelper {
  PermissionHelper._();

  static Map<String, Map<String, bool>> _permissions = {};
  static String _role = 'member';
  static String? _userId;
  static String? _memberId;
  static String? _email;
  static List<Map<String, dynamic>> _departmentRoles = const [];
  static bool _loaded = false;

  // ---------------------------------------------------------------------------
  // Chargement
  // ---------------------------------------------------------------------------

  /// Charge le profil et ses permissions.
  ///
  /// À appeler après la connexion, et à chaque fois qu'un administrateur
  /// modifie les droits — sans quoi l'interface afficherait l'ancienne grille
  /// jusqu'à la prochaine connexion.
  static Future<void> load() async {
    try {
      final profile = await AuthService.getProfile();

      _role = profile['role'] as String? ?? 'member';
      _userId = profile['id'] as String?;
      _memberId = profile['member_id'] as String?;
      _email = profile['email'] as String?;

      _departmentRoles = ((profile['department_roles'] as List?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      final raw = (profile['permissions'] as Map?) ?? {};
      _permissions = raw.map(
        (key, value) => MapEntry(
          key.toString(),
          (value as Map).map((k, v) => MapEntry(k.toString(), v == true)),
        ),
      );

      _loaded = true;
    } catch (error) {
      debugPrint('[PermissionHelper] Chargement impossible : $error');
      // En cas d'échec, aucune permission n'est accordée. C'est le sens sûr :
      // afficher un bouton inutilisable vaut mieux que d'en masquer un
      // légitime, mais accorder des droits par défaut serait une faille.
      _reset();
    }
  }

  /// Recharge les permissions. Alias explicite de [load].
  static Future<void> refresh() => load();

  /// Efface le cache — à appeler à la déconnexion.
  static void clear() => _reset();

  static void _reset() {
    _permissions = {};
    _role = 'member';
    _userId = null;
    _memberId = null;
    _email = null;
    _departmentRoles = const [];
    _loaded = false;
  }

  /// Indique si les permissions ont été chargées.
  ///
  /// Utile pour afficher un indicateur de chargement plutôt qu'une interface
  /// vide au démarrage.
  static bool get isLoaded => _loaded;

  // ---------------------------------------------------------------------------
  // Vérifications
  // ---------------------------------------------------------------------------

  static Future<bool> canView(String featureName) async =>
      _check(featureName, 'view');

  static Future<bool> canCreate(String featureName) async =>
      _check(featureName, 'create');

  static Future<bool> canEdit(String featureName) async =>
      _check(featureName, 'edit');

  static Future<bool> canDelete(String featureName) async =>
      _check(featureName, 'delete');

  /// Administrateur ou pasteur — accès complet.
  static Future<bool> isAdminOrPastor() async => _isPrivileged;

  /// Les quatre droits d'un module en une fois.
  static Future<Map<String, bool>> getPermissions(String featureName) async {
    return {
      'view': _check(featureName, 'view'),
      'create': _check(featureName, 'create'),
      'edit': _check(featureName, 'edit'),
      'delete': _check(featureName, 'delete'),
    };
  }

  // ---------------------------------------------------------------------------
  // Versions synchrones
  // ---------------------------------------------------------------------------
  //
  // Les permissions étant en mémoire, la vérification n'a plus besoin d'être
  // asynchrone. Ces variantes évitent un `FutureBuilder` là où un simple `if`
  // suffit — préfère-les dans les nouveaux écrans.

  static bool canViewSync(String featureName) => _check(featureName, 'view');
  static bool canCreateSync(String featureName) => _check(featureName, 'create');
  static bool canEditSync(String featureName) => _check(featureName, 'edit');
  static bool canDeleteSync(String featureName) => _check(featureName, 'delete');

  // ---------------------------------------------------------------------------
  // Rôles
  // ---------------------------------------------------------------------------

  /// Responsable au sens large.
  ///
  /// Reproduit la règle du serveur : est responsable celui dont le rôle global
  /// le stipule, **ou** celui qui dirige un département — même si son rôle
  /// global n'est que `member`.
  static bool get isLeader {
    if (_isPrivileged || _role == 'leader') return true;

    return _departmentRoles.any(
      (d) => d['role'] == 'leader' || d['role'] == 'subleader',
    );
  }

  /// Accès aux données financières.
  ///
  /// Réservé aux administrateurs et aux responsables du département
  /// « Finance ». Sert à décider d'afficher l'onglet — le serveur reste seul
  /// juge de l'accès réel, via sa propre garde.
  static bool get isFinanceLeader {
    if (_isPrivileged) return true;

    return _departmentRoles.any((d) {
      final name = (d['department_name'] as String? ?? '').trim().toLowerCase();
      return name == 'finance' &&
          (d['role'] == 'leader' || d['role'] == 'subleader');
    });
  }

  static String get role => _role;

  /// Identifiant du compte connecté.
  static String? get userId => _userId;

  /// Identifiant de la fiche membre associée au compte.
  ///
  /// Vaut `null` pour un compte sans fiche — cas rare, mais possible pour un
  /// administrateur système créé hors du flux habituel.
  ///
  /// Cette valeur vient du profil chargé à la connexion : aucune requête n'est
  /// nécessaire pour l'obtenir, là où l'ancienne implémentation interrogeait la
  /// table `users` à chaque besoin.
  static String? get memberId => _memberId;

  /// Adresse e-mail du compte connecté.
  static String? get currentEmail => _email;

  static List<Map<String, dynamic>> get departmentRoles => _departmentRoles;

  // ---------------------------------------------------------------------------
  // Interne
  // ---------------------------------------------------------------------------

  static bool get _isPrivileged => _role == 'admin' || _role == 'pastor';

  /// Cœur de la vérification.
  ///
  /// Les administrateurs et pasteurs passent partout, exactement comme côté
  /// serveur. Pour les autres, le droit doit avoir été accordé explicitement :
  /// l'absence d'entrée vaut refus.
  ///
  /// Cette vérification sert **uniquement à l'affichage**. Masquer un bouton
  /// inutilisable est plus agréable que de laisser tenter une action refusée,
  /// mais elle ne protège rien : un client modifié la contournerait. La
  /// sécurité repose entièrement sur les gardes du backend.
  static bool _check(String featureName, String action) {
    if (_isPrivileged) return true;
    return _permissions[featureName]?[action] ?? false;
  }
}