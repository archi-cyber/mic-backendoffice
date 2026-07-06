import 'package:flutter/material.dart';
import '../../classes/classes_list_page.dart';

class DesktopTrainingsPage extends StatelessWidget {
  DesktopTrainingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ClassesListPage(hideAppBarAndBottomNav: true);
  }
}
