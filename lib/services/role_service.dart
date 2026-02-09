import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service for checking user roles and privileges
class RoleService {
  static final _client = SupabaseService.client;

  /// Special admin email that always has full privileges
  static const String superAdminEmail = 'mic@mic.com';

  /// Check if a user has admin privileges
  /// mic@mic.com always returns true
  static Future<bool> isAdmin({String? userId, String? email}) async {
    try {
      // Special case: mic@mic.com always has admin privileges
      if (email == superAdminEmail) {
        return true;
      }

      // If email is provided, check by email first
      if (email != null) {
        final user = await _client
            .from('users')
            .select('role, is_active, email')
            .eq('email', email)
            .maybeSingle();

        if (user != null) {
          // Ensure mic@mic.com always has admin role
          if (user['email'] == superAdminEmail) {
            // Update role to admin if not already
            final currentRole = user['role'] as String?;
            if (currentRole != 'admin') {
              await _client
                  .from('users')
                  .update({
                    'role': 'admin',
                    'is_active': true,
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('email', superAdminEmail);
            }
            return true;
          }

          final role = user['role'] as String?;
          final isActive = user['is_active'] == true;
          return (role == 'admin' || role == 'pastor') && isActive;
        }
      }

      // Check by user ID
      if (userId != null) {
        final user = await _client
            .from('users')
            .select('role, is_active, email')
            .eq('id', userId)
            .maybeSingle();

        if (user != null) {
          // Ensure mic@mic.com always has admin role
          if (user['email'] == superAdminEmail) {
            // Update role to admin if not already
            final currentRole = user['role'] as String?;
            if (currentRole != 'admin') {
              await _client
                  .from('users')
                  .update({
                    'role': 'admin',
                    'is_active': true,
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', userId);
            }
            return true;
          }

          final role = user['role'] as String?;
          final isActive = user['is_active'] == true;
          return (role == 'admin' || role == 'pastor') && isActive;
        }
      }

      // Check current user if no ID/email provided
      final currentUser = SupabaseService.currentUser;
      if (currentUser != null) {
        // Check if current user is mic@mic.com
        if (currentUser.email == superAdminEmail) {
          return true;
        }

        final user = await _client
            .from('users')
            .select('role, is_active, email')
            .eq('id', currentUser.id)
            .maybeSingle();

        if (user != null) {
          // Ensure mic@mic.com always has admin role
          if (user['email'] == superAdminEmail) {
            final currentRole = user['role'] as String?;
            if (currentRole != 'admin') {
              await _client
                  .from('users')
                  .update({
                    'role': 'admin',
                    'is_active': true,
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', currentUser.id);
            }
            return true;
          }

          final role = user['role'] as String?;
          final isActive = user['is_active'] == true;
          return (role == 'admin' || role == 'pastor') && isActive;
        }
      }

      return false;
    } catch (e) {
      // If check fails, return false for security
      return false;
    }
  }

  /// Check if current user has admin privileges
  static Future<bool> isCurrentUserAdmin() async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) return false;

    return await isAdmin(
      userId: currentUser.id,
      email: currentUser.email,
    );
  }

  /// Ensure mic@mic.com has admin role (call this after user creation/login)
  static Future<void> ensureSuperAdminPrivileges(String email) async {
    if (email != superAdminEmail) return;

    try {
      // Update users table
      await _client
          .from('users')
          .update({
            'role': 'admin',
            'is_active': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('email', email);

      // Also update Supabase Auth metadata
      try {
        final currentUser = SupabaseService.currentUser;
        if (currentUser != null && currentUser.email == email) {
          await _client.auth.updateUser(
            UserAttributes(data: {'role': 'admin'}),
          );
        }
      } catch (e) {
        // Ignore metadata update errors
        debugPrint('Warning: Could not update auth metadata: $e');
      }
    } catch (e) {
      debugPrint('Warning: Could not ensure super admin privileges: $e');
    }
  }

  /// Get user role
  static Future<String?> getUserRole({String? userId, String? email}) async {
    try {
      if (email == superAdminEmail) {
        return 'admin';
      }

      if (email != null) {
        final user = await _client
            .from('users')
            .select('role, email')
            .eq('email', email)
            .maybeSingle();

        if (user != null) {
          if (user['email'] == superAdminEmail) {
            return 'admin';
          }
          return user['role'] as String?;
        }
      }

      if (userId != null) {
        final user = await _client
            .from('users')
            .select('role, email')
            .eq('id', userId)
            .maybeSingle();

        if (user != null) {
          if (user['email'] == superAdminEmail) {
            return 'admin';
          }
          return user['role'] as String?;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}

