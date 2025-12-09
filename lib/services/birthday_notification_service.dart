import 'supabase_service.dart';

/// Service for birthday notifications with configuration options
class BirthdayNotificationService {
  static final _client = SupabaseService.client;

  /// Get birthday notification configuration
  static Future<Map<String, dynamic>> getNotificationConfig() async {
    try {
      // Try to get from settings table, or return defaults
      final config = await _client
          .from('app_settings')
          .select()
          .eq('key', 'birthday_notifications')
          .maybeSingle();

      if (config != null) {
        return {
          'target': config['value']?['target'] ?? 'all',
          // 'all', 'leaders_only', or 'opt_out'
        };
      }

      // Default: all church app users
      return {'target': 'all'};
    } catch (e) {
      // Return default if settings table doesn't exist
      return {'target': 'all'};
    }
  }

  /// Update birthday notification configuration
  static Future<void> updateNotificationConfig({
    required String target, // 'all', 'leaders_only', or 'opt_out'
  }) async {
    try {
      await _client.from('app_settings').upsert({
        'key': 'birthday_notifications',
        'value': {'target': target},
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update notification config: $e');
    }
  }

  /// Get members with birthdays in the current month
  static Future<List<Map<String, dynamic>>> getBirthdayMembers({
    int? month, // If null, uses current month
  }) async {
    try {
      final targetMonth = month ?? DateTime.now().month;
      final startDate = DateTime(DateTime.now().year, targetMonth, 1);
      final endDate = DateTime(DateTime.now().year, targetMonth + 1, 0);

      final members = await _client
          .from('members')
          .select()
          .gte('birthday', startDate.toIso8601String())
          .lte('birthday', endDate.toIso8601String())
          .eq('is_active', true);

      return List<Map<String, dynamic>>.from(members);
    } catch (e) {
      throw Exception('Failed to get birthday members: $e');
    }
  }

  /// Send birthday notifications based on configuration
  static Future<void> sendBirthdayNotifications() async {
    try {
      final config = await getNotificationConfig();
      final target = config['target'] as String;

      final birthdayMembers = await getBirthdayMembers();

      List<String> targetMemberIds = [];

      if (target == 'all') {
        // Get all active members who haven't opted out
        final allMembers = await _client
            .from('members')
            .select('id')
            .eq('is_active', true)
            .eq('birthday_notifications_opt_out', false);

        targetMemberIds = (allMembers as List)
            .map((m) => m['id'].toString())
            .toList();
      } else if (target == 'leaders_only') {
        // Get only leaders/admins
        final leaders = await _client
            .from('department_members')
            .select('member_id')
            .inFilter('role', ['leader', 'subleader']);

        targetMemberIds = (leaders as List)
            .map((m) => m['member_id'].toString())
            .toSet()
            .toList();
      }
      // 'opt_out' means no notifications sent

      // Create notifications for target members
      if (targetMemberIds.isNotEmpty && birthdayMembers.isNotEmpty) {
        final notifications = <Map<String, dynamic>>[];

        for (final birthdayMember in birthdayMembers) {
          final memberId = birthdayMember['id'].toString();
          if (targetMemberIds.contains(memberId)) {
            notifications.add({
              'member_id': memberId,
              'type': 'birthday',
              'title': 'Birthday Alert',
              'message':
                  '${birthdayMember['first_name']} ${birthdayMember['last_name']} has a birthday this month!',
              'related_id': memberId,
              'related_type': 'member',
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }

        if (notifications.isNotEmpty) {
          await _client.from('notifications').insert(notifications);
        }
      }
    } catch (e) {
      throw Exception('Failed to send birthday notifications: $e');
    }
  }

  /// Opt out a user from birthday notifications
  static Future<void> optOutUser(String memberId) async {
    try {
      await _client
          .from('members')
          .update({
            'birthday_notifications_opt_out': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', memberId);
    } catch (e) {
      throw Exception('Failed to opt out user: $e');
    }
  }

  /// Opt in a user to birthday notifications
  static Future<void> optInUser(String memberId) async {
    try {
      await _client
          .from('members')
          .update({
            'birthday_notifications_opt_out': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', memberId);
    } catch (e) {
      throw Exception('Failed to opt in user: $e');
    }
  }
}
