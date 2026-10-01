import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/navigation/app_navigator.dart';
import '../firebase_options.dart';
import 'browser_notification.dart';

const String _notificationPayload = 'open_notifications';

/// Top-level function for handling background messages
/// This MUST be a top-level function, not a static method
/// It runs in a separate isolate, so Firebase must be initialized here
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('Background message received: ${message.messageId}');
  debugPrint('Message data: ${message.data}');
  debugPrint('Message notification: ${message.notification?.title}');
}

/// Handler for push notifications (FCM)
class PushNotificationHandler {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
        'mic_notifications',
        'MIC Notifications',
        description: 'General notifications from MIC Backoffice',
        importance: Importance.high,
      );

  /// Initialize push notification handlers
  static Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      throw Exception(
        'Firebase is not initialized. Please configure Firebase first.',
      );
    }

    if (!kIsWeb) {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_defaultChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else {
      final granted = await ensureBrowserNotificationPermission();
      debugPrint(
        '[PushNotificationHandler] Web notification permission: '
        '${browserNotificationPermissionStatus} (granted=$granted)',
      );
      setupWebNotificationClickHandling(AppNavigator.navigateToNotifications);
      checkWebNotificationLaunchQuery(
        AppNavigator.markPendingNotificationsNavigation,
      );
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  /// Re-check browser notification permission after login (web only).
  static Future<void> ensureWebNotificationPermission() async {
    if (!kIsWeb) return;
    final granted = await ensureBrowserNotificationPermission();
    debugPrint(
      '[PushNotificationHandler] Web notification permission after login: '
      '${browserNotificationPermissionStatus} (granted=$granted)',
    );
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';

    debugPrint(
      '[PushNotificationHandler] Foreground message: id=${message.messageId} '
      'title=$title',
    );

    if (kIsWeb) {
      await ensureBrowserNotificationPermission();
      showBrowserNotification(title: title, body: body.isEmpty ? null : body);
      return;
    }

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _defaultChannel.id,
          _defaultChannel.name,
          channelDescription: _defaultChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: _notificationPayload,
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    AppNavigator.navigateToNotifications();
  }

  static void _onNotificationTapped(NotificationResponse response) {
    AppNavigator.navigateToNotifications();
  }

  /// Get initial message (if app was opened from notification)
  static Future<RemoteMessage?> getInitialMessage() async {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseMessaging.instance.getInitialMessage();
  }

  /// Call after the app shell is ready (post-login navigation).
  static Future<void> handleLaunchNotification() async {
    if (kIsWeb) {
      checkWebNotificationLaunchQuery(
        AppNavigator.markPendingNotificationsNavigation,
      );
    }

    final initialMessage = await getInitialMessage();
    if (initialMessage != null) {
      AppNavigator.markPendingNotificationsNavigation();
    }
  }
}
