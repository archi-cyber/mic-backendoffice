import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../core/api/realtime_client.dart';
import '../core/offline/offline_cache.dart';
import '../core/offline/offline_queue.dart';
import '../core/utils/permission_helper.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

/// État d'authentification de l'application.
///
/// Remplace l'implémentation Supabase. Trois simplifications notables :
///
///   - le rafraîchissement des jetons n'est plus géré ici : `ApiClient` s'en
///     charge de façon transparente, ce qui supprime le minuteur et toute la
///     logique de surveillance du cycle de vie ;
///   - la synchronisation manuelle avec la table `users` disparaît : le
///     serveur garantit la cohérence ;
///   - les permissions sont fournies par le serveur, plus déduites côté client.
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _mustChangePassword = false;
  String? _errorMessage;

  Map<String, dynamic>? _profile;
  Map<String, Map<String, bool>> _permissions = {};

  RealtimeClient? _realtime;

  // ---------------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------------

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get mustChangePassword => _mustChangePassword;
  String? get errorMessage => _errorMessage;

  Map<String, dynamic>? get profile => _profile;
  String? get userId => _profile?['id'] as String?;
  String? get memberId => _profile?['member_id'] as String?;
  String get role => _profile?['role'] as String? ?? 'member';

  Map<String, dynamic>? get member =>
      (_profile?['member'] as Map?)?.cast<String, dynamic>();

  /// Utilisateur connecté — conservé pour les écrans qui l'attendent.
  ///
  /// Renvoie le profil complet : identifiant, e-mail, rôle, fiche membre,
  /// départements et permissions.
  Map<String, dynamic>? get currentUser => _profile;

  /// Identifiant du compte connecté.
  String? get currentUserId => _profile?['id'] as String?;

  String get displayName {
    final m = member;
    if (m == null) return _profile?['email'] as String? ?? '';
    return '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
  }

  /// Connexion temps réel, disponible une fois authentifié.
  RealtimeClient? get realtime => _realtime;

  /// Départements de l'utilisateur, avec son rôle dans chacun.
  List<Map<String, dynamic>> get departmentRoles =>
      ((_profile?['department_roles'] as List?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Indique si l'utilisateur détient un droit sur un module.
  ///
  /// Les administrateurs et pasteurs passent partout, comme côté serveur.
  ///
  /// Cette vérification sert **uniquement à l'affichage** : masquer un bouton
  /// inutilisable est plus agréable que de laisser tenter une action refusée.
  /// Elle ne remplace pas le contrôle serveur, qui reste seul à faire foi.
  bool can(String feature, String action) {
    if (role == 'admin' || role == 'pastor') return true;
    return _permissions[feature]?[action] ?? false;
  }

  bool canView(String feature) => can(feature, 'view');
  bool canCreate(String feature) => can(feature, 'create');
  bool canEdit(String feature) => can(feature, 'edit');
  bool canDelete(String feature) => can(feature, 'delete');

  /// Responsable au sens large : par le rôle global, ou par la direction d'un
  /// département.
  bool get isLeader {
    if (role == 'admin' || role == 'pastor' || role == 'leader') return true;
    return departmentRoles.any(
      (d) => d['role'] == 'leader' || d['role'] == 'subleader',
    );
  }

  /// Accès aux données financières.
  ///
  /// Réservé aux administrateurs et aux responsables du département
  /// « Finance ». Reproduit la règle du serveur pour décider d'afficher ou non
  /// l'onglet.
  bool get isFinanceLeader {
    if (role == 'admin' || role == 'pastor') return true;
    return departmentRoles.any((d) {
      final name = (d['department_name'] as String? ?? '').trim().toLowerCase();
      return name == 'finance' &&
          (d['role'] == 'leader' || d['role'] == 'subleader');
    });
  }

  // ---------------------------------------------------------------------------
  // Cycle de vie
  // ---------------------------------------------------------------------------

  /// Restaure la session au démarrage.
  ///
  /// L'appel à `/auth/me` est le seul moyen fiable de savoir si les jetons
  /// stockés sont encore valides : leur simple présence ne garantit rien, le
  /// compte ayant pu être désactivé entre-temps.
  Future<void> initialize() async {
    _setLoading(true);

    try {
      if (!await AuthService.hasSession()) {
        _isAuthenticated = false;
        return;
      }

      await _loadProfile();
      _isAuthenticated = true;
      await _connectRealtime();
      await _startOfflineQueue();
    } catch (error) {
      debugPrint('[AuthProvider] Session non restaurée : $error');
      _isAuthenticated = false;
      _profile = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final result = await AuthService.login(email: email, password: password);

      _mustChangePassword = result['must_change_password'] as bool? ?? false;

      // Le profil complet est chargé après la connexion : la réponse de login
      // ne contient que l'essentiel, pas les permissions.
      await _loadProfile();

      _isAuthenticated = true;
      await _connectRealtime();
      await _startOfflineQueue();

      return true;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);

    try {
      await _realtime?.disconnect();
      await OfflineQueue.instance.stop();

      // Le cache est vidé : les données d'un utilisateur ne doivent pas rester
      // lisibles par le suivant sur un appareil partagé.
      await OfflineCache.instance.clear();

      await AuthService.logout();
    } finally {
      _reset();
      _setLoading(false);
    }
  }

  /// Change le mot de passe.
  ///
  /// Le serveur ferme toutes les sessions à cette occasion : une reconnexion
  /// est donc nécessaire, et l'état local est remis à zéro.
  /// Change le mot de passe.
  ///
  /// [currentPassword] peut être omis lors du premier changement obligatoire :
  /// le serveur ne l'exige que si le compte n'est plus dans cet état.
  ///
  /// Toutes les sessions sont fermées à cette occasion, y compris celle-ci :
  /// si le changement fait suite à une compromission, laisser les jetons
  /// actifs annulerait tout le bénéfice.
  Future<bool> changePassword(
    String newPassword, {
    String? currentPassword,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await AuthService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      // La session reste ouverte : le serveur a émis un nouveau couple de
      // jetons pour cet appareil. Le profil est rechargé pour que
      // `mustChangePassword` repasse à faux et libère la navigation.
      await _loadProfile();

      // Le socket portait l'ancien jeton : il faut le rouvrir avec le nouveau.
      await _realtime?.reconnectWithFreshToken();

      return true;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Recharge le profil et les permissions.
  ///
  /// À appeler après qu'un administrateur a modifié les droits : sans cela,
  /// l'interface continuerait d'afficher l'ancienne grille jusqu'à la
  /// prochaine connexion.
  Future<void> refreshProfile() async {
    try {
      await _loadProfile();
      notifyListeners();
    } on ApiException catch (error) {
      debugPrint('[AuthProvider] Rechargement impossible : ${error.code}');
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Interne
  // ---------------------------------------------------------------------------

  Future<void> _loadProfile() async {
    _profile = await AuthService.getProfile();
    _mustChangePassword = _profile?['must_change_password'] as bool? ?? false;

    final raw = (_profile?['permissions'] as Map?) ?? {};
    _permissions = raw.map(
      (key, value) => MapEntry(
        key.toString(),
        (value as Map).map((k, v) => MapEntry(k.toString(), v == true)),
      ),
    );

    // Le helper partage le même profil : le charger ici évite une seconde
    // requête, et garantit que les deux sources ne divergent jamais.
    await PermissionHelper.load();

    // Couche de compatibilite : une quinzaine d'ecrans lisent encore
    // SupabaseService.currentUser. Alimenter la source unique ici garantit
    // qu'elle ne diverge pas du profil.
    SupabaseService.setCurrentUser(_profile);
  }

  /// Ouvre la connexion temps réel.
  ///
  /// Un échec est absorbé : l'application reste pleinement utilisable sans
  /// temps réel, seules les mises à jour instantanées manquent.
  /// Démarre la synchronisation hors ligne.
  ///
  /// Après authentification uniquement : rejouer la file sans jeton valide
  /// produirait des 401 en série et épuiserait le compteur de tentatives de
  /// chaque opération.
  Future<void> _startOfflineQueue() async {
    try {
      await OfflineQueue.instance.start(AuthService.client);
    } catch (error) {
      debugPrint('[AuthProvider] File hors ligne indisponible : $error');
    }
  }

  Future<void> _connectRealtime() async {
    try {
      _realtime ??= RealtimeClient(tokenStorage: AuthService.client.tokens);
      await _realtime!.connect();
    } catch (error) {
      debugPrint('[AuthProvider] Temps réel indisponible : $error');
    }
  }

  void _reset() {
    PermissionHelper.clear();
    SupabaseService.clear();
    _isAuthenticated = false;
    _profile = null;
    _permissions = {};
    _mustChangePassword = false;
    _errorMessage = null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _realtime?.dispose();
    super.dispose();
  }
}