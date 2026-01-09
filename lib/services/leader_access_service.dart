import 'supabase_service.dart';

/// Leader access service for managing feature access permissions
class LeaderAccessService {
  static final _client = SupabaseService.client;

  /// Get all leaders (users with role 'leader')
  static Future<List<Map<String, dynamic>>> getLeaders() async {
    try {
      final response = await _client
          .from('users')
          .select('id, email, role, members(id, first_name, last_name)')
          .eq('role', 'leader')
          .eq('is_active', true)
          .order('email');

      final leaders = List<Map<String, dynamic>>.from(response);
      return leaders;
    } catch (e) {
      throw Exception('Failed to get leaders: $e');
    }
  }

  /// Get access permissions for a specific leader
  static Future<List<Map<String, dynamic>>> getLeaderAccess(String userId) async {
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
