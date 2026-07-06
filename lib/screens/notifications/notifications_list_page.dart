import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../core/localization/app_localizations.dart';
import '../desktop/desktop_shell_scope.dart';

/// Notifications list page
class NotificationsListPage extends StatefulWidget {
  /// When true (e.g. desktop layout), no app bar is shown.
  final bool hideAppBarAndBottomNav;

  NotificationsListPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<NotificationsListPage> createState() => _NotificationsListPageState();
}

class _NotificationsListPageState extends State<NotificationsListPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _memberId;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMemberId();
  }

  Future<void> _loadMemberId() async {
    try {
      debugPrint('[Notifications] Starting to load member ID...');
      final currentUserId = SupabaseService.currentUser?.id;
      debugPrint('[Notifications] Current user ID: $currentUserId');

      if (currentUserId == null) {
        debugPrint('[Notifications] ERROR: No current user ID found');
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('Error: Not authenticated. Please login again.'),
              ),
            ),
          );
        }
        return;
      }

      // Query users table to get member_id and role
      debugPrint(
        '[Notifications] Querying users table for member_id and role...',
      );
      final user = await SupabaseService.client
          .from('users')
          .select('member_id, role, email')
          .eq('id', currentUserId)
          .maybeSingle();

      debugPrint('[Notifications] User query result: $user');

      if (user == null) {
        debugPrint('[Notifications] ERROR: User not found in users table');
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: User profile not found. Please contact support.',
              ),
            ),
          );
        }
        return;
      }

      final memberId = user['member_id']?.toString();
      final userRole = user['role']?.toString();
      final userEmail = user['email']?.toString();

      debugPrint('[Notifications] User role: $userRole');
      debugPrint('[Notifications] User email: $userEmail');
      debugPrint('[Notifications] Member ID: $memberId');

      if (memberId != null) {
        debugPrint('[Notifications] Found member_id: $memberId');
        setState(() {
          _memberId = memberId;
        });
        await _loadNotifications();
      } else {
        // User doesn't have a member_id - might be an admin or system user
        debugPrint(
          '[Notifications] WARNING: No member_id found for user. Role: $userRole',
        );

        // Try to load notifications without member_id (for admins/system users)
        // Some notifications might be system-wide or user-based
        debugPrint(
          '[Notifications] Attempting to load notifications without member_id...',
        );

        // Set memberId to null but still try to load
        // The NotificationService should handle this case
        setState(() {
          _memberId = null; // Explicitly set to null
        });

        // Try loading notifications - the service might handle user-based queries
        try {
          await _loadNotificationsForUserWithoutMember();
        } catch (e) {
          debugPrint(
            '[Notifications] Failed to load notifications without member_id: $e',
          );
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No notifications available. '
                  'This account is not linked to a member profile. '
                  'Role: ${userRole ?? 'Unknown'}',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[Notifications] ERROR in _loadMemberId: $e');
      debugPrint('[Notifications] Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading notifications: $e')),
          ),
        );
      }
    }
  }

  /// Load notifications for users without member_id (admins/system users)
  Future<void> _loadNotificationsForUserWithoutMember() async {
    debugPrint(
      '[Notifications] Loading notifications for user without member_id...',
    );
    setState(() => _isLoading = true);

    try {
      // Try to query notifications table directly by user_id if the table supports it
      // Or show empty list if no member_id means no notifications
      final currentUserId = SupabaseService.currentUser?.id;
      debugPrint('[Notifications] Current user ID: $currentUserId');

      // Check if notifications table has a user_id column or if we can query all
      // For now, we'll show an empty list with a helpful message
      debugPrint(
        '[Notifications] No member_id available, showing empty notifications list',
      );

      setState(() {
        _notifications = [];
        _unreadCount = 0;
        _isLoading = false;
      });

      debugPrint(
        '[Notifications] Set empty notifications list for user without member_id',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[Notifications] ERROR in _loadNotificationsForUserWithoutMember: $e',
      );
      debugPrint('[Notifications] Stack trace: $stackTrace');
      setState(() {
        _notifications = [];
        _unreadCount = 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotifications() async {
    debugPrint(
      '[Notifications] _loadNotifications called with memberId: $_memberId',
    );

    if (_memberId == null) {
      debugPrint(
        '[Notifications] ERROR: memberId is null, cannot load notifications',
      );
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Error: Member ID not found. Please try again.'),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      debugPrint('[Notifications] Fetching notifications and unread count...');
      final results = await Future.wait([
        NotificationService.getNotifications(memberId: _memberId),
        NotificationService.getUnreadCount(memberId: _memberId),
      ]);

      final notifications = results[0] as List<Map<String, dynamic>>;
      final unreadCount = results[1] as int;

      debugPrint(
        '[Notifications] Successfully loaded ${notifications.length} notifications',
      );
      debugPrint('[Notifications] Unread count: $unreadCount');

      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
        _isLoading = false;
      });

      debugPrint('[Notifications] State updated successfully');
    } catch (e, stackTrace) {
      debugPrint('[Notifications] ERROR in _loadNotifications: $e');
      debugPrint('[Notifications] Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading notifications: $e')),
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await NotificationService.markAsRead(notificationId);
      _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error marking notification as read: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await NotificationService.markAllAsRead(memberId: _memberId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('All notifications marked as read')),
            backgroundColor: AppColors.success,
          ),
        );
        _loadNotifications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error marking all as read: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await NotificationService.deleteNotification(notificationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Notification deleted')),
            backgroundColor: AppColors.success,
          ),
        );
        _loadNotifications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error deleting notification: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Mark as read if unread
    if (notification['is_read'] != true) {
      _markAsRead(notification['id'].toString());
    }

    // Navigate based on related_type
    final relatedType = notification['related_type']?.toString();
    final relatedId = notification['related_id']?.toString();

    if (relatedType == null || relatedId == null) return;

    switch (relatedType) {
      case 'task':
        _openNotificationTarget(RouteNames.taskDetail, relatedId);
        break;
      case 'announcement':
        _openNotificationListTarget(RouteNames.desktopChat, RouteNames.chat);
        break;
      case 'event':
        _openNotificationTarget(RouteNames.eventDetail, relatedId);
        break;
      case 'member':
        _openNotificationTarget(RouteNames.memberDetail, relatedId);
        break;
    }
  }

  void _openNotificationTarget(String route, String relatedId) {
    final shell = DesktopShellScope.maybeOf(context);
    if (shell != null) {
      shell.pushDetail(route, relatedId);
      return;
    }

    Navigator.of(context).pushNamed(route.replaceAll(':id', relatedId));
  }

  void _openNotificationListTarget(String desktopRoute, String mobileRoute) {
    final shell = DesktopShellScope.maybeOf(context);
    if (shell != null) {
      shell.pushList(desktopRoute);
      return;
    }

    Navigator.of(context).pushNamed(mobileRoute);
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'task_assigned':
      case 'task_reminder':
        return Icons.assignment;
      case 'birthday':
        return Icons.cake;
      case 'announcement':
        return Icons.campaign;
      case 'event':
        return Icons.event;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'task_assigned':
      case 'task_reminder':
        return AppColors.warning;
      case 'birthday':
        return Colors.pink;
      case 'announcement':
        return AppColors.primary;
      case 'event':
        return AppColors.info;
      default:
        return context.mic.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(context.tr('Notifications')),
              actions: [
                if (_unreadCount > 0)
                  TextButton.icon(
                    onPressed: _markAllAsRead,
                    icon: Icon(Icons.done_all),
                    label: Text(context.tr('Mark all read')),
                  ),
              ],
            ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: context.mic.textSecondary,
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  Text(context.tr('No notifications')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final isRead = notification['is_read'] == true;
                  final type = notification['type']?.toString();
                  final createdAt = notification['created_at'] != null
                      ? DateTime.parse(notification['created_at'])
                      : null;

                  return Dismissible(
                    key: Key(notification['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: AppDimensions.paddingMD),
                      color: AppColors.error,
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) =>
                        _deleteNotification(notification['id'].toString()),
                    child: InkWell(
                      onTap: () => _handleNotificationTap(notification),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isRead
                              ? null
                              : AppColors.primary.withValues(alpha: 0.05),
                          border: Border(
                            left: BorderSide(
                              color: _getNotificationColor(type),
                              width: 4,
                            ),
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getNotificationColor(
                              type,
                            ).withValues(alpha: 0.1),
                            child: Icon(
                              _getNotificationIcon(type),
                              color: _getNotificationColor(type),
                            ),
                          ),
                          title: Text(
                            notification['title'] ?? 'Notification',
                            style: TextStyle(
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text(
                                notification['message'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (createdAt != null) ...[
                                SizedBox(height: 4),
                                Text(
                                  _formatDate(createdAt),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: context.mic.textSecondary,
                                      ),
                                ),
                              ],
                            ],
                          ),
                          trailing: isRead
                              ? null
                              : Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: AppColors.primary,
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
