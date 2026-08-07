import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Événements, séances, inscriptions et présence.
///
/// Signatures identiques à l'implémentation Supabase.
class EventService {
  static ApiClient get _client => AuthService.client;

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // Événements
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> createEvent({
    required Map<String, dynamic> eventData,
  }) async {
    final data = await _client.post('/events', body: eventData);
    return (data as Map).cast<String, dynamic>();
  }

  /// Liste des événements.
  ///
  /// [filters] accepte les mêmes clés qu'auparavant : `is_active`, `upcoming`,
  /// `search`.
  static Future<List<Map<String, dynamic>>> getEvents({
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final effectiveLimit = (limit ?? 200).clamp(1, 200);
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    return _client.getList('/events', query: {
      'page': page,
      'limit': effectiveLimit,
      if (fromDate != null) 'from': _day(fromDate),
      if (toDate != null) 'to': _day(toDate),
      ...?filters,
    });
  }

  /// Détail d'un événement, avec ses séances, inscriptions et décomptes.
  static Future<Map<String, dynamic>> getEventById(String eventId) =>
      _client.getOne('/events/$eventId');

  static Future<Map<String, dynamic>> updateEvent({
    required String eventId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _client.patch('/events/$eventId', body: updates);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteEvent(String eventId) async {
    await _client.delete('/events/$eventId');
  }

  // ---------------------------------------------------------------------------
  // Séances
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getEventSessions(
    String eventId,
  ) async {
    final event = await _client.getOne('/events/$eventId');
    final sessions = (event['sessions'] as List?) ?? const [];
    return sessions.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Crée plusieurs séances à partir d'une liste de dates.
  static Future<List<Map<String, dynamic>>> createEventSessions({
    required String eventId,
    required List<Map<String, dynamic>> sessionsData,
  }) async {
    final created = <Map<String, dynamic>>[];

    for (final session in sessionsData) {
      final date = session['session_date'] ?? session['sessionDate'];
      if (date == null) continue;

      final data = await _client.post(
        '/events/$eventId/sessions',
        body: {'session_date': date.toString()},
      );
      created.add((data as Map).cast<String, dynamic>());
    }

    return created;
  }

  /// Génère des séances à intervalle régulier.
  ///
  /// L'API crée les séances une par une : le calcul des dates est fait ici,
  /// ce qui évite de le disperser dans les écrans et garantit un espacement
  /// cohérent.
  static Future<List<Map<String, dynamic>>> generateEventSessions({
    required String eventId,
    required int numberOfSessions,
    DateTime? startDate,
    int? daysBetweenSessions,
  }) async {
    final start = startDate ?? DateTime.now();
    final gap = daysBetweenSessions ?? 7;
    final created = <Map<String, dynamic>>[];

    for (var i = 0; i < numberOfSessions; i++) {
      final date = start.add(Duration(days: i * gap));

      final data = await _client.post(
        '/events/$eventId/sessions',
        body: {'session_date': date.toIso8601String()},
      );
      created.add((data as Map).cast<String, dynamic>());
    }

    return created;
  }

  static Future<Map<String, dynamic>?> getEventSessionById({
    required String eventId,
    required String sessionId,
  }) async {
    final sessions = await getEventSessions(eventId);

    for (final session in sessions) {
      if (session['id'] == sessionId) return session;
    }

    return null;
  }

  static Future<void> deleteEventSession({
    required String eventId,
    required String sessionId,
  }) async {
    await _client.delete('/events/sessions/$sessionId');
  }

  // ---------------------------------------------------------------------------
  // Inscriptions
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getEventRegistrations(
    String eventId,
  ) async {
    final event = await _client.getOne('/events/$eventId');
    final registrations = (event['registrations'] as List?) ?? const [];
    return registrations.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  static Future<Map<String, dynamic>> registerForEvent({
    required String eventId,
    required String memberId,
  }) async {
    final data = await _client.post(
      '/events/$eventId/registrations',
      body: {'member_id': memberId},
    );
    return (data as Map).cast<String, dynamic>();
  }

  /// Inscrit un invité externe.
  ///
  /// Membre et invité sont exclusifs : un invité n'a pas de fiche membre, et
  /// un membre n'a pas besoin qu'on ressaisisse son nom. Accepter les deux
  /// créerait des doublons impossibles à réconcilier au décompte.
  static Future<Map<String, dynamic>> registerGuestForEvent({
    required String eventId,
    required String guestName,
    String? guestEmail,
    String? guestPhone,
  }) async {
    final data = await _client.post('/events/$eventId/registrations', body: {
      'guest_name': guestName,
      if (guestEmail != null) 'guest_email': guestEmail,
      if (guestPhone != null) 'guest_phone': guestPhone,
    });
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> registerMembersForEvent({
    required String eventId,
    required List<String> memberIds,
  }) async {
    final data = await _client.post(
      '/events/$eventId/registrations/bulk',
      body: {'member_ids': memberIds},
    );
    return (data as Map).cast<String, dynamic>();
  }

  /// Désinscrit un membre.
  ///
  /// L'inscription est retrouvée par son membre : l'API supprime par
  /// identifiant d'inscription, non par couple événement + membre.
  static Future<void> unregisterFromEvent({
    required String eventId,
    required String memberId,
  }) async {
    final registrations = await getEventRegistrations(eventId);

    for (final registration in registrations) {
      final member = (registration['member'] as Map?)?.cast<String, dynamic>();
      if (member?['id'] == memberId) {
        await _client.delete('/events/registrations/${registration['id']}');
        return;
      }
    }
  }

  static Future<void> removeRegistration({
    required String eventId,
    required String registrationId,
  }) async {
    await _client.delete('/events/registrations/$registrationId');
  }

  // ---------------------------------------------------------------------------
  // Présence
  // ---------------------------------------------------------------------------

  /// Enregistre la présence à l'événement, toutes séances confondues.
  ///
  /// Chaque entrée : `{'member_id': '...', 'status': 'present'|'absent'|
  /// 'excused'|'late', 'notes': '...'}`
  static Future<Map<String, dynamic>> recordEventAttendance({
    required String eventId,
    required List<Map<String, dynamic>> attendanceRecords,
  }) async {
    final data = await _client.post('/events/$eventId/attendance', body: {
      'entries': attendanceRecords,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Enregistre la présence à une séance précise.
  static Future<Map<String, dynamic>> recordEventSessionAttendance({
    required String eventId,
    required String sessionId,
    required List<Map<String, dynamic>> attendanceRecords,
  }) async {
    final data = await _client.post('/events/$eventId/attendance', body: {
      'session_id': sessionId,
      'entries': attendanceRecords,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Présences enregistrées pour l'événement.
  static Future<List<Map<String, dynamic>>> getEventAttendance(
    String eventId,
  ) async {
    final event = await _client.getOne('/events/$eventId');
    final attendances = (event['attendances'] as List?) ?? const [];
    return attendances.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Présences d'une séance précise.
  static Future<List<Map<String, dynamic>>> getEventSessionAttendance({
    required String eventId,
    required String sessionId,
  }) async {
    final all = await getEventAttendance(eventId);
    return all.where((row) => row['session_id'] == sessionId).toList();
  }
}