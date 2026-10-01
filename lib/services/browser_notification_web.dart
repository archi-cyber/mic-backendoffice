// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

Future<bool> requestBrowserNotificationPermission() async {
  final permission = await html.Notification.requestPermission();
  debugPrint('[BrowserNotification] Permission result: $permission');
  return permission == 'granted';
}

bool isBrowserNotificationPermissionGranted() {
  return html.Notification.permission == 'granted';
}

String get browserNotificationPermissionStatus {
  return html.Notification.permission ?? 'unknown';
}

Future<bool> ensureBrowserNotificationPermission() async {
  if (isBrowserNotificationPermissionGranted()) return true;
  if (browserNotificationPermissionStatus == 'denied') {
    debugPrint(
      '[BrowserNotification] Permission denied — enable notifications for this site in browser settings.',
    );
    return false;
  }
  return await requestBrowserNotificationPermission();
}

void showBrowserNotification({
  required String title,
  String? body,
}) {
  if (!isBrowserNotificationPermissionGranted()) {
    debugPrint(
      '[BrowserNotification] Cannot show "$title" — permission is '
      '${browserNotificationPermissionStatus}',
    );
    return;
  }

  try {
    html.Notification(
      title,
      body: body,
      icon: 'icons/Icon-192.png',
    );
    debugPrint('[BrowserNotification] Shown: $title');
  } catch (e) {
    debugPrint('[BrowserNotification] Failed to show "$title": $e');
  }
}

const _notificationClickMessage = 'mic-notification-click';

/// Listen for notification taps from [firebase-messaging-sw.js].
void setupWebNotificationClickHandling(void Function() onNotificationClick) {
  html.window.onMessage.listen((event) {
    final data = event.data;
    if (data is Map && data['type'] == _notificationClickMessage) {
      debugPrint('[BrowserNotification] Service worker notification click');
      onNotificationClick();
    }
  });
}

/// Cold-start fallback when the app was opened from a notification click.
void checkWebNotificationLaunchQuery(void Function() onPendingNavigation) {
  if (Uri.base.queryParameters['openNotifications'] == '1') {
    debugPrint('[BrowserNotification] Pending navigation from launch query');
    onPendingNavigation();
  }
}
