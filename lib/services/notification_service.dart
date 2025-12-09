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
      // Get current user's member ID if not provided
      final currentUserId = SupabaseService.currentUser?.id;
      if (memberId == null && currentUserId != null) {
        // Try to get member_id from members table
        final member = await _client
            .from('members')
            .select('id')
            .eq('user_id', currentUserId)
            .maybeSingle();
        memberId = member?['id']?.toString();
      }

      if (memberId == null) {
        throw Exception('Member ID is required');
      }

      var query = _client
          .from('notifications')
          .select()
          .eq('member_id', memberId);

      // Apply filters
      if (isRead != null) {
        query = query.eq('is_read', isRead);
      }
      if (type != null) {
        query = query.eq('type', type);
      }

      // Apply ordering (returns PostgrestTransformBuilder)
      dynamic transformQuery = query.order('created_at', ascending: false);

      // Apply pagination
      if (limit != null) {
        transformQuery = transformQuery.limit(limit);
      }
      if (offset != null) {
        transformQuery = transformQuery.range(
          offset,
          offset + (limit ?? 10) - 1,
        );
      }

      final response = await transformQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get notifications: $e');
    }
  }

  /// Get unread notifications count
  /// GET /notifications/count
  static Future<int> getUnreadCount({String? memberId}) async {
    try {
      // Get current user's member ID if not provided
      final currentUserId = SupabaseService.currentUser?.id;
      if (memberId == null && currentUserId != null) {
        final member = await _client
            .from('members')
            .select('id')
            .eq('user_id', currentUserId)
            .maybeSingle();
        memberId = member?['id']?.toString();
      }

      if (memberId == null) {
        return 0;
      }

      final response = await _client
          .from('notifications')
          .select()
          .eq('member_id', memberId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
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
        final member = await _client
            .from('members')
            .select('id')
            .eq('user_id', currentUserId)
            .maybeSingle();
        memberId = member?['id']?.toString();
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
      }
    } catch (e) {
      throw Exception('Failed to create bulk notifications: $e');
    }
  }
}
