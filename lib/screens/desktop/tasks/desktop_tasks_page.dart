import 'package:flutter/material.dart';
import '../../tasks/tasks_list_page.dart';

class DesktopTasksPage extends StatelessWidget {
  const DesktopTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TasksListPage(hideAppBarAndBottomNav: true);
  }
}
