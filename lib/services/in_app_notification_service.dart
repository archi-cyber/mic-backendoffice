import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/api/realtime_client.dart';
import '../core/navigation/app_navigator.dart';
import '../core/utils/permission_helper.dart';
import '../core/platform/platform_capabilities.dart';
import 'browser_notification.dart';
import 'notification_service.dart';

/// Desktop in-app notification listener (API realtime + Windows toast).
class InAppNotificationService extends ChangeNotifier {
  InAppNotificationService._();
  static final InAppNotificationService instance = InAppNotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  RealtimeClient? _realtime;
  String? _memberId;
  int _unreadCount = 0;
  bool _initialized = false;
  bool _localNotificationsReady = false;

  int get unreadCount => _unreadCount;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (!PlatformCapabilities.supportsInAppNotifications) return;
    if (_initialized) return;

    final memberId = await _resolveMemberId();
    if (memberId == null) return;

    _memberId = memberId;
    await _initLocalNotifications();
    await _refreshUnreadCount();
    _subscribeToRealtime(memberId);
    _initialized = true;
    notifyListeners();
  }

  Future<void> disposeService() async {
    _realtime?.off(RealtimeEvents.notificationNew, _onRealtimeNotification);
    _realtime = null;
    _memberId = null;
    _initialized = false;
    _localNotificationsReady = false;
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> refresh() => _refreshUnreadCount();

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) {
      try {
        _localNotificationsReady = await ensureBrowserNotificationPermission();
        debugPrint(
          '[InAppNotificationService] Web notification permission: '
          '${browserNotificationPermissionStatus}',
        );
      } catch (e) {
        debugPrint('[InAppNotificationService] web permission failed: $e');
        _localNotificationsReady = false;
      }
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.windows) return;

    const initSettings = InitializationSettings(
      windows: WindowsInitializationSettings(
        appName: 'SysteMIC',
        appUserModelId: 'Molded.MIC.Backoffice.1',
        guid: '7c4f8a2e-9b1d-4e6a-8f3c-2d5e9a1b7c4f',
      ),
    );

    try {
      final initialized = await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (_) {
          AppNavigator.navigateToNotifications();
        },
      );
      _localNotificationsReady = initialized ?? false;
      debugPrint(
        '[InAppNotificationService] Windows notifications initialized: '
        '$_localNotificationsReady',
      );
    } catch (e) {
      debugPrint('[InAppNotificationService] init failed: $e');
      _localNotificationsReady = false;
    }
  }

  Future<String?> _resolveMemberId() async => PermissionHelper.memberId;

  void _subscribeToRealtime(String memberId) {
    final realtime = RealtimeClient.current;
    if (realtime == null) {
      debugPrint('[InAppNotificationService] Realtime unavailable');
      return;
    }
    debugPrint(
      '[InAppNotificationService] Listening for notifications of '
      'member_id=$memberId',
    );
    _realtime = realtime;
    realtime.on(RealtimeEvents.notificationNew, _onRealtimeNotification);
  }

  void _onRealtimeNotification(dynamic data) {
    if (data is! Map) return;
    final record = data.cast<String, dynamic>();
    final target = record['member_id']?.toString();
    // Les notifications globales (sans destinataire) concernent tout le monde.
    if (target != null && target.isNotEmpty && target != _memberId) return;
    debugPrint(
      '[InAppNotificationService] Realtime notification received: '
      '${record['type']}',
    );
    unawaited(_handleNewNotification(record));
  }

  Future<void> _handleNewNotification(Map<String, dynamic> record) async {
    _unreadCount++;
    notifyListeners();

    final title = record['title']?.toString() ?? 'Notification';
    final message = record['message']?.toString() ?? '';
    final type = record['type']?.toString() ?? '';

    final notificationTitle = type == 'task_assigned'
        ? 'Task assigned: $title'
        : title;
    final notificationBody = type == 'task_assigned'
        ? (message.isNotEmpty ? message : 'You have been assigned a new task.')
        : message;

    await _showSystemNotification(title: notificationTitle, body: notificationBody);
  }

  Future<void> _showSystemNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      _localNotificationsReady = await ensureBrowserNotificationPermission();
      if (!_localNotificationsReady) return;
      showBrowserNotification(
        title: title,
        body: body.isEmpty ? null : body,
      );
      return;
    }

    if (!_localNotificationsReady ||
        defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }

    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body.isEmpty ? null : body,
        const NotificationDetails(
          windows: WindowsNotificationDetails(
            duration: WindowsNotificationDuration.long,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[InAppNotificationService] toast failed: $e');
    }
  }

  Future<void> _refreshUnreadCount() async {
    try {
      _unreadCount = await NotificationService.getUnreadCount(
        memberId: _memberId,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[InAppNotificationService] unread count error: $e');
    }
  }
}
