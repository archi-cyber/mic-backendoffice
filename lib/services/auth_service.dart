import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'device_token_service.dart';

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
      debugPrint('[AuthService] Attempting login for: $email');

      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null) {
        throw Exception('Login failed: No session returned');
      }

      // Check if password is the default password
      const defaultPassword = 'Password123';
      bool isDefaultPassword = password == defaultPassword;

      debugPrint('[AuthService] Is default password: $isDefaultPassword');

      // Get user metadata to check must_change_password flag
      bool mustChangePassword =
          response.user?.userMetadata?['must_change_password'] == true ||
          response.user?.userMetadata?['must_change_password'] == 'true';

      // Force password change if using default password
      if (isDefaultPassword && !mustChangePassword) {
        debugPrint(
          '[AuthService] Default password detected, forcing password change',
        );
        mustChangePassword = true;

        // Update user metadata to require password change
        try {
          await _client.auth.updateUser(
            UserAttributes(data: {'must_change_password': true}),
          );

          // Also update users table if it exists
          try {
            await _client
                .from('users')
                .update({
                  'must_change_password': true,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', response.user!.id);
          } catch (e) {
            debugPrint(
              '[AuthService] Warning: Could not update users table: $e',
            );
          }
        } catch (e) {
          debugPrint(
            '[AuthService] Warning: Could not update user metadata: $e',
          );
          // Continue anyway - we'll still return must_change_password=true
        }
      }

      debugPrint(
        '[AuthService] Login successful. must_change_password: $mustChangePassword',
      );

      return {
        'token': response.session!.accessToken,
        'must_change_password': mustChangePassword,
        'user': response.user,
      };
    } on AuthException catch (e) {
      debugPrint('[AuthService] Login failed: ${e.message}');
      throw Exception('Login failed: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('[AuthService] Login error: $e');
      debugPrint('[AuthService] Stack trace: $stackTrace');
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
  /// Also removes device token if FCM is available
  static Future<void> logout() async {
    try {
      // Remove device token before logout
      try {
        final currentToken = DeviceTokenService.currentToken;
        if (currentToken != null) {
          await DeviceTokenService.removeDeviceToken(currentToken);
        }
      } catch (e) {
        // Ignore errors when removing device token
        debugPrint('Warning: Failed to remove device token on logout: $e');
      }

      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  /// Get current authenticated user
  static User? getCurrentUser() {
    return SupabaseService.currentUser;
  }

  /// Check if the current session token is expired or about to expire
  /// Returns true if token is expired or will expire within the next 5 minutes
  static bool isTokenExpiredOrExpiringSoon() {
    final session = SupabaseService.currentSession;
    if (session == null) return true;

    final expiresAt = session.expiresAt;
    if (expiresAt == null) return true;

    // Check if token is expired or will expire in the next 5 minutes
    final expirationTime = DateTime.fromMillisecondsSinceEpoch(
      expiresAt * 1000,
    );
    final now = DateTime.now();
    final fiveMinutesFromNow = now.add(const Duration(minutes: 5));

    return expirationTime.isBefore(fiveMinutesFromNow);
  }

  /// Refresh the current session token
  /// Returns true if refresh was successful, false otherwise
  static Future<bool> refreshToken() async {
    try {
      final session = SupabaseService.currentSession;
      if (session == null) return false;

      // Supabase automatically refreshes tokens, but we can force a refresh
      final refreshedSession = await _client.auth.refreshSession();
      return refreshedSession.session != null;
    } catch (e) {
      return false;
    }
  }

  /// Check token and refresh if needed
  /// Returns true if session is valid (either already valid or successfully refreshed)
  /// Returns false if session is invalid and cannot be refreshed
  static Future<bool> ensureValidSession() async {
    try {
      final session = SupabaseService.currentSession;
      if (session == null) return false;

      // If token is expired or expiring soon, try to refresh
      if (isTokenExpiredOrExpiringSoon()) {
        return await refreshToken();
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
