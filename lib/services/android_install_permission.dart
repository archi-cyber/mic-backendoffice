import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only helpers for sideloaded APK installs.
class AndroidInstallPermission {
  AndroidInstallPermission._();

  static const _channel = MethodChannel('com.example.mic_backoffice/installer');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether this app is allowed to install packages (Android 8+).
  static Future<bool> canInstallPackages() async {
    if (!_isAndroid) return true;
    try {
      final allowed = await _channel.invokeMethod<bool>('canInstallPackages');
      return allowed ?? true;
    } catch (e) {
      debugPrint('canInstallPackages failed: $e');
      return true;
    }
  }

  /// Opens system settings so the user can allow installs from this app.
  static Future<void> openInstallPermissionSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openInstallPermissionSettings');
    } catch (e) {
      debugPrint('openInstallPermissionSettings failed: $e');
    }
  }
}
