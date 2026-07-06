import 'package:flutter/material.dart';
import '../../reports/reports_page.dart';

class DesktopReportsPage extends StatelessWidget {
  DesktopReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ReportsPage(hideAppBarAndBottomNav: true);
  }
}
