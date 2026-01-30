import 'package:flutter/material.dart';
import '../../attendance/church_attendance_list_page.dart';

class DesktopChurchAttendancePage extends StatelessWidget {
  const DesktopChurchAttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChurchAttendanceListPage(hideAppBarAndBottomNav: true);
  }
}
