import 'package:flutter/material.dart';
import '../../reports/reports_page.dart';

class DesktopReportsPage extends StatelessWidget {
  const DesktopReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReportsPage(hideAppBarAndBottomNav: true);
  }
}
