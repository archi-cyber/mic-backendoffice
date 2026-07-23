import 'package:flutter/foundation.dart';
import '../screens/service_schedule/service_schedule_constants.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

class ServiceScheduleService {
  ServiceScheduleService._();

  static final _client = SupabaseService.client;

  static const _scheduleSelect =
      '*, service_schedule_assignments(id, role, member_id, is_done, created_at, members(id, first_name, last_name))';

  static String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _roleLabel(String role) =>
      ServiceScheduleRoles.labelKeys[role] ?? role;

  static List<Map<String, dynamic>> _assignmentsFor(
    Map<String, dynamic> schedule,
    String role,
  ) {
    final rows = schedule['service_schedule_assignments'];
    if (rows is! List) return [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['role']?.toString() == role)
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getSchedules({
    required String departmentId,
    int limit = 200,
  }) async {
    try {
      final response = await _client
          .from('service_schedules')
          .select(_scheduleSelect)
          .eq('department_id', departmentId)
          .order('service_date', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, stackTrace) {
      debugPrint('[ServiceScheduleService] getSchedules error: $e');
      debugPrint('$stackTrace');
      throw Exception('Failed to load service schedules: $e');
    }
  }

  static Future<Map<String, dynamic>> createSchedule({
    required String departmentId,
    required DateTime serviceDate,
    String? notes,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final response = await _client
          .from('service_schedules')
          .insert({
            'department_id': departmentId,
            'service_date': _dateOnly(serviceDate),
            'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
            'created_by': user.id,
          })
          .select(_scheduleSelect)
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      if (e.toString().contains('service_schedules_department_date_unique') ||
          e.toString().contains('duplicate key')) {
        throw Exception('A schedule already exists for this service date');
      }
      throw Exception('Failed to create service schedule: $e');
    }
  }

  static Future<void> updateNotes({
    required String scheduleId,
    String? notes,
  }) async {
    try {
      await _client
          .from('service_schedules')
          .update({
            'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
          })
          .eq('id', scheduleId);
    } catch (e) {
      throw Exception('Failed to update notes: $e');
    }
  }

  static Future<void> deleteSchedule(String scheduleId) async {
    try {
      await _client.from('service_schedules').delete().eq('id', scheduleId);
    } catch (e) {
      throw Exception('Failed to delete service schedule: $e');
    }
  }

  static Future<Map<String, dynamic>> addAssignment({
    required Map<String, dynamic> schedule,
    required String role,
    required String memberId,
    required String serviceDateLabel,
  }) async {
    final scheduleId = schedule['id']?.toString();
    if (scheduleId == null) {
      throw Exception('Invalid schedule');
    }

    final existing = _assignmentsFor(schedule, role);
    if (existing.length >= ServiceScheduleRoles.maxMembersPerRole) {
      throw Exception(
        'Maximum ${ServiceScheduleRoles.maxMembersPerRole} members per role',
      );
    }
    if (existing.any((row) => row['member_id']?.toString() == memberId)) {
      throw Exception('Member is already assigned to this role');
    }

    try {
      final response = await _client
          .from('service_schedule_assignments')
          .insert({
            'schedule_id': scheduleId,
            'role': role,
            'member_id': memberId,
            'is_done': false,
          })
          .select('id, role, member_id, is_done, members(id, first_name, last_name)')
          .single();

      final roleLabel = _roleLabel(role);
      await NotificationService.createBulkNotifications(
        memberIds: [memberId],
        type: 'service_schedule_assigned',
        title: 'Media service assignment',
        message:
            'You have been assigned to $roleLabel on $serviceDateLabel.',
        relatedId: scheduleId,
        relatedType: 'service_schedule',
      );

      return Map<String, dynamic>.from(response);
    } catch (e) {
      if (e.toString().contains('service_schedule_assignments_unique') ||
          e.toString().contains('duplicate key')) {
        throw Exception('Member is already assigned to this role');
      }
      throw Exception('Failed to assign member: $e');
    }
  }

  static Future<void> removeAssignment(String assignmentId) async {
    try {
      await _client
          .from('service_schedule_assignments')
          .delete()
          .eq('id', assignmentId);
    } catch (e) {
      throw Exception('Failed to remove assignment: $e');
    }
  }

  static Future<void> setAssignmentDone({
    required String assignmentId,
    required bool isDone,
  }) async {
    try {
      await _client
          .from('service_schedule_assignments')
          .update({'is_done': isDone})
          .eq('id', assignmentId);
    } catch (e) {
      throw Exception('Failed to update completion status: $e');
    }
  }

  static bool isMediaTeamDepartment(Map<String, dynamic>? department) {
    final name = department?['name']?.toString().trim().toLowerCase() ?? '';
    return name == 'media team';
  }
}
