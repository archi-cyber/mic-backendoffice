import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';

/// Notifications list page
class NotificationsListPage extends StatefulWidget {
  const NotificationsListPage({super.key});

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
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId != null) {
        final member = await SupabaseService.client
            .from('members')
            .select('id')
            .eq('user_id', currentUserId)
            .maybeSingle();
        if (member != null) {
          setState(() => _memberId = member['id'].toString());
          _loadNotifications();
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
    }
  }

  Future<void> _loadNotifications() async {
    if (_memberId == null) return;

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        NotificationService.getNotifications(memberId: _memberId),
        NotificationService.getUnreadCount(memberId: _memberId),
      ]);

      setState(() {
        _notifications = results[0] as List<Map<String, dynamic>>;
        _unreadCount = results[1] as int;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
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
            content: Text('Error marking notification as read: $e'),
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
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadNotifications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking all as read: $e'),
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
          const SnackBar(
            content: Text('Notification deleted'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadNotifications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting notification: $e'),
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
        Navigator.of(
          context,
        ).pushNamed(RouteNames.taskDetail.replaceAll(':id', relatedId));
        break;
      case 'announcement':
        // Navigate to announcements/chat page
        Navigator.of(context).pushNamed(RouteNames.chat);
        break;
      case 'event':
        Navigator.of(
          context,
        ).pushNamed(RouteNames.eventDetail.replaceAll(':id', relatedId));
        break;
      case 'member':
        Navigator.of(
          context,
        ).pushNamed(RouteNames.memberDetail.replaceAll(':id', relatedId));
        break;
    }
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
        return Colors.blue;
      default:
        return AppColors.textSecondary;
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
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all),
              label: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),
                  const Text('No notifications'),
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
                      padding: const EdgeInsets.only(
                        right: AppDimensions.paddingMD,
                      ),
                      color: AppColors.error,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) =>
                        _deleteNotification(notification['id'].toString()),
                    child: InkWell(
                      onTap: () => _handleNotificationTap(notification),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isRead
                              ? null
                              : AppColors.primary.withOpacity(0.05),
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
                            ).withOpacity(0.1),
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
                              const SizedBox(height: 4),
                              Text(
                                notification['message'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (createdAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(createdAt),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ],
                          ),
                          trailing: isRead
                              ? null
                              : const Icon(
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
