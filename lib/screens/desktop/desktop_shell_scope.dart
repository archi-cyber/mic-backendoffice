import 'package:flutter/material.dart';

/// Scope provided to desktop content so it can push list/detail without routes.
/// In a separate file to avoid circular imports (dashboard_page -> desktop_shell -> desktop_home_page -> dashboard_page).
class DesktopShellScope extends InheritedWidget {
  final void Function(String route) pushList;
  final void Function(String route, String id) pushDetail;
  final void Function() pop;
  final bool canPop;

  DesktopShellScope({
    super.key,
    required super.child,
    required this.pushList,
    required this.pushDetail,
    required this.pop,
    required this.canPop,
  });

  static DesktopShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DesktopShellScope>();
  }

  @override
  bool updateShouldNotify(DesktopShellScope oldWidget) {
    return pushList != oldWidget.pushList ||
        pushDetail != oldWidget.pushDetail ||
        pop != oldWidget.pop ||
        canPop != oldWidget.canPop;
  }
}
