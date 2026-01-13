import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';

/// Top-level function for handling background messages
/// This MUST be a top-level function, not a static method
/// It runs in a separate isolate, so Firebase must be initialized here
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in the background isolate
  // This is required because background handlers run in a separate isolate
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Handle background message
  // This runs in a separate isolate
  print('Background message received: ${message.messageId}');
  print('Message data: ${message.data}');
  print('Message notification: ${message.notification?.title}');
  
  // You can add additional processing here, such as:
  // - Saving notification to local database
  // - Updating app state
  // - Triggering local notifications
}

/// Handler for push notifications (FCM)
class PushNotificationHandler {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize push notification handlers
  static Future<void> initialize() async {
    // Check if Firebase is initialized
    if (Firebase.apps.isEmpty) {
      throw Exception(
        'Firebase is not initialized. Please configure Firebase first.',
      );
    }
    
    // Note: Background message handler should already be registered in main.dart
    // before this method is called. This ensures it's registered before runApp()
    
    // Initialize local notifications
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

    // Request permissions for iOS
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  /// Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Show local notification when app is in foreground
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Notification',
      message.notification?.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'birthday_channel',
          'Birthday Notifications',
          channelDescription: 'Notifications for upcoming birthdays',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    // Navigate to relevant screen based on notification data
    final data = message.data;
    if (data['type'] == 'birthday') {
      // Navigate to member profile or birthday list
      // This would typically use a navigation service
    }
  }

  /// Handle local notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    // Handle local notification tap
    // Navigate to relevant screen
  }

  /// Get initial message (if app was opened from notification)
  static Future<RemoteMessage?> getInitialMessage() async {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return await FirebaseMessaging.instance.getInitialMessage();
  }
}
