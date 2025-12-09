import 'supabase_service.dart';

/// Service for managing user accounts linked to members
/// Handles business rules for user activation/deactivation based on leadership roles
class UserManagementService {
  static final _client = SupabaseService.client;

  /// Create inactive user account for a member
  /// Called when admin creates a member
  static Future<String?> createInactiveUserForMember({
    required String memberId,
    required String? email,
    required String? phone,
  }) async {
    try {
      // Use email or phone as identifier
      final identifier = email ?? phone;
      if (identifier == null) {
        throw Exception(
          'Member must have email or phone to create user account',
        );
      }

      // Create user in Supabase Auth (inactive)
      // Note: In production, this should be done server-side via Supabase Admin API
      // For client-side, we'll create a record in users table
      final userData = {
        'email': email,
        'phone': phone,
        'member_id': memberId,
        'is_active': false,
        'role': 'member',
        'must_change_password': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert into users table (if using custom users table)
      // Or use Supabase Admin API to create auth user
      final response = await _client
          .from('users')
          .insert(userData)
          .select()
          .single();

      return response['id']?.toString();
    } catch (e) {
      throw Exception('Failed to create user account: $e');
    }
  }

  /// Activate user and set as leader when assigned leadership role
  /// Sets default password and must_change_password=true
  static Future<void> activateUserAsLeader({
    required String userId,
    String? defaultPassword,
  }) async {
    try {
      // Get current user to check if password exists
      final user = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      final hasPassword = user?['encrypted_password'] != null;

      // Update user: activate, set role, set default password if needed
      final updates = <String, dynamic>{
        'is_active': true,
        'role': 'leader',
        'must_change_password': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Only set default password if user doesn't have one
      if (!hasPassword && defaultPassword != null) {
        // Note: In production, hash password server-side
        // For now, we'll set a flag that password needs to be set
        updates['encrypted_password'] = defaultPassword; // Should be hashed
      }

      await _client.from('users').update(updates).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to activate user as leader: $e');
    }
  }

  /// Check if member has any leadership roles
  static Future<bool> hasLeadershipRole(String memberId) async {
    try {
      final leadershipRoles = await _client
          .from('department_members')
          .select()
          .eq('member_id', memberId)
          .inFilter('role', ['leader', 'subleader']);

      return (leadershipRoles as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Deactivate user when no longer has leadership roles
  /// Preserves password
  static Future<void> deactivateUserIfNoLeadership({
    required String userId,
    required String memberId,
  }) async {
    try {
      final hasLeadership = await hasLeadershipRole(memberId);

      if (!hasLeadership) {
        // Deactivate user but preserve password
        await _client
            .from('users')
            .update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
              // Note: Do NOT clear password or role
            })
            .eq('id', userId);
      }
    } catch (e) {
      throw Exception('Failed to deactivate user: $e');
    }
  }

  /// Reactivate user when re-assigned as leader
  /// Preserves existing password unless admin forced reset
  static Future<void> reactivateUserAsLeader({required String userId}) async {
    try {
      // Get current user to check must_change_password flag
      final user = await _client
          .from('users')
          .select('must_change_password')
          .eq('id', userId)
          .maybeSingle();

      final mustChangePassword = user?['must_change_password'] == true;

      // Reactivate and set role, but preserve password
      await _client
          .from('users')
          .update({
            'is_active': true,
            'role': 'leader',
            // Keep must_change_password as is (only set if admin forced reset)
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to reactivate user as leader: $e');
    }
  }

  /// Get user ID for a member
  static Future<String?> getUserIdForMember(String memberId) async {
    try {
      final user = await _client
          .from('users')
          .select('id')
          .eq('member_id', memberId)
          .maybeSingle();

      return user?['id']?.toString();
    } catch (e) {
      return null;
    }
  }
}
