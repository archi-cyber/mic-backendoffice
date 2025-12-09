/// App-wide string constants
/// Note: For user-facing strings, use localization instead
class AppStrings {
  AppStrings._(); // Private constructor to prevent instantiation

  // App Info
  static const String appName = 'SysteMIC';
  static const String appVersion = '1.0.0';

  // Routes
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeDashboard = '/dashboard';
  static const String routeHome = '/home';

  // Storage Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';

  // Error Messages
  static const String errorGeneric = 'An error occurred. Please try again.';
  static const String errorNetwork =
      'Network error. Please check your connection.';
  static const String errorAuth = 'Authentication failed. Please try again.';
  static const String errorNotFound = 'Resource not found.';
  static const String errorUnauthorized =
      'You are not authorized to perform this action.';

  // Success Messages
  static const String successLogin = 'Login successful';
  static const String successLogout = 'Logout successful';
  static const String successSave = 'Saved successfully';
  static const String successDelete = 'Deleted successfully';
}
