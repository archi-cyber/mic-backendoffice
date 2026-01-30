import 'package:flutter/material.dart';
import '../../visitors/visitors_list_page.dart';

class DesktopVisitorsPage extends StatelessWidget {
  const DesktopVisitorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VisitorsListPage(hideAppBarAndBottomNav: true);
  }
}
