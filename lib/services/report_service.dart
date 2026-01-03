import 'supabase_service.dart';

/// Report service for generating reports
class ReportService {
  static final _client = SupabaseService.client;

  /// Get member report
  /// GET /reports/member/:memberId?from=&to=
  static Future<Map<String, dynamic>> getMemberReport({
    required String memberId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Build query for member attendance
      var attendanceQuery = _client
          .from('attendance')
          .select()
          .eq('member_id', memberId);

      if (fromDate != null) {
        attendanceQuery = attendanceQuery.gte(
          'created_at',
          fromDate.toIso8601String(),
        );
      }
      if (toDate != null) {
        attendanceQuery = attendanceQuery.lte(
          'created_at',
          toDate.toIso8601String(),
        );
      }

      final attendance = await attendanceQuery;

      // Get member giving records
      var givingQuery = _client
          .from('giving')
          .select()
          .eq('member_id', memberId);

      if (fromDate != null) {
        givingQuery = givingQuery.gte('date', fromDate.toIso8601String());
      }
      if (toDate != null) {
        givingQuery = givingQuery.lte('date', toDate.toIso8601String());
      }

      final giving = await givingQuery;

      // Calculate statistics
      final totalAttendance = (attendance as List).length;
      final totalGiving = (giving as List).fold<double>(
        0.0,
        (sum, record) => sum + (record['amount'] ?? 0.0),
      );

      return {
        'member_id': memberId,
        'period': {
          'from': fromDate?.toIso8601String(),
          'to': toDate?.toIso8601String(),
        },
        'attendance': {'total': totalAttendance, 'records': attendance},
        'giving': {'total': totalGiving, 'records': giving},
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to generate member report: $e');
    }
  }

  /// Get class report
  /// GET /reports/class/:classId?from=&to=
  static Future<Map<String, dynamic>> getClassReport({
    required String classId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Get all sessions for the class
      var sessionsQuery = _client
          .from('sessions')
          .select()
          .eq('class_id', classId);

      if (fromDate != null) {
        sessionsQuery = sessionsQuery.gte(
          'session_date',
          fromDate.toIso8601String(),
        );
      }
      if (toDate != null) {
        sessionsQuery = sessionsQuery.lte(
          'session_date',
          toDate.toIso8601String(),
        );
      }

      final sessions = await sessionsQuery;

      // Get attendance for all sessions
      final sessionIds = (sessions as List).map((s) => s['id']).toList();

      var attendanceQuery = _client
          .from('attendance')
          .select()
          .inFilter('session_id', sessionIds);

      final attendance = await attendanceQuery;

      // Calculate statistics
      final totalSessions = sessions.length;
      final attendanceList = attendance as List;
      // Total attendance should count only 'present' records (actual attendance)
      final totalAttendance = attendanceList
          .where((record) =>
              record['status']?.toString().toLowerCase() == 'present')
          .length;
      final uniqueMembers = attendanceList
          .map((a) => a['member_id'])
          .toSet()
          .length;

      return {
        'class_id': classId,
        'period': {
          'from': fromDate?.toIso8601String(),
          'to': toDate?.toIso8601String(),
        },
        'sessions': {'total': totalSessions, 'records': sessions},
        'attendance': {
          'total': totalAttendance,
          'unique_members': uniqueMembers,
          'records': attendance,
        },
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to generate class report: $e');
    }
  }
}
