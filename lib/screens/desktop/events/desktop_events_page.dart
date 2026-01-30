import 'package:flutter/material.dart';
import '../../events/events_list_page.dart';

class DesktopEventsPage extends StatelessWidget {
  const DesktopEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EventsListPage(hideAppBarAndBottomNav: true);
  }
}
