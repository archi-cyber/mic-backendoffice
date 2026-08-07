import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Planning de service — typiquement l'équipe média.
///
/// Signatures identiques à l'implémentation Supabase.
class ServiceScheduleService {
  static ApiClient get _client => AuthService.client;

  /// Noms reconnus comme département média.
  ///
  /// Le planning de service est conçu pour cette équipe : projection,
  /// captation, cadreurs, photographe. Les deux orthographes sont acceptées,
  /// insensibles à la casse.
  static const _mediaDepartmentNames = <String>['média', 'media'];

  /// Indique si un département est l'équipe média.
  ///
  /// Sert à n'afficher l'onglet Planning que là où il a un sens. Le serveur ne
  /// pose pas cette restriction — un autre département peut techniquement
  /// avoir un planning — mais l'exposer partout encombrerait l'interface.
  static bool isMediaTeamDepartment(dynamic department) {
    final name = department is Map
        ? department['name']?.toString()
        : department?.toString();

    if (name == null) return false;

    return _mediaDepartmentNames.contains(name.trim().toLowerCase());
  }

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Assignations d'un planning pour un poste donné.
  ///
  /// Le serveur renvoie `assignments` là où Supabase renvoyait
  /// `service_schedule_assignments` ; les deux clés sont acceptées pour ne pas
  /// casser les écrans qui liraient encore l'ancienne.
  static List<Map<String, dynamic>> _assignmentsFor(
    Map<String, dynamic> schedule,
    String role,
  ) {
    final rows = schedule['assignments'] ??
        schedule['service_schedule_assignments'] ??
        const [];

    if (rows is! List) return const [];

    return rows
        .map((e) => (e as Map).cast<String, dynamic>())
        .where((row) => row['role'] == role)
        .toList();
  }

  /// Expose la même logique aux écrans.
  static List<Map<String, dynamic>> assignmentsFor(
    Map<String, dynamic> schedule,
    String role,
  ) =>
      _assignmentsFor(schedule, role);

  // ---------------------------------------------------------------------------
  // Plannings
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getSchedules({
    required String departmentId,
    int limit = 200,
  }) =>
      _client.getList('/service-schedules', query: {
        'department_id': departmentId,
        'limit': limit,
      });

  /// Crée un planning.
  ///
  /// Un seul par département et par date : le serveur refuse un doublon avec
  /// le code `SCHEDULE_ALREADY_EXISTS`. Deux plannings concurrents pour le
  /// même service laisseraient l'équipe sans savoir lequel fait foi.
  static Future<Map<String, dynamic>> createSchedule({
    required String departmentId,
    required DateTime serviceDate,
    String? notes,
  }) async {
    final data = await _client.post('/service-schedules', body: {
      'department_id': departmentId,
      'service_date': _day(serviceDate),
      if (notes != null) 'notes': notes,
    });
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> updateNotes({
    required String scheduleId,
    String? notes,
  }) async {
    await _client.patch('/service-schedules/$scheduleId', body: {'notes': notes});
  }

  static Future<void> deleteSchedule(String scheduleId) async {
    await _client.delete('/service-schedules/$scheduleId');
  }

  // ---------------------------------------------------------------------------
  // Assignations
  // ---------------------------------------------------------------------------

  /// Attribue un poste à un membre.
  ///
  /// Le membre est notifié côté serveur : sans cela, il découvrirait son
  /// service en arrivant, ou pas du tout.
  ///
  /// [serviceDateLabel] est repris tel quel dans le message de notification,
  /// ce qui permet d'y mettre une date formatée dans la langue de l'utilisateur.
  static Future<Map<String, dynamic>> addAssignment({
    required Map<String, dynamic> schedule,
    required String role,
    required String memberId,
    required String serviceDateLabel,
  }) async {
    final scheduleId = schedule['id'] as String;

    final data = await _client.post(
      '/service-schedules/$scheduleId/assignments',
      body: {'role': role, 'member_id': memberId},
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> removeAssignment(String assignmentId) async {
    await _client.delete('/service-schedules/assignments/$assignmentId');
  }

  /// Marque un poste comme assuré, ou revient dessus.
  static Future<void> setAssignmentDone({
    required String assignmentId,
    required bool isDone,
  }) async {
    await _client.patch(
      '/service-schedules/assignments/$assignmentId/done',
      body: {'is_done': isDone},
    );
  }
}