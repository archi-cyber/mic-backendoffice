import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Comptes de connexion des membres.
///
/// Signatures identiques à l'implémentation Supabase.
class MemberAccountService {
  static ApiClient get _client => AuthService.client;

  /// Mot de passe attribué aux comptes créés par un administrateur.
  ///
  /// Doit correspondre à `DEFAULT_USER_PASSWORD` du backend, qui l'applique
  /// réellement. Cette constante ne sert qu'à l'affichage : montrer à
  /// l'administrateur ce qu'il doit communiquer au membre.
  ///
  /// Le compte est créé avec obligation de changement à la première connexion,
  /// donc ce mot de passe ne reste valable qu'un instant.
  static const String defaultPassword = 'Password123';

  /// Membres avec l'état de leur compte de connexion.
  ///
  /// Une seule requête suffit : l'API renvoie le compte associé dans la fiche
  /// membre. L'ancienne version croisait deux tables côté client.
  static Future<List<Map<String, dynamic>>> getMembersWithAccountStatus() async {
    final members = await _client.getList('/members', query: {
      'is_active': true,
      'limit': 200,
      'orderBy': 'lastName',
      'order': 'asc',
    });

    return members.map((member) {
      final user = (member['user'] as Map?)?.cast<String, dynamic>();

      return {
        ...member,
        'has_account': user != null,
        'account_email': user?['email'],
        'account_is_active': user?['is_active'] ?? false,
        'account_id': user?['id'],
        'must_change_password': user?['must_change_password'] ?? false,
        'last_login_at': user?['last_login_at'],
      };
    }).toList();
  }

  /// Crée un compte pour un membre.
  ///
  /// [password] est ignoré : le serveur attribue le mot de passe par défaut,
  /// avec changement obligatoire à la première connexion. Laisser un
  /// administrateur choisir le mot de passe d'autrui signifierait qu'il le
  /// connaît, ce qui rend impossible toute imputabilité des actions du compte.
  ///
  /// Le nouveau compte n'a **aucune permission** : elles doivent être
  /// accordées explicitement via `LeaderAccessService`. C'est le principe du
  /// moindre privilège — un compte créé par erreur ne donne accès à rien.
  static Future<void> createAccountForMember({
    required String memberId,
    required String email,
    String? password,
  }) async {
    final data = await _client.post('/users', body: {
      'member_id': memberId,
      'email': email.trim().toLowerCase(),
      'role': 'member',
    });

    final result = (data as Map).cast<String, dynamic>();
    final temporary = result['temporary_password'];

    if (temporary != null) {
      debugPrint('[MemberAccount] Mot de passe temporaire généré pour $email');
    }
  }

  /// Désactive un compte.
  ///
  /// Toutes les sessions sont fermées immédiatement côté serveur : sans cela,
  /// un jeton d'accès resterait valide jusqu'à quinze minutes après la coupure.
  ///
  /// Le serveur refuse de désactiver le dernier administrateur actif — code
  /// `LAST_ADMIN` — sans quoi l'application deviendrait inadministrable.
  static Future<void> deactivateMemberAccount(String userId) async {
    await _client.patch('/users/$userId/active', body: {'is_active': false});
  }

  /// Réactive un compte.
  static Future<void> activateMemberAccount(String userId) async {
    await _client.patch('/users/$userId/active', body: {'is_active': true});
  }

  /// Réinitialise le mot de passe à la valeur par défaut.
  ///
  /// Utile quand le membre n'a plus accès à son adresse e-mail et ne peut donc
  /// pas suivre la procédure autonome. La réponse contient
  /// `temporary_password`, à lui communiquer.
  static Future<Map<String, dynamic>> resetMemberPassword(String userId) async {
    final data = await _client.post('/users/$userId/reset-password');
    return (data as Map).cast<String, dynamic>();
  }
}