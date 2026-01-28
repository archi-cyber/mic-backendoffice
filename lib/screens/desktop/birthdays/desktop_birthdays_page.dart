import 'package:flutter/material.dart';
import '../../members/upcoming_birthdays_page.dart';

class DesktopBirthdaysPage extends StatelessWidget {
  const DesktopBirthdaysPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const UpcomingBirthdaysPage(hideAppBarAndBottomNav: true);
  }
}
