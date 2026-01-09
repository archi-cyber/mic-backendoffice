import 'package:flutter/foundation.dart' show debugPrint;
import 'supabase_service.dart';

/// Service for managing Sunday school attendance (for children only)
class SundaySchoolAttendanceService {
  static final _client = SupabaseService.client;

  /// Mark attendance for a member (child)
  static Future<Map<String, dynamic>> markAttendance({
    required String memberId,
    required DateTime attendanceDate,
  }) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to mark attendance');
      }

      debugPrint(
        '[SundaySchoolAttendanceService] Marking attendance for member: $memberId, date: $attendanceDate',
      );

      final response = await _client
          .from('sunday_school_attendance')
          .insert({
            'member_id': memberId,
            'attendance_date': attendanceDate.toIso8601String().split('T')[0],
            'created_by': currentUser.id,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      debugPrint(
        '[SundaySchoolAttendanceService] Attendance marked successfully',
      );
      return response;
    } catch (e) {
      debugPrint(
        '[SundaySchoolAttendanceService] Error marking attendance: $e',
      );
      throw Exception('Failed to mark attendance: $e');
    }
  }

  /// Mark attendance for multiple members (bulk operation)
  static Future<List<Map<String, dynamic>>> markBulkAttendance({
    required List<String> memberIds,
    required DateTime attendanceDate,
  }) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to mark attendance');
      }

      debugPrint(
        '[SundaySchoolAttendanceService] Marking bulk attendance for ${memberIds.length} members',
      );

      final dateString = attendanceDate.toIso8601String().split('T')[0];
      final attendanceRecords = memberIds
          .map(
            (memberId) => {
              'member_id': memberId,
              'attendance_date': dateString,
              'created_by': currentUser.id,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      final response = await _client
          .from('sunday_school_attendance')
          .insert(attendanceRecords)
          .select();

      debugPrint(
        '[SundaySchoolAttendanceService] Bulk attendance marked successfully: ${response.length} records',
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint(
        '[SundaySchoolAttendanceService] Error marking bulk attendance: $e',
      );
      throw Exception('Failed to mark bulk attendance: $e');
    }
  }

  /// Get attendance for a specific date
  static Future<List<Map<String, dynamic>>> getDateAttendance({
    required DateTime attendanceDate,
  }) async {
    try {
      final dateString = attendanceDate.toIso8601String().split('T')[0];
      final response = await _client
          .from('sunday_school_attendance')
          .select(
            '*, member:members(id, first_name, last_name, email, birthday)',
          )
          .eq('attendance_date', dateString)
          .order('created_at', ascending: false);

      final records = List<Map<String, dynamic>>.from(response);
      // Filter out deleted records
      return records.where((r) => r['deleted_at'] == null).toList();
    } catch (e) {
      debugPrint(
        '[SundaySchoolAttendanceService] Error getting date attendance: $e',
      );
      throw Exception('Failed to get date attendance: $e');
    }
  }

  /// Get all unique attendance dates (for listing sessions)
  /// Returns sessions with attendance counts
  static Future<List<Map<String, dynamic>>> getAllSessions({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      // Get all attendance records with filters
      // Note: Filters must be applied before transforms (order, limit)
      dynamic query = _client
          .from('sunday_school_attendance')
          .select('attendance_date, id');

      // Apply filters first
      if (startDate != null) {
        query = query.gte(
          'attendance_date',
          startDate.toIso8601String().split('T')[0],
        );
      }
      if (endDate != null) {
        query = query.lte(
          'attendance_date',
          endDate.toIso8601String().split('T')[0],
        );
      }

      // Apply transforms after filters
      query = query.order('attendance_date', ascending: false);

      if (limit != null) {
        query = query.limit(limit * 10);
      }

      final response = await query;
      final records = List<Map<String, dynamic>>.from(response);

      // Filter out deleted records and group by attendance_date
      final sessionCounts = <String, int>{};
      final sessionMap = <String, Map<String, dynamic>>{};

      for (final record in records) {
        if (record['deleted_at'] == null) {
          final attendanceDate = record['attendance_date'] as String;
          final key = attendanceDate;

          sessionCounts[key] = (sessionCounts[key] ?? 0) + 1;

          if (!sessionMap.containsKey(key)) {
            sessionMap[key] = {'attendance_date': attendanceDate};
          }
        }
      }

      // Combine session info with counts
      final sessionsWithCounts = sessionMap.entries.map((entry) {
        return {
          ...entry.value,
          'attendance_count': sessionCounts[entry.key] ?? 0,
        };
      }).toList();

      // Sort by date descending
      sessionsWithCounts.sort((a, b) {
        final dateA = DateTime.parse(a['attendance_date'] as String);
        final dateB = DateTime.parse(b['attendance_date'] as String);
        return dateB.compareTo(dateA);
      });

      // Apply limit after grouping
      if (limit != null && sessionsWithCounts.length > limit) {
        return sessionsWithCounts.take(limit).toList();
      }

      return sessionsWithCounts;
    } catch (e) {
      debugPrint(
        '[SundaySchoolAttendanceService] Error getting all sessions: $e',
      );
      throw Exception('Failed to get all sessions: $e');
    }
  }

  /// Remove attendance record (soft delete)
  static Future<void> removeAttendance(String attendanceId) async {
    try {
      await _client
          .from('sunday_school_attendance')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', attendanceId);
      debugPrint(
        '[SundaySchoolAttendanceService] Attendance removed successfully',
      );
    } catch (e) {
      debugPrint(
        '[SundaySchoolAttendanceService] Error removing attendance: $e',
      );
      throw Exception('Failed to remove attendance: $e');
    }
  }

  /// Update attendance for a session (add/remove members)
  /// This will sync the attendance records for a date to match the provided member IDs
  static Future<void> updateSessionAttendance({
    required DateTime attendanceDate,
    required List<String> memberIds,
  }) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to update attendance');
      }

      debugPrint(
        '[SundaySchoolAttendanceService] Updating session attendance for date: $attendanceDate',
      );

      final dateString = attendanceDate.toIso8601String().split('T')[0];

      // Get existing attendance records for this date
      final existingRecordsResponse = await _client
          .from('sunday_school_attendance')
          .select('id, member_id')
          .eq('attendance_date', dateString);

      final existingRecords = (existingRecordsResponse as List)
          .where((r) => r['deleted_at'] == null)
          .toList();

      final existingMemberIds = existingRecords
          .map((r) => r['member_id']?.toString())
          .whereType<String>()
          .toSet();

      // Find members to add (in new list but not in existing)
      final membersToAdd = memberIds
          .where((id) => !existingMemberIds.contains(id))
          .toList();

      // Find members to remove (in existing but not in new list)
      final recordsToRemove = (existingRecords)
          .where((r) {
            final memberId = r['member_id']?.toString();
            return memberId != null && !memberIds.contains(memberId);
          })
          .map((r) => r['id'].toString())
          .toList();

      // Remove members that are no longer in the list
      if (recordsToRemove.isNotEmpty) {
        await _client
            .from('sunday_school_attendance')
            .update({'deleted_at': DateTime.now().toIso8601String()})
            .inFilter('id', recordsToRemove);
      }

      // Add new members
      if (membersToAdd.isNotEmpty) {
        final attendanceRecords = membersToAdd
            .map(
              (memberId) => {
                'member_id': memberId,
                'attendance_date': dateString,
                'created_by': currentUser.id,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              },
            )
            .toList();

        await _client
            .from('sunday_school_attendance')
            .insert(attendanceRecords);
      }

      debugPrint(
        '[SundaySchoolAttendanceService] Session attendance updated successfully. Added: ${membersToAdd.length}, Removed: ${recordsToRemove.length}',
      );
    } catch (e) {
      debugPrint(
        '[SundaySchoolAttendanceService] Error updating session attendance: $e',
      );
      throw Exception('Failed to update session attendance: $e');
    }
  }
}
