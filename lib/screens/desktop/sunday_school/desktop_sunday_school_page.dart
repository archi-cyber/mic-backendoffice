import 'package:flutter/material.dart';
import '../../attendance/sunday_school_attendance_list_page.dart';

class DesktopSundaySchoolPage extends StatelessWidget {
  DesktopSundaySchoolPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SundaySchoolAttendanceListPage(hideAppBarAndBottomNav: true);
  }
}
