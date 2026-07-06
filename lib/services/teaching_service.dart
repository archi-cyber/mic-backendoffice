import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'task_service.dart';

/// Teaching service for teaching management operations
class TeachingService {
  static final _client = SupabaseService.client;

  /// Create teaching
  /// POST /teachings
  static Future<Map<String, dynamic>> createTeaching({
    required Map<String, dynamic> teachingData,
  }) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to create teaching');
      }

      final response = await _client
          .from('teachings')
          .insert({
            ...teachingData,
            'created_by': currentUser.id,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      try {
        await TaskService.createTeachingTasks(teaching: response);
      } catch (e) {
        debugPrint(
          '[TeachingService] Teaching created, but auto-tasks failed: $e',
        );
      }

      return response;
    } catch (e) {
      throw Exception('Failed to create teaching: $e');
    }
  }

  /// Get teachings with optional filters
  /// GET /teachings
  static Future<List<Map<String, dynamic>>> getTeachings({
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
    String? orderBy,
    bool ascending = false,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Build base query with filters
      var filterQuery = _client.from('teachings').select();

      // Apply date filters
      if (fromDate != null) {
        filterQuery = filterQuery.gte(
          'teaching_date',
          fromDate.toIso8601String().split('T')[0],
        );
      }
      if (toDate != null) {
        filterQuery = filterQuery.lte(
          'teaching_date',
          toDate.toIso8601String().split('T')[0],
        );
      }

      // Apply other filters
      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null) {
            filterQuery = filterQuery.eq(key, value);
          }
        });
      }

      // Apply ordering (returns PostgrestTransformBuilder)
      dynamic transformQuery = filterQuery;
      if (orderBy != null) {
        transformQuery = transformQuery.order(orderBy, ascending: ascending);
      } else {
        // Default to most recent teachings first
        transformQuery = transformQuery
            .order('teaching_date', ascending: false)
            .order('created_at', ascending: false);
      }

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
      throw Exception('Failed to get teachings: $e');
    }
  }

  /// Get teaching by ID
  /// GET /teachings/:id
  static Future<Map<String, dynamic>> getTeachingById(String teachingId) async {
    try {
      final response = await _client
          .from('teachings')
          .select()
          .eq('id', teachingId)
          .single();

      // Filter out deleted records
      if (response['deleted_at'] != null) {
        throw Exception('Teaching not found');
      }

      return response;
    } catch (e) {
      throw Exception('Failed to get teaching: $e');
    }
  }

  /// Update teaching
  /// PATCH /teachings/:id
  static Future<Map<String, dynamic>> updateTeaching({
    required String teachingId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await _client
          .from('teachings')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', teachingId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to update teaching: $e');
    }
  }

  /// Delete teaching (soft delete)
  /// DELETE /teachings/:id
  static Future<void> deleteTeaching(String teachingId) async {
    try {
      await _client
          .from('teachings')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', teachingId);
    } catch (e) {
      throw Exception('Failed to delete teaching: $e');
    }
  }

  /// Get listeners for a teaching
  /// GET /teachings/:id/listeners
  static Future<List<Map<String, dynamic>>> getTeachingListeners(
    String teachingId,
  ) async {
    try {
      final response = await _client
          .from('teaching_listeners')
          .select('''
            *,
            members (
              id,
              first_name,
              last_name,
              email,
              role
            )
          ''')
          .eq('teaching_id', teachingId)
          .order('created_at', ascending: false);

      final records = List<Map<String, dynamic>>.from(response);
      // Filter out deleted records
      return records.where((r) => r['deleted_at'] == null).toList();
    } catch (e) {
      throw Exception('Failed to get teaching listeners: $e');
    }
  }

  /// Get all workers, leaders, and admins (potential listeners)
  /// GET /members?role=worker,leader,admin
  static Future<List<Map<String, dynamic>>> getPotentialListeners() async {
    try {
      final response = await _client
          .from('members')
          .select('id, first_name, last_name, email, role')
          .inFilter('role', ['worker', 'leader', 'admin'])
          .order('first_name', ascending: true)
          .order('last_name', ascending: true);

      final records = List<Map<String, dynamic>>.from(response);
      // Return all members (no filtering by deleted_at as per requirements)
      return records;
    } catch (e) {
      throw Exception('Failed to get potential listeners: $e');
    }
  }

  /// Add listener to teaching
  /// POST /teaching_listeners
  static Future<Map<String, dynamic>> addListener({
    required String teachingId,
    required String memberId,
  }) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated');
      }

      final response = await _client
          .from('teaching_listeners')
          .insert({
            'teaching_id': teachingId,
            'member_id': memberId,
            'created_by': currentUser.id,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to add listener: $e');
    }
  }

  /// Remove listener from teaching (soft delete)
  /// DELETE /teaching_listeners/:id
  static Future<void> removeListener(String listenerId) async {
    try {
      await _client
          .from('teaching_listeners')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', listenerId);
    } catch (e) {
      throw Exception('Failed to remove listener: $e');
    }
  }

  /// Sync teaching listeners from church attendance
  /// Calls the sync_teaching_listeners SQL function
  static Future<int> syncListenersFromAttendance(String teachingId) async {
    try {
      // Call the SQL function
      final response = await _client.rpc(
        'sync_teaching_listeners',
        params: {'teaching_uuid': teachingId},
      );

      return response as int;
    } catch (e) {
      throw Exception('Failed to sync listeners: $e');
    }
  }
}
