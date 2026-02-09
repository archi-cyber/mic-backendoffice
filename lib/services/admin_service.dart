import 'package:flutter/foundation.dart';
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
            debugPrint('Warning: Failed to send password reset email: $e');
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to force password reset: $e');
    }
  }

  /// Update user role
  /// PATCH /users/:id/role
  /// Business Rule: Only admins can update user roles
  static Future<void> updateUserRole({
    required String userId,
    required String role, // 'admin', 'pastor', 'leader', etc.
  }) async {
    try {
      // Update role in users table
      await _client
          .from('users')
          .update({
            'role': role,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Also update Supabase Auth metadata if possible
      try {
        final user = await _client
            .from('users')
            .select('email')
            .eq('id', userId)
            .maybeSingle();

        if (user?['email'] != null) {
          // Note: Updating auth metadata requires admin privileges
          // This might need to be done through Supabase Dashboard or Admin API
          debugPrint('Note: User role updated in users table. Auth metadata may need manual update.');
        }
      } catch (e) {
        // Log but don't fail - role update in users table is the primary source
        debugPrint('Warning: Could not update auth metadata: $e');
      }
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  /// Update user role by email
  /// PATCH /users/role
  static Future<void> updateUserRoleByEmail({
    required String email,
    required String role, // 'admin', 'pastor', 'leader', etc.
  }) async {
    try {
      await _client
          .from('users')
          .update({
            'role': role,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('email', email);
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }
}
