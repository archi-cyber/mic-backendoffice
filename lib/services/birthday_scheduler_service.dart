import 'supabase_service.dart';
import 'device_token_service.dart';
import 'fcm_service.dart';

/// Birthday scheduler service - runs daily to compute and send birthday notifications
/// This should be called by a scheduled job (server-side) or background task
class BirthdaySchedulerService {
  static final _client = SupabaseService.client;

  /// Main scheduler function - computes birthdays and sends notifications
  /// Should run daily at a fixed time (server timezone)
  /// Computes birthdays in 7 days, 1 day, and today (match month & day)
  static Future<void> processBirthdayNotifications() async {
    try {
      final today = DateTime.now();

      // Compute target dates: today, 1 day from now, 7 days from now
      final targetDates = [
        {'days': 0, 'date': today},
        {'days': 1, 'date': today.add(const Duration(days: 1))},
        {'days': 7, 'date': today.add(const Duration(days: 7))},
      ];

      // Get all active members with birthdays
      final allMembers = await _client
          .from('members')
          .select()
          .eq('is_active', true)
          .not('birthday', 'is', null);

      final birthdayMembers = <Map<String, dynamic>>[];

      // Filter members whose birthday matches any target date (month & day)
      for (final member in allMembers as List) {
        final birthday = member['birthday'];
        if (birthday == null) continue;

        try {
          final birthdayDate = DateTime.parse(birthday);
          final birthdayMonth = birthdayDate.month;
          final birthdayDay = birthdayDate.day;

          // Check if birthday matches any target date (match month & day)
          for (final target in targetDates) {
            final targetDate = target['date'] as DateTime;
            if (birthdayMonth == targetDate.month &&
                birthdayDay == targetDate.day) {
              birthdayMembers.add({
                ...member,
                'days_until': target['days'] as int,
                'scheduled_for': targetDate.toIso8601String().split('T')[0],
              });
              break; // Only add once even if matches multiple dates
            }
          }
        } catch (e) {
          // Skip invalid birthday dates
          continue;
        }
      }

      if (birthdayMembers.isEmpty) {
        return; // No birthdays to process
      }

      // Get notification configuration
      final config = await _getNotificationConfig();
      final target = config['target'] as String;

      // Get target user IDs based on configuration
      final targetUserIds = await _getTargetUserIds(target);

      if (targetUserIds.isEmpty) {
        return; // No target users
      }

      // Get device tokens for target users
      final deviceTokensMap = await DeviceTokenService.getDeviceTokensForUsers(
        targetUserIds,
      );

      // Process each birthday member
      for (final birthdayMember in birthdayMembers) {
        final memberId = birthdayMember['id'].toString();
        final daysUntil = birthdayMember['days_until'] as int;
        final scheduledFor = birthdayMember['scheduled_for'] as String;

        // Determine notification message based on days until
        String message;
        String title;
        if (daysUntil == 0) {
          title = 'Birthday Today! 🎉';
          message =
              '${birthdayMember['first_name']} ${birthdayMember['last_name']} has a birthday today!';
        } else if (daysUntil == 1) {
          title = 'Birthday Tomorrow';
          message =
              '${birthdayMember['first_name']} ${birthdayMember['last_name']} has a birthday tomorrow!';
        } else {
          title = 'Upcoming Birthday';
          message =
              '${birthdayMember['first_name']} ${birthdayMember['last_name']} has a birthday in $daysUntil days!';
        }

        // Create notification for each target user
        final notifications = <Map<String, dynamic>>[];
        final pushTokens = <String>[];

        for (final userId in targetUserIds) {
          // Skip if user has opted out
          if (await _hasUserOptedOut(userId)) {
            continue;
          }

          // Check for duplicates: same type + target user + related_id + scheduled_for
          final isDuplicate = await _checkDuplicateNotification(
            type: 'birthday',
            targetUserId: userId,
            relatedId: memberId,
            scheduledFor: scheduledFor,
          );

          if (isDuplicate) {
            continue; // Skip if duplicate exists for this user
          }

          notifications.add({
            'member_id': userId,
            'type': 'birthday',
            'title': title,
            'message': message,
            'related_id': memberId,
            'related_type': 'member',
            'scheduled_for': scheduledFor,
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });

          // Collect device tokens for push notifications
          final tokens = deviceTokensMap[userId] ?? [];
          pushTokens.addAll(tokens);
        }

        // Insert notifications (batch insert)
        if (notifications.isNotEmpty) {
          await _client.from('notifications').insert(notifications);
        }

        // Send FCM push notifications (deduplicate tokens)
        final uniqueTokens = pushTokens.toSet().toList();
        if (uniqueTokens.isNotEmpty) {
          await FCMService.sendPushNotification(
            tokens: uniqueTokens,
            title: title,
            body: message,
            data: {
              'type': 'birthday',
              'member_id': memberId,
              'scheduled_for': scheduledFor,
            },
          );
        }
      }
    } catch (e) {
      throw Exception('Failed to process birthday notifications: $e');
    }
  }

  /// Check for duplicate notification
  /// Avoid duplicates: check notifications for same type + target user + related_id + scheduled_for
  static Future<bool> _checkDuplicateNotification({
    required String type,
    required String targetUserId,
    required String relatedId,
    required String scheduledFor,
  }) async {
    try {
      final existing = await _client
          .from('notifications')
          .select('id')
          .eq('type', type)
          .eq(
            'member_id',
            targetUserId,
          ) // Target user (who receives notification)
          .eq('related_id', relatedId) // Birthday member
          .eq('scheduled_for', scheduledFor) // Scheduled date
          .limit(1)
          .maybeSingle();

      return existing != null;
    } catch (e) {
      // If error, assume not duplicate to avoid blocking notifications
      return false;
    }
  }

  /// Get notification configuration
  static Future<Map<String, dynamic>> _getNotificationConfig() async {
    try {
      final config = await _client
          .from('app_settings')
          .select()
          .eq('key', 'birthday_notifications')
          .maybeSingle();

      if (config != null) {
        return {'target': config['value']?['target'] ?? 'all'};
      }

      return {'target': 'all'};
    } catch (e) {
      return {'target': 'all'};
    }
  }

  /// Get target user IDs based on configuration
  static Future<List<String>> _getTargetUserIds(String target) async {
    try {
      if (target == 'all') {
        // Get all active members who haven't opted out
        final allMembers = await _client
            .from('members')
            .select('id,user_id')
            .eq('is_active', true)
            .eq('birthday_notifications_opt_out', false);

        return (allMembers as List)
            .map((m) => m['user_id']?.toString() ?? m['id'].toString())
            .where((id) => id != null)
            .toList();
      } else if (target == 'leaders_only') {
        // Get only leaders/admins
        final leaders = await _client
            .from('department_members')
            .select('member_id')
            .inFilter('role', ['leader', 'subleader']);

        final leaderMemberIds = (leaders as List)
            .map((m) => m['member_id'].toString())
            .toSet()
            .toList();

        // Get user IDs for leaders
        if (leaderMemberIds.isEmpty) return [];

        final leaderMembers = await _client
            .from('members')
            .select('id,user_id')
            .inFilter('id', leaderMemberIds)
            .eq('birthday_notifications_opt_out', false);

        return (leaderMembers as List)
            .map((m) => m['user_id']?.toString() ?? m['id'].toString())
            .where((id) => id != null)
            .toList();
      }

      // 'opt_out' means no notifications
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Check if user has opted out
  static Future<bool> _hasUserOptedOut(String userId) async {
    try {
      final member = await _client
          .from('members')
          .select('birthday_notifications_opt_out')
          .eq('user_id', userId)
          .maybeSingle();

      return member?['birthday_notifications_opt_out'] == true;
    } catch (e) {
      return false;
    }
  }
}
