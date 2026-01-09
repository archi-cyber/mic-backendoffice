import 'supabase_service.dart';
import 'user_management_service.dart';
import 'role_service.dart';

/// Department service for department management
class DepartmentService {
  static final _client = SupabaseService.client;

  /// Check if current user is a leader of a specific department
  static Future<bool> isDepartmentLeader(String departmentId) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return false;

      // Check if user is admin (admins can manage all departments)
      final isAdmin = await RoleService.isCurrentUserAdmin();
      if (isAdmin) return true;

      // Get user's member_id
      final user = await _client
          .from('users')
          .select('member_id')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (user == null || user['member_id'] == null) return false;

      final memberId = user['member_id'].toString();

      // Check if member is a leader of this department
      final assignment = await _client
          .from('department_members')
          .select('role')
          .eq('department_id', departmentId)
          .eq('member_id', memberId)
          .eq('role', 'leader')
          .maybeSingle();

      return assignment != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if current user is a subleader of a specific department
  static Future<bool> isDepartmentSubleader(String departmentId) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return false;

      // Get user's member_id
      final user = await _client
          .from('users')
          .select('member_id')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (user == null || user['member_id'] == null) return false;

      final memberId = user['member_id'].toString();

      // Check if member is a subleader of this department
      final assignment = await _client
          .from('department_members')
          .select('role')
          .eq('department_id', departmentId)
          .eq('member_id', memberId)
          .eq('role', 'subleader')
          .maybeSingle();

      return assignment != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if current user can edit a department (admin, leader, or subleader)
  static Future<bool> canEditDepartment(String departmentId) async {
    try {
      final isAdmin = await RoleService.isCurrentUserAdmin();
      if (isAdmin) return true;

      final isLeader = await isDepartmentLeader(departmentId);
      if (isLeader) return true;

      final isSubleader = await isDepartmentSubleader(departmentId);
      return isSubleader;
    } catch (e) {
      return false;
    }
  }

  /// Check if current user can delete a department (admin or leader only, not subleader)
  static Future<bool> canDeleteDepartment(String departmentId) async {
    try {
      final isAdmin = await RoleService.isCurrentUserAdmin();
      if (isAdmin) return true;

      final isLeader = await isDepartmentLeader(departmentId);
      return isLeader;
    } catch (e) {
      return false;
    }
  }

  /// Create department
  /// POST /departments
  /// Only admin or department leaders can create departments
  static Future<Map<String, dynamic>> createDepartment({
    required Map<String, dynamic> departmentData,
  }) async {
    try {
      // Check if user has permission (admin or any department leader)
      final isAdmin = await RoleService.isCurrentUserAdmin();
      
      if (!isAdmin) {
        // Check if user is a leader of any department
        final currentUser = SupabaseService.currentUser;
        if (currentUser == null) {
          throw Exception('Must be logged in');
        }

        final user = await _client
            .from('users')
            .select('member_id')
            .eq('id', currentUser.id)
            .maybeSingle();

        if (user == null || user['member_id'] == null) {
          throw Exception('Admin or leader required');
        }

        final memberId = user['member_id'].toString();

        // Check if user is a leader of any department
        final hasLeadership = await _client
            .from('department_members')
            .select('id')
            .eq('member_id', memberId)
            .eq('role', 'leader')
            .maybeSingle();

        if (hasLeadership == null) {
          throw Exception('Admin or leader required');
        }
      }

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
      throw Exception('Failed to create department');
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
      throw Exception('Failed to load departments');
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
      throw Exception('Failed to load department');
    }
  }

  /// Update department
  /// PATCH /departments/:id
  /// Only admin, department leader, or subleader can update departments
  static Future<Map<String, dynamic>> updateDepartment({
    required String departmentId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      // Check if user has permission (admin, leader, or subleader of this department)
      final canEdit = await canEditDepartment(departmentId);

      if (!canEdit) {
        throw Exception('Admin, leader, or subleader required');
      }

      final response = await _client
          .from('departments')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', departmentId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to update department');
    }
  }

  /// Delete department (soft delete by setting is_active=false)
  /// DELETE /departments/:id
  /// Only admin or department leader can delete (not subleaders)
  static Future<void> deleteDepartment(String departmentId) async {
    try {
      // Check if user has permission (admin or leader only, not subleader)
      final canDelete = await canDeleteDepartment(departmentId);

      if (!canDelete) {
        throw Exception('Admin or leader required to delete department');
      }

      await _client
          .from('departments')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', departmentId);
    } catch (e) {
      throw Exception('Failed to delete department');
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
      throw Exception('Failed to load members');
    }
  }

  /// Get all workers with their departments
  /// Returns a list of workers, each with their department assignments
  static Future<List<Map<String, dynamic>>> getAllWorkersWithDepartments() async {
    try {
      // Get all department_members with member and department info
      final response = await _client
          .from('department_members')
          .select('*, members(*), departments(id, name)')
          .order('created_at', ascending: false);

      final records = List<Map<String, dynamic>>.from(response);
      
      // Group by member_id to combine multiple departments per worker
      final Map<String, Map<String, dynamic>> workersMap = {};
      
      for (final record in records) {
        final member = record['members'] as Map<String, dynamic>?;
        final department = record['departments'] as Map<String, dynamic>?;
        
        if (member == null) continue;
        
        final memberId = member['id']?.toString() ?? '';
        if (memberId.isEmpty) continue;

        // Initialize worker entry if not exists
        if (!workersMap.containsKey(memberId)) {
          workersMap[memberId] = {
            'member': member,
            'departments': <Map<String, dynamic>>[],
            'main_department_id': null,
          };
        }

        // Add department to worker's department list
        if (department != null) {
          final isMain = record['is_main'] == true;
          final deptInfo = {
            'department_id': department['id']?.toString(),
            'department_name': department['name']?.toString(),
            'role': record['role']?.toString() ?? 'member',
            'is_main': isMain,
          };
          
          // Track main department
          if (isMain) {
            workersMap[memberId]!['main_department_id'] = department['id']?.toString();
          }
          
          // Avoid duplicates
          final existingDept = workersMap[memberId]!['departments']
              as List<Map<String, dynamic>>;
          if (!existingDept.any((d) => d['department_id'] == deptInfo['department_id'])) {
            existingDept.add(deptInfo);
          }
        }
      }

      // Convert map to list and sort by member name
      final workersList = workersMap.values.toList();
      workersList.sort((a, b) {
        final memberA = a['member'] as Map<String, dynamic>;
        final memberB = b['member'] as Map<String, dynamic>;
        
        final firstNameA = (memberA['first_name'] ?? '').toString().toLowerCase();
        final lastNameA = (memberA['last_name'] ?? '').toString().toLowerCase();
        final firstNameB = (memberB['first_name'] ?? '').toString().toLowerCase();
        final lastNameB = (memberB['last_name'] ?? '').toString().toLowerCase();

        final firstNameComparison = firstNameA.compareTo(firstNameB);
        if (firstNameComparison != 0) {
          return firstNameComparison;
        }
        return lastNameA.compareTo(lastNameB);
      });

      return workersList;
    } catch (e) {
      throw Exception('Failed to load workers with departments: $e');
    }
  }

  /// Set main department for a worker
  /// This will unset any existing main department and set the new one
  static Future<void> setMainDepartment({
    required String memberId,
    required String departmentId,
  }) async {
    try {
      // First, unset all main departments for this member
      await _client
          .from('department_members')
          .update({'is_main': false})
          .eq('member_id', memberId);

      // Then set the new main department
      await _client
          .from('department_members')
          .update({
            'is_main': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('member_id', memberId)
          .eq('department_id', departmentId);
    } catch (e) {
      throw Exception('Failed to set main department: $e');
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
        var userId = await UserManagementService.getUserIdForMember(memberId);

        // If user doesn't exist, create account for the member
        if (userId == null) {
          // Get member details to create account
          final member = await _client
              .from('members')
              .select('email, phone')
              .eq('id', memberId)
              .maybeSingle();

          if (member != null) {
            final email = member['email'] as String?;
            final phone = member['phone'] as String?;

            if (email != null || phone != null) {
              // Create inactive user account first
              userId = await UserManagementService.createInactiveUserForMember(
                memberId: memberId,
                email: email,
                phone: phone,
              );
            } else {
              throw Exception('Email or phone required');
            }
          } else {
            throw Exception('Member not found');
          }
        }

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
                  'Password123', // Default password for new leaders
            );
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to add member');
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
      throw Exception('Failed to remove member');
    }
  }
}
