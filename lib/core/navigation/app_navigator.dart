import 'package:flutter/material.dart';

import '../../screens/desktop/desktop_shell.dart';
import '../routes/route_names.dart';

/// Global navigation helpers for contexts without a [BuildContext] (e.g. push taps).
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  /// Set by [DesktopShell] while mounted so push taps can switch sidebar sections.
  static void Function(String route)? desktopNavigateToList;

  static bool _pendingNotificationsNavigation = false;

  static void markPendingNotificationsNavigation() {
    _pendingNotificationsNavigation = true;
  }

  static void consumePendingNotificationsNavigation() {
    if (!_pendingNotificationsNavigation) return;
    _pendingNotificationsNavigation = false;
    navigateToNotifications();
  }

  static void navigateToNotifications() {
    final navigator = rootNavigatorKey.currentState;
    final context = rootNavigatorKey.currentContext;
    if (navigator == null || context == null) {
      markPendingNotificationsNavigation();
      return;
    }

    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

    if (isDesktop) {
      final desktopNav = desktopNavigateToList;
      if (desktopNav != null) {
        desktopNav(RouteNames.desktopNotifications);
        return;
      }

      navigator.pushNamedAndRemoveUntil(
        RouteNames.desktopMain,
        (_) => false,
        arguments: RouteNames.desktopNotifications,
      );
      return;
    }

    navigator.pushNamed(RouteNames.notifications);
  }
}
