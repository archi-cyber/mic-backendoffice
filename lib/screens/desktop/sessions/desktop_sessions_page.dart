import 'package:flutter/material.dart';
import '../../classes/classes_list_page.dart';

/// Sessions: trainings list (open a training to see its sessions).
class DesktopSessionsPage extends StatelessWidget {
  const DesktopSessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClassesListPage(hideAppBarAndBottomNav: true);
  }
}
