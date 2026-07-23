import 'package:flutter/foundation.dart';

import 'member_service.dart';
import 'supabase_service.dart';

/// Bulk members report with roster stats and attendance by period.
class MembersReportService {
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
    final start = DateTime(y, 1, 1);
    final end = DateTime(y, 12, 31);
    return getReport(startDate: start, endDate: end);
  }

  static Future<Map<String, dynamic>> getReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final members = await _fetchMembers();
    final statusSummary = _buildStatusSummary(members);
    final roleSummary = _buildRoleSummary(members);
    final attendanceReport = await _buildAttendanceReport(
      members,
      startDate: startDate,
      endDate: endDate,
    );

    return {
      'period': {
        'start': startDate?.toIso8601String().split('T')[0],
        'end': endDate?.toIso8601String().split('T')[0],
      },
      'total': members.length,
      'status_summary': statusSummary,
      'role_summary': roleSummary,
      'attendance_report': attendanceReport,
      'records': members,
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  static Future<List<Map<String, dynamic>>> _fetchMembers() async {
    try {
      final response = await _client
          .from('members')
          .select()
          .isFilter('deleted_at', null)
          .order('first_name', ascending: true)
          .order('last_name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[MembersReportService] Member fetch failed: $e');
      return MemberService.getMembers();
    }
  }

  static Map<String, int> _buildStatusSummary(
    List<Map<String, dynamic>> members,
  ) {
    var active = 0;
    var inactive = 0;
    var newcomers = 0;

    for (final member in members) {
      if (member['is_active'] == true) {
        active++;
      } else {
        inactive++;
      }
      if (member['is_new_comer'] == true) {
        newcomers++;
      }
    }

    return {
      'active': active,
      'inactive': inactive,
      'new_comer': newcomers,
    };
  }

  static Map<String, int> _buildRoleSummary(
    List<Map<String, dynamic>> members,
  ) {
    final summary = <String, int>{
      'member': 0,
      'leader': 0,
      'worker': 0,
      'admin': 0,
      'sympathiser': 0,
    };

    for (final member in members) {
      final role = member['role']?.toString() ?? 'member';
      summary[role] = (summary[role] ?? 0) + 1;
    }

    return summary;
  }

  static Future<Map<String, dynamic>> _buildAttendanceReport(
    List<Map<String, dynamic>> members, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final memberIds = members
        .map((member) => member['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    if (memberIds.isEmpty) {
      return _emptyAttendanceReport();
    }

    try {
      dynamic query = _client
          .from('church_attendance')
          .select(
            'id, member_id, service_date, church_service_id, attendance_type',
          )
          .inFilter('member_id', memberIds)
          .isFilter('deleted_at', null);

      if (startDate != null) {
        query = query.gte(
          'service_date',
          startDate.toIso8601String().split('T')[0],
        );
      }
      if (endDate != null) {
        query = query.lte(
          'service_date',
          endDate.toIso8601String().split('T')[0],
        );
      }

      query = query.order('service_date', ascending: false);
      final attendanceRecords = List<Map<String, dynamic>>.from(await query);
      final memberById = {
        for (final member in members)
          if (member['id'] != null) member['id'].toString(): member,
      };
      final rowsByMember = <String, Map<String, dynamic>>{};

      for (final memberId in memberIds) {
        final member = memberById[memberId];
        rowsByMember[memberId] = {
          'member_id': memberId,
          'name': '${member?['first_name'] ?? ''} ${member?['last_name'] ?? ''}'
              .trim(),
          'role': member?['role'] ?? 'member',
          'is_active': member?['is_active'] == true,
          'onsite': 0,
          'online': 0,
          'absent': 0,
          'attended': 0,
          'total': 0,
          'last_attended': null,
        };
      }

      var onsite = 0;
      var online = 0;
      var absent = 0;
      final serviceKeys = <String>{};

      for (final attendance in attendanceRecords) {
        final memberId = attendance['member_id']?.toString();
        if (memberId == null) continue;

        final type = attendance['attendance_type']?.toString() ?? 'absent';
        final serviceDate = attendance['service_date']?.toString();
        final churchServiceId =
            attendance['church_service_id']?.toString() ?? '';
        if (serviceDate != null) {
          serviceKeys.add('$serviceDate|$churchServiceId');
        }

        final row = rowsByMember[memberId];
        if (row == null) continue;

        row['total'] = (row['total'] as int) + 1;
        if (type == 'onsite') {
          onsite++;
          row['onsite'] = (row['onsite'] as int) + 1;
          row['attended'] = (row['attended'] as int) + 1;
          row['last_attended'] ??= serviceDate;
        } else if (type == 'online') {
          online++;
          row['online'] = (row['online'] as int) + 1;
          row['attended'] = (row['attended'] as int) + 1;
          row['last_attended'] ??= serviceDate;
        } else {
          absent++;
          row['absent'] = (row['absent'] as int) + 1;
        }
      }

      final memberRows = rowsByMember.values.toList()
        ..sort((a, b) {
          final attendedCompare = (b['attended'] as int).compareTo(
            a['attended'] as int,
          );
          if (attendedCompare != 0) return attendedCompare;
          return (a['name']?.toString() ?? '').compareTo(
            b['name']?.toString() ?? '',
          );
        });

      return {
        'total_records': attendanceRecords.length,
        'onsite': onsite,
        'online': online,
        'absent': absent,
        'attended': onsite + online,
        'unique_services': serviceKeys.length,
        'member_rows': memberRows,
        'records': attendanceRecords,
      };
    } catch (e) {
      debugPrint('[MembersReportService] Attendance report failed: $e');
      return {
        ..._emptyAttendanceReport(),
        'error': e.toString(),
      };
    }
  }

  static Map<String, dynamic> _emptyAttendanceReport() => {
    'total_records': 0,
    'onsite': 0,
    'online': 0,
    'absent': 0,
    'attended': 0,
    'unique_services': 0,
    'member_rows': <Map<String, dynamic>>[],
    'records': <Map<String, dynamic>>[],
  };
}
