import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Synchronisation entre comptes et membres.
///
/// **Ce service n'a presque plus d'objet.** Il existait parce que Supabase Auth
/// et la table `members` étaient deux mondes séparés : un compte pouvait vivre
/// sans fiche membre, une fiche sans compte, et rien ne garantissait la
/// cohérence. Il fallait donc rattraper périodiquement les écarts.
///
/// Le backend supprime cette classe de problèmes : la relation est de un à un,
/// portée par une clé étrangère unique, et créer un compte exige un membre
/// existant. Une désynchronisation n'est plus représentable.
///
/// Deux méthodes gardent une utilité réelle — créer les comptes manquants pour
/// les responsables — et sont conservées. Les autres renvoient un résultat
/// vide, pour ne pas casser les écrans qui les appellent.
class UserMemberSyncService {
  static ApiClient get _client => AuthService.client;

  /// Mot de passe attribué aux comptes créés.
  ///
  /// Correspond à `DEFAULT_USER_PASSWORD` du backend, qui l'applique
  /// réellement. Cette constante ne sert qu'à l'affichage.
  static const String defaultPassword = 'Password123';

  /// Crée une fiche membre pour chaque compte qui n'en aurait pas.
  ///
  /// Sans objet : `POST /users` exige un `member_id` existant. Un compte sans
  /// fiche ne peut plus être créé.
  ///
  /// Conservée pour compatibilité ; renvoie un décompte nul.
  static Future<Map<String, dynamic>> syncUsersToMembers() async {
    debugPrint(
      '[UserMemberSync] Sans objet : la relation compte-membre est garantie '
      'par le schéma.',
    );

    return {
      'created': 0,
      'skipped': 0,
      'errors': 0,
      'error_details': <String>[],
    };
  }

  /// Crée un compte pour chaque responsable qui n'en a pas.
  ///
  /// Garde une utilité réelle : un membre peut être promu responsable sans
  /// qu'un compte lui soit créé dans la foulée. Cette méthode rattrape ces cas.
  ///
  /// Seuls les membres disposant d'une adresse e-mail sont traités : le
  /// serveur authentifie par e-mail, un compte sans adresse serait inutilisable.
  static Future<Map<String, dynamic>> syncLeadersToUsers() async {
    debugPrint('[UserMemberSync] Création des comptes manquants...');

    var created = 0;
    var skipped = 0;
    var errors = 0;
    final errorsList = <String>[];

    try {
      final leaders = await _client.getList('/members', query: {
        'role': 'leader',
        'is_active': true,
        'limit': 200,
      });

      for (final leader in leaders) {
        final memberId = leader['id']?.toString();
        final email = leader['email']?.toString();

        if (memberId == null) {
          skipped++;
          continue;
        }

        // Un compte existe déjà : la fiche membre le porte.
        if (leader['user'] != null) {
          skipped++;
          continue;
        }

        if (email == null || email.isEmpty) {
          debugPrint(
            '[UserMemberSync] ${leader['first_name']} sans e-mail : ignoré',
          );
          skipped++;
          continue;
        }

        try {
          await _client.post('/users', body: {
            'member_id': memberId,
            'email': email,
            'role': 'leader',
          });
          created++;
        } catch (e) {
          errors++;
          errorsList.add('Membre $memberId : $e');
        }
      }

      debugPrint(
        '[UserMemberSync] Terminé : $created créé(s), $skipped ignoré(s), '
        '$errors erreur(s)',
      );
    } catch (e) {
      debugPrint('[UserMemberSync] Échec : $e');
      throw Exception('Failed to sync leaders to users: $e');
    }

    return {
      'created': created,
      'skipped': skipped,
      'errors': errors,
      'error_details': errorsList,
    };
  }

  /// Vérifie que chaque compte actif dispose bien d'identifiants.
  ///
  /// Sans objet : le mot de passe est créé en même temps que le compte, dans
  /// la même transaction. Un compte sans identifiants n'est pas représentable.
  static Future<Map<String, dynamic>> ensureAuthAccountsForActiveUsers() async {
    debugPrint(
      '[UserMemberSync] Sans objet : les identifiants sont créés avec le '
      'compte.',
    );

    return {
      'created': 0,
      'skipped': 0,
      'errors': 0,
      'error_details': <String>[],
    };
  }

  /// Lance l'ensemble des synchronisations.
  ///
  /// Seule `syncLeadersToUsers` a encore un effet.
  static Future<Map<String, dynamic>> syncAll() async {
    final leaders = await syncLeadersToUsers();

    return {
      'users_to_members': await syncUsersToMembers(),
      'leaders_to_users': leaders,
      'auth_accounts': await ensureAuthAccountsForActiveUsers(),
    };
  }
}