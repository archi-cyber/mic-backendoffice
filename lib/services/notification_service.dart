import 'package:flutter/foundation.dart';
import 'device_token_service.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Notification service for managing user notifications
class NotificationService {
  static final _client = SupabaseService.client;

  /// Get notifications for current user
  /// GET /notifications
  static Future<List<Map<String, dynamic>>> getNotifications({
    String? memberId,
    bool? isRead,
    String? type,
    int? limit,
    int? offset,
  }) async {
    try {
      debugPrint(
        '[NotificationService] getNotifications called with memberId: $memberId',
      );

      // Get current user's member ID if not provided
      final currentUserId = SupabaseService.currentUser?.id;
      debugPrint('[NotificationService] Current user ID: $currentUserId');

      if (memberId == null && currentUserId != null) {
        debugPrint(
          '[NotificationService] Member ID not provided, fetching from users table...',
        );
        // Query users table to get member_id (users.member_id, not members.user_id)
        final user = await _client
            .from('users')
            .select('member_id')
            .eq('id', currentUserId)
            .maybeSingle();
        debugPrint('[NotificationService] User query result: $user');
        memberId = user?['member_id']?.toString();
        debugPrint('[NotificationService] Extracted memberId: $memberId');
      }

      if (memberId == null) {
        debugPrint('[NotificationService] ERROR: Member ID is null');
        throw Exception('Member ID is required');
      }

      debugPrint(
        '[NotificationService] Querying notifications table for member_id: $memberId',
      );
      var query = _client
          .from('notifications')
          .select()
          .eq('member_id', memberId);

      // Apply filters
      if (isRead != null) {
        debugPrint('[NotificationService] Filtering by is_read: $isRead');
        query = query.eq('is_read', isRead);
      }
      if (type != null) {
        debugPrint('[NotificationService] Filtering by type: $type');
        query = query.eq('type', type);
      }

      // Apply ordering (returns PostgrestTransformBuilder)
      debugPrint('[NotificationService] Applying ordering...');
      dynamic transformQuery = query.order('created_at', ascending: false);

      // Apply pagination
      if (limit != null) {
        debugPrint('[NotificationService] Applying limit: $limit');
        transformQuery = transformQuery.limit(limit);
      }
      if (offset != null) {
        debugPrint('[NotificationService] Applying offset: $offset');
        transformQuery = transformQuery.range(
          offset,
          offset + (limit ?? 10) - 1,
        );
      }

      debugPrint('[NotificationService] Executing query...');
      final response = await transformQuery;
      final notifications = List<Map<String, dynamic>>.from(response);
      debugPrint(
        '[NotificationService] Successfully retrieved ${notifications.length} notifications',
      );
      return notifications;
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] ERROR in getNotifications: $e');
      debugPrint('[NotificationService] Stack trace: $stackTrace');

      // If error mentions "members.user_id does not exist", it's an RLS policy issue
      // Run FIX_NOTIFICATIONS_RLS.sql in Supabase SQL Editor to fix it
      if (e.toString().contains('members.user_id') ||
          e.toString().contains('does not exist')) {
        throw Exception(
          'Database configuration error: RLS policy issue. '
          'Please run FIX_NOTIFICATIONS_RLS.sql in Supabase SQL Editor. '
          'Original error: $e',
        );
      }
      throw Exception('Failed to get notifications: $e');
    }
  }

  /// Get unread notifications count
  /// GET /notifications/count
  static Future<int> getUnreadCount({String? memberId}) async {
    try {
      debugPrint(
        '[NotificationService] getUnreadCount called with memberId: $memberId',
      );

      // Get current user's member ID if not provided
      final currentUserId = SupabaseService.currentUser?.id;
      debugPrint('[NotificationService] Current user ID: $currentUserId');

      if (memberId == null && currentUserId != null) {
        debugPrint(
          '[NotificationService] Member ID not provided, fetching from users table...',
        );
        // Query users table to get member_id (users.member_id, not members.user_id)
        final user = await _client
            .from('users')
            .select('member_id')
            .eq('id', currentUserId)
            .maybeSingle();
        debugPrint('[NotificationService] User query result: $user');
        memberId = user?['member_id']?.toString();
        debugPrint('[NotificationService] Extracted memberId: $memberId');
      }

      if (memberId == null) {
        debugPrint(
          '[NotificationService] WARNING: Member ID is null, returning 0',
        );
        return 0;
      }

      debugPrint(
        '[NotificationService] Querying unread notifications for member_id: $memberId',
      );
      final response = await _client
          .from('notifications')
          .select()
          .eq('member_id', memberId)
          .eq('is_read', false);

      final count = (response as List).length;
      debugPrint('[NotificationService] Unread count: $count');
      return count;
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] ERROR in getUnreadCount: $e');
      debugPrint('[NotificationService] Stack trace: $stackTrace');

      // If error mentions "members.user_id does not exist", it's an RLS policy issue
      if (e.toString().contains('members.user_id') ||
          e.toString().contains('does not exist')) {
        throw Exception(
          'Database configuration error: RLS policy issue. '
          'Please run FIX_NOTIFICATIONS_RLS.sql in Supabase SQL Editor. '
          'Original error: $e',
        );
      }
      throw Exception('Failed to get unread count: $e');
    }
  }

  /// Mark notification as read
  /// PATCH /notifications/:id/read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications as read
  /// PATCH /notifications/read-all
  static Future<void> markAllAsRead({String? memberId}) async {
    try {
      // Get current user's member ID if not provided
      final currentUserId = SupabaseService.currentUser?.id;
      if (memberId == null && currentUserId != null) {
        // Query users table to get member_id (users.member_id, not members.user_id)
        final user = await _client
            .from('users')
            .select('member_id')
            .eq('id', currentUserId)
            .maybeSingle();
        memberId = user?['member_id']?.toString();
      }

      if (memberId == null) {
        throw Exception('Member ID is required');
      }

      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('member_id', memberId)
          .eq('is_read', false);
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  /// Delete notification
  /// DELETE /notifications/:id
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _client.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }

  /// Create notification
  /// POST /notifications
  static Future<Map<String, dynamic>> createNotification({
    required String memberId,
    required String type,
    required String title,
    required String message,
    String? relatedId,
    String? relatedType,
    DateTime? scheduledFor,
  }) async {
    try {
      final response = await _client
          .from('notifications')
          .insert({
            'member_id': memberId,
            'type': type,
            'title': title,
            'message': message,
            'related_id': relatedId,
            'related_type': relatedType,
            'is_read': false,
            'scheduled_for': scheduledFor?.toIso8601String().split('T')[0],
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      await _sendPushToMembers(
        memberIds: [memberId],
        title: title,
        message: message,
        type: type,
        relatedId: relatedId,
        relatedType: relatedType,
      );

      return response;
    } catch (e) {
      throw Exception('Failed to create notification: $e');
    }
  }

  /// Create notifications for multiple members
  /// POST /notifications/bulk
  static Future<void> createBulkNotifications({
    required List<String> memberIds,
    required String type,
    required String title,
    required String message,
    String? relatedId,
    String? relatedType,
    DateTime? scheduledFor,
  }) async {
    try {
      final notifications = memberIds
          .map(
            (memberId) => {
              'member_id': memberId,
              'type': type,
              'title': title,
              'message': message,
              'related_id': relatedId,
              'related_type': relatedType,
              'is_read': false,
              'scheduled_for': scheduledFor?.toIso8601String().split('T')[0],
              'created_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      if (notifications.isNotEmpty) {
        await _client.from('notifications').insert(notifications);
        await _sendPushToMembers(
          memberIds: memberIds,
          title: title,
          message: message,
          type: type,
          relatedId: relatedId,
          relatedType: relatedType,
        );
      }
    } catch (e) {
      throw Exception('Failed to create bulk notifications: $e');
    }
  }

  static Future<void> _sendPushToMembers({
    required List<String> memberIds,
    required String title,
    required String message,
    required String type,
    String? relatedId,
    String? relatedType,
  }) async {
    try {
      final uniqueMemberIds = memberIds
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .toList();
      if (uniqueMemberIds.isEmpty) return;

      final users = await _client
          .from('users')
          .select('id')
          .inFilter('member_id', uniqueMemberIds)
          .eq('is_active', true);

      final userIds = List<Map<String, dynamic>>.from(
        users,
      ).map((user) => user['id']?.toString()).whereType<String>().toList();
      if (userIds.isEmpty) return;

      final tokensByUser = await DeviceTokenService.getDeviceTokensForUsers(
        userIds,
      );
      final tokens = <String>{};
      for (final userTokens in tokensByUser.values) {
        tokens.addAll(userTokens);
      }
      if (tokens.isEmpty) return;

      await PushNotificationService.sendPushNotification(
        deviceTokens: tokens.toList(),
        title: title,
        body: message,
        data: {
          'type': type,
          if (relatedId != null) 'related_id': relatedId,
          if (relatedType != null) 'related_type': relatedType,
          if (relatedType == 'task' && relatedId != null) 'taskId': relatedId,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );
    } catch (e) {
      debugPrint('[NotificationService] Push delivery failed: $e');
    }
  }
}
