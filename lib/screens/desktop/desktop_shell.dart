import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../screens/events/event_detail_page.dart';
import '../../screens/events/add_event_page.dart';
import '../../screens/events/edit_event_page.dart';
import '../../screens/teachings/teaching_detail_page.dart';
import '../../screens/teachings/add_teaching_page.dart';
import '../../screens/teachings/edit_teaching_page.dart';
import '../../screens/classes/class_detail_page.dart';
import '../../screens/classes/add_class_page.dart';
import '../../screens/classes/edit_class_page.dart';
import '../../screens/classes/attendance_page.dart';
import '../../screens/attendance/church_attendance_page.dart';
import '../../screens/attendance/sunday_school_attendance_page.dart';
import '../../screens/visitors/add_visitor_page.dart';
import '../../screens/visitors/edit_visitor_page.dart';
import '../../screens/finance/add_giving_page.dart';
import '../../screens/finance/edit_giving_page.dart';
import '../../screens/reports/member_report_page.dart';
import '../../screens/reports/class_report_page.dart';
import '../../screens/members/member_profile_page.dart';
import '../../screens/departments/department_detail_page.dart';
import '../../screens/departments/add_department_page.dart';
import '../../screens/departments/edit_department_page.dart';
import '../../screens/settings/leader_access_page.dart';
import '../../screens/settings/member_accounts_page.dart';
import '../../screens/tasks/task_detail_page.dart';
import '../../screens/tasks/add_task_page.dart';
import '../../screens/tasks/edit_task_page.dart';
import '../../screens/tasks/add_project_page.dart';
import '../../screens/tasks/manage_projects_page.dart';
import '../../screens/tasks/manage_tags_page.dart';
import '../../screens/tasks/tasks_list_page.dart';
import 'desktop_shell_scope.dart';
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

/// Entry in the desktop content stack (list page or detail overlay).
class _DesktopViewEntry {
  final bool isList;
  final String route;
  final String? id;

  const _DesktopViewEntry({required this.isList, required this.route, this.id});
}

/// Desktop shell: sidebar + content area. Shown when screen width >= [kDesktopBreakpoint].
/// Uses a stack of views (no routes); sidebar always visible.
class DesktopShell extends StatefulWidget {
  /// Initial list route (e.g. [RouteNames.desktopHome]).
  final String initialRoute;

  const DesktopShell({super.key, this.initialRoute = RouteNames.desktopHome});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  List<_DesktopViewEntry> _stack = [];
  int _refreshSeed = 0;

  @override
  void initState() {
    super.initState();
    _stack = [
      _DesktopViewEntry(isList: true, route: widget.initialRoute, id: null),
    ];
  }

  void _pushList(String route) {
    setState(() {
      _stack.add(_DesktopViewEntry(isList: true, route: route, id: null));
    });
  }

  void _pushDetail(String route, String id) {
    setState(() {
      _stack.add(_DesktopViewEntry(isList: false, route: route, id: id));
    });
  }

  void _pop() {
    if (_stack.length <= 1) return;
    setState(() {
      _stack.removeLast();
      _refreshSeed++;
    });
  }

  void _navigate(String route) {
    setState(() {
      _stack = [_DesktopViewEntry(isList: true, route: route, id: null)];
    });
  }

  bool _isActive(String route) {
    if (_stack.isEmpty) return false;
    final top = _stack.last;
    return top.route == route ||
        (route != RouteNames.desktopHome && top.route.startsWith(route));
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

  String _getTitleForEntry(_DesktopViewEntry entry) {
    if (entry.isList) return _getTitleForRoute(entry.route);
    // Detail titles
    if (entry.route == RouteNames.eventDetail) return 'Event';
    if (entry.route == RouteNames.addEvent) return 'Add Event';
    if (entry.route == RouteNames.editEvent) return 'Edit Event';
    if (entry.route == RouteNames.teachingDetail) return 'Teaching';
    if (entry.route == RouteNames.classDetail) return 'Training';
    if (entry.route == RouteNames.memberDetail) return 'Member';
    if (entry.route == RouteNames.departmentDetail) return 'Department';
    if (entry.route == RouteNames.addDepartment) return 'Add Department';
    if (entry.route == RouteNames.editDepartment) return 'Edit Department';
    if (entry.route == RouteNames.leaderAccess) return 'Leader Access';
    if (entry.route == RouteNames.memberAccounts) return 'Member Accounts';
    if (entry.route == RouteNames.addTeaching) return 'Add Teaching';
    if (entry.route == RouteNames.editTeaching) return 'Edit Teaching';
    if (entry.route == RouteNames.taskDetail) return 'Task';
    if (entry.route == RouteNames.addTask) return 'Add Task';
    if (entry.route == RouteNames.editTask) return 'Edit Task';
    if (entry.route == RouteNames.addProject) return 'Add Project';
    if (entry.route == RouteNames.tasks && (entry.id ?? '').isNotEmpty) {
      return 'Manage Tasks';
    }
    if (entry.route == RouteNames.addClass) return 'Add Training';
    if (entry.route == RouteNames.editClass) return 'Edit Training';
    if (entry.route == RouteNames.churchAttendance) return 'Church Attendance';
    if (entry.route == RouteNames.sundaySchoolAttendance) {
      return 'Sunday School';
    }
    if (entry.route == RouteNames.addVisitor) return 'Add Visitor';
    if (entry.route == RouteNames.editVisitor) return 'Edit Visitor';
    if (entry.route == RouteNames.addGiving) return 'Add Giving Record';
    if (entry.route == RouteNames.editGiving) return 'Edit Giving Record';
    if (entry.route == RouteNames.memberReport) return 'Member Report';
    if (entry.route == RouteNames.classReport) return 'Training Report';
    if (entry.route == RouteNames.takeAttendance) return 'Take Attendance';
    if (entry.route == RouteNames.manageProjects) return 'Manage Projects';
    if (entry.route == RouteNames.manageTags) return 'Manage Tags';
    return 'Details';
  }

  Widget _buildListPage(String route) {
    switch (route) {
      case RouteNames.desktopHome:
        return const DesktopHomePage();
      case RouteNames.desktopMembers:
        return const DesktopMembersPage();
      case RouteNames.desktopFinance:
        return const DesktopFinancePage();
      case RouteNames.desktopChat:
        return const DesktopChatPage();
      case RouteNames.desktopSettings:
        return const DesktopSettingsPage();
      case RouteNames.desktopNotifications:
        return const DesktopNotificationsPage();
      case RouteNames.desktopBirthdays:
        return const DesktopBirthdaysPage();
      case RouteNames.desktopEvents:
        return const DesktopEventsPage();
      case RouteNames.desktopTasks:
        return const DesktopTasksPage();
      case RouteNames.desktopTrainings:
        return const DesktopTrainingsPage();
      case RouteNames.desktopDepartments:
        return const DesktopDepartmentsPage();
      case RouteNames.desktopReports:
        return const DesktopReportsPage();
      case RouteNames.desktopChurchAttendance:
        return const DesktopChurchAttendancePage();
      case RouteNames.desktopSundaySchool:
        return const DesktopSundaySchoolPage();
      case RouteNames.desktopVisitors:
        return const DesktopVisitorsPage();
      case RouteNames.desktopTeachings:
        return const DesktopTeachingsPage();
      case RouteNames.desktopSessions:
        return const DesktopSessionsPage();
      default:
        return const DesktopHomePage();
    }
  }

  Widget _buildDetailPage(_DesktopViewEntry entry) {
    final id = entry.id ?? '';
    final onClose = _pop;
    if (entry.route == RouteNames.eventDetail && id.isNotEmpty) {
      return EventDetailPage(eventId: id, onClose: onClose);
    }
    if (entry.route == RouteNames.addEvent) {
      return AddEventPage(onClose: (_) => onClose());
    }
    if (entry.route == RouteNames.editEvent && id.isNotEmpty) {
      return EditEventPage(eventId: id, onClose: (_) => onClose());
    }
    if (entry.route == RouteNames.teachingDetail) {
      return TeachingDetailPage(teachingId: id, onClose: onClose);
    }
    if (entry.route == RouteNames.classDetail) {
      return ClassDetailPage(classId: id, onClose: onClose);
    }
    if (entry.route == RouteNames.memberDetail) {
      return MemberProfilePage(memberId: id, onClose: (_) => onClose());
    }
    if (entry.route == RouteNames.departmentDetail && id.isNotEmpty) {
      return DepartmentDetailPage(departmentId: id, onClose: () => onClose());
    }
    if (entry.route == RouteNames.addDepartment) {
      return AddDepartmentPage(onClose: (_) => onClose());
    }
    if (entry.route == RouteNames.editDepartment && id.isNotEmpty) {
      return EditDepartmentPage(departmentId: id, onClose: (_) => onClose());
    }
    if (entry.route == RouteNames.leaderAccess) {
      return LeaderAccessPage(onClose: onClose);
    }
    if (entry.route == RouteNames.memberAccounts) {
      return MemberAccountsPage(onClose: onClose);
    }
    if (entry.route == RouteNames.addTeaching) {
      return AddTeachingPage(onClose: (_) => onClose());
    }
    if (entry.route == RouteNames.editTeaching && id.isNotEmpty) {
      return EditTeachingPage(teachingId: id, onClose: (_) => onClose());
    }
    if (entry.route == RouteNames.taskDetail && id.isNotEmpty) {
      return TaskDetailPage(taskId: id, onClose: onClose);
    }
    if (entry.route == RouteNames.addTask) {
      return AddTaskPage(
        departmentId: id.isEmpty ? null : id,
        onClose: (_) => onClose(),
      );
    }
    if (entry.route == RouteNames.addProject) {
      return AddProjectPage(
        departmentId: id.isEmpty ? null : id,
        onClose: (_) => onClose(),
      );
    }
    if (entry.route == RouteNames.editTask && id.isNotEmpty) {
      return EditTaskPage(taskId: id, onClose: (_) => onClose());
    }
    if (entry.route == RouteNames.addClass) {
      return AddClassPage(onClose: (_) => onClose());
    }
    if (entry.route == RouteNames.editClass && id.isNotEmpty) {
      return EditClassPage(classId: id, onClose: (_) => onClose());
    }
    if (entry.route == RouteNames.churchAttendance) {
      final serviceDate = id.contains('|') ? id.split('|').first : null;
      final serviceType = id.contains('|') && id.split('|').length > 1
          ? id.split('|')[1]
          : null;
      return ChurchAttendancePage(
        serviceDate: serviceDate,
        serviceType: serviceType,
        onClose: onClose,
      );
    }
    if (entry.route == RouteNames.sundaySchoolAttendance) {
      return SundaySchoolAttendancePage(
        sessionDate: id.isNotEmpty ? id : null,
        onClose: onClose,
      );
    }
    if (entry.route == RouteNames.addVisitor) {
      return AddVisitorPage(onClose: (_) => onClose());
    }
    if (entry.route == RouteNames.editVisitor && id.isNotEmpty) {
      return EditVisitorPage(visitorId: id, onClose: (_) => onClose());
    }
    if (entry.route == RouteNames.addGiving) {
      return AddGivingPage(onClose: ([_]) => onClose());
    }
    if (entry.route == RouteNames.editGiving && id.isNotEmpty) {
      return EditGivingPage(givingId: id, onClose: ([_]) => onClose());
    }
    if (entry.route == RouteNames.memberReport && id.isNotEmpty) {
      return MemberReportPage(memberId: id, onClose: onClose);
    }
    if (entry.route == RouteNames.classReport && id.isNotEmpty) {
      return ClassReportPage(classId: id, onClose: onClose);
    }
    if (entry.route == RouteNames.takeAttendance && id.isNotEmpty) {
      return AttendancePage(sessionId: id, members: null, onClose: onClose);
    }
    if (entry.route == RouteNames.manageProjects) {
      return ManageProjectsPage(
        departmentId: id.isEmpty ? null : id,
        onClose: (_) => onClose(),
      );
    }
    if (entry.route == RouteNames.manageTags) {
      return ManageTagsPage(
        departmentId: id.isEmpty ? null : id,
        onClose: (_) => onClose(),
      );
    }
    if (entry.route == RouteNames.tasks && id.isNotEmpty) {
      return TasksListPage(
        departmentId: id,
        hideAppBarAndBottomNav: true,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildContent(_DesktopViewEntry entry) {
    if (entry.isList) return _buildListPage(entry.route);
    return _buildDetailPage(entry);
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
                          onTap: () => _navigate(RouteNames.desktopHome),
                        ),
                        _NavTile(
                          icon: Icons.people_outline,
                          activeIcon: Icons.people,
                          label: 'Members',
                          isActive: _isActive(RouteNames.desktopMembers),
                          onTap: () => _navigate(RouteNames.desktopMembers),
                        ),
                        _NavTile(
                          icon: Icons.business_outlined,
                          activeIcon: Icons.business,
                          label: 'Departments',
                          isActive: _isActive(RouteNames.desktopDepartments),
                          onTap: () => _navigate(RouteNames.desktopDepartments),
                        ),
                        _NavTile(
                          icon: Icons.attach_money_outlined,
                          activeIcon: Icons.attach_money,
                          label: 'Finance',
                          isActive: _isActive(RouteNames.desktopFinance),
                          onTap: () => _navigate(RouteNames.desktopFinance),
                        ),
                        _NavTile(
                          icon: Icons.chat_bubble_outline,
                          activeIcon: Icons.chat_bubble,
                          label: 'Chat',
                          isActive: _isActive(RouteNames.desktopChat),
                          onTap: () => _navigate(RouteNames.desktopChat),
                        ),
                        _NavTile(
                          icon: Icons.settings_outlined,
                          activeIcon: Icons.settings,
                          label: 'Settings',
                          isActive: _isActive(RouteNames.desktopSettings),
                          onTap: () => _navigate(RouteNames.desktopSettings),
                        ),
                        _NavTile(
                          icon: Icons.notifications_outlined,
                          activeIcon: Icons.notifications,
                          label: 'Notifications',
                          isActive: _isActive(RouteNames.desktopNotifications),
                          onTap: () =>
                              _navigate(RouteNames.desktopNotifications),
                        ),
                        _NavTile(
                          icon: Icons.cake_outlined,
                          activeIcon: Icons.cake,
                          label: 'Birthdays',
                          isActive: _isActive(RouteNames.desktopBirthdays),
                          onTap: () => _navigate(RouteNames.desktopBirthdays),
                        ),
                        _NavTile(
                          icon: Icons.event_outlined,
                          activeIcon: Icons.event,
                          label: 'Events',
                          isActive: _isActive(RouteNames.desktopEvents),
                          onTap: () => _navigate(RouteNames.desktopEvents),
                        ),
                        _NavTile(
                          icon: Icons.task_alt_outlined,
                          activeIcon: Icons.task_alt,
                          label: 'Tasks',
                          isActive: _isActive(RouteNames.desktopTasks),
                          onTap: () => _navigate(RouteNames.desktopTasks),
                        ),
                        _NavTile(
                          icon: Icons.school_outlined,
                          activeIcon: Icons.school,
                          label: 'Trainings',
                          isActive: _isActive(RouteNames.desktopTrainings),
                          onTap: () => _navigate(RouteNames.desktopTrainings),
                        ),
                        _NavTile(
                          icon: Icons.assessment_outlined,
                          activeIcon: Icons.assessment,
                          label: 'Reports',
                          isActive: _isActive(RouteNames.desktopReports),
                          onTap: () => _navigate(RouteNames.desktopReports),
                        ),
                        _NavTile(
                          icon: Icons.church_outlined,
                          activeIcon: Icons.church,
                          label: 'Church Attendance',
                          isActive: _isActive(
                            RouteNames.desktopChurchAttendance,
                          ),
                          onTap: () =>
                              _navigate(RouteNames.desktopChurchAttendance),
                        ),
                        _NavTile(
                          icon: Icons.menu_book_outlined,
                          activeIcon: Icons.menu_book,
                          label: 'Sunday School',
                          isActive: _isActive(RouteNames.desktopSundaySchool),
                          onTap: () =>
                              _navigate(RouteNames.desktopSundaySchool),
                        ),
                        _NavTile(
                          icon: Icons.person_add_outlined,
                          activeIcon: Icons.person_add,
                          label: 'Visitors',
                          isActive: _isActive(RouteNames.desktopVisitors),
                          onTap: () => _navigate(RouteNames.desktopVisitors),
                        ),
                        _NavTile(
                          icon: Icons.menu_book_outlined,
                          activeIcon: Icons.menu_book,
                          label: 'Teachings',
                          isActive: _isActive(RouteNames.desktopTeachings),
                          onTap: () => _navigate(RouteNames.desktopTeachings),
                        ),
                        _NavTile(
                          icon: Icons.event_note_outlined,
                          activeIcon: Icons.event_note,
                          label: 'Sessions',
                          isActive: _isActive(RouteNames.desktopSessions),
                          onTap: () => _navigate(RouteNames.desktopSessions),
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
          // Content with page header (stack-based; sidebar always visible)
          Expanded(
            child: DesktopShellScope(
              pushList: _pushList,
              pushDetail: _pushDetail,
              pop: _pop,
              canPop: _stack.length > 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingMD),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        if (_stack.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppDimensions.spacingMD,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: _pop,
                              tooltip: 'Back',
                            ),
                          ),
                        Expanded(
                          child: Text(
                            _stack.isNotEmpty
                                ? _getTitleForEntry(_stack.last)
                                : 'Backoffice',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _stack.isEmpty
                        ? const SizedBox.shrink()
                        : KeyedSubtree(
                            key: ValueKey<String>(
                              '${_stack.last.route}_${_stack.last.id}_$_refreshSeed',
                            ),
                            child: _buildContent(_stack.last),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
