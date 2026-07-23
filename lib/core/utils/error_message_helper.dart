import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../localization/app_localizations.dart';

/// Maps technical exceptions to short, user-facing messages.
/// Never surfaces raw URIs, stack traces, or ClientException dumps in the UI.
class ErrorMessageHelper {
  /// Logical category used to pick a localized message.
  static String getErrorMessage(BuildContext? context, dynamic error) {
    final kind = _classify(error);
    final l10n = context != null ? AppLocalizations.of(context) : null;

    switch (kind) {
      case _ErrorKind.network:
        return l10n?.networkError ??
            'Network error. Please check your connection.';
      case _ErrorKind.authCredentials:
        return l10n?.errorInvalidCredentials ?? 'Invalid email or password.';
      case _ErrorKind.emailNotConfirmed:
        return l10n?.errorEmailNotConfirmed ??
            'Please confirm your email to continue.';
      case _ErrorKind.userNotFound:
        return l10n?.errorUserNotFound ?? 'User not found.';
      case _ErrorKind.duplicate:
        return l10n?.errorDuplicateEmail ?? 'This record already exists.';
      case _ErrorKind.permission:
        return l10n?.errorPermissionDenied ??
            "You don't have permission for this action.";
      case _ErrorKind.notLoggedIn:
        return l10n?.errorMustBeLoggedIn ?? 'You must be logged in.';
      case _ErrorKind.adminOrLeader:
        return l10n?.errorAdminOrLeaderRequired ??
            'Admin or leader access is required.';
      case _ErrorKind.memberNotFound:
        return l10n?.errorMemberNotFound ?? 'Member not found.';
      case _ErrorKind.emailOrPhoneRequired:
        return l10n?.errorEmailOrPhoneRequired ??
            'Email or phone is required.';
      case _ErrorKind.departmentNotFound:
        return l10n?.errorDepartmentNotFound ?? 'Department not found.';
      case _ErrorKind.upload:
        return l10n?.errorFileUploadFailed ?? 'File upload failed.';
      case _ErrorKind.passwordReset:
        return l10n?.errorPasswordResetFailed ?? 'Password reset failed.';
      case _ErrorKind.accountCreation:
        return l10n?.errorAccountCreationFailed ?? 'Could not create account.';
      case _ErrorKind.notFound:
        return l10n?.genericError ?? 'The requested item was not found.';
      case _ErrorKind.server:
        return l10n?.errorOperationFailed ??
            'Something went wrong on the server. Please try again.';
      case _ErrorKind.validation:
        return _safeValidationMessage(error) ??
            (l10n?.errorOperationFailed ??
                'Please check your input and try again.');
      case _ErrorKind.generic:
        return l10n?.errorOperationFailed ??
            (l10n?.genericError ?? 'An error occurred. Please try again.');
    }
  }

  /// Shows a snackbar with a logical message. Never dumps technical details.
  static void showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    String? title,
  }) {
    final logical = getErrorMessage(context, error);
    final message = (title == null || title.trim().isEmpty)
        ? logical
        : '$title. $logical';

    if (kDebugMode) {
      debugPrint('[ErrorMessageHelper] $message | raw: ${_safeDebugError(error)}');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Compact raw error for logs only (no full query URIs).
  static String _safeDebugError(dynamic error) {
    var text = error?.toString() ?? 'null';
    text = text.replaceAll(RegExp(r'https?://[^\s,)]+'), '[url]');
    text = text.replaceAll(RegExp(r'uri=[^\s,)]+'), 'uri=[url]');
    if (text.length > 180) {
      text = '${text.substring(0, 177)}...';
    }
    return text;
  }

  static _ErrorKind _classify(dynamic error) {
    final raw = error?.toString() ?? '';
    final s = raw.toLowerCase();

    // Network / connectivity (include ClientException connection abort)
    if (_looksLikeNetwork(s)) {
      return _ErrorKind.network;
    }

    if (s.contains('email not confirmed') || s.contains('email_not_confirmed')) {
      return _ErrorKind.emailNotConfirmed;
    }

    if (s.contains('invalid') &&
        (s.contains('password') ||
            s.contains('credentials') ||
            s.contains('login'))) {
      return _ErrorKind.authCredentials;
    }

    if (s.contains('user not found') || s.contains('user_not_found')) {
      return _ErrorKind.userNotFound;
    }

    if (s.contains('duplicate') ||
        s.contains('already exists') ||
        s.contains('already registered') ||
        s.contains('unique constraint') ||
        s.contains('23505')) {
      return _ErrorKind.duplicate;
    }

    if (s.contains('permission') ||
        s.contains('unauthorized') ||
        s.contains('forbidden') ||
        s.contains('row-level security') ||
        s.contains('rls') ||
        s.contains('42501') ||
        s.contains('401') ||
        s.contains('403')) {
      return _ErrorKind.permission;
    }

    if (s.contains('not logged in') ||
        s.contains('must be logged in') ||
        s.contains('no session') ||
        s.contains('jwt') ||
        s.contains('session expired')) {
      return _ErrorKind.notLoggedIn;
    }

    if (s.contains('admin') && s.contains('leader')) {
      return _ErrorKind.adminOrLeader;
    }

    if (s.contains('member not found')) {
      return _ErrorKind.memberNotFound;
    }

    if (s.contains('email or phone') || s.contains('email/phone')) {
      return _ErrorKind.emailOrPhoneRequired;
    }

    if (s.contains('department not found')) {
      return _ErrorKind.departmentNotFound;
    }

    if (s.contains('upload') && (s.contains('fail') || s.contains('error'))) {
      return _ErrorKind.upload;
    }

    if (s.contains('password reset') || s.contains('reset password')) {
      return _ErrorKind.passwordReset;
    }

    if (s.contains('create') && s.contains('account')) {
      return _ErrorKind.accountCreation;
    }

    if (s.contains('not found') || s.contains('404') || s.contains('pgrst116')) {
      return _ErrorKind.notFound;
    }

    if (s.contains('500') ||
        s.contains('502') ||
        s.contains('503') ||
        s.contains('504') ||
        s.contains('internal server')) {
      return _ErrorKind.server;
    }

    // Safe short validation-style messages (no URLs / exception types)
    if (_looksLikeSafeUserMessage(raw)) {
      return _ErrorKind.validation;
    }

    return _ErrorKind.generic;
  }

  static bool _looksLikeNetwork(String s) {
    return s.contains('network') ||
        s.contains('connection') ||
        s.contains('timeout') ||
        s.contains('timed out') ||
        s.contains('socketexception') ||
        s.contains('clientexception') ||
        s.contains('connection abort') ||
        s.contains('connection reset') ||
        s.contains('connection refused') ||
        s.contains('failed host lookup') ||
        s.contains('failed to fetch') ||
        s.contains('xmlhttprequest') ||
        s.contains('handshake') ||
        s.contains('unreachable') ||
        s.contains('offline') ||
        s.contains('no internet') ||
        s.contains('network is unreachable');
  }

  static bool _looksLikeSafeUserMessage(String raw) {
    if (raw.length > 120) return false;
    final lower = raw.toLowerCase();
    if (lower.contains('http') ||
        lower.contains('uri=') ||
        lower.contains('exception') ||
        lower.contains('error:') ||
        lower.contains('postgrest') ||
        lower.contains('supabase') ||
        lower.contains('stack') ||
        lower.contains('{') ||
        RegExp(r'\b\d{3}\b').hasMatch(lower) && lower.contains('status')) {
      return false;
    }
    // Prefer messages that look like plain English sentences we threw ourselves.
    return !lower.startsWith('clientexception') &&
        !lower.startsWith('exception') &&
        !lower.contains('file://') &&
        !lower.contains('/rest/v1/');
  }

  static String? _safeValidationMessage(dynamic error) {
    final raw = error?.toString() ?? '';
    var message = raw
        .replaceAll(RegExp(r'^(Exception|Error|Failed):\s*', caseSensitive: false), '')
        .trim();
    if (message.contains('\n')) {
      message = message.split('\n').first.trim();
    }
    if (!_looksLikeSafeUserMessage(message)) return null;
    if (message.isEmpty) return null;
    return message[0].toUpperCase() + message.substring(1);
  }
}

enum _ErrorKind {
  network,
  authCredentials,
  emailNotConfirmed,
  userNotFound,
  duplicate,
  permission,
  notLoggedIn,
  adminOrLeader,
  memberNotFound,
  emailOrPhoneRequired,
  departmentNotFound,
  upload,
  passwordReset,
  accountCreation,
  notFound,
  server,
  validation,
  generic,
}
