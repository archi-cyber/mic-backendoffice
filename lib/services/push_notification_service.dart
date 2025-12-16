import 'package:flutter/foundation.dart';
import 'device_token_service.dart';
import 'supabase_service.dart';

/// Service for sending push notifications via Supabase Edge Functions
/// The Edge Function handles FCM communication securely on the server
class PushNotificationService {
  static const String _edgeFunctionName = 'send-push-notification';

  /// Send push notification to multiple device tokens via Supabase Edge Function
  static Future<void> sendPushNotification({
    required List<String> deviceTokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (deviceTokens.isEmpty) {
      debugPrint('[PushNotificationService] No device tokens to send to');
      return;
    }

    try {
      debugPrint(
        '[PushNotificationService] Sending push notifications to ${deviceTokens.length} devices via Edge Function',
      );

      final response = await SupabaseService.client.functions.invoke(
        _edgeFunctionName,
        body: {
          'deviceTokens': deviceTokens,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );

      if (response.status == 200) {
        final responseData = response.data as Map<String, dynamic>?;
        final totalSuccess = responseData?['totalSuccess'] as int? ?? 0;
        final totalFailure = responseData?['totalFailure'] as int? ?? 0;
        debugPrint(
          '[PushNotificationService] Successfully sent: $totalSuccess success, $totalFailure failures',
        );
      } else {
        debugPrint(
          '[PushNotificationService] Edge Function error: ${response.status} - ${response.data}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        '[PushNotificationService] ERROR: Failed to send push notifications: $e',
      );
      debugPrint('[PushNotificationService] Stack trace: $stackTrace');
      // Don't throw - push notifications are secondary to announcement creation
    }
  }

  /// Send push notifications to all users (excluding creator) for an announcement
  static Future<void> sendAnnouncementPushNotification({
    required String title,
    required String message,
    required String announcementId,
    String? excludeUserId,
  }) async {
    try {
      debugPrint(
        '[PushNotificationService] Sending announcement push notifications: $announcementId',
      );

      // Get all active users
      final allUsers = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('is_active', true)
          .limit(10000);

      final userIds = (allUsers as List)
          .map((u) => u['id']?.toString())
          .whereType<String>()
          .where((id) => id != excludeUserId)
          .toList();

      debugPrint(
        '[PushNotificationService] Found ${userIds.length} users to notify (excluding creator)',
      );

      if (userIds.isEmpty) {
        debugPrint('[PushNotificationService] No users to notify');
        return;
      }

      // Get device tokens for all users
      final tokensMap = await DeviceTokenService.getDeviceTokensForUsers(
        userIds,
      );

      // Collect all device tokens
      final allTokens = <String>[];
      tokensMap.forEach((userId, tokens) {
        allTokens.addAll(tokens);
      });

      debugPrint(
        '[PushNotificationService] Found ${allTokens.length} device tokens to send to',
      );

      if (allTokens.isEmpty) {
        debugPrint('[PushNotificationService] No device tokens found');
        return;
      }

      // Send push notifications
      await sendPushNotification(
        deviceTokens: allTokens,
        title: title,
        body: message,
        data: {
          'type': 'announcement',
          'announcement_id': announcementId,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[PushNotificationService] ERROR: Failed to send announcement push notifications: $e',
      );
      debugPrint('[PushNotificationService] Stack trace: $stackTrace');
      // Don't throw - push notifications are secondary
    }
  }
}
