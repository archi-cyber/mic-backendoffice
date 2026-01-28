import 'supabase_service.dart';

/// Leader access service for managing feature access permissions
class LeaderAccessService {
  static final _client = SupabaseService.client;

  /// Get all leaders and members with accounts (for access management)
  /// Includes: role='leader', department leaders/subleaders, and role='member'
  static Future<List<Map<String, dynamic>>> getLeaders() async {
    try {
      // Get users with role='leader' in users table
      final usersWithLeaderRole = await _client
          .from('users')
          .select('id, email, role, members(id, first_name, last_name)')
          .eq('role', 'leader')
          .eq('is_active', true);

      // Get users with role='member' (member accounts - view-only by default)
      final memberUsers = await _client
          .from('users')
          .select('id, email, role, members(id, first_name, last_name)')
          .eq('role', 'member')
          .eq('is_active', true);

      // Get all member_ids who are leaders or subleaders in any department
      final departmentLeadersResponse = await _client
          .from('department_members')
          .select('member_id')
          .inFilter('role', ['leader', 'subleader']);

      // Extract unique member_ids
      final Set<String> leaderMemberIds = {};
      for (var item in departmentLeadersResponse) {
        final memberId = item['member_id']?.toString();
        if (memberId != null) {
          leaderMemberIds.add(memberId);
        }
      }

      // Get users for these member_ids (where member_id matches)
      List<Map<String, dynamic>> departmentLeaderUsers = [];
      if (leaderMemberIds.isNotEmpty) {
        final usersResponse = await _client
            .from('users')
            .select('id, email, role, members(id, first_name, last_name)')
            .inFilter('member_id', leaderMemberIds.toList())
            .eq('is_active', true);

        departmentLeaderUsers = List<Map<String, dynamic>>.from(usersResponse);
      }

      // Combine and deduplicate by user id
      final Map<String, Map<String, dynamic>> leadersMap = {};

      // Add users with role='leader'
      for (var user in usersWithLeaderRole) {
        final id = user['id'].toString();
        leadersMap[id] = user;
      }

      // Add department leaders/subleaders (will overwrite if already exists, which is fine)
      for (var user in departmentLeaderUsers) {
        final id = user['id'].toString();
        leadersMap[id] = user;
      }

      // Add member-role users (so admins can manage their access)
      for (var user in memberUsers as List) {
        final id = user['id'].toString();
        leadersMap[id] = Map<String, dynamic>.from(user);
      }

      final leaders = leadersMap.values.toList();
      // Sort by role (leaders first) then email
      leaders.sort((a, b) {
        final roleA = a['role']?.toString() ?? '';
        final roleB = b['role']?.toString() ?? '';
        final roleCompare = roleB.compareTo(roleA); // leader before member
        if (roleCompare != 0) return roleCompare;
        final emailA = a['email']?.toString() ?? '';
        final emailB = b['email']?.toString() ?? '';
        return emailA.compareTo(emailB);
      });

      return leaders;
    } catch (e) {
      throw Exception('Failed to get leaders: $e');
    }
  }

  /// Get access permissions for a specific leader
  static Future<List<Map<String, dynamic>>> getLeaderAccess(
    String userId,
  ) async {
    try {
      final response = await _client
          .from('leader_access')
          .select()
          .eq('user_id', userId)
          .order('feature_name');

      final records = List<Map<String, dynamic>>.from(response);
      // Filter out deleted records
      return records.where((r) => r['deleted_at'] == null).toList();
    } catch (e) {
      throw Exception('Failed to get leader access: $e');
    }
  }

  /// Get access permission for a specific leader and feature
  static Future<Map<String, dynamic>?> getLeaderFeatureAccess({
    required String userId,
    required String featureName,
  }) async {
    try {
      final response = await _client
          .from('leader_access')
          .select()
          .eq('user_id', userId)
          .eq('feature_name', featureName)
          .maybeSingle();

      if (response == null) return null;
      // Filter out deleted records
      if (response['deleted_at'] != null) return null;

      return response;
    } catch (e) {
      throw Exception('Failed to get leader feature access: $e');
    }
  }

  /// Set or update access permissions for a leader and feature
  static Future<Map<String, dynamic>> setLeaderAccess({
    required String userId,
    required String featureName,
    required bool canView,
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
  }) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated');
      }

      // Check if access record already exists
      final existingResponse = await _client
          .from('leader_access')
          .select('id')
          .eq('user_id', userId)
          .eq('feature_name', featureName)
          .maybeSingle();

      // Filter out deleted records
      Map<String, dynamic>? existing;
      if (existingResponse != null && existingResponse['deleted_at'] == null) {
        existing = existingResponse;
      }

      if (existing != null) {
        // Update existing record
        final response = await _client
            .from('leader_access')
            .update({
              'can_view': canView,
              'can_create': canCreate,
              'can_edit': canEdit,
              'can_delete': canDelete,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id'])
            .select()
            .single();

        return response;
      } else {
        // Create new record
        final response = await _client
            .from('leader_access')
            .insert({
              'user_id': userId,
              'feature_name': featureName,
              'can_view': canView,
              'can_create': canCreate,
              'can_edit': canEdit,
              'can_delete': canDelete,
              'created_by': currentUser.id,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        return response;
      }
    } catch (e) {
      throw Exception('Failed to set leader access: $e');
    }
  }

  /// Delete access permission for a leader and feature (soft delete)
  static Future<void> deleteLeaderAccess({
    required String userId,
    required String featureName,
  }) async {
    try {
      // First check if record exists and is not deleted
      final checkResponse = await _client
          .from('leader_access')
          .select('id')
          .eq('user_id', userId)
          .eq('feature_name', featureName)
          .maybeSingle();

      if (checkResponse != null && checkResponse['deleted_at'] == null) {
        await _client
            .from('leader_access')
            .update({
              'deleted_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', checkResponse['id']);
      }
    } catch (e) {
      throw Exception('Failed to delete leader access: $e');
    }
  }

  /// Check if a leader has a specific permission for a feature
  static Future<bool> hasPermission({
    required String userId,
    required String featureName,
    required String permission, // 'view', 'create', 'edit', 'delete'
  }) async {
    try {
      final access = await getLeaderFeatureAccess(
        userId: userId,
        featureName: featureName,
      );

      if (access == null) return false;

      switch (permission.toLowerCase()) {
        case 'view':
          return access['can_view'] == true;
        case 'create':
          return access['can_create'] == true;
        case 'edit':
          return access['can_edit'] == true;
        case 'delete':
          return access['can_delete'] == true;
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Get all available features
  static List<String> getAvailableFeatures() {
    return [
      'members',
      'departments',
      'trainings',
      'events',
      'tasks',
      'reports',
      'church_attendance',
      'sunday_school_attendance',
      'visitors',
      'giving',
      'chat',
      'teachings',
    ];
  }
}
