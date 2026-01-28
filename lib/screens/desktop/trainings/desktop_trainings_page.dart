import 'package:flutter/material.dart';
import '../../classes/classes_list_page.dart';

class DesktopTrainingsPage extends StatelessWidget {
  const DesktopTrainingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClassesListPage(hideAppBarAndBottomNav: true);
  }
}
