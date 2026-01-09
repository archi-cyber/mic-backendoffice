import 'supabase_service.dart';

/// Training service for trainings and sessions management
class ClassService {
  static final _client = SupabaseService.client;

  /// Create training
  /// POST /classes
  static Future<Map<String, dynamic>> createClass({
    required Map<String, dynamic> classData,
  }) async {
    try {
      final response = await _client
          .from('classes')
          .insert({
            ...classData,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to create training: $e');
    }
  }

  /// Get all trainings
  /// GET /classes
  static Future<List<Map<String, dynamic>>> getClasses({
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
    String? orderBy,
    bool ascending = true,
  }) async {
    try {
      // Build base query with filters
      var filterQuery = _client.from('classes').select();

      // Apply filters
      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null) {
            filterQuery = filterQuery.eq(key, value);
          }
        });
      }

      // Apply ordering (returns PostgrestTransformBuilder)
      var transformQuery = orderBy != null
          ? filterQuery.order(orderBy, ascending: ascending)
          : filterQuery.order('created_at', ascending: false);

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
      throw Exception('Failed to get trainings: $e');
    }
  }

  /// Get training by ID
  /// GET /classes/:id
  static Future<Map<String, dynamic>> getClassById(String classId) async {
    try {
      final response = await _client
          .from('classes')
          .select()
          .eq('id', classId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to get training: $e');
    }
  }

  /// Update class
  /// Update training
  /// PATCH /classes/:id
  static Future<Map<String, dynamic>> updateClass({
    required String classId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await _client
          .from('classes')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', classId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to update training: $e');
    }
  }

  /// Delete class (soft delete by setting is_active=false)
  /// DELETE /classes/:id
  static Future<void> deleteClass(String classId) async {
    try {
      await _client
          .from('classes')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', classId);
    } catch (e) {
      throw Exception('Failed to delete training: $e');
    }
  }

  /// Get sessions for a class
  static Future<List<Map<String, dynamic>>> getClassSessions(
    String classId,
  ) async {
    try {
      final response = await _client
          .from('sessions')
          .select()
          .eq('class_id', classId)
          .order('session_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get training sessions: $e');
    }
  }

  /// Get members enrolled in a class
  static Future<List<Map<String, dynamic>>> getClassMembers(
    String classId,
  ) async {
    try {
      final response = await _client
          .from('class_members')
          .select('*, members(*)')
          .eq('class_id', classId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get training members: $e');
    }
  }

  /// Generate next N sessions for a class (on-demand generation)
  /// POST /classes/:id/sessions/generate
  /// Operational note: Prefer on-demand generation instead of infinite sessions
  static Future<List<Map<String, dynamic>>> generateSessions({
    required String classId,
    required int numberOfSessions,
    DateTime? startDate,
    int? weeksBetweenSessions, // Default: 1 (weekly)
  }) async {
    try {
      // Get the last session date to continue from there
      final lastSession = await _client
          .from('sessions')
          .select('session_date')
          .eq('class_id', classId)
          .order('session_date', ascending: false)
          .limit(1)
          .maybeSingle();

      DateTime start;
      if (lastSession != null && lastSession['session_date'] != null) {
        // Continue from last session
        final lastDate = DateTime.parse(lastSession['session_date']);
        final weeksBetween = weeksBetweenSessions ?? 1;
        start = lastDate.add(Duration(days: weeksBetween * 7));
      } else {
        // Start from provided date or now
        start = startDate ?? DateTime.now();
      }

      final sessions = <Map<String, dynamic>>[];
      final weeksBetween = weeksBetweenSessions ?? 1;

      for (int i = 0; i < numberOfSessions; i++) {
        final sessionDate = start.add(Duration(days: i * weeksBetween * 7));

        final session = await _client
            .from('sessions')
            .insert({
              'class_id': classId,
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
      throw Exception('Failed to generate sessions: $e');
    }
  }

  /// Get session by ID
  /// GET /sessions/:id
  static Future<Map<String, dynamic>> getSessionById(String sessionId) async {
    try {
      final response = await _client
          .from('sessions')
          .select()
          .eq('id', sessionId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to get session: $e');
    }
  }

  /// Get attendance for a session
  /// GET /sessions/:id/attendance
  static Future<List<Map<String, dynamic>>> getSessionAttendance(
    String sessionId,
  ) async {
    try {
      final response = await _client
          .from('attendance')
          .select()
          .eq('session_id', sessionId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get session attendance: $e');
    }
  }

  /// Record bulk attendance for a session
  /// POST /sessions/:id/attendance
  static Future<void> recordAttendance({
    required String sessionId,
    required List<Map<String, dynamic>> attendanceRecords,
  }) async {
    try {
      // Get existing attendance records for this session to avoid duplicates
      final existingAttendance = await _client
          .from('attendance')
          .select('id, member_id')
          .eq('session_id', sessionId);

      final existingMemberIds = (existingAttendance as List)
          .map((record) => record['member_id']?.toString())
          .where((id) => id != null)
          .toSet();

      // Separate records into new and updates
      final recordsToInsert = <Map<String, dynamic>>[];
      final recordsToUpdate = <Map<String, dynamic>>[];

      for (final record in attendanceRecords) {
        final memberId = record['member_id']?.toString();
        if (memberId == null) continue;

        final attendanceData = {
          'session_id': sessionId,
          'member_id': memberId,
          'status': record['status'], // 'present', 'absent', 'late', etc.
          'notes': record['notes'],
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (existingMemberIds.contains(memberId)) {
          // Update existing record
          recordsToUpdate.add(attendanceData);
        } else {
          // Insert new record
          recordsToInsert.add({
            ...attendanceData,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // Insert new records
      if (recordsToInsert.isNotEmpty) {
        await _client.from('attendance').insert(recordsToInsert);
      }

      // Update existing records
      for (final record in recordsToUpdate) {
        await _client
            .from('attendance')
            .update({
              'status': record['status'],
              'notes': record['notes'],
              'updated_at': record['updated_at'],
            })
            .eq('session_id', sessionId)
            .eq('member_id', record['member_id']);
      }
    } catch (e) {
      throw Exception('Failed to record attendance: $e');
    }
  }

  /// Add member to class
  /// POST /classes/:id/members
  static Future<void> addMemberToClass({
    required String classId,
    required String memberId,
  }) async {
    try {
      // Check if member is already in class
      final existing = await _client
          .from('class_members')
          .select()
          .eq('class_id', classId)
          .eq('member_id', memberId)
          .maybeSingle();

      if (existing != null) {
        throw Exception('Member is already enrolled in this class');
      }

      // Add member to class
      await _client.from('class_members').insert({
        'class_id': classId,
        'member_id': memberId,
        'enrolled_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to add member to training: $e');
    }
  }

  /// Remove member from class
  /// DELETE /classes/:id/members/:memberId
  static Future<void> removeMemberFromClass({
    required String classId,
    required String memberId,
  }) async {
    try {
      await _client
          .from('class_members')
          .delete()
          .eq('class_id', classId)
          .eq('member_id', memberId);
    } catch (e) {
      throw Exception('Failed to remove member from training: $e');
    }
  }
}
