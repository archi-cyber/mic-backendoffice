import 'package:flutter/material.dart';
import '../../departments/departments_list_page.dart';

class DesktopDepartmentsPage extends StatelessWidget {
  DesktopDepartmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DepartmentsListPage(hideAppBarAndBottomNav: true);
  }
}
