import 'package:flutter/material.dart';
import '../../settings/settings_page.dart';

/// Desktop/Web settings. Uses same [SettingsPage] and services.
class DesktopSettingsPage extends StatelessWidget {
  DesktopSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPage(hideAppBarAndBottomNav: true);
  }
}
