import '../core/api/api_client.dart';
import 'auth_service.dart';

/// École du dimanche — enfants de 0 à 12 ans.
///
/// Signatures identiques à l'implémentation Supabase.
///
/// Le serveur refuse un membre plus âgé avec le code
/// `MEMBER_TOO_OLD_FOR_SUNDAY_SCHOOL`, et un membre sans date de naissance
/// avec `BIRTHDAY_REQUIRED` : son éligibilité ne peut pas être établie.
class SundaySchoolAttendanceService {
  static ApiClient get _client => AuthService.client;

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // Saisie
  // ---------------------------------------------------------------------------

  /// Marque la présence d'un enfant.
  ///
  /// L'API travaille par lot ; un enfant seul est envoyé comme une liste d'un
  /// élément. Attention : le remplacement étant total pour la date, cet appel
  /// **retirerait** tous les autres enfants déjà marqués. Utiliser
  /// [markBulkAttendance] avec la liste complète pour une feuille de présence.
  static Future<Map<String, dynamic>> markAttendance({
    required String memberId,
    required DateTime attendanceDate,
  }) async {
    final existing = await getDateAttendance(attendanceDate: attendanceDate);

    final memberIds = existing
        .map((row) => row['member_id'] as String?)
        .whereType<String>()
        .toSet()
      ..add(memberId);

    final data = await _client.post('/sunday-school', body: {
      'attendance_date': _day(attendanceDate),
      'member_ids': memberIds.toList(),
    });

    return (data as Map).cast<String, dynamic>();
  }

  /// Enregistre la feuille de présence d'une date.
  ///
  /// Le remplacement est **total** : les enfants absents de la liste voient
  /// leur présence retirée. C'est ce qui permet de corriger une saisie — sans
  /// cela, décocher un enfant n'aurait aucun effet.
  static Future<List<Map<String, dynamic>>> markBulkAttendance({
    required List<String> memberIds,
    required DateTime attendanceDate,
  }) async {
    await _client.post('/sunday-school', body: {
      'attendance_date': _day(attendanceDate),
      'member_ids': memberIds,
    });

    return getDateAttendance(attendanceDate: attendanceDate);
  }

  /// Met à jour la présence d'une session.
  ///
  /// Même opération que [markBulkAttendance], le remplacement étant total.
  static Future<void> updateSessionAttendance({
    required DateTime attendanceDate,
    required List<String> memberIds,
  }) async {
    await _client.post('/sunday-school', body: {
      'attendance_date': _day(attendanceDate),
      'member_ids': memberIds,
    });
  }

  // ---------------------------------------------------------------------------
  // Consultation
  // ---------------------------------------------------------------------------

  /// Présences enregistrées à une date.
  ///
  /// Renvoie uniquement les enfants **présents**. Pour la feuille de saisie
  /// complète, avec les éligibles non pointés, utiliser [getSessionSheet].
  static Future<List<Map<String, dynamic>>> getDateAttendance({
    required DateTime attendanceDate,
  }) async {
    final data = await _client.getOne(
      '/sunday-school/date/${_day(attendanceDate)}',
    );

    final sheet = (data['sheet'] as List?) ?? const [];

    return sheet
        .map((e) => (e as Map).cast<String, dynamic>())
        .where((row) => row['is_present'] == true)
        .map((row) => {
              'member_id': row['id'],
              'attendance_date': _day(attendanceDate),
              'member': row,
            })
        .toList();
  }

  /// Feuille de présence complète d'une date.
  ///
  /// Contient tous les enfants éligibles avec un indicateur `is_present`,
  /// prêt pour l'écran de saisie.
  static Future<Map<String, dynamic>> getSessionSheet(
    DateTime attendanceDate,
  ) =>
      _client.getOne('/sunday-school/date/${_day(attendanceDate)}');

  /// Enfants éligibles, avec leur âge calculé.
  static Future<List<Map<String, dynamic>>> getEligibleChildren({
    int maxAge = 12,
  }) =>
      _client.getList('/sunday-school/children', query: {'maxAge': maxAge});

  /// Sessions passées.
  static Future<List<Map<String, dynamic>>> getAllSessions({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) =>
      _client.getList('/sunday-school', query: {
        if (startDate != null) 'from': _day(startDate),
        if (endDate != null) 'to': _day(endDate),
        'limit': limit ?? 300,
      });

  /// Historique de présence, filtrable par membre.
  static Future<List<Map<String, dynamic>>> getHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? memberId,
    int? limit,
  }) =>
      _client.getList('/sunday-school', query: {
        if (startDate != null) 'from': _day(startDate),
        if (endDate != null) 'to': _day(endDate),
        if (memberId != null) 'member_id': memberId,
        'limit': limit ?? 300,
      });

  // ---------------------------------------------------------------------------
  // Suppression
  // ---------------------------------------------------------------------------

  /// Retire un enfant de la feuille de présence.
  ///
  /// L'API ne supprime pas une ligne isolée : la feuille est réenvoyée sans
  /// l'enfant concerné. [attendanceDate] est donc nécessaire.
  static Future<void> removeAttendance(
    String attendanceId, {
    DateTime? attendanceDate,
    String? memberId,
  }) async {
    if (attendanceDate == null || memberId == null) {
      throw ArgumentError(
        'attendanceDate et memberId sont requis : la feuille est réenvoyée '
        'sans l\'enfant concerné, il n\'y a pas de suppression unitaire.',
      );
    }

    final existing = await getDateAttendance(attendanceDate: attendanceDate);

    final memberIds = existing
        .map((row) => row['member_id'] as String?)
        .whereType<String>()
        .where((id) => id != memberId)
        .toList();

    await _client.post('/sunday-school', body: {
      'attendance_date': _day(attendanceDate),
      'member_ids': memberIds,
    });
  }

  /// Supprime toute la session d'une date.
  static Future<void> deleteSession(DateTime attendanceDate) async {
    await _client.delete('/sunday-school/date/${_day(attendanceDate)}');
  }
}