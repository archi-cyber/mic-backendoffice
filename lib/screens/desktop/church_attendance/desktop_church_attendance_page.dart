import 'package:flutter/material.dart';
import '../../attendance/church_attendance_list_page.dart';

class DesktopChurchAttendancePage extends StatelessWidget {
  DesktopChurchAttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChurchAttendanceListPage(hideAppBarAndBottomNav: true);
  }
}
