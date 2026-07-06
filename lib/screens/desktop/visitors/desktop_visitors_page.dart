import 'package:flutter/material.dart';
import '../../visitors/visitors_list_page.dart';

class DesktopVisitorsPage extends StatelessWidget {
  DesktopVisitorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return VisitorsListPage(hideAppBarAndBottomNav: true);
  }
}
