import 'package:flutter/material.dart';
import '../../members/members_list_page.dart';

/// Desktop/Web members. Uses same [MembersListPage] and services.
class DesktopMembersPage extends StatelessWidget {
  DesktopMembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MembersListPage(hideAppBarAndBottomNav: true);
  }
}
