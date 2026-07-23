import 'supabase_service.dart';
import 'new_comer_service.dart';
import 'members_report_service.dart';

/// Report service for generating reports
class ReportService {
  static final _client = SupabaseService.client;

  static String _churchServiceDisplayName(Map<String, dynamic> record) {
    final joined = record['church_service'];
    if (joined is Map) {
      final name = joined['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return 'Church service';
  }

  /// Get member report
  /// GET /reports/member/:memberId?from=&to=
  static Future<Map<String, dynamic>> getMemberReport({
    required String memberId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Get church attendance records
      var churchAttendanceQuery = _client
          .from('church_attendance')
          .select('*, church_service:church_services(name)')
          .eq('member_id', memberId);

      if (fromDate != null) {
        churchAttendanceQuery = churchAttendanceQuery.gte(
          'service_date',
          fromDate.toIso8601String().split('T')[0],
        );
      }
      if (toDate != null) {
        churchAttendanceQuery = churchAttendanceQuery.lte(
          'service_date',
          toDate.toIso8601String().split('T')[0],
        );
      }

      final churchAttendance = await churchAttendanceQuery;

      // Get Sunday school attendance records
      var sundaySchoolAttendanceQuery = _client
          .from('sunday_school_attendance')
          .select('*')
          .eq('member_id', memberId);

      if (fromDate != null) {
        sundaySchoolAttendanceQuery = sundaySchoolAttendanceQuery.gte(
          'attendance_date',
          fromDate.toIso8601String().split('T')[0],
        );
      }
      if (toDate != null) {
        sundaySchoolAttendanceQuery = sundaySchoolAttendanceQuery.lte(
          'attendance_date',
          toDate.toIso8601String().split('T')[0],
        );
      }

      final sundaySchoolAttendance = await sundaySchoolAttendanceQuery;

      // Combine and format attendance records
      final allAttendanceRecords = <Map<String, dynamic>>[];

      // Add church attendance records with type indicator (filter out deleted)
      for (var record in churchAttendance as List) {
        if (record['deleted_at'] == null) {
          allAttendanceRecords.add({
            ...record,
            'attendance_category': 'church',
            'display_date': record['service_date'],
            'display_type': _churchServiceDisplayName(record),
            'attendance_type_display': record['attendance_type'] == 'onsite'
                ? 'Onsite'
                : record['attendance_type'] == 'online'
                ? 'Online'
                : 'Absent',
          });
        }
      }

      // Add Sunday school attendance records with type indicator (filter out deleted)
      for (var record in sundaySchoolAttendance as List) {
        if (record['deleted_at'] == null) {
          allAttendanceRecords.add({
            ...record,
            'attendance_category': 'sunday_school',
            'display_date': record['attendance_date'],
            'display_type': 'Sunday School',
            'attendance_type_display': 'Present',
          });
        }
      }

      // Sort by date descending
      allAttendanceRecords.sort((a, b) {
        final dateA = (a['display_date'] ?? '').toString();
        final dateB = (b['display_date'] ?? '').toString();
        return dateB.compareTo(dateA);
      });

      // Count only actual attendance (onsite or online for church, all for Sunday school)
      final totalAttendance = allAttendanceRecords
          .where((record) {
            final category = record['attendance_category']?.toString();
            final attendanceType = record['attendance_type']?.toString();
            if (category == 'church') {
              return attendanceType == 'onsite' || attendanceType == 'online';
            } else {
              return true; // All Sunday school records count as attendance
            }
          })
          .length;

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

      // Calculate giving total
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
        'attendance': {
          'total': totalAttendance,
          'records': allAttendanceRecords,
        },
        'giving': {'total': totalGiving, 'records': giving},
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to generate member report: $e');
    }
  }

  /// Church service attendance only for a member (no Sunday school or giving).
  static Future<Map<String, dynamic>> getMemberChurchAttendanceReport({
    required String memberId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var churchAttendanceQuery = _client
          .from('church_attendance')
          .select('*, church_service:church_services(name)')
          .eq('member_id', memberId);

      if (fromDate != null) {
        churchAttendanceQuery = churchAttendanceQuery.gte(
          'service_date',
          fromDate.toIso8601String().split('T')[0],
        );
      }
      if (toDate != null) {
        churchAttendanceQuery = churchAttendanceQuery.lte(
          'service_date',
          toDate.toIso8601String().split('T')[0],
        );
      }

      final churchAttendance = await churchAttendanceQuery;
      final records = <Map<String, dynamic>>[];

      for (final record in churchAttendance as List) {
        if (record['deleted_at'] != null) continue;
        records.add({
          ...record,
          'attendance_category': 'church',
          'display_date': record['service_date'],
          'display_type': _churchServiceDisplayName(record),
          'attendance_type_display': record['attendance_type'] == 'onsite'
              ? 'Onsite'
              : record['attendance_type'] == 'online'
              ? 'Online'
              : 'Absent',
        });
      }

      records.sort((a, b) {
        final dateA = (a['display_date'] ?? '').toString();
        final dateB = (b['display_date'] ?? '').toString();
        return dateB.compareTo(dateA);
      });

      final totalPresent = records
          .where((record) {
            final type = record['attendance_type']?.toString();
            return type == 'onsite' || type == 'online';
          })
          .length;

      final onsite = records
          .where((r) => r['attendance_type']?.toString() == 'onsite')
          .length;
      final online = records
          .where((r) => r['attendance_type']?.toString() == 'online')
          .length;
      final absent = records
          .where((r) => r['attendance_type']?.toString() == 'absent')
          .length;

      return {
        'member_id': memberId,
        'period': {
          'from': fromDate?.toIso8601String(),
          'to': toDate?.toIso8601String(),
        },
        'attendance': {
          'total': totalPresent,
          'onsite': onsite,
          'online': online,
          'absent': absent,
          'records': records,
        },
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to generate church attendance report: $e');
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

  /// Get newcomer report for a custom period.
  static Future<Map<String, dynamic>> getNewComerReport({
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int? offset,
  }) async {
    try {
      return await NewComerService.getReport(
        startDate: fromDate,
        endDate: toDate,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw Exception('Failed to generate newcomer report: $e');
    }
  }

  /// Get newcomer report for the current/reference week.
  static Future<Map<String, dynamic>> getWeeklyNewComerReport({
    DateTime? referenceDate,
  }) async {
    try {
      return await NewComerService.getWeeklyReport(referenceDate: referenceDate);
    } catch (e) {
      throw Exception('Failed to generate weekly newcomer report: $e');
    }
  }

  /// Get newcomer report for the current/reference month.
  static Future<Map<String, dynamic>> getMonthlyNewComerReport({
    DateTime? referenceDate,
  }) async {
    try {
      return await NewComerService.getMonthlyReport(referenceDate: referenceDate);
    } catch (e) {
      throw Exception('Failed to generate monthly newcomer report: $e');
    }
  }

  /// Get yearly newcomer report for a given year.
  static Future<Map<String, dynamic>> getYearlyNewComerReport({int? year}) async {
    try {
      return await NewComerService.getYearlyReport(year: year);
    } catch (e) {
      throw Exception('Failed to generate yearly newcomer report: $e');
    }
  }

  /// Get members report for a custom period.
  static Future<Map<String, dynamic>> getMembersReport({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      return await MembersReportService.getReport(
        startDate: fromDate,
        endDate: toDate,
      );
    } catch (e) {
      throw Exception('Failed to generate members report: $e');
    }
  }

  /// Get members report for the current/reference week.
  static Future<Map<String, dynamic>> getWeeklyMembersReport({
    DateTime? referenceDate,
  }) async {
    try {
      return await MembersReportService.getWeeklyReport(
        referenceDate: referenceDate,
      );
    } catch (e) {
      throw Exception('Failed to generate weekly members report: $e');
    }
  }

  /// Get members report for the current/reference month.
  static Future<Map<String, dynamic>> getMonthlyMembersReport({
    DateTime? referenceDate,
  }) async {
    try {
      return await MembersReportService.getMonthlyReport(
        referenceDate: referenceDate,
      );
    } catch (e) {
      throw Exception('Failed to generate monthly members report: $e');
    }
  }

  /// Get members report for a given year.
  static Future<Map<String, dynamic>> getYearlyMembersReport({int? year}) async {
    try {
      return await MembersReportService.getYearlyReport(year: year);
    } catch (e) {
      throw Exception('Failed to generate yearly members report: $e');
    }
  }
}
