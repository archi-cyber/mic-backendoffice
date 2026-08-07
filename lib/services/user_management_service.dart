import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Comptes de connexion liés aux membres.
///
/// Signatures identiques à l'implémentation Supabase, mais l'intérieur se
/// réduit considérablement. L'ancienne version devait créer une ligne dans
/// `users`, puis un compte dans `auth.users` via `signUp`, gérer les collisions
/// d'e-mail, les erreurs de clé dupliquée et les confirmations par e-mail.
///
/// `POST /users` fait tout cela en une transaction côté serveur : création du
/// compte, mot de passe par défaut haché en Argon2id, obligation de changement
/// à la première connexion. Les cas d'erreur remontent avec un code explicite
/// plutôt qu'un message à analyser.
class UserManagementService {
  static ApiClient get _client => AuthService.client;

  /// Crée un compte pour un membre.
  ///
  /// Renvoie l'identifiant du compte, ou celui du compte existant si le membre
  /// en avait déjà un — le serveur refuse alors avec
  /// `MEMBER_ALREADY_HAS_ACCOUNT`, que l'on rattrape pour rester idempotent.
  ///
  /// Le compte est créé **actif** : l'API ne distingue plus compte inactif et
  /// compte absent. Un compte qui ne doit pas servir se désactive
  /// explicitement, ce qui est plus lisible qu'un état intermédiaire.
  static Future<String?> createInactiveUserForMember({
    required String memberId,
    required String? email,
    required String? phone,
  }) async {
    final identifier = email ?? phone;
    if (identifier == null || identifier.isEmpty) {
      throw Exception('Email or phone required');
    }

    // Un compte de connexion suppose une adresse : le serveur authentifie par
    // e-mail, pas par téléphone.
    if (email == null || email.isEmpty) {
      debugPrint(
        '[UserManagement] Aucun e-mail : compte non créé pour $memberId',
      );
      return null;
    }

    try {
      final user = await _client.post('/users', body: {
        'member_id': memberId,
        'email': email,
        'role': 'member',
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });

      return (user as Map)['id']?.toString();
    } catch (e) {
      // Le membre a déjà un compte, ou l'adresse est prise : on renvoie
      // l'existant plutôt que d'échouer.
      final existing = await getUserIdForMember(memberId);
      if (existing != null) return existing;

      debugPrint('[UserManagement] Création impossible : $e');
      throw Exception('Failed to create account');
    }
  }

  /// Active un compte et lui donne le rôle de responsable.
  ///
  /// [defaultPassword] est ignoré : le serveur applique le mot de passe par
  /// défaut lors de la création, avec changement obligatoire. Le client ne
  /// choisit jamais le mot de passe d'autrui — le connaître rendrait
  /// impossible toute imputabilité des actions du compte.
  static Future<void> activateUserAsLeader({
    required String userId,
    String? defaultPassword,
  }) async {
    await _client.patch('/users/$userId', body: {'role': 'leader'});
    await _client.patch('/users/$userId/active', body: {'is_active': true});

    debugPrint('[UserManagement] Compte $userId activé comme responsable');
  }

  /// Indique si le membre dirige au moins un département.
  ///
  /// Lu depuis la fiche membre, qui porte ses appartenances : l'ancienne
  /// version interrogeait `department_members` séparément.
  static Future<bool> hasLeadershipRole(String memberId) async {
    try {
      final member = await _client.getOne('/members/$memberId');
      final memberships =
          (member['department_members'] as List?) ?? const <dynamic>[];

      return memberships.any((entry) {
        final role = (entry as Map)['role'];
        return role == 'leader' || role == 'subleader';
      });
    } catch (e) {
      debugPrint('[UserManagement] Vérification impossible : $e');
      return false;
    }
  }

  /// Désactive le compte si le membre ne dirige plus aucun département.
  ///
  /// Appelé après le retrait d'un rôle de responsable. Le serveur refuse de
  /// désactiver le dernier administrateur actif — code `LAST_ADMIN` — ce qui
  /// évite de rendre l'application inadministrable par une fausse manœuvre.
  static Future<void> deactivateUserIfNoLeadership({
    required String userId,
    required String memberId,
  }) async {
    final stillLeader = await hasLeadershipRole(memberId);
    if (stillLeader) return;

    try {
      await _client.patch('/users/$userId', body: {'role': 'member'});
      await _client.patch('/users/$userId/active', body: {'is_active': false});

      debugPrint('[UserManagement] Compte $userId désactivé');
    } catch (e) {
      debugPrint('[UserManagement] Désactivation refusée : $e');
    }
  }

  static Future<void> reactivateUserAsLeader({required String userId}) =>
      activateUserAsLeader(userId: userId);

  /// Identifiant du compte associé à un membre, ou `null`.
  static Future<String?> getUserIdForMember(String memberId) async {
    try {
      final member = await _client.getOne('/members/$memberId');
      final user = (member['user'] as Map?)?.cast<String, dynamic>();
      return user?['id']?.toString();
    } catch (e) {
      debugPrint('[UserManagement] Compte introuvable pour $memberId : $e');
      return null;
    }
  }
}