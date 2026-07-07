import 'package:flutter/foundation.dart';

/// Platform feature flags used to avoid initializing mobile-only services on
/// desktop builds (Windows/macOS/Linux), where they can hang or fail silently.
class PlatformCapabilities {
  static bool get supportsPushNotifications {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  static bool get supportsBackgroundTasks => supportsPushNotifications;
}
