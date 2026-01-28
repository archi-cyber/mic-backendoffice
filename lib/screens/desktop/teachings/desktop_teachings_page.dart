import 'package:flutter/material.dart';
import '../../teachings/teachings_list_page.dart';

class DesktopTeachingsPage extends StatelessWidget {
  const DesktopTeachingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TeachingsListPage(hideAppBarAndBottomNav: true);
  }
}
