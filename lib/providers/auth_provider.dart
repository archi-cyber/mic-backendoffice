import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

/// Authentication provider for state management
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  dynamic _currentUser;
  bool _mustChangePassword = false;
  String? _errorMessage;

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
        _mustChangePassword =
            user.userMetadata?['must_change_password'] == true ||
            user.userMetadata?['must_change_password'] == 'true';
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize auth: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      await AuthService.resetPassword(
        token: '', // Not needed when authenticated
        newPassword: newPassword,
      );

      // Update metadata to clear must_change_password flag
      await SupabaseService.client.auth.updateUser(
        UserAttributes(data: {'must_change_password': false}),
      );

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

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
