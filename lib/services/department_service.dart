import 'supabase_service.dart';
import 'user_management_service.dart';

/// Department service for department management
class DepartmentService {
  static final _client = SupabaseService.client;

  /// Create department
  /// POST /departments
  static Future<Map<String, dynamic>> createDepartment({
    required Map<String, dynamic> departmentData,
  }) async {
    try {
      final response = await _client
          .from('departments')
          .insert({
            ...departmentData,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to create department: $e');
    }
  }

  /// Get all departments
  /// GET /departments
  static Future<List<Map<String, dynamic>>> getDepartments({
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
  }) async {
    try {
      // Build base query with filters
      var filterQuery = _client.from('departments').select();

      // Apply filters
      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null) {
            filterQuery = filterQuery.eq(key, value);
          }
        });
      }

      // Apply pagination
      // Note: limit() and range() can be called on PostgrestFilterBuilder
      // and return PostgrestTransformBuilder, so we use dynamic type
      dynamic paginatedQuery = filterQuery;
      if (limit != null) {
        paginatedQuery = paginatedQuery.limit(limit);
      }
      if (offset != null) {
        paginatedQuery = paginatedQuery.range(
          offset,
          offset + (limit ?? 10) - 1,
        );
      }

      final response = await paginatedQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get departments: $e');
    }
  }

  /// Get department by ID
  /// GET /departments/:id
  static Future<Map<String, dynamic>> getDepartmentById(
    String departmentId,
  ) async {
    try {
      final response = await _client
          .from('departments')
          .select()
          .eq('id', departmentId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to get department: $e');
    }
  }

  /// Update department
  /// PATCH /departments/:id
  static Future<Map<String, dynamic>> updateDepartment({
    required String departmentId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await _client
          .from('departments')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', departmentId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to update department: $e');
    }
  }

  /// Delete department (soft delete by setting is_active=false)
  /// DELETE /departments/:id
  static Future<void> deleteDepartment(String departmentId) async {
    try {
      await _client
          .from('departments')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', departmentId);
    } catch (e) {
      throw Exception('Failed to delete department: $e');
    }
  }

  /// Get department members
  static Future<List<Map<String, dynamic>>> getDepartmentMembers(
    String departmentId,
  ) async {
    try {
      final response = await _client
          .from('department_members')
          .select('*, members(*)')
          .eq('department_id', departmentId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get department members: $e');
    }
  }

  /// Add member to department (as leader/subleader/member)
  /// POST /departments/:id/members
  /// Business Rules:
  /// - When assigned as Leader → user.active=true, user.role=leader, default password, must_change_password=true
  /// - When re-assigned as leader → user.active=true, existing password preserved (unless admin forced reset)
  static Future<void> addMemberToDepartment({
    required String departmentId,
    required String memberId,
    required String role, // 'leader', 'subleader', 'member'
    String? defaultPassword, // Default password for new leaders
  }) async {
    try {
      // Check if member is already in department
      final existing = await _client
          .from('department_members')
          .select()
          .eq('department_id', departmentId)
          .eq('member_id', memberId)
          .maybeSingle();

      if (existing != null) {
        // Update role if already exists
        await _client
            .from('department_members')
            .update({
              'role': role,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('department_id', departmentId)
            .eq('member_id', memberId);
      } else {
        // Insert new assignment
        await _client.from('department_members').insert({
          'department_id': departmentId,
          'member_id': memberId,
          'role': role,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Business Rule: If assigned as leader/subleader, activate user
      if (role == 'leader' || role == 'subleader') {
        final userId = await UserManagementService.getUserIdForMember(memberId);

        if (userId != null) {
          // Check if user is already active (re-assignment)
          final user = await _client
              .from('users')
              .select('is_active')
              .eq('id', userId)
              .maybeSingle();

          final isReactivation = user?['is_active'] == false;

          if (isReactivation) {
            // Re-assignment: Reactivate but preserve password
            await UserManagementService.reactivateUserAsLeader(userId: userId);
          } else {
            // New assignment: Activate with default password
            await UserManagementService.activateUserAsLeader(
              userId: userId,
              defaultPassword:
                  defaultPassword ??
                  'DefaultPassword123!', // Should be configurable
            );
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to add member to department: $e');
    }
  }

  /// Remove member from department (triggers deactivation check)
  /// DELETE /departments/:id/members/:memberId
  /// Business Rule: When member no longer has leadership in any department → user.active=false, password preserved
  /// Edge case: Checks other department assignments before deactivation
  static Future<void> removeMemberFromDepartment({
    required String departmentId,
    required String memberId,
  }) async {
    try {
      // Get the role being removed
      final assignment = await _client
          .from('department_members')
          .select('role')
          .eq('department_id', departmentId)
          .eq('member_id', memberId)
          .maybeSingle();

      final removedRole = assignment?['role'] as String?;

      // Remove from this department
      await _client
          .from('department_members')
          .delete()
          .eq('department_id', departmentId)
          .eq('member_id', memberId);

      // Business Rule: If removed role was leader/subleader, check if still has leadership
      if (removedRole == 'leader' || removedRole == 'subleader') {
        final userId = await UserManagementService.getUserIdForMember(memberId);

        if (userId != null) {
          // Check if member still has any leadership roles
          final hasLeadership = await UserManagementService.hasLeadershipRole(
            memberId,
          );

          if (!hasLeadership) {
            // Business Rule: Deactivate user but preserve password
            await UserManagementService.deactivateUserIfNoLeadership(
              userId: userId,
              memberId: memberId,
            );
          }
        }
      }

      // Edge case: Check if member has other department assignments before deactivating member
      final otherAssignments = await _client
          .from('department_members')
          .select()
          .eq('member_id', memberId);

      // Only deactivate member if no department assignments remain
      if ((otherAssignments as List).isEmpty) {
        await _client
            .from('members')
            .update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', memberId);
      }
    } catch (e) {
      throw Exception('Failed to remove member from department: $e');
    }
  }
}
