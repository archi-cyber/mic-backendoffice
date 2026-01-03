import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'supabase_service.dart';

/// Service for managing FCM device tokens
class DeviceTokenService {
  static final _client = SupabaseService.client;
  static FirebaseMessaging? _firebaseMessaging;
  static String? _currentToken;

  /// Get FirebaseMessaging instance (lazy initialization)
  static FirebaseMessaging? get _messaging {
    if (_firebaseMessaging == null) {
      try {
        // Check if Firebase is initialized before accessing FirebaseMessaging
        if (Firebase.apps.isNotEmpty) {
          _firebaseMessaging = FirebaseMessaging.instance;
        } else {
          return null;
        }
      } catch (e) {
        // Firebase not initialized or error accessing FirebaseMessaging
        return null;
      }
    }
    return _firebaseMessaging;
  }

  /// Initialize FCM and get device token
  static Future<String?> initialize() async {
    try {
      // Check if Firebase is available
      final messaging = _messaging;
      if (messaging == null) {
        throw Exception(
          'Firebase is not initialized. Please configure Firebase first.',
        );
      }

      // Request permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get token
        final token = await messaging.getToken();
        _currentToken = token;

        debugPrint('[DeviceTokenService] ✅ FCM token generated: ${token?.substring(0, 20)}...');
        debugPrint('[DeviceTokenService] Token length: ${token?.length}');

        // Save token to database if user is authenticated
        if (SupabaseService.isAuthenticated) {
          debugPrint('[DeviceTokenService] User is authenticated, saving device token to database...');
          await saveDeviceToken(token);
        } else {
          debugPrint('[DeviceTokenService] User is not authenticated, token will be saved after login');
        }

        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) {
          _currentToken = newToken;
          debugPrint('[DeviceTokenService] 🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
          if (SupabaseService.isAuthenticated) {
            saveDeviceToken(newToken);
          }
        });

        return token;
      } else {
        debugPrint('[DeviceTokenService] ❌ Notification permission not authorized. Status: ${settings.authorizationStatus}');
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
      final authUserId = SupabaseService.currentUser?.id;
      if (authUserId == null) {
        debugPrint('[DeviceTokenService] Cannot save token: User not authenticated');
        return;
      }

      debugPrint('[DeviceTokenService] Saving device token for user: $authUserId');

      // Get the user_id from users table (not auth.users)
      // The user_devices table references users.id, not auth.users.id
      final user = await _client
          .from('users')
          .select('id')
          .eq('id', authUserId)
          .maybeSingle();

      // If user doesn't exist in users table, we can't save the device token
      // This can happen if the user was created in auth but not synced to users table
      if (user == null) {
        // Log warning but don't throw error - device token will be saved on next login
        // when user record is created
        debugPrint(
          '[DeviceTokenService] ⚠️ Warning: User $authUserId not found in users table. '
          'Device token will not be saved. User record may need to be created.',
        );
        return;
      }

      final userId = user['id'].toString();

      // Get device info
      // Note: You may want to add device info like platform, model, etc.

      // Upsert device token
      await _client.from('user_devices').upsert({
        'user_id': userId,
        'device_token': token,
        'platform': 'mobile', // Could be 'android' or 'ios'
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,device_token');

      debugPrint('[DeviceTokenService] ✅ Device token saved successfully to user_devices table');
    } catch (e) {
      // If it's a foreign key constraint error, provide helpful message
      if (e.toString().contains('foreign key constraint') ||
          e.toString().contains('user_devices_user_id_fkey')) {
        throw Exception(
          'Failed to save device token: User record not found in users table. '
          'Please ensure the user is properly synced. Original error: $e',
        );
      }
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
          .map((device) => device['device_token'] as String?)
          .whereType<String>()
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
