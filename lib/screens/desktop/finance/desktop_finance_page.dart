import 'package:flutter/material.dart';
import '../../finance/finance_page.dart';

/// Desktop/Web finance. Uses same [FinancePage] and services.
class DesktopFinancePage extends StatelessWidget {
  DesktopFinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FinancePage(hideAppBarAndBottomNav: true);
  }
}
