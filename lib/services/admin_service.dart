import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Administration des comptes.
class AdminService {
  static ApiClient get _client => AuthService.client;

  /// Crée un compte de connexion pour un membre.
  ///
  /// Aucun mot de passe n'est demandé : le compte reçoit celui par défaut,
  /// avec changement obligatoire à la première connexion. Laisser un
  /// administrateur choisir le mot de passe d'autrui signifierait qu'il le
  /// connaît, ce qui rend impossible toute imputabilité des actions du compte.
  ///
  /// La réponse contient `temporary_password`, à communiquer au membre — il
  /// n'est jamais renvoyé par la suite.
  static Future<Map<String, dynamic>> createAdminUser({
    required String email,
    String? password,
    String role = 'member',
    String? memberId,
    String? phone,
    String? firstName,
    String? lastName,
  }) async {
    // Un compte suppose une fiche membre : la relation est de un à un côté
    // serveur, et créer un compte orphelin le priverait de présence, de tâches
    // et de rapports. Si aucun membre n'est fourni, on en crée un à partir de
    // l'adresse.
    var resolvedMemberId = memberId;

    if (resolvedMemberId == null) {
      final local = email.split('@').first;
      final parts = local.split(RegExp(r'[._-]'));

      final member = await _client.post('/members', body: {
        'first_name': firstName ?? _capitalize(parts.first),
        'last_name': lastName ??
            (parts.length > 1
                ? parts.sublist(1).map(_capitalize).join(' ')
                : ''),
        'email': email,
        if (phone != null) 'phone': phone,
        'role': role == 'admin' || role == 'pastor' ? 'admin' : 'member',
        'is_active': true,
      });

      resolvedMemberId = (member as Map)['id']?.toString();
    }

    // `password` est ignoré : le serveur applique le mot de passe par défaut
    // avec changement obligatoire. Laisser un administrateur choisir celui
    // d'autrui signifierait qu'il le connaît, ce qui rend impossible toute
    // imputabilité des actions du compte.
    final data = await _client.post('/users', body: {
      'member_id': resolvedMemberId,
      'email': email,
      'role': role,
      if (phone != null) 'phone': phone,
    });

    return (data as Map).cast<String, dynamic>();
  }

  /// Met la première lettre en majuscule.
  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  static Future<List<Map<String, dynamic>>> getUsers({
    int? limit,
    int? offset,
    String? role,
    bool? isActive,
  }) {
    final effectiveLimit = limit ?? 100;
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    return _client.getList('/users', query: {
      'page': page,
      'limit': effectiveLimit,
      if (role != null) 'role': role,
      if (isActive != null) 'is_active': isActive,
    });
  }

  static Future<Map<String, dynamic>> getUserById(String userId) =>
      _client.getOne('/users/$userId');

  static Future<Map<String, dynamic>> updateUser({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _client.patch('/users/$userId', body: updates);
    return (data as Map).cast<String, dynamic>();
  }

  /// Active ou désactive un compte.
  ///
  /// La désactivation ferme immédiatement toutes les sessions. Le serveur
  /// refuse de désactiver le dernier administrateur actif — code `LAST_ADMIN` —
  /// faute de quoi l'application deviendrait inadministrable.
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

  static Future<Map<String, dynamic>> resetUserPassword(String userId) async {
    final data = await _client.post('/users/$userId/reset-password');
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteUser(String userId) async {
    await _client.delete('/users/$userId');
  }
}