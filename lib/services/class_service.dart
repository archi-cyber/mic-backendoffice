import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Formations, séances et présence.
///
/// Signatures identiques à l'implémentation Supabase.
///
/// Contrairement au culte, une formation a une **liste fermée** : seuls les
/// inscrits peuvent être pointés. Le serveur refuse les autres avec le code
/// `NOT_ENROLLED`, ce qui préserve la justesse des taux d'assiduité.
class ClassService {
  static ApiClient get _client => AuthService.client;

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // Formations
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> createClass({
    required Map<String, dynamic> classData,
  }) async {
    final data = await _client.post('/classes', body: classData);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getClasses({
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
    String? orderBy,
    bool ascending = true,
  }) {
    final effectiveLimit = (limit ?? 200).clamp(1, 200);
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    return _client.getList('/classes', query: {
      'page': page,
      'limit': effectiveLimit,
      'order': ascending ? 'asc' : 'desc',
      if (orderBy != null) 'orderBy': orderBy,
      ...?filters,
    });
  }

  /// Détail d'une formation, avec ses inscrits et ses séances.
  static Future<Map<String, dynamic>> getClassById(String classId) =>
      _client.getOne('/classes/$classId');

  static Future<Map<String, dynamic>> updateClass({
    required String classId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _client.patch('/classes/$classId', body: updates);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteClass(String classId) async {
    await _client.delete('/classes/$classId');
  }

  /// Taux d'assiduité de chaque inscrit sur l'ensemble des séances.
  static Future<Map<String, dynamic>> getClassReport(String classId) =>
      _client.getOne('/classes/$classId/report');

  // ---------------------------------------------------------------------------
  // Inscriptions
  // ---------------------------------------------------------------------------

  /// Inscrits d'une formation.
  ///
  /// Extraits du détail : une seule requête suffit là où l'ancienne version
  /// en faisait deux.
  static Future<List<Map<String, dynamic>>> getClassMembers(
    String classId,
  ) async {
    final training = await _client.getOne('/classes/$classId');
    final members = (training['members'] as List?) ?? const [];
    return members.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>> addMemberToClass({
    required String classId,
    required String memberId,
  }) async {
    final data = await _client.post(
      '/classes/$classId/members',
      body: {'member_ids': [memberId]},
    );
    return (data as Map).cast<String, dynamic>();
  }

  /// Retire une inscription.
  ///
  /// Les présences déjà enregistrées sont conservées : elles attestent d'une
  /// participation réelle, utile pour délivrer une attestation même si la
  /// personne a quitté le cycle en cours de route.
  static Future<void> removeMemberFromClass({
    required String classId,
    required String memberId,
  }) async {
    await _client.delete('/classes/$classId/members/$memberId');
  }

  // ---------------------------------------------------------------------------
  // Séances
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getClassSessions(
    String classId,
  ) async {
    final training = await _client.getOne('/classes/$classId');
    final sessions = (training['sessions'] as List?) ?? const [];
    return sessions.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Génère des séances à intervalle régulier.
  ///
  /// Les dates déjà occupées sont ignorées : relancer la génération pour
  /// prolonger un cycle ne provoque pas d'erreur.
  static Future<Map<String, dynamic>> generateSessions({
    required String classId,
    required int numberOfSessions,
    DateTime? startDate,
    int? weeksBetweenSessions,
  }) async {
    final data = await _client.post(
      '/classes/$classId/sessions/generate',
      body: {
        'count': numberOfSessions,
        'start_date': _day(startDate ?? DateTime.now()),
        'weeks_between': weeksBetweenSessions ?? 1,
      },
    );
    return (data as Map).cast<String, dynamic>();
  }

  /// Feuille de présence d'une séance, limitée aux inscrits.
  static Future<Map<String, dynamic>> getSessionById(String sessionId) =>
      _client.getOne('/class-sessions/$sessionId');

  /// Présences enregistrées pour une séance.
  ///
  /// Ne renvoie que les lignes réellement pointées : la feuille contient aussi
  /// les inscrits sans statut, dont l'absence de valeur ne constitue pas une
  /// présence.
  static Future<List<Map<String, dynamic>>> getSessionAttendance(
    String sessionId,
  ) async {
    final session = await _client.getOne('/class-sessions/$sessionId');
    final sheet = (session['sheet'] as List?) ?? const [];

    return sheet
        .map((e) => (e as Map).cast<String, dynamic>())
        .where((row) => row['status'] != null)
        .toList();
  }

  /// Enregistre la présence d'une séance.
  ///
  /// Chaque entrée : `{'member_id': '...', 'status': 'present'|'absent'|
  /// 'excused'|'late', 'notes': '...'}`
  static Future<Map<String, dynamic>> recordAttendance({
    required String sessionId,
    required List<Map<String, dynamic>> attendanceRecords,
  }) async {
    final data = await _client.post(
      '/class-sessions/$sessionId/attendance',
      body: {'entries': attendanceRecords},
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteSession(String sessionId) async {
    await _client.delete('/class-sessions/$sessionId');
  }
}