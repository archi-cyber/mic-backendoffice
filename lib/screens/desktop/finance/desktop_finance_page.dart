import 'package:flutter/material.dart';
import '../../finance/finance_page.dart';

/// Desktop/Web finance. Uses same [FinancePage] and services.
class DesktopFinancePage extends StatelessWidget {
  const DesktopFinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FinancePage(hideAppBarAndBottomNav: true);
  }
}
