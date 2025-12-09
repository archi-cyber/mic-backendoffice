import 'package:firebase_messaging/firebase_messaging.dart';
import 'supabase_service.dart';

/// Service for managing FCM device tokens
class DeviceTokenService {
  static final _client = SupabaseService.client;
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static String? _currentToken;

  /// Initialize FCM and get device token
  static Future<String?> initialize() async {
    try {
      // Request permission
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get token
        final token = await _firebaseMessaging.getToken();
        _currentToken = token;

        // Save token to database if user is authenticated
        if (SupabaseService.isAuthenticated) {
          await saveDeviceToken(token);
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          _currentToken = newToken;
          if (SupabaseService.isAuthenticated) {
            saveDeviceToken(newToken);
          }
        });

        return token;
      }

      return null;
    } catch (e) {
      throw Exception('Failed to initialize FCM: $e');
    }
  }

  /// Save device token to database
  static Future<void> saveDeviceToken(String? token) async {
    if (token == null) return;

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;

      // Get device info
      // Note: You may want to add device info like platform, model, etc.

      // Upsert device token
      await _client.from('user_devices').upsert({
        'user_id': userId,
        'device_token': token,
        'platform': 'mobile', // Could be 'android' or 'ios'
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,device_token');
    } catch (e) {
      throw Exception('Failed to save device token: $e');
    }
  }

  /// Get device tokens for a user
  static Future<List<String>> getDeviceTokensForUser(String userId) async {
    try {
      final devices = await _client
          .from('user_devices')
          .select('device_token')
          .eq('user_id', userId);

      return (devices as List)
          .map((device) => device['device_token'] as String)
          .where((token) => token != null)
          .toList();
    } catch (e) {
      throw Exception('Failed to get device tokens: $e');
    }
  }

  /// Get all device tokens for multiple users
  static Future<Map<String, List<String>>> getDeviceTokensForUsers(
    List<String> userIds,
  ) async {
    try {
      final devices = await _client
          .from('user_devices')
          .select('user_id,device_token')
          .inFilter('user_id', userIds);

      final Map<String, List<String>> tokensMap = {};

      for (final device in devices as List) {
        final userId = device['user_id'].toString();
        final token = device['device_token'] as String?;

        if (token != null) {
          tokensMap.putIfAbsent(userId, () => []).add(token);
        }
      }

      return tokensMap;
    } catch (e) {
      throw Exception('Failed to get device tokens for users: $e');
    }
  }

  /// Remove device token (on logout)
  static Future<void> removeDeviceToken(String token) async {
    try {
      await _client.from('user_devices').delete().eq('device_token', token);
    } catch (e) {
      throw Exception('Failed to remove device token: $e');
    }
  }

  /// Get current device token
  static String? get currentToken => _currentToken;
}
