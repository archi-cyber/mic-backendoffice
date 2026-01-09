import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/role_service.dart';
import '../services/device_token_service.dart';
import 'dart:async';

/// Authentication provider for state management
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  dynamic _currentUser;
  bool _mustChangePassword = false;
  String? _errorMessage;
  Timer? _tokenCheckTimer;
  bool _isAppActive = true;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  dynamic get currentUser => _currentUser;
  bool get mustChangePassword => _mustChangePassword;
  String? get errorMessage => _errorMessage;

  /// Initialize auth state from Supabase session
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;

        // Check must_change_password flag from users table (primary source)
        // Also check user metadata as fallback
        try {
          final userRecord = await SupabaseService.client
              .from('users')
              .select('must_change_password')
              .eq('id', user.id)
              .maybeSingle();

          if (userRecord != null) {
            _mustChangePassword = userRecord['must_change_password'] == true;
          } else {
            // Fallback to metadata if users table record doesn't exist
            _mustChangePassword =
                user.userMetadata?['must_change_password'] == true ||
                user.userMetadata?['must_change_password'] == 'true';
          }
        } catch (e) {
          // Fallback to metadata if query fails
          debugPrint(
            '[AuthProvider] Error checking users table: $e, using metadata',
          );
          _mustChangePassword =
              user.userMetadata?['must_change_password'] == true ||
              user.userMetadata?['must_change_password'] == 'true';
        }

        // Ensure mic@mic.com has admin privileges
        final userEmail = user.email;
        if (userEmail != null && userEmail == RoleService.superAdminEmail) {
          await RoleService.ensureSuperAdminPrivileges(userEmail);
        }

        // Save device token if user is already authenticated on app start
        try {
          final deviceToken = DeviceTokenService.currentToken;
          if (deviceToken != null) {
            debugPrint(
              '[AuthProvider] Saving device token on initialization: ${deviceToken.substring(0, 20)}...',
            );
            await DeviceTokenService.saveDeviceToken(deviceToken);
          }
        } catch (e) {
          debugPrint(
            '[AuthProvider] Warning: Failed to save device token on initialization: $e',
          );
        }

        // Start token monitoring
        _startTokenMonitoring();
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize auth: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start monitoring token expiration
  void _startTokenMonitoring() {
    // Check token every 5 minutes
    _tokenCheckTimer?.cancel();
    _tokenCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (_isAuthenticated && _isAppActive) {
        // Only check if app is active
        await checkAndRefreshToken();
      }
    });

    // Also listen to Supabase auth state changes
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.tokenRefreshed) {
        // Token was refreshed successfully
        debugPrint('Token refreshed successfully');
      } else if (event == AuthChangeEvent.signedOut) {
        // User was signed out
        _isAuthenticated = false;
        _currentUser = null;
        _mustChangePassword = false;
        _tokenCheckTimer?.cancel();
        notifyListeners();
      } else if (event == AuthChangeEvent.userUpdated) {
        // User was updated
        _currentUser = session?.user;
        notifyListeners();
      }
    });
  }

  /// Set app active state (call when app goes to background/foreground)
  void setAppActive(bool isActive) {
    _isAppActive = isActive;
    if (isActive && _isAuthenticated) {
      // Check token immediately when app becomes active
      checkAndRefreshToken();
    }
  }

  @override
  void dispose() {
    _tokenCheckTimer?.cancel();
    super.dispose();
  }

  /// Login with email/phone and password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await AuthService.login(email: email, password: password);

      _currentUser = result['user'];
      _isAuthenticated = true;
      _mustChangePassword = result['must_change_password'] ?? false;

      // Wait a moment for the sync trigger to complete
      // The trigger should create the user record in the users table
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify user exists in users table (trigger should have created it)
      // If not, wait a bit more and check again
      bool userExists = false;
      for (int i = 0; i < 3; i++) {
        try {
          final user = await SupabaseService.client
              .from('users')
              .select('id')
              .eq('id', _currentUser?.id)
              .maybeSingle();
          if (user != null) {
            userExists = true;
            break;
          }
        } catch (e) {
          // Ignore errors, will retry
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!userExists && _currentUser != null) {
        debugPrint(
          'Warning: User record not found in users table after login. '
          'The sync trigger may have failed. Attempting manual sync...',
        );
        // Try to manually create the user record as a fallback
        try {
          final userData = {
            'id': _currentUser!.id,
            'email': _currentUser!.email,
            'phone': _currentUser!.phone,
            'role': _currentUser!.userMetadata?['role'] ?? 'member',
            'created_at':
                _currentUser!.createdAt?.toIso8601String() ??
                DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
          // Only include is_active if the column exists (will fail gracefully if it doesn't)
          if (_currentUser!.userMetadata?['is_active'] != null) {
            userData['is_active'] = _currentUser!.userMetadata?['is_active'];
          }
          await SupabaseService.client.from('users').insert(userData);
          debugPrint('Successfully created user record manually');
        } catch (e) {
          debugPrint(
            'Failed to manually create user record: $e. '
            'This may be due to RLS policies or missing columns. Please run FIX_USER_SYNC_RLS.sql',
          );
          // Don't fail login, but log the error
        }
      }

      // Ensure mic@mic.com has admin privileges
      final userEmail = _currentUser?.email;
      if (userEmail != null && userEmail == RoleService.superAdminEmail) {
        await RoleService.ensureSuperAdminPrivileges(userEmail);
      }

      // Save device token after successful login
      // This ensures push notifications work for users who log in after app start
      try {
        final deviceToken = DeviceTokenService.currentToken;
        if (deviceToken != null) {
          debugPrint(
            '[AuthProvider] Saving device token after login: ${deviceToken.substring(0, 20)}...',
          );
          await DeviceTokenService.saveDeviceToken(deviceToken);
        } else {
          debugPrint(
            '[AuthProvider] No device token available to save. '
            'FCM may not be initialized or permission not granted.',
          );
        }
      } catch (e) {
        debugPrint(
          '[AuthProvider] Warning: Failed to save device token after login: $e',
        );
        // Don't fail login if device token save fails
      }

      // Start token monitoring after successful login
      _startTokenMonitoring();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Change password (for first-time login)
  Future<bool> changePassword(String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Update password (this also updates users table)
      await AuthService.resetPassword(
        token: '', // Not needed when authenticated
        newPassword: newPassword,
      );

      // Update metadata to clear must_change_password flag
      await SupabaseService.client.auth.updateUser(
        UserAttributes(data: {'must_change_password': false}),
      );

      // Ensure users table is updated (resetPassword should have done this, but double-check)
      try {
        final userId = _currentUser?.id;
        if (userId != null) {
          await SupabaseService.client
              .from('users')
              .update({
                'must_change_password': false,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', userId);
        }
      } catch (e) {
        debugPrint(
          '[AuthProvider] Warning: Could not update users table: $e',
        );
        // Don't fail password change if users table update fails
      }

      _mustChangePassword = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await AuthService.logout();
      _isAuthenticated = false;
      _currentUser = null;
      _mustChangePassword = false;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Logout failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check and refresh token if needed
  /// Returns true if session is valid, false if user should be logged out
  Future<bool> checkAndRefreshToken() async {
    try {
      final isValid = await AuthService.ensureValidSession();
      if (!isValid) {
        // Token is invalid and cannot be refreshed
        await logout();
        return false;
      }
      return true;
    } catch (e) {
      // If check fails, logout for security
      await logout();
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
