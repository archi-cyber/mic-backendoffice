import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Authentication service for login, password reset, etc.
class AuthService {
  static final _client = SupabaseService.client;

  /// Login with email and password
  /// Returns: {token, must_change_password}
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null) {
        throw Exception('Login failed: No session returned');
      }

      // Get user metadata to check must_change_password flag
      final mustChangePassword =
          response.user?.userMetadata?['must_change_password'] == true ||
          response.user?.userMetadata?['must_change_password'] == 'true';

      return {
        'token': response.session!.accessToken,
        'must_change_password': mustChangePassword,
        'user': response.user,
      };
    } on AuthException catch (e) {
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  /// Send password reset link
  /// Business Rule: Any active leader can reset password via "Forgot password" flow
  static Future<void> forgotPassword({required String email}) async {
    try {
      // Check if user is active leader before allowing password reset
      // Note: This validation should ideally be done server-side
      final user = await _client
          .from('users')
          .select('is_active, role')
          .eq('email', email)
          .maybeSingle();

      if (user != null) {
        final isActive = user['is_active'] == true;
        final role = user['role'] as String?;

        // Business Rule: Only active leaders can reset password
        if (!isActive || role != 'leader') {
          throw Exception(
            'Password reset is only available for active leaders. '
            'Please contact an administrator.',
          );
        }
      }

      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: null, // Configure redirect URL in Supabase dashboard
      );
    } on AuthException catch (e) {
      throw Exception('Failed to send reset link: ${e.message}');
    } catch (e) {
      throw Exception('Failed to send reset link: $e');
    }
  }

  /// Reset password with token
  static Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      // Supabase handles password reset through email link
      // This method is typically called after user clicks the reset link
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw Exception('Password reset failed: ${e.message}');
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  /// Logout current user
  static Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  /// Get current authenticated user
  static User? getCurrentUser() {
    return SupabaseService.currentUser;
  }
}
