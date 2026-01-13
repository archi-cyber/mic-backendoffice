import 'package:flutter/foundation.dart' show debugPrint;
import 'supabase_service.dart';

/// Service for managing church attendance (Wednesday and Sunday services)
class ChurchAttendanceService {
  static final _client = SupabaseService.client;

  /// Mark attendance for a member
  /// serviceType: 'wednesday' or 'sunday'
  /// attendanceType: 'onsite', 'online', or 'absent'
  static Future<Map<String, dynamic>> markAttendance({
    required String memberId,
    required DateTime serviceDate,
    required String serviceType, // 'wednesday' or 'sunday'
    String attendanceType = 'onsite', // 'onsite', 'online', or 'absent'
  }) async {
    try {
      if (serviceType != 'wednesday' && serviceType != 'sunday') {
        throw Exception('Service type must be "wednesday" or "sunday"');
      }

      if (attendanceType != 'onsite' &&
          attendanceType != 'online' &&
          attendanceType != 'absent') {
        throw Exception(
          'Attendance type must be "onsite", "online", or "absent"',
        );
      }

      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to mark attendance');
      }

      debugPrint(
        '[ChurchAttendanceService] Marking attendance for member: $memberId, date: $serviceDate, type: $serviceType, attendance: $attendanceType',
      );

      final response = await _client
          .from('church_attendance')
          .insert({
            'member_id': memberId,
            'service_date': serviceDate.toIso8601String().split(
              'T',
            )[0], // Date only
            'service_type': serviceType,
            'attendance_type': attendanceType,
            'created_by': currentUser.id,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      debugPrint('[ChurchAttendanceService] Attendance marked successfully');
      return response;
    } catch (e) {
      debugPrint('[ChurchAttendanceService] Error marking attendance: $e');
      throw Exception('Failed to mark attendance: $e');
    }
  }

  /// Mark attendance for multiple members (bulk operation)
  /// attendanceType: 'onsite', 'online', or 'absent'
  static Future<List<Map<String, dynamic>>> markBulkAttendance({
    required List<String> memberIds,
    required DateTime serviceDate,
    required String serviceType,
    String attendanceType = 'onsite', // 'onsite', 'online', or 'absent'
  }) async {
    try {
      if (serviceType != 'wednesday' && serviceType != 'sunday') {
        throw Exception('Service type must be "wednesday" or "sunday"');
      }

      if (attendanceType != 'onsite' &&
          attendanceType != 'online' &&
          attendanceType != 'absent') {
        throw Exception(
          'Attendance type must be "onsite", "online", or "absent"',
        );
      }

      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to mark attendance');
      }

      debugPrint(
        '[ChurchAttendanceService] Marking bulk attendance for ${memberIds.length} members',
      );

      final dateString = serviceDate.toIso8601String().split('T')[0];
      final attendanceRecords = memberIds
          .map(
            (memberId) => {
              'member_id': memberId,
              'service_date': dateString,
              'service_type': serviceType,
              'attendance_type': attendanceType,
              'created_by': currentUser.id,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      final response = await _client
          .from('church_attendance')
          .insert(attendanceRecords)
          .select();

      debugPrint(
        '[ChurchAttendanceService] Bulk attendance marked successfully: ${response.length} records',
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[ChurchAttendanceService] Error marking bulk attendance: $e');
      throw Exception('Failed to mark bulk attendance: $e');
    }
  }

  /// Get attendance for a member
  static Future<List<Map<String, dynamic>>> getMemberAttendance({
    required String memberId,
    DateTime? startDate,
    DateTime? endDate,
    String? serviceType,
    int? limit,
    int? offset,
  }) async {
    try {
      // Build base query with filters
      dynamic filterQuery = _client
          .from('church_attendance')
          .select('*')
          .eq('member_id', memberId);

      if (startDate != null) {
        filterQuery = filterQuery.gte(
          'service_date',
          startDate.toIso8601String().split('T')[0],
        );
      }
      if (endDate != null) {
        filterQuery = filterQuery.lte(
          'service_date',
          endDate.toIso8601String().split('T')[0],
        );
      }
      if (serviceType != null) {
        filterQuery = filterQuery.eq('service_type', serviceType);
      }

      // Apply ordering (returns PostgrestTransformBuilder)
      dynamic transformQuery = filterQuery.order(
        'service_date',
        ascending: false,
      );

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
      final records = List<Map<String, dynamic>>.from(response);
      // Filter out deleted records
      return records.where((r) => r['deleted_at'] == null).toList();
    } catch (e) {
      debugPrint(
        '[ChurchAttendanceService] Error getting member attendance: $e',
      );
      throw Exception('Failed to get member attendance: $e');
    }
  }

  /// Get attendance for a specific service date
  static Future<List<Map<String, dynamic>>> getServiceAttendance({
    required DateTime serviceDate,
    required String serviceType,
  }) async {
    try {
      final dateString = serviceDate.toIso8601String().split('T')[0];
      final response = await _client
          .from('church_attendance')
          .select('*, member:members(id, first_name, last_name, email)')
          .eq('service_date', dateString)
          .eq('service_type', serviceType)
          .order('created_at', ascending: false);

      final records = List<Map<String, dynamic>>.from(response);
      // Filter out deleted records
      return records.where((r) => r['deleted_at'] == null).toList();
    } catch (e) {
      debugPrint(
        '[ChurchAttendanceService] Error getting service attendance: $e',
      );
      throw Exception('Failed to get service attendance: $e');
    }
  }

  /// Get all unique service dates and types (for listing services)
  /// Returns services with attendance counts
  static Future<List<Map<String, dynamic>>> getAllServices({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      // Get all attendance records with filters
      // Note: Filters must be applied before transforms (order, limit)
      dynamic query = _client
          .from('church_attendance')
          .select('service_date, service_type, id, attendance_type, member_id');

      // Apply filters first
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

      // Apply transforms after filters
      query = query.order('service_date', ascending: false);

      if (limit != null) {
        query = query.limit(
          limit * 10,
        ); // Get more records to account for multiple services per date
      }

      final response = await query;
      final records = List<Map<String, dynamic>>.from(response);

      // Filter out deleted records and group by service_date + service_type
      // Only count unique members with 'onsite' and 'online' attendance, exclude 'absent'
      final serviceMemberSets =
          <String, Set<String>>{}; // Track unique member IDs
      final serviceMap = <String, Map<String, dynamic>>{};

      for (final record in records) {
        if (record['deleted_at'] == null) {
          final attendanceType = record['attendance_type']?.toString();
          // Only count actual attendance (onsite or online), not absent
          if (attendanceType != null && attendanceType != 'absent') {
            final serviceDate = record['service_date'] as String;
            final serviceType = record['service_type'] as String;
            final key = '${serviceDate}_$serviceType';
            final memberId = record['member_id']?.toString();

            // Track unique member IDs per service
            if (memberId != null) {
              serviceMemberSets.putIfAbsent(key, () => <String>{});
              serviceMemberSets[key]!.add(memberId);
            }

            if (!serviceMap.containsKey(key)) {
              serviceMap[key] = {
                'service_date': serviceDate,
                'service_type': serviceType,
              };
            }
          }
        }
      }

      // Combine service info with counts (using unique member count)
      final servicesWithCounts = serviceMap.entries.map((entry) {
        final uniqueMemberCount = serviceMemberSets[entry.key]?.length ?? 0;
        return {...entry.value, 'attendance_count': uniqueMemberCount};
      }).toList();

      // Sort by date descending
      servicesWithCounts.sort((a, b) {
        final dateA = DateTime.parse(a['service_date'] as String);
        final dateB = DateTime.parse(b['service_date'] as String);
        return dateB.compareTo(dateA);
      });

      // Apply limit after grouping
      if (limit != null && servicesWithCounts.length > limit) {
        return servicesWithCounts.take(limit).toList();
      }

      return servicesWithCounts;
    } catch (e) {
      debugPrint('[ChurchAttendanceService] Error getting all services: $e');
      throw Exception('Failed to get all services: $e');
    }
  }

  /// Get attendance count for a member in the last 3 months
  /// Used to check if new comer should be promoted to member
  static Future<int> getMemberAttendanceCountLast3Months(
    String memberId,
  ) async {
    try {
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      final dateString = threeMonthsAgo.toIso8601String().split('T')[0];

      final response = await _client
          .from('church_attendance')
          .select('id')
          .eq('member_id', memberId)
          .gte('service_date', dateString);

      // Filter out deleted records and get count
      final records = List<Map<String, dynamic>>.from(response);
      final count = records.where((r) => r['deleted_at'] == null).length;

      debugPrint(
        '[ChurchAttendanceService] Member $memberId has $count attendances in last 3 months',
      );
      return count;
    } catch (e) {
      debugPrint(
        '[ChurchAttendanceService] Error getting attendance count: $e',
      );
      throw Exception('Failed to get attendance count: $e');
    }
  }

  /// Update attendance record
  static Future<Map<String, dynamic>> updateAttendance({
    required String attendanceId,
    String? attendanceType,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (attendanceType != null) {
        if (attendanceType != 'onsite' &&
            attendanceType != 'online' &&
            attendanceType != 'absent') {
          throw Exception(
            'Attendance type must be "onsite", "online", or "absent"',
          );
        }
        updates['attendance_type'] = attendanceType;
      }

      final response = await _client
          .from('church_attendance')
          .update(updates)
          .eq('id', attendanceId)
          .select()
          .single();

      debugPrint('[ChurchAttendanceService] Attendance updated successfully');
      return response;
    } catch (e) {
      debugPrint('[ChurchAttendanceService] Error updating attendance: $e');
      throw Exception('Failed to update attendance: $e');
    }
  }

  /// Remove attendance record (soft delete)
  static Future<void> removeAttendance(String attendanceId) async {
    try {
      await _client
          .from('church_attendance')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', attendanceId);
      debugPrint('[ChurchAttendanceService] Attendance removed successfully');
    } catch (e) {
      debugPrint('[ChurchAttendanceService] Error removing attendance: $e');
      throw Exception('Failed to remove attendance: $e');
    }
  }

  /// Check and update new comer status for a member
  /// This calls the database function that checks if member has 9+ attendances in 3 months
  static Future<bool> checkAndUpdateNewComerStatus(String memberId) async {
    try {
      debugPrint(
        '[ChurchAttendanceService] Checking new comer status for member: $memberId',
      );

      // Call the database function
      final response = await _client.rpc(
        'check_and_update_new_comer_status',
        params: {'member_uuid': memberId},
      );

      final wasUpdated = response == true;
      if (wasUpdated) {
        debugPrint(
          '[ChurchAttendanceService] Member $memberId promoted from new comer to member',
        );
      } else {
        debugPrint(
          '[ChurchAttendanceService] Member $memberId still needs more attendances',
        );
      }

      return wasUpdated;
    } catch (e) {
      debugPrint(
        '[ChurchAttendanceService] Error checking new comer status: $e',
      );
      // Don't throw - this is a background check
      return false;
    }
  }
}
