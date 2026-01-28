import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import 'home/desktop_home_page.dart';
import 'members/desktop_members_page.dart';
import 'finance/desktop_finance_page.dart';
import 'chat/desktop_chat_page.dart';
import 'settings/desktop_settings_page.dart';
import 'notifications/desktop_notifications_page.dart';
import 'birthdays/desktop_birthdays_page.dart';
import 'events/desktop_events_page.dart';
import 'tasks/desktop_tasks_page.dart';
import 'trainings/desktop_trainings_page.dart';
import 'departments/desktop_departments_page.dart';
import 'reports/desktop_reports_page.dart';
import 'church_attendance/desktop_church_attendance_page.dart';
import 'sunday_school/desktop_sunday_school_page.dart';
import 'visitors/desktop_visitors_page.dart';
import 'teachings/desktop_teachings_page.dart';
import 'sessions/desktop_sessions_page.dart';

/// Minimum width to show desktop layout (sidebar + content).
const double kDesktopBreakpoint = 500;

/// Desktop shell: sidebar + content area. Shown when screen width >= [kDesktopBreakpoint].
/// Uses a nested Navigator for content (home, members, finance, chat, settings, notifications).
class DesktopShell extends StatefulWidget {
  /// Initial nested route (e.g. [RouteNames.desktopHome]).
  final String initialRoute;

  const DesktopShell({super.key, this.initialRoute = RouteNames.desktopHome});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  late final GlobalKey<NavigatorState> _nestedKey;
  String _currentRoute = RouteNames.desktopHome;

  @override
  void initState() {
    super.initState();
    _nestedKey = GlobalKey<NavigatorState>();
    _currentRoute = widget.initialRoute;
  }

  void _onNavigate(String route) {
    setState(() => _currentRoute = route);
    _nestedKey.currentState?.pushReplacementNamed(route);
  }

  bool _isActive(String route) {
    return _currentRoute == route ||
        (route != RouteNames.desktopHome && _currentRoute.startsWith(route));
  }

  String _getTitleForRoute(String route) {
    switch (route) {
      case RouteNames.desktopHome:
        return 'Home';
      case RouteNames.desktopMembers:
        return 'Members';
      case RouteNames.desktopFinance:
        return 'Finance';
      case RouteNames.desktopChat:
        return 'Chat';
      case RouteNames.desktopSettings:
        return 'Settings';
      case RouteNames.desktopNotifications:
        return 'Notifications';
      case RouteNames.desktopBirthdays:
        return 'Birthdays';
      case RouteNames.desktopEvents:
        return 'Events';
      case RouteNames.desktopTasks:
        return 'Tasks';
      case RouteNames.desktopTrainings:
        return 'Trainings';
      case RouteNames.desktopDepartments:
        return 'Departments';
      case RouteNames.desktopReports:
        return 'Reports';
      case RouteNames.desktopChurchAttendance:
        return 'Church Attendance';
      case RouteNames.desktopSundaySchool:
        return 'Sunday School';
      case RouteNames.desktopVisitors:
        return 'Visitors';
      case RouteNames.desktopTeachings:
        return 'Teachings';
      case RouteNames.desktopSessions:
        return 'Sessions';
      default:
        return 'Backoffice';
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      if (!context.mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(RouteNames.desktopLogin, (route) => false);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = SupabaseService.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                right: BorderSide(color: theme.dividerColor, width: 1),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: AppDimensions.spacingLG),
                // Logo / title
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMD,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.church,
                        size: 28,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppDimensions.spacingSM),
                      Text(
                        'Backoffice',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXL),
                const Divider(height: 1),
                // Nav items (scrollable)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NavTile(
                          icon: Icons.dashboard_outlined,
                          activeIcon: Icons.dashboard,
                          label: 'Home',
                          isActive: _isActive(RouteNames.desktopHome),
                          onTap: () => _onNavigate(RouteNames.desktopHome),
                        ),
                        _NavTile(
                          icon: Icons.people_outline,
                          activeIcon: Icons.people,
                          label: 'Members',
                          isActive: _isActive(RouteNames.desktopMembers),
                          onTap: () => _onNavigate(RouteNames.desktopMembers),
                        ),
                        _NavTile(
                          icon: Icons.business_outlined,
                          activeIcon: Icons.business,
                          label: 'Departments',
                          isActive: _isActive(RouteNames.desktopDepartments),
                          onTap: () =>
                              _onNavigate(RouteNames.desktopDepartments),
                        ),
                        _NavTile(
                          icon: Icons.attach_money_outlined,
                          activeIcon: Icons.attach_money,
                          label: 'Finance',
                          isActive: _isActive(RouteNames.desktopFinance),
                          onTap: () => _onNavigate(RouteNames.desktopFinance),
                        ),
                        _NavTile(
                          icon: Icons.chat_bubble_outline,
                          activeIcon: Icons.chat_bubble,
                          label: 'Chat',
                          isActive: _isActive(RouteNames.desktopChat),
                          onTap: () => _onNavigate(RouteNames.desktopChat),
                        ),
                        _NavTile(
                          icon: Icons.settings_outlined,
                          activeIcon: Icons.settings,
                          label: 'Settings',
                          isActive: _isActive(RouteNames.desktopSettings),
                          onTap: () => _onNavigate(RouteNames.desktopSettings),
                        ),
                        _NavTile(
                          icon: Icons.notifications_outlined,
                          activeIcon: Icons.notifications,
                          label: 'Notifications',
                          isActive: _isActive(RouteNames.desktopNotifications),
                          onTap: () =>
                              _onNavigate(RouteNames.desktopNotifications),
                        ),
                        _NavTile(
                          icon: Icons.cake_outlined,
                          activeIcon: Icons.cake,
                          label: 'Birthdays',
                          isActive: _isActive(RouteNames.desktopBirthdays),
                          onTap: () => _onNavigate(RouteNames.desktopBirthdays),
                        ),
                        _NavTile(
                          icon: Icons.event_outlined,
                          activeIcon: Icons.event,
                          label: 'Events',
                          isActive: _isActive(RouteNames.desktopEvents),
                          onTap: () => _onNavigate(RouteNames.desktopEvents),
                        ),
                        _NavTile(
                          icon: Icons.task_alt_outlined,
                          activeIcon: Icons.task_alt,
                          label: 'Tasks',
                          isActive: _isActive(RouteNames.desktopTasks),
                          onTap: () => _onNavigate(RouteNames.desktopTasks),
                        ),
                        _NavTile(
                          icon: Icons.school_outlined,
                          activeIcon: Icons.school,
                          label: 'Trainings',
                          isActive: _isActive(RouteNames.desktopTrainings),
                          onTap: () => _onNavigate(RouteNames.desktopTrainings),
                        ),
                        _NavTile(
                          icon: Icons.assessment_outlined,
                          activeIcon: Icons.assessment,
                          label: 'Reports',
                          isActive: _isActive(RouteNames.desktopReports),
                          onTap: () => _onNavigate(RouteNames.desktopReports),
                        ),
                        _NavTile(
                          icon: Icons.church_outlined,
                          activeIcon: Icons.church,
                          label: 'Church Attendance',
                          isActive: _isActive(
                            RouteNames.desktopChurchAttendance,
                          ),
                          onTap: () =>
                              _onNavigate(RouteNames.desktopChurchAttendance),
                        ),
                        _NavTile(
                          icon: Icons.menu_book_outlined,
                          activeIcon: Icons.menu_book,
                          label: 'Sunday School',
                          isActive: _isActive(RouteNames.desktopSundaySchool),
                          onTap: () =>
                              _onNavigate(RouteNames.desktopSundaySchool),
                        ),
                        _NavTile(
                          icon: Icons.person_add_outlined,
                          activeIcon: Icons.person_add,
                          label: 'Visitors',
                          isActive: _isActive(RouteNames.desktopVisitors),
                          onTap: () => _onNavigate(RouteNames.desktopVisitors),
                        ),
                        _NavTile(
                          icon: Icons.menu_book_outlined,
                          activeIcon: Icons.menu_book,
                          label: 'Teachings',
                          isActive: _isActive(RouteNames.desktopTeachings),
                          onTap: () => _onNavigate(RouteNames.desktopTeachings),
                        ),
                        _NavTile(
                          icon: Icons.event_note_outlined,
                          activeIcon: Icons.event_note,
                          label: 'Sessions',
                          isActive: _isActive(RouteNames.desktopSessions),
                          onTap: () => _onNavigate(RouteNames.desktopSessions),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Current user + logout
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingMD),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          email.isNotEmpty
                              ? email.substring(0, 1).toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSM),
                      Expanded(
                        child: Text(
                          email,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        tooltip: 'Logout',
                        onPressed: () => _handleLogout(context),
                        color: theme.colorScheme.error,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content with page header
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingMD),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _getTitleForRoute(_currentRoute),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Navigator(
                    key: _nestedKey,
                    initialRoute: widget.initialRoute,
                    onGenerateRoute: _desktopOnGenerateRoute,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Route<dynamic>? _desktopOnGenerateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case RouteNames.desktopHome:
        page = const DesktopHomePage();
        break;
      case RouteNames.desktopMembers:
        page = const DesktopMembersPage();
        break;
      case RouteNames.desktopFinance:
        page = const DesktopFinancePage();
        break;
      case RouteNames.desktopChat:
        page = const DesktopChatPage();
        break;
      case RouteNames.desktopSettings:
        page = const DesktopSettingsPage();
        break;
      case RouteNames.desktopNotifications:
        page = const DesktopNotificationsPage();
        break;
      case RouteNames.desktopBirthdays:
        page = const DesktopBirthdaysPage();
        break;
      case RouteNames.desktopEvents:
        page = const DesktopEventsPage();
        break;
      case RouteNames.desktopTasks:
        page = const DesktopTasksPage();
        break;
      case RouteNames.desktopTrainings:
        page = const DesktopTrainingsPage();
        break;
      case RouteNames.desktopDepartments:
        page = const DesktopDepartmentsPage();
        break;
      case RouteNames.desktopReports:
        page = const DesktopReportsPage();
        break;
      case RouteNames.desktopChurchAttendance:
        page = const DesktopChurchAttendancePage();
        break;
      case RouteNames.desktopSundaySchool:
        page = const DesktopSundaySchoolPage();
        break;
      case RouteNames.desktopVisitors:
        page = const DesktopVisitorsPage();
        break;
      case RouteNames.desktopTeachings:
        page = const DesktopTeachingsPage();
        break;
      case RouteNames.desktopSessions:
        page = const DesktopSessionsPage();
        break;
      default:
        page = const DesktopHomePage();
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        isActive ? activeIcon : icon,
        size: 22,
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
      selected: isActive,
      onTap: onTap,
    );
  }
}
