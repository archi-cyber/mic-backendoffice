import 'package:flutter/material.dart';
import '../../notifications/notifications_list_page.dart';

/// Desktop/Web notifications. Uses same [NotificationsListPage] and services.
class DesktopNotificationsPage extends StatelessWidget {
  DesktopNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return NotificationsListPage(hideAppBarAndBottomNav: true);
  }
}
