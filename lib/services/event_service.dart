import 'supabase_service.dart';
import '../core/utils/phone_number_utils.dart';

/// Event service for event management
class EventService {
  static final _client = SupabaseService.client;

  /// Create event
  /// POST /events
  static Future<Map<String, dynamic>> createEvent({
    required Map<String, dynamic> eventData,
  }) async {
    try {
      final response = await _client
          .from('events')
          .insert({
            ...eventData,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }

  /// Get all events (visible to all members)
  /// GET /events
  static Future<List<Map<String, dynamic>>> getEvents({
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _client.from('events').select();

      // Filter out inactive (deleted) events by default
      query = query.eq('is_active', true);

      // Apply date filters
      if (fromDate != null) {
        query = query.gte('event_date', fromDate.toIso8601String());
      }
      if (toDate != null) {
        query = query.lte('event_date', toDate.toIso8601String());
      }

      // Apply other filters
      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null) {
            query = query.eq(key, value);
          }
        });
      }

      // Order by event date (returns PostgrestTransformBuilder)
      dynamic transformQuery = query.order('event_date', ascending: true);

      // Apply pagination (on PostgrestTransformBuilder)
      if (limit != null) {
        transformQuery = transformQuery.limit(limit);
      }
      if (offset != null) {
        transformQuery = transformQuery.range(
          offset,
          offset + (limit ?? 10) - 1,
        );
      }

      final response = await transformQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get events: $e');
    }
  }

  /// Get event by ID
  /// GET /events/:id
  static Future<Map<String, dynamic>> getEventById(String eventId) async {
    try {
      final response = await _client
          .from('events')
          .select()
          .eq('id', eventId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to get event: $e');
    }
  }

  /// Create event sessions
  /// POST /events/:id/sessions
  static Future<List<Map<String, dynamic>>> createEventSessions({
    required String eventId,
    required List<Map<String, dynamic>> sessionsData,
  }) async {
    try {
      final sessions = sessionsData
          .map(
            (session) => {
              'event_id': eventId,
              ...session,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      final response = await _client
          .from('event_sessions')
          .insert(sessions)
          .select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to create event sessions: $e');
    }
  }

  /// Generate sessions for repeated events (on-demand, like classes)
  /// POST /events/:id/sessions/generate
  /// Operational note: For repeated events, treat them like classes with sessions
  static Future<List<Map<String, dynamic>>> generateEventSessions({
    required String eventId,
    required int numberOfSessions,
    DateTime? startDate,
    int? daysBetweenSessions, // Default: 7 (weekly)
  }) async {
    try {
      // Get event to check if it's a repeated event
      final event = await getEventById(eventId);
      final isRepeated = event['is_repeated'] == true;

      if (!isRepeated) {
        throw Exception(
          'Event is not marked as repeated. Use createEventSessions for single events.',
        );
      }

      // Get the last session date to continue from there
      final lastSession = await _client
          .from('event_sessions')
          .select('session_date')
          .eq('event_id', eventId)
          .order('session_date', ascending: false)
          .limit(1)
          .maybeSingle();

      DateTime start;
      if (lastSession != null && lastSession['session_date'] != null) {
        // Continue from last session
        final lastDate = DateTime.parse(lastSession['session_date']);
        final daysBetween = daysBetweenSessions ?? 7;
        start = lastDate.add(Duration(days: daysBetween));
      } else {
        // Start from event date or provided date
        start =
            startDate ??
            (event['event_date'] != null
                ? DateTime.parse(event['event_date'])
                : DateTime.now());
      }

      final sessions = <Map<String, dynamic>>[];
      final daysBetween = daysBetweenSessions ?? 7;

      for (int i = 0; i < numberOfSessions; i++) {
        final sessionDate = start.add(Duration(days: i * daysBetween));

        final session = await _client
            .from('event_sessions')
            .insert({
              'event_id': eventId,
              'session_date': sessionDate.toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        sessions.add(session);
      }

      return sessions;
    } catch (e) {
      throw Exception('Failed to generate event sessions: $e');
    }
  }

  /// Get event session by ID (for repeated events)
  /// GET /events/:eventId/sessions/:sessionId
  static Future<Map<String, dynamic>> getEventSessionById({
    required String eventId,
    required String sessionId,
  }) async {
    try {
      final response = await _client
          .from('event_sessions')
          .select()
          .eq('event_id', eventId)
          .eq('id', sessionId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to get event session: $e');
    }
  }

  /// Record attendance for a specific event session (like class sessions)
  /// POST /events/:eventId/sessions/:sessionId/attendance
  static Future<void> recordEventSessionAttendance({
    required String eventId,
    required String sessionId,
    required List<Map<String, dynamic>> attendanceRecords,
  }) async {
    try {
      // Prepare attendance records
      final records = attendanceRecords
          .map(
            (record) => {
              'event_id': eventId,
              'session_id': sessionId,
              'member_id': record['member_id'],
              'status': record['status'],
              'notes': record['notes'],
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      await _client.from('event_attendance').insert(records);
    } catch (e) {
      throw Exception('Failed to record event session attendance: $e');
    }
  }

  /// Record attendance for event sessions
  /// POST /events/:id/attendance
  static Future<void> recordEventAttendance({
    required String eventId,
    required List<Map<String, dynamic>> attendanceRecords,
  }) async {
    try {
      // Prepare attendance records
      final records = attendanceRecords
          .map(
            (record) => {
              'event_id': eventId,
              'session_id': record['session_id'],
              'member_id': record['member_id'],
              'status': record['status'],
              'notes': record['notes'],
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      await _client.from('event_attendance').insert(records);
    } catch (e) {
      throw Exception('Failed to record event attendance: $e');
    }
  }

  /// Update event
  /// PATCH /events/:id
  static Future<Map<String, dynamic>> updateEvent({
    required String eventId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await _client
          .from('events')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', eventId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }

  /// Delete event (soft delete by setting is_active=false)
  /// DELETE /events/:id
  static Future<void> deleteEvent(String eventId) async {
    try {
      await _client
          .from('events')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', eventId);
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }

  /// Get all sessions for an event
  /// GET /events/:id/sessions
  static Future<List<Map<String, dynamic>>> getEventSessions(
    String eventId,
  ) async {
    try {
      final response = await _client
          .from('event_sessions')
          .select()
          .eq('event_id', eventId)
          .order('session_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get event sessions: $e');
    }
  }

  /// Delete event session
  /// DELETE /events/:id/sessions/:sessionId
  static Future<void> deleteEventSession({
    required String eventId,
    required String sessionId,
  }) async {
    try {
      await _client
          .from('event_sessions')
          .delete()
          .eq('event_id', eventId)
          .eq('id', sessionId);
    } catch (e) {
      throw Exception('Failed to delete event session: $e');
    }
  }

  /// Register member for event
  /// POST /events/:id/register
  static Future<void> registerForEvent({
    required String eventId,
    required String memberId,
  }) async {
    try {
      // Check if already registered
      final existing = await _client
          .from('event_registrations')
          .select()
          .eq('event_id', eventId)
          .eq('member_id', memberId)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Member is already registered for this event');
      }

      await _client.from('event_registrations').insert({
        'event_id': eventId,
        'member_id': memberId,
        'registered_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to register for event: $e');
    }
  }

  /// Register non-member (guest) for event
  /// POST /events/:id/register-guest
  static Future<void> registerGuestForEvent({
    required String eventId,
    required String guestName,
    String? guestEmail,
    String? guestPhone,
  }) async {
    try {
      // For guests, we'll insert with member_id as null and store guest info
      // Note: This requires the event_registrations table to allow NULL member_id
      // and have guest_name, guest_email, guest_phone fields
      // If the schema doesn't support this, we may need to create a separate table
      await _client.from('event_registrations').insert({
        'event_id': eventId,
        'member_id': null, // NULL for guests
        'guest_name': guestName,
        'guest_email': guestEmail,
        'guest_phone': PhoneNumberUtils.normalizeOrNull(guestPhone),
        'registered_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to register guest for event: $e');
    }
  }

  /// Register multiple members for event (leader function)
  /// POST /events/:id/register-members
  static Future<void> registerMembersForEvent({
    required String eventId,
    required List<String> memberIds,
  }) async {
    try {
      // Check which members are already registered
      final existing = await _client
          .from('event_registrations')
          .select('member_id')
          .eq('event_id', eventId)
          .inFilter('member_id', memberIds);

      final existingMemberIds = (existing as List)
          .map((e) => e['member_id']?.toString())
          .whereType<String>()
          .toSet();

      // Filter out already registered members
      final newMemberIds = memberIds
          .where((id) => !existingMemberIds.contains(id))
          .toList();

      if (newMemberIds.isEmpty) {
        throw Exception('All selected members are already registered');
      }

      // Insert registrations for new members
      final registrations = newMemberIds
          .map(
            (memberId) => {
              'event_id': eventId,
              'member_id': memberId,
              'registered_at': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      await _client.from('event_registrations').insert(registrations);
    } catch (e) {
      throw Exception('Failed to register members for event: $e');
    }
  }

  /// Unregister member from event
  /// DELETE /events/:id/register
  static Future<void> unregisterFromEvent({
    required String eventId,
    required String memberId,
  }) async {
    try {
      await _client
          .from('event_registrations')
          .delete()
          .eq('event_id', eventId)
          .eq('member_id', memberId);
    } catch (e) {
      throw Exception('Failed to unregister from event: $e');
    }
  }

  /// Get event registrations
  /// GET /events/:id/registrations
  static Future<List<Map<String, dynamic>>> getEventRegistrations(
    String eventId,
  ) async {
    try {
      final response = await _client
          .from('event_registrations')
          .select('*, members(*)')
          .eq('event_id', eventId)
          .order('registered_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get event registrations: $e');
    }
  }

  /// Remove registration (member or guest)
  /// DELETE /events/:id/registrations/:registrationId
  static Future<void> removeRegistration({
    required String eventId,
    required String registrationId,
  }) async {
    try {
      await _client
          .from('event_registrations')
          .delete()
          .eq('id', registrationId)
          .eq('event_id', eventId);
    } catch (e) {
      throw Exception('Failed to remove registration: $e');
    }
  }

  /// Get attendance for an event (all sessions)
  /// GET /events/:id/attendance
  static Future<List<Map<String, dynamic>>> getEventAttendance(
    String eventId,
  ) async {
    try {
      final response = await _client
          .from('event_attendance')
          .select('*, members(*), event_sessions(*)')
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get event attendance: $e');
    }
  }

  /// Get attendance for a specific event session
  /// GET /events/:id/sessions/:sessionId/attendance
  static Future<List<Map<String, dynamic>>> getEventSessionAttendance({
    required String eventId,
    required String sessionId,
  }) async {
    try {
      final response = await _client
          .from('event_attendance')
          .select('*, members(*)')
          .eq('event_id', eventId)
          .eq('session_id', sessionId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get event session attendance: $e');
    }
  }
}
