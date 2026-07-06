import 'package:flutter/foundation.dart';

import 'class_service.dart';
import 'supabase_service.dart';

/// Bulk trainings report with per-training attendance summaries.
class TrainingsReportService {
  static final _client = SupabaseService.client;

  static Future<Map<String, dynamic>> getWeeklyReport({
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final start = DateTime(
      ref.year,
      ref.month,
      ref.day,
    ).subtract(Duration(days: ref.weekday - DateTime.monday));
    final end = start.add(const Duration(days: 6));
    return getReport(startDate: start, endDate: end);
  }

  static Future<Map<String, dynamic>> getMonthlyReport({
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final start = DateTime(ref.year, ref.month, 1);
    final end = DateTime(ref.year, ref.month + 1, 0);
    return getReport(startDate: start, endDate: end);
  }

  static Future<Map<String, dynamic>> getYearlyReport({int? year}) {
    final y = year ?? DateTime.now().year;
    return getReport(
      startDate: DateTime(y, 1, 1),
      endDate: DateTime(y, 12, 31),
    );
  }

  static Future<Map<String, dynamic>> getReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final classes = await ClassService.getClasses(limit: 200);

    var sessionsQuery = _client
        .from('sessions')
        .select('id, class_id, session_date');
    if (startDate != null) {
      sessionsQuery = sessionsQuery.gte('session_date', _dateOnly(startDate));
    }
    if (endDate != null) {
      sessionsQuery = sessionsQuery.lte('session_date', _dateOnly(endDate));
    }
    final sessions = List<Map<String, dynamic>>.from(await sessionsQuery);

    final sessionIds = sessions
        .map((session) => session['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    var attendance = <Map<String, dynamic>>[];
    if (sessionIds.isNotEmpty) {
      try {
        attendance = List<Map<String, dynamic>>.from(
          await _client
              .from('attendance')
              .select('session_id, member_id, status')
              .inFilter('session_id', sessionIds),
        );
      } catch (e) {
        debugPrint('[TrainingsReportService] Attendance fetch failed: $e');
      }
    }

    final enrollments = List<Map<String, dynamic>>.from(
      await _client.from('class_members').select('class_id'),
    );
    final memberCounts = <String, int>{};
    for (final enrollment in enrollments) {
      final classId = enrollment['class_id']?.toString();
      if (classId == null) continue;
      memberCounts[classId] = (memberCounts[classId] ?? 0) + 1;
    }

    final sessionsByClass = <String, int>{};
    final sessionIdsByClass = <String, List<String>>{};
    for (final session in sessions) {
      final classId = session['class_id']?.toString();
      final sessionId = session['id']?.toString();
      if (classId == null || sessionId == null) continue;
      sessionsByClass[classId] = (sessionsByClass[classId] ?? 0) + 1;
      sessionIdsByClass.putIfAbsent(classId, () => []).add(sessionId);
    }

    final records = classes.map((training) {
      final classId = training['id']?.toString() ?? '';
      final classSessionIds = sessionIdsByClass[classId] ?? const <String>[];
      final classAttendance = attendance.where(
        (record) =>
            classSessionIds.contains(record['session_id']?.toString()),
      );

      var present = 0;
      var absent = 0;
      var late = 0;
      for (final record in classAttendance) {
        final status = record['status']?.toString().toLowerCase() ?? '';
        if (status == 'present') {
          present++;
        } else if (status == 'absent') {
          absent++;
        } else if (status == 'late') {
          late++;
        }
      }

      final uniqueAttendees = classAttendance
          .where(
            (record) =>
                record['status']?.toString().toLowerCase() == 'present',
          )
          .map((record) => record['member_id'])
          .toSet()
          .length;

      return {
        ...training,
        'class_id': classId,
        'member_count': memberCounts[classId] ?? 0,
        'session_count': sessionsByClass[classId] ?? 0,
        'present_count': present,
        'absent_count': absent,
        'late_count': late,
        'attendance_count': present,
        'unique_attendees': uniqueAttendees,
      };
    }).toList();

    final totalPresent = attendance
        .where(
          (record) => record['status']?.toString().toLowerCase() == 'present',
        )
        .length;

    return {
      'period': {
        'start': startDate?.toIso8601String().split('T').first,
        'end': endDate?.toIso8601String().split('T').first,
      },
      'summary': {
        'total_trainings': classes.length,
        'active_trainings':
            classes.where((training) => training['is_active'] == true).length,
        'total_sessions': sessions.length,
        'total_attendance': totalPresent,
        'total_enrollments': enrollments.length,
      },
      'records': records,
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  static String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
