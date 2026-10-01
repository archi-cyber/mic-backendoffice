import 'package:flutter/foundation.dart';

/// Platform feature flags used to avoid initializing mobile-only services on
/// desktop builds (Windows/macOS/Linux), where they can hang or fail silently.
class PlatformCapabilities {
  static bool get isMobileNative {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  /// FCM push on mobile and in the browser.
  static bool get supportsPushNotifications => isMobileNative || kIsWeb;

  static bool get supportsBackgroundTasks => isMobileNative;

  /// Supabase realtime badge + system/browser alerts (web and desktop).
  static bool get supportsInAppNotifications => kIsWeb || !isMobileNative;

  /// GitHub Releases OTA updates (Android, Windows, web).
  static bool get supportsAppUpdates {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.windows:
        return true;
      default:
        return false;
    }
  }
}
