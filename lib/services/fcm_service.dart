import 'package:http/http.dart' as http;
import 'dart:convert';

/// FCM service for sending push notifications
/// Note: In production, this should be done server-side for security
class FCMService {
  // FCM Server Key - Should be stored securely on server
  // For client-side, you'd typically call a backend API
  static const String _fcmServerKey = 'YOUR_FCM_SERVER_KEY';
  static const String _fcmUrl = 'https://fcm.googleapis.com/fcm/send';

  /// Send push notification to multiple device tokens
  /// Note: In production, this should be called from server-side
  static Future<void> sendPushNotification({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (tokens.isEmpty) return;

    try {
      // For multiple tokens, send to each or use topic/condition
      // Using individual sends for simplicity
      for (final token in tokens) {
        await _sendToToken(token: token, title: title, body: body, data: data);
      }
    } catch (e) {
      throw Exception('Failed to send push notification: $e');
    }
  }

  /// Send notification to a single token
  static Future<void> _sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final payload = {
        'to': token,
        'notification': {'title': title, 'body': body, 'sound': 'default'},
        'data': data ?? {},
        'priority': 'high',
      };

      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_fcmServerKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'FCM send failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to send FCM notification: $e');
    }
  }

  /// Send to topic (for broadcast notifications)
  static Future<void> sendToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final payload = {
        'to': '/topics/$topic',
        'notification': {'title': title, 'body': body, 'sound': 'default'},
        'data': data ?? {},
        'priority': 'high',
      };

      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_fcmServerKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'FCM send failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to send FCM notification to topic: $e');
    }
  }
}
