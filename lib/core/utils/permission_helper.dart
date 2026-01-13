import '../../services/role_service.dart';
import '../../services/leader_access_service.dart';
import '../../services/supabase_service.dart';

/// Helper utility for checking feature permissions
/// Handles both admin/pastor (full access) and leader (granular access)
class PermissionHelper {
  /// Check if current user is a leader (has role='leader' OR is a department leader/subleader)
  static Future<bool> _isLeader() async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) return false;

    // Check if user has role='leader' in users table
    final role = await RoleService.getUserRole(userId: currentUser.id);
    if (role == 'leader') return true;

    // Also check if user is a department leader or subleader
    try {
      final _client = SupabaseService.client;
      final user = await _client
          .from('users')
          .select('member_id')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (user == null || user['member_id'] == null) return false;

      final memberId = user['member_id'].toString();

      // Check if member is a leader or subleader of any department
      final assignment = await _client
          .from('department_members')
          .select('id')
          .eq('member_id', memberId)
          .inFilter('role', ['leader', 'subleader'])
          .limit(1)
          .maybeSingle();

      return assignment != null;
    } catch (e) {
      return false;
    }
  }
  /// Check if current user can view a feature
  static Future<bool> canView(String featureName) async {
    // Admins and pastors have full access
    final isAdmin = await RoleService.isCurrentUserAdmin();
    if (isAdmin) return true;

    // Check if user is a leader (has role='leader' OR is department leader/subleader)
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) return false;

    final isLeader = await _isLeader();
    if (!isLeader) return false;

    // Check leader access
    return await LeaderAccessService.hasPermission(
      userId: currentUser.id,
      featureName: featureName,
      permission: 'view',
    );
  }

  /// Check if current user can create in a feature
  static Future<bool> canCreate(String featureName) async {
    // Admins and pastors have full access
    final isAdmin = await RoleService.isCurrentUserAdmin();
    if (isAdmin) return true;

    // Check if user is a leader (has role='leader' OR is department leader/subleader)
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) return false;

    final isLeader = await _isLeader();
    if (!isLeader) return false;

    // Check leader access
    return await LeaderAccessService.hasPermission(
      userId: currentUser.id,
      featureName: featureName,
      permission: 'create',
    );
  }

  /// Check if current user can edit in a feature
  static Future<bool> canEdit(String featureName) async {
    // Admins and pastors have full access
    final isAdmin = await RoleService.isCurrentUserAdmin();
    if (isAdmin) return true;

    // Check if user is a leader (has role='leader' OR is department leader/subleader)
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) return false;

    final isLeader = await _isLeader();
    if (!isLeader) return false;

    // Check leader access
    return await LeaderAccessService.hasPermission(
      userId: currentUser.id,
      featureName: featureName,
      permission: 'edit',
    );
  }

  /// Check if current user can delete in a feature
  static Future<bool> canDelete(String featureName) async {
    // Admins and pastors have full access
    final isAdmin = await RoleService.isCurrentUserAdmin();
    if (isAdmin) return true;

    // Check if user is a leader (has role='leader' OR is department leader/subleader)
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) return false;

    final isLeader = await _isLeader();
    if (!isLeader) return false;

    // Check leader access
    return await LeaderAccessService.hasPermission(
      userId: currentUser.id,
      featureName: featureName,
      permission: 'delete',
    );
  }

  /// Check if current user is admin or pastor (full access)
  static Future<bool> isAdminOrPastor() async {
    return await RoleService.isCurrentUserAdmin();
  }

  /// Get all permissions for a feature at once
  static Future<Map<String, bool>> getPermissions(String featureName) async {
    return {
      'view': await canView(featureName),
      'create': await canCreate(featureName),
      'edit': await canEdit(featureName),
      'delete': await canDelete(featureName),
    };
  }
}
