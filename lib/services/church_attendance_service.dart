import 'package:flutter/foundation.dart' show debugPrint;
import 'church_service_service.dart';
import 'supabase_service.dart';

/// Service for managing church attendance linked to [church_services].
class ChurchAttendanceService {
  static final _client = SupabaseService.client;

  static String _dateOnly(DateTime date) =>
      date.toIso8601String().split('T')[0];

  static Future<Map<String, dynamic>> _requireService(String churchServiceId) async {
    final service = await ChurchServiceService.getById(churchServiceId);
    if (service == null) {
      throw Exception('Church service not found');
    }
    return service;
  }

  /// Mark attendance for a member on a church service.
  /// attendanceType: 'onsite', 'online', or 'absent'
  static Future<Map<String, dynamic>> markAttendance({
    required String memberId,
    required String churchServiceId,
    String attendanceType = 'onsite',
    String? specificObservation,
  }) async {
    try {
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

      final service = await _requireService(churchServiceId);
      final serviceDate = service['service_date']?.toString();
      if (serviceDate == null || serviceDate.isEmpty) {
        throw Exception('Church service has no date');
      }

      final observation = specificObservation?.trim();

      final response = await _client
          .from('church_attendance')
          .insert({
            'member_id': memberId,
            'church_service_id': churchServiceId,
            'service_date': serviceDate,
            'attendance_type': attendanceType,
            if (observation != null && observation.isNotEmpty)
              'specific_observation': observation,
            'created_by': currentUser.id,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('[ChurchAttendanceService] Error marking attendance: $e');
      throw Exception('Failed to mark attendance: $e');
    }
  }

  /// Mark attendance for multiple members (bulk operation).
  static Future<List<Map<String, dynamic>>> markBulkAttendance({
    required List<String> memberIds,
    required String churchServiceId,
    String attendanceType = 'onsite',
    Map<String, String?>? specificObservationsByMemberId,
  }) async {
    try {
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

      final service = await _requireService(churchServiceId);
      final serviceDate = service['service_date']?.toString();
      if (serviceDate == null || serviceDate.isEmpty) {
        throw Exception('Church service has no date');
      }

      final attendanceRecords = memberIds.map((memberId) {
        final observation =
            specificObservationsByMemberId?[memberId]?.trim();
        return {
          'member_id': memberId,
          'church_service_id': churchServiceId,
          'service_date': serviceDate,
          'attendance_type': attendanceType,
          if (observation != null && observation.isNotEmpty)
            'specific_observation': observation,
          'created_by': currentUser.id,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      final response = await _client
          .from('church_attendance')
          .insert(attendanceRecords)
          .select();

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
    String? churchServiceId,
    int? limit,
    int? offset,
  }) async {
    try {
      dynamic filterQuery = _client
          .from('church_attendance')
          .select(
            '*, church_service:church_services(id, name, service_date)',
          )
          .eq('member_id', memberId);

      if (startDate != null) {
        filterQuery = filterQuery.gte(
          'service_date',
          _dateOnly(startDate),
        );
      }
      if (endDate != null) {
        filterQuery = filterQuery.lte(
          'service_date',
          _dateOnly(endDate),
        );
      }
      if (churchServiceId != null) {
        filterQuery = filterQuery.eq('church_service_id', churchServiceId);
      }

      dynamic transformQuery = filterQuery.order(
        'service_date',
        ascending: false,
      );

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
      return records.where((r) => r['deleted_at'] == null).toList();
    } catch (e) {
      debugPrint(
        '[ChurchAttendanceService] Error getting member attendance: $e',
      );
      throw Exception('Failed to get member attendance: $e');
    }
  }

  /// Get attendance for a specific church service
  static Future<List<Map<String, dynamic>>> getServiceAttendance({
    required String churchServiceId,
  }) async {
    try {
      final response = await _client
          .from('church_attendance')
          .select(
            '*, member:members(id, first_name, last_name, email, birthday, is_new_comer)',
          )
          .eq('church_service_id', churchServiceId)
          .order('created_at', ascending: false);

      final records = List<Map<String, dynamic>>.from(response);
      return records.where((r) => r['deleted_at'] == null).toList();
    } catch (e) {
      debugPrint(
        '[ChurchAttendanceService] Error getting service attendance: $e',
      );
      throw Exception('Failed to get service attendance: $e');
    }
  }

  /// List church services with attendance counts (onsite/online members).
  static Future<List<Map<String, dynamic>>> getAllServices({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final services = await ChurchServiceService.getAllServices(
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
      if (services.isEmpty) return services;

      const pageSize = 1000;
      var offset = 0;
      var hasMore = true;
      final records = <Map<String, dynamic>>[];

      while (hasMore) {
        dynamic query = _client
            .from('church_attendance')
            .select(
              'church_service_id, id, attendance_type, member_id, deleted_at, created_at',
            )
            .isFilter('deleted_at', null);

        if (startDate != null) {
          query = query.gte('service_date', _dateOnly(startDate));
        }
        if (endDate != null) {
          query = query.lte('service_date', _dateOnly(endDate));
        }

        query = query
            .order('created_at', ascending: false)
            .range(offset, offset + pageSize - 1);

        final page = List<Map<String, dynamic>>.from(await query);
        records.addAll(page);
        hasMore = page.length == pageSize;
        offset += page.length;
      }

      final latestByServiceMember = <String, Map<String, dynamic>>{};
      for (final record in records) {
        final serviceId = record['church_service_id']?.toString();
        final memberId = record['member_id']?.toString();
        if (serviceId == null || memberId == null) continue;
        final key = '${serviceId}_$memberId';
        final existing = latestByServiceMember[key];
        if (existing == null) {
          latestByServiceMember[key] = record;
          continue;
        }
        final existingCreatedAt = existing['created_at']?.toString() ?? '';
        final incomingCreatedAt = record['created_at']?.toString() ?? '';
        if (incomingCreatedAt.compareTo(existingCreatedAt) >= 0) {
          latestByServiceMember[key] = record;
        }
      }

      final attendedMemberSets = <String, Set<String>>{};
      for (final row in latestByServiceMember.values) {
        final serviceId = row['church_service_id']?.toString();
        final memberId = row['member_id']?.toString();
        final attendanceType = row['attendance_type']?.toString();
        if (serviceId == null || memberId == null) continue;
        if (attendanceType == 'onsite' || attendanceType == 'online') {
          attendedMemberSets.putIfAbsent(serviceId, () => <String>{});
          attendedMemberSets[serviceId]!.add(memberId);
        }
      }

      return services.map((service) {
        final id = service['id']?.toString() ?? '';
        return {
          ...service,
          'attendance_count': attendedMemberSets[id]?.length ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('[ChurchAttendanceService] Error getting all services: $e');
      throw Exception('Failed to get all services: $e');
    }
  }

  /// Get raw church attendance rows with pagination support.
  static Future<List<Map<String, dynamic>>> getRawAttendanceRows({
    DateTime? startDate,
    DateTime? endDate,
    String? churchServiceId,
    bool includeDeleted = false,
    int limit = 300,
    int offset = 0,
  }) async {
    try {
      dynamic query = _client
          .from('church_attendance')
          .select(
            'id, member_id, service_date, church_service_id, attendance_type, deleted_at',
          );

      if (startDate != null) {
        query = query.gte('service_date', _dateOnly(startDate));
      }
      if (endDate != null) {
        query = query.lte('service_date', _dateOnly(endDate));
      }
      if (churchServiceId != null) {
        query = query.eq('church_service_id', churchServiceId);
      }
      if (!includeDeleted) {
        query = query.isFilter('deleted_at', null);
      }

      query = query
          .order('service_date', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint(
        '[ChurchAttendanceService] Error getting raw attendance rows: $e',
      );
      throw Exception('Failed to get raw attendance rows: $e');
    }
  }

  /// Get attendance count for a member in the last 3 months
  static Future<int> getMemberAttendanceCountLast3Months(
    String memberId,
  ) async {
    try {
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      final dateString = _dateOnly(threeMonthsAgo);

      final response = await _client
          .from('church_attendance')
          .select('id')
          .eq('member_id', memberId)
          .gte('service_date', dateString);

      final records = List<Map<String, dynamic>>.from(response);
      return records.where((r) => r['deleted_at'] == null).length;
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
    String? specificObservation,
    bool clearSpecificObservation = false,
    String? churchServiceId,
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

      if (churchServiceId != null) {
        final service = await _requireService(churchServiceId);
        updates['church_service_id'] = churchServiceId;
        updates['service_date'] = service['service_date'];
      }

      if (clearSpecificObservation) {
        updates['specific_observation'] = null;
      } else if (specificObservation != null) {
        final trimmed = specificObservation.trim();
        updates['specific_observation'] =
            trimmed.isEmpty ? null : trimmed;
      }

      final response = await _client
          .from('church_attendance')
          .update(updates)
          .eq('id', attendanceId)
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('[ChurchAttendanceService] Error updating attendance: $e');
      throw Exception('Failed to update attendance: $e');
    }
  }

  /// Soft-delete a church service and all of its attendance rows.
  static Future<void> deleteService({
    required String churchServiceId,
  }) async {
    try {
      final deletedAt = DateTime.now().toIso8601String();
      await _client
          .from('church_attendance')
          .update({'deleted_at': deletedAt, 'updated_at': deletedAt})
          .eq('church_service_id', churchServiceId)
          .isFilter('deleted_at', null);

      await ChurchServiceService.softDelete(churchServiceId);
    } catch (e) {
      debugPrint('[ChurchAttendanceService] Error deleting service: $e');
      throw Exception('Failed to delete service: $e');
    }
  }

  /// Remove attendance record (soft delete)
  static Future<void> removeAttendance(String attendanceId) async {
    try {
      await _client
          .from('church_attendance')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', attendanceId);
    } catch (e) {
      debugPrint('[ChurchAttendanceService] Error removing attendance: $e');
      throw Exception('Failed to remove attendance: $e');
    }
  }

  /// Check and update new comer status for a member
  static Future<bool> checkAndUpdateNewComerStatus(String memberId) async {
    try {
      final response = await _client.rpc(
        'check_and_update_new_comer_status',
        params: {'member_uuid': memberId},
      );
      return response == true;
    } catch (e) {
      debugPrint(
        '[ChurchAttendanceService] Error checking new comer status: $e',
      );
      return false;
    }
  }
}
