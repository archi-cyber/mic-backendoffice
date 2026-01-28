import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'device_token_service.dart';
import 'role_service.dart';

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
        throw Exception('Login failed. No session returned.');
      }

      // Check if password is the default password
      const defaultPassword = 'Password123';
      bool isDefaultPassword = password == defaultPassword;

      debugPrint('[AuthService] Is default password: $isDefaultPassword');

      // Check must_change_password flag from users table (primary source)
      // Also check user metadata as fallback
      bool mustChangePassword = false;
      try {
        final userRecord = await _client
            .from('users')
            .select('must_change_password')
            .eq('id', response.user!.id)
            .maybeSingle();

        if (userRecord != null) {
          mustChangePassword = userRecord['must_change_password'] == true;
          debugPrint(
            '[AuthService] Found user record, must_change_password: $mustChangePassword',
          );
        } else {
          // Fallback to metadata if users table record doesn't exist
          mustChangePassword =
              response.user?.userMetadata?['must_change_password'] == true ||
              response.user?.userMetadata?['must_change_password'] == 'true';
          debugPrint(
            '[AuthService] No user record found, using metadata: $mustChangePassword',
          );
        }
      } catch (e) {
        // Fallback to metadata if query fails
        debugPrint(
          '[AuthService] Error checking users table: $e, using metadata',
        );
        mustChangePassword =
            response.user?.userMetadata?['must_change_password'] == true ||
            response.user?.userMetadata?['must_change_password'] == 'true';
      }

      // Force password change if using default password (for newly created users)
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

      // Ensure mic@mic.com has admin privileges
      final userEmail = response.user?.email;
      if (userEmail != null && userEmail == RoleService.superAdminEmail) {
        await RoleService.ensureSuperAdminPrivileges(userEmail);
      }

      return {
        'token': response.session!.accessToken,
        'must_change_password': mustChangePassword,
        'user': response.user,
      };
    } on AuthException catch (e) {
      debugPrint('[AuthService] Login failed: ${e.message}');

      // Handle email not confirmed error
      if (e.message.toLowerCase().contains('email not confirmed') ||
          e.message.toLowerCase().contains('email_not_confirmed')) {
        throw Exception('Email not confirmed');
      }

      // Handle invalid credentials
      if (e.message.toLowerCase().contains('invalid') ||
          e.message.toLowerCase().contains('wrong password') ||
          e.message.toLowerCase().contains('incorrect')) {
        throw Exception('Invalid credentials');
      }

      throw Exception('Login failed');
    } catch (e, stackTrace) {
      debugPrint('[AuthService] Login error: $e');
      debugPrint('[AuthService] Stack trace: $stackTrace');

      // Handle email not confirmed error in generic catch
      if (e.toString().toLowerCase().contains('email not confirmed') ||
          e.toString().toLowerCase().contains('email_not_confirmed')) {
        throw Exception('Email not confirmed');
      }

      throw Exception('Login failed');
    }
  }

  /// Resend email confirmation
  /// Sends a new confirmation email to the user
  static Future<void> resendConfirmationEmail({required String email}) async {
    try {
      await _client.auth.resend(type: OtpType.signup, email: email);
    } on AuthException {
      throw Exception('Failed to resend confirmation email');
    } catch (_) {
      throw Exception('Failed to resend confirmation email');
    }
  }

  /// Send password reset OTP token via email
  /// Business Rule: Active leaders and members with accounts can reset password
  static Future<void> forgotPassword({required String email}) async {
    try {
      // Check if user is active (leader or member) before allowing password reset
      final user = await _client
          .from('users')
          .select('is_active, role')
          .eq('email', email)
          .maybeSingle();

      if (user != null) {
        final isActive = user['is_active'] == true;
        final role = user['role'] as String?;

        // Allow active leaders and members with accounts to reset password
        if (!isActive || (role != 'leader' && role != 'member')) {
          throw Exception(
            'Password reset only available for active leaders and members with accounts',
          );
        }
      }

      // Send OTP token via email for password recovery
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: null, // Not using redirect, using token instead
      );
    } on AuthException catch (e) {
      debugPrint('[AuthService] Password reset error: ${e.message}');
      throw Exception('Failed to send reset token: ${e.message}');
    } catch (e) {
      debugPrint('[AuthService] Password reset error: $e');
      throw Exception('Failed to send reset token');
    }
  }

  /// Verify password reset token and reset password
  /// This method verifies the OTP token from email and then resets the password
  static Future<void> resetPassword({
    required String token,
    required String email,
    required String newPassword,
  }) async {
    try {
      debugPrint('[AuthService] Verifying password reset token for: $email');

      // Verify the OTP token by attempting to exchange it for a session
      // Supabase will verify the token and create a temporary session
      final response = await _client.auth.verifyOTP(
        type: OtpType.recovery,
        token: token,
        email: email,
      );

      if (response.session == null) {
        throw Exception(
          'Invalid or expired token. Please request a new reset token.',
        );
      }

      debugPrint('[AuthService] Token verified successfully');

      // Now update the password using the temporary session
      await _client.auth.updateUser(UserAttributes(password: newPassword));

      // Also update users table to clear must_change_password flag
      try {
        final userId = response.user?.id;
        if (userId != null) {
          await _client
              .from('users')
              .update({
                'must_change_password': false,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', userId);
        }
      } catch (e) {
        debugPrint('[AuthService] Warning: Could not update users table: $e');
        // Don't fail password change if users table update fails
      }

      // Sign out the temporary session after password reset
      await _client.auth.signOut();

      debugPrint('[AuthService] Password reset successful');
    } on AuthException catch (e) {
      debugPrint('[AuthService] Password reset error: ${e.message}');
      if (e.message.toLowerCase().contains('invalid') ||
          e.message.toLowerCase().contains('expired') ||
          e.message.toLowerCase().contains('token')) {
        throw Exception(
          'Invalid or expired token. Please request a new reset token.',
        );
      }
      throw Exception('Password reset failed: ${e.message}');
    } catch (e) {
      debugPrint('[AuthService] Password reset error: $e');
      if (e.toString().toLowerCase().contains('invalid') ||
          e.toString().toLowerCase().contains('expired') ||
          e.toString().toLowerCase().contains('token')) {
        throw Exception(
          'Invalid or expired token. Please request a new reset token.',
        );
      }
      throw Exception('Password reset failed');
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
      throw Exception('Logout failed');
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
