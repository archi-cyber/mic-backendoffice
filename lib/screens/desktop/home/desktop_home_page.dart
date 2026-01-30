import 'package:flutter/material.dart';
import '../../home/dashboard_page.dart';

/// Desktop/Web home. Uses same [DashboardPage] and services.
class DesktopHomePage extends StatelessWidget {
  const DesktopHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardPage(hideAppBarAndBottomNav: true);
  }
}
