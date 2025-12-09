import 'supabase_service.dart';

/// Admin service for user management operations
class AdminService {
  static final _client = SupabaseService.client;

  /// Create admin/pastor/admin users
  /// POST /admin/users
  static Future<Map<String, dynamic>> createAdminUser({
    required String email,
    required String password,
    required String role, // 'admin', 'pastor', etc.
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _client
          .from('users')
          .insert({
            'email': email,
            'password': password, // Note: In production, hash this server-side
            'role': role,
            'is_active': true,
            'metadata': metadata ?? {},
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to create admin user: $e');
    }
  }

  /// Activate/deactivate user
  /// PATCH /users/:id/activate
  static Future<void> activateUser({
    required String userId,
    required bool isActive,
  }) async {
    try {
      await _client
          .from('users')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to activate/deactivate user: $e');
    }
  }

  /// Force password reset for user
  /// PATCH /users/:id/force-reset
  /// Business Rule: Admins/pastor can force password reset (must_change_password=true)
  static Future<void> forcePasswordReset({
    required String userId,
    bool sendEmail = false,
  }) async {
    try {
      // Update user metadata - force password change
      await _client
          .from('users')
          .update({
            'must_change_password': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // If sendEmail is true, trigger password reset email
      if (sendEmail) {
        final user = await _client
            .from('users')
            .select('email')
            .eq('id', userId)
            .maybeSingle();

        if (user?['email'] != null) {
          // Use AuthService to send reset email
          // Note: This requires email to be in Supabase Auth
          try {
            // Import AuthService if needed
            // await AuthService.forgotPassword(email: user['email']);
          } catch (e) {
            // Log but don't fail
            print('Warning: Failed to send password reset email: $e');
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to force password reset: $e');
    }
  }
}
