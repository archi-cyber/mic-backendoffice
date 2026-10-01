Future<bool> requestBrowserNotificationPermission() async => false;

bool isBrowserNotificationPermissionGranted() => false;

String get browserNotificationPermissionStatus => 'unsupported';

Future<bool> ensureBrowserNotificationPermission() async => false;

void showBrowserNotification({
  required String title,
  String? body,
}) {}

void setupWebNotificationClickHandling(void Function() onNotificationClick) {}

void checkWebNotificationLaunchQuery(void Function() onPendingNavigation) {}
