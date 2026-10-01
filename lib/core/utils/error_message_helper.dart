import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

/// Helper class to provide short, descriptive error messages
class ErrorMessageHelper {
  /// Get a localized error message from an exception
  static String getErrorMessage(BuildContext? context, dynamic error) {
    if (context == null) {
      return _getDefaultErrorMessage(error);
    }

    final localizations = AppLocalizations.of(context);
    if (localizations == null) {
      return _getDefaultErrorMessage(error);
    }

    final errorString = error.toString().toLowerCase();
    final errorMessage = error.toString();

    // Email not confirmed
    if (errorString.contains('email not confirmed') ||
        errorString.contains('email_not_confirmed')) {
      return localizations.errorEmailNotConfirmed;
    }

    // Invalid credentials
    if (errorString.contains('invalid') &&
        (errorString.contains('password') || errorString.contains('credentials'))) {
      return localizations.errorInvalidCredentials;
    }

    // User not found
    if (errorString.contains('user not found') ||
        errorString.contains('user_not_found')) {
      return localizations.errorUserNotFound;
    }

    // Duplicate email
    if (errorString.contains('duplicate') ||
        errorString.contains('already exists') ||
        errorString.contains('already registered')) {
      return localizations.errorDuplicateEmail;
    }

    // Permission denied
    if (errorString.contains('permission') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden')) {
      return localizations.errorPermissionDenied;
    }

    // Network errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return localizations.networkError;
    }

    // Not logged in
    if (errorString.contains('not logged in') ||
        errorString.contains('must be logged in') ||
        errorString.contains('no session')) {
      return localizations.errorMustBeLoggedIn;
    }

    // Admin or leader required
    if (errorString.contains('admin') && errorString.contains('leader')) {
      return localizations.errorAdminOrLeaderRequired;
    }

    // Member not found
    if (errorString.contains('member not found')) {
      return localizations.errorMemberNotFound;
    }

    // Email or phone required
    if (errorString.contains('email or phone') ||
        errorString.contains('email/phone')) {
      return localizations.errorEmailOrPhoneRequired;
    }

    // Department not found
    if (errorString.contains('department not found')) {
      return localizations.errorDepartmentNotFound;
    }

    // File upload failed
    if (errorString.contains('upload') && errorString.contains('fail')) {
      return localizations.errorFileUploadFailed;
    }

    // Password reset failed
    if (errorString.contains('password reset') ||
        errorString.contains('reset password')) {
      return localizations.errorPasswordResetFailed;
    }

    // Account creation failed
    if (errorString.contains('create') && errorString.contains('account')) {
      return localizations.errorAccountCreationFailed;
    }

    // Generic operation failed
    if (errorString.contains('failed') || errorString.contains('error')) {
      return localizations.errorOperationFailed;
    }

    // Return the original error message if no match, but make it shorter
    return _shortenErrorMessage(errorMessage);
  }

  /// Get default error message when context is not available
  static String _getDefaultErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    final errorMessage = error.toString();

    if (errorString.contains('email not confirmed')) {
      return 'Please confirm your email to continue.';
    }
    if (errorString.contains('invalid') &&
        (errorString.contains('password') || errorString.contains('credentials'))) {
      return 'Invalid email or password.';
    }
    if (errorString.contains('user not found')) {
      return 'User not found.';
    }
    if (errorString.contains('duplicate') ||
        errorString.contains('already exists')) {
      return 'Email already in use.';
    }
    if (errorString.contains('permission') ||
        errorString.contains('unauthorized')) {
      return 'You don\'t have permission for this action.';
    }
    if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network error. Please check your connection.';
    }

    return _shortenErrorMessage(errorMessage);
  }

  /// Shorten error messages to be more user-friendly
  static String _shortenErrorMessage(String message) {
    // Remove common prefixes
    message = message.replaceAll(RegExp(r'^(Exception|Error|Failed):\s*', caseSensitive: false), '');
    
    // Remove stack traces
    if (message.contains('\n')) {
      message = message.split('\n').first;
    }

    // Limit length
    if (message.length > 100) {
      message = '${message.substring(0, 97)}...';
    }

    // Capitalize first letter
    if (message.isNotEmpty) {
      message = message[0].toUpperCase() + message.substring(1);
    }

    return message.isEmpty ? 'An error occurred. Please try again.' : message;
  }
}

