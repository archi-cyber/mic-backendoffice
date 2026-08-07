import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Membres.
///
/// Les signatures sont **identiques** à l'implémentation Supabase : les écrans
/// n'ont rien à changer. Seul l'intérieur diffère — appels HTTP au lieu de
/// requêtes sur la base.
///
/// Les clés restent en `snake_case` dans les deux sens : [ApiClient] fait la
/// conversion vers et depuis le camelCase de l'API.
class MemberService {
  static ApiClient get _client => AuthService.client;

  /// Crée un membre.
  ///
  /// Une intention `just_passing` est refusée par le serveur avec le code
  /// `JUST_PASSING_MUST_BE_VISITOR` : ces personnes relèvent des visiteurs.
  /// La vérification n'est plus faite ici — la dupliquer risquerait de la
  /// laisser diverger de la règle serveur.
  static Future<Map<String, dynamic>> createMember({
    required Map<String, dynamic> memberData,
  }) async {
    final data = await _client.post('/members', body: memberData);
    debugPrint('[MemberService] Membre créé');
    return (data as Map).cast<String, dynamic>();
  }

  /// Liste des membres.
  ///
  /// [filters] accepte les mêmes clés qu'auparavant : `role`, `department_id`,
  /// `is_active`, `is_new_comer`, `gender`, `profession`, `search`.
  static Future<List<Map<String, dynamic>>> getMembers({
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
    String? orderBy,
    bool ascending = true,
  }) async {
    // L'API pagine par numéro de page, l'ancienne interface par décalage.
    // La conversion est faite ici pour ne pas propager le changement dans les
    // écrans.
    final effectiveLimit = (limit ?? 200).clamp(1, 200);
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    final query = <String, dynamic>{
      'page': page,
      'limit': effectiveLimit,
      'order': ascending ? 'asc' : 'desc',
      if (orderBy != null) 'orderBy': orderBy,
      ...?filters,
    };

    return _client.getList('/members', query: query);
  }

  static Future<Map<String, dynamic>> getMemberById(String memberId) =>
      _client.getOne('/members/$memberId');

  static Future<Map<String, dynamic>> updateMember({
    required String memberId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _client.patch('/members/$memberId', body: updates);
    return (data as Map).cast<String, dynamic>();
  }

  /// Suppression logique.
  ///
  /// Le compte de connexion associé est désactivé et ses sessions fermées, du
  /// côté serveur et dans la même transaction.
  static Future<void> deleteMember(String memberId) async {
    await _client.delete('/members/$memberId');
  }

  /// Restaure un membre supprimé. Réservé aux administrateurs.
  static Future<Map<String, dynamic>> restoreMember(String memberId) async {
    final data = await _client.post('/members/$memberId/restore');
    return (data as Map).cast<String, dynamic>();
  }

  /// Anniversaires à venir.
  static Future<List<Map<String, dynamic>>> getUpcomingBirthdays({
    int days = 30,
  }) =>
      _client.getList('/members/birthdays', query: {'days': days});

  /// Rattache le membre à un département.
  static Future<Map<String, dynamic>> addToDepartment({
    required String memberId,
    required String departmentId,
    String role = 'member',
    bool isMain = false,
  }) async {
    final data = await _client.post(
      '/members/$memberId/departments',
      body: {
        'department_id': departmentId,
        'role': role,
        'is_main': isMain,
      },
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> removeFromDepartment({
    required String memberId,
    required String departmentId,
  }) async {
    await _client.delete('/members/$memberId/departments/$departmentId');
  }
}