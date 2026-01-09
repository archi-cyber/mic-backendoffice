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
          '[PushNotificationService] ✅ Successfully sent: $totalSuccess success, $totalFailure failures',
        );
        if (totalFailure > 0) {
          debugPrint(
            '[PushNotificationService] ⚠️ Some notifications failed. Check Edge Function logs for details.',
          );
        }
      } else {
        final errorData = response.data;
        debugPrint(
          '[PushNotificationService] ❌ Edge Function error: HTTP ${response.status}',
        );
        debugPrint('[PushNotificationService] Error response: $errorData');
        
        // Provide helpful error messages based on status code
        if (response.status == 404) {
          debugPrint(
            '[PushNotificationService] ⚠️ Edge Function not found. '
            'Please deploy the function: supabase functions deploy send-push-notification',
          );
        } else if (response.status == 500) {
          debugPrint(
            '[PushNotificationService] ⚠️ Edge Function internal error. '
            'Check Supabase secrets (FIREBASE_PROJECT_ID and FIREBASE_SERVICE_ACCOUNT) are set correctly.',
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint(
        '[PushNotificationService] ❌ ERROR: Failed to send push notifications: $e',
      );
      debugPrint('[PushNotificationService] Error type: ${e.runtimeType}');
      debugPrint('[PushNotificationService] Stack trace: $stackTrace');
      
      // Provide helpful diagnostic information
      if (e.toString().contains('Function not found') || 
          e.toString().contains('404') ||
          e.toString().contains('not deployed')) {
        debugPrint(
          '[PushNotificationService] 💡 DIAGNOSIS: Edge Function not deployed. '
          'Run: supabase functions deploy send-push-notification',
        );
      } else if (e.toString().contains('secret') || 
                 e.toString().contains('FIREBASE_PROJECT_ID') ||
                 e.toString().contains('FIREBASE_SERVICE_ACCOUNT')) {
        debugPrint(
          '[PushNotificationService] 💡 DIAGNOSIS: Supabase secrets not configured. '
          'Set FIREBASE_PROJECT_ID and FIREBASE_SERVICE_ACCOUNT secrets.',
        );
      }
      
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
      debugPrint(
        '[PushNotificationService] Excluding user ID: ${excludeUserId ?? "none"}',
      );

      // Get all active users
      final allUsers = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('is_active', true)
          .limit(10000);

      debugPrint(
        '[PushNotificationService] Found ${(allUsers as List).length} active users in database',
      );

      // Convert excludeUserId to string for comparison, handle null
      final excludeUserIdStr = excludeUserId?.toString();

      final userIds = (allUsers as List)
          .map((u) => u['id']?.toString())
          .whereType<String>()
          .where((id) {
            // Exclude the creator if excludeUserId is provided
            if (excludeUserIdStr != null && id == excludeUserIdStr) {
              debugPrint(
                '[PushNotificationService] Excluding creator user ID: $id',
              );
              return false;
            }
            return true;
          })
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
      debugPrint(
        '[PushNotificationService] Users with tokens: ${tokensMap.keys.length} out of ${userIds.length}',
      );

      if (allTokens.isEmpty) {
        debugPrint(
          '[PushNotificationService] ⚠️ WARNING: No device tokens found for ${userIds.length} users. '
          'Users may not have registered their device tokens. Ensure users have logged in and granted notification permissions.',
        );
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

      debugPrint(
        '[PushNotificationService] ✅ Push notification request sent for ${allTokens.length} devices',
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
