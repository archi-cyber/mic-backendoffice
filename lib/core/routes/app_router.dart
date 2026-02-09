import 'package:flutter/material.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/login_page.dart';
import '../../screens/auth/forgot_password_page.dart';
import '../../screens/auth/reset_password_page.dart';
import '../../screens/auth/change_password_page.dart';
import '../../screens/home/dashboard_page.dart';
import '../../screens/members/members_list_page.dart';
import '../../screens/members/member_profile_page.dart';
import '../../screens/members/add_member_page.dart';
import '../../screens/members/edit_member_page.dart';
import '../../screens/members/upcoming_birthdays_page.dart';
import '../../screens/departments/departments_list_page.dart';
import '../../screens/departments/department_detail_page.dart';
import '../../screens/departments/add_department_page.dart';
import '../../screens/departments/edit_department_page.dart';
import '../../screens/departments/department_reports_list_page.dart';
import '../../screens/departments/add_department_report_page.dart';
import '../../screens/departments/edit_department_report_page.dart';
import '../../screens/events/events_list_page.dart';
import '../../screens/events/event_detail_page.dart';
import '../../screens/events/add_event_page.dart';
import '../../screens/events/edit_event_page.dart';
import '../../screens/tasks/tasks_list_page.dart';
import '../../screens/tasks/task_detail_page.dart';
import '../../screens/tasks/add_task_page.dart';
import '../../screens/tasks/edit_task_page.dart';
import '../../screens/tasks/add_project_page.dart';
import '../../screens/tasks/edit_project_page.dart';
import '../../screens/tasks/manage_projects_page.dart';
import '../../screens/tasks/manage_tags_page.dart';
import '../../screens/classes/classes_list_page.dart';
import '../../screens/classes/class_detail_page.dart';
import '../../screens/classes/add_class_page.dart';
import '../../screens/classes/edit_class_page.dart';
import '../../screens/reports/reports_page.dart';
import '../../screens/reports/member_report_page.dart';
import '../../screens/reports/class_report_page.dart';
import '../../screens/chat/chat_page.dart';
import '../../screens/admin/admin_panel_page.dart';
import '../../screens/notifications/notifications_list_page.dart';
import '../../screens/settings/birthday_notifications_settings_page.dart';
import '../../screens/settings/settings_page.dart';
import '../../screens/settings/leader_access_page.dart';
import '../../screens/settings/member_accounts_page.dart';
import '../../screens/finance/finance_page.dart';
import '../../screens/finance/add_giving_page.dart';
import '../../screens/finance/edit_giving_page.dart';
import '../../screens/attendance/church_attendance_page.dart';
import '../../screens/attendance/church_attendance_list_page.dart';
import '../../screens/attendance/sunday_school_attendance_page.dart';
import '../../screens/attendance/sunday_school_attendance_list_page.dart';
import '../../screens/visitors/visitors_list_page.dart';
import '../../screens/visitors/add_visitor_page.dart';
import '../../screens/visitors/edit_visitor_page.dart';
import '../../screens/teachings/teachings_list_page.dart';
import '../../screens/teachings/add_teaching_page.dart';
import '../../screens/teachings/edit_teaching_page.dart';
import '../../screens/teachings/teaching_detail_page.dart';
import '../../screens/common/file_viewer_page.dart';
import '../../screens/desktop/desktop_shell.dart';
import '../../screens/desktop/auth/desktop_login_page.dart';
import '../../screens/desktop/auth/desktop_signup_page.dart';
import '../../screens/desktop/auth/desktop_forgot_password_page.dart';
import '../../screens/desktop/auth/desktop_reset_password_page.dart';
import '../constants/app_strings.dart';
import 'route_names.dart';

class AppRouter {
  AppRouter._();
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppStrings.routeSplash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );

      case AppStrings.routeLogin:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
          settings: settings,
        );

      case RouteNames.forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordPage(),
          settings: settings,
        );

      case RouteNames.resetPassword:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ResetPasswordPage(email: args?['email'] as String?),
          settings: settings,
        );

      case RouteNames.changePassword:
        return MaterialPageRoute(
          builder: (_) => const ChangePasswordPage(),
          settings: settings,
        );

      // Desktop/Web (width >= 500px) - auth
      case RouteNames.desktopLogin:
        return MaterialPageRoute(
          builder: (_) => const DesktopLoginPage(),
          settings: settings,
        );
      case RouteNames.desktopSignup:
        return MaterialPageRoute(
          builder: (_) => const DesktopSignupPage(),
          settings: settings,
        );
      case RouteNames.desktopForgotPassword:
        return MaterialPageRoute(
          builder: (_) => const DesktopForgotPasswordPage(),
          settings: settings,
        );
      case RouteNames.desktopResetPassword:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) =>
              DesktopResetPasswordPage(email: args?['email'] as String?),
          settings: settings,
        );
      case RouteNames.desktopMain:
        return MaterialPageRoute(
          builder: (_) =>
              const DesktopShell(initialRoute: RouteNames.desktopHome),
          settings: settings,
        );

      case AppStrings.routeDashboard:
      case AppStrings.routeHome:
        return MaterialPageRoute(
          builder: (_) => const DashboardPage(),
          settings: settings,
        );

      case RouteNames.members:
        return MaterialPageRoute(
          builder: (_) => const MembersListPage(),
          settings: settings,
        );
      case RouteNames.upcomingBirthdays:
        return MaterialPageRoute(
          builder: (_) => const UpcomingBirthdaysPage(),
          settings: settings,
        );

      case RouteNames.departments:
        return MaterialPageRoute(
          builder: (_) => const DepartmentsListPage(),
          settings: settings,
        );

      case RouteNames.events:
        return MaterialPageRoute(
          builder: (_) => const EventsListPage(),
          settings: settings,
        );

      case RouteNames.tasks:
        return MaterialPageRoute(
          builder: (_) {
            final departmentId = settings.arguments as String?;
            return TasksListPage(departmentId: departmentId);
          },
          settings: settings,
        );

      case RouteNames.giving:
        return MaterialPageRoute(
          builder: (_) => const FinancePage(),
          settings: settings,
        );

      case RouteNames.classes:
        return MaterialPageRoute(
          builder: (_) => const ClassesListPage(),
          settings: settings,
        );

      case RouteNames.reports:
        return MaterialPageRoute(
          builder: (_) => const ReportsPage(),
          settings: settings,
        );

      case RouteNames.churchAttendanceList:
        return MaterialPageRoute(
          builder: (_) => const ChurchAttendanceListPage(),
          settings: settings,
        );

      case RouteNames.churchAttendance:
        // Check if arguments are provided (for viewing specific service)
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ChurchAttendancePage(
            serviceDate: args?['serviceDate'] as String?,
            serviceType: args?['serviceType'] as String?,
          ),
          settings: settings,
        );

      case RouteNames.sundaySchoolAttendanceList:
        return MaterialPageRoute(
          builder: (_) => const SundaySchoolAttendanceListPage(),
          settings: settings,
        );

      case RouteNames.sundaySchoolAttendance:
        // Check if arguments are provided (for viewing specific session)
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => SundaySchoolAttendancePage(
            sessionDate: args?['sessionDate'] as String?,
          ),
          settings: settings,
        );

      case RouteNames.visitors:
        return MaterialPageRoute(
          builder: (_) => const VisitorsListPage(),
          settings: settings,
        );

      case RouteNames.addVisitor:
        return MaterialPageRoute(
          builder: (_) => const AddVisitorPage(),
          settings: settings,
        );

      case RouteNames.editVisitor:
        // Extract visitor ID from route
        if (settings.name?.startsWith('/visitors/') == true) {
          final parts = settings.name!.split('/');
          if (parts.length >= 4 && parts[2] != 'add') {
            final visitorId = parts[2];
            return MaterialPageRoute(
              builder: (_) => EditVisitorPage(visitorId: visitorId),
              settings: settings,
            );
          }
        }
        // Fallback if route parsing fails
        return MaterialPageRoute(
          builder: (_) => const VisitorsListPage(),
          settings: settings,
        );

      case RouteNames.teachings:
        return MaterialPageRoute(
          builder: (_) => const TeachingsListPage(),
          settings: settings,
        );

      case RouteNames.addTeaching:
        return MaterialPageRoute(
          builder: (_) => const AddTeachingPage(),
          settings: settings,
        );

      case RouteNames.chat:
        return MaterialPageRoute(
          builder: (_) => const ChatPage(),
          settings: settings,
        );

      case RouteNames.admin:
        return MaterialPageRoute(
          builder: (_) => const AdminPanelPage(),
          settings: settings,
        );

      case RouteNames.addMember:
        return MaterialPageRoute(
          builder: (_) => const AddMemberPage(),
          settings: settings,
        );

      case RouteNames.addClass:
        return MaterialPageRoute(
          builder: (_) => const AddClassPage(),
          settings: settings,
        );

      case RouteNames.addDepartment:
        return MaterialPageRoute(
          builder: (_) => const AddDepartmentPage(),
          settings: settings,
        );

      case RouteNames.addTask:
        return MaterialPageRoute(
          builder: (_) {
            final departmentId = settings.arguments as String?;
            return AddTaskPage(departmentId: departmentId);
          },
          settings: settings,
        );

      case RouteNames.manageProjects:
        final departmentId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => ManageProjectsPage(departmentId: departmentId),
          settings: settings,
        );

      case RouteNames.addProject:
        return MaterialPageRoute(
          builder: (_) => const AddProjectPage(),
          settings: settings,
        );

      case RouteNames.manageTags:
        final tagDepartmentId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => ManageTagsPage(departmentId: tagDepartmentId),
          settings: settings,
        );

      case RouteNames.addEvent:
        return MaterialPageRoute(
          builder: (_) => const AddEventPage(),
          settings: settings,
        );

      case RouteNames.addGiving:
        return MaterialPageRoute(
          builder: (_) => const AddGivingPage(),
          settings: settings,
        );

      case RouteNames.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsPage(),
          settings: settings,
        );

      case RouteNames.leaderAccess:
        return MaterialPageRoute(
          builder: (_) => const LeaderAccessPage(),
          settings: settings,
        );

      case RouteNames.memberAccounts:
        return MaterialPageRoute(
          builder: (_) => const MemberAccountsPage(),
          settings: settings,
        );

      case RouteNames.notifications:
        // Birthday notifications settings
        if (settings.arguments == 'birthday') {
          return MaterialPageRoute(
            builder: (_) => const BirthdayNotificationsSettingsPage(),
            settings: settings,
          );
        }
        // Regular notifications list page
        return MaterialPageRoute(
          builder: (_) => const NotificationsListPage(),
          settings: settings,
        );

      case RouteNames.fileViewer:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => FileViewerPage(
            fileUrl: args?['fileUrl'] as String? ?? '',
            fileName: args?['fileName'] as String? ?? 'File',
          ),
          settings: settings,
        );

      default:
        // Handle dynamic routes with parameters
        if (settings.name?.startsWith('/members/') == true) {
          final parts = settings.name!.split('/');

          // Check if it's an edit route (last part is 'edit')
          if (parts.length >= 4 && parts.last == 'edit') {
            final memberId =
                parts[parts.length - 2]; // Get ID from second-to-last part
            return MaterialPageRoute(
              builder: (_) => EditMemberPage(memberId: memberId),
              settings: settings,
            );
          }

          // Check if it's an add route
          if (parts.length >= 3 && parts.last == 'add') {
            return MaterialPageRoute(
              builder: (_) => const AddMemberPage(),
              settings: settings,
            );
          }

          // Otherwise it's a detail/profile page
          final memberId = parts.last;
          return MaterialPageRoute(
            builder: (_) => MemberProfilePage(memberId: memberId),
            settings: settings,
          );
        }
        if (settings.name?.startsWith('/departments/') == true) {
          final parts = settings.name!.split('/');

          // Check for department report routes first (more specific)
          // /departments/reports/:id or /departments/reports/:id/edit
          if (parts.length >= 4 && parts[2] == 'reports') {
            final reportId = parts.last == 'edit'
                ? parts[parts.length - 2]
                : parts.last;
            if (parts.last == 'edit') {
              return MaterialPageRoute(
                builder: (_) => EditDepartmentReportPage(reportId: reportId),
                settings: settings,
              );
            } else {
              // Detail view - redirect to edit for now
              return MaterialPageRoute(
                builder: (_) => EditDepartmentReportPage(reportId: reportId),
                settings: settings,
              );
            }
          }

          // Check for department reports list/add routes
          // /departments/:id/reports or /departments/:id/reports/add
          if (parts.length >= 4 && parts[parts.length - 2] == 'reports') {
            // /departments/:id/reports
            if (parts.last == 'reports') {
              final deptId = parts[parts.length - 2];
              return MaterialPageRoute(
                builder: (_) => DepartmentReportsListPage(departmentId: deptId),
                settings: settings,
              );
            }
            // /departments/:id/reports/add
            if (parts.last == 'add') {
              final deptId = parts[parts.length - 3];
              return MaterialPageRoute(
                builder: (_) => AddDepartmentReportPage(departmentId: deptId),
                settings: settings,
              );
            }
          }

          // Check if it's an edit route (last part is 'edit')
          if (parts.length >= 4 && parts.last == 'edit') {
            final deptId =
                parts[parts.length - 2]; // Get ID from second-to-last part
            return MaterialPageRoute(
              builder: (_) => EditDepartmentPage(departmentId: deptId),
              settings: settings,
            );
          }

          // Otherwise it's a detail page
          final deptId = parts.last;
          return MaterialPageRoute(
            builder: (_) => DepartmentDetailPage(departmentId: deptId),
            settings: settings,
          );
        }
        if (settings.name?.startsWith('/events/') == true) {
          final parts = settings.name!.split('/');

          // Check if it's an edit route (last part is 'edit')
          if (parts.length >= 4 && parts.last == 'edit') {
            final eventId =
                parts[parts.length - 2]; // Get ID from second-to-last part
            return MaterialPageRoute(
              builder: (_) => EditEventPage(eventId: eventId),
              settings: settings,
            );
          }

          // Otherwise it's a detail page
          final eventId = parts.last;
          return MaterialPageRoute(
            builder: (_) => EventDetailPage(eventId: eventId),
            settings: settings,
          );
        }
        if (settings.name?.startsWith('/tasks/projects') == true) {
          final parts = settings.name!.split('/');
          // /tasks/projects -> manage, /tasks/projects/add -> add, /tasks/projects/:id/edit -> edit
          if (parts.length == 3) {
            return MaterialPageRoute(
              builder: (_) => const ManageProjectsPage(),
              settings: settings,
            );
          }
          if (parts.length == 4 && parts[3] == 'add') {
            return MaterialPageRoute(
              builder: (_) => const AddProjectPage(),
              settings: settings,
            );
          }
          if (parts.length >= 5 && parts.last == 'edit') {
            final projectId = parts[parts.length - 2];
            return MaterialPageRoute(
              builder: (_) => EditProjectPage(projectId: projectId),
              settings: settings,
            );
          }
        }
        if (settings.name?.startsWith('/tasks/') == true) {
          final parts = settings.name!.split('/');

          // Check if it's an edit route (last part is 'edit')
          if (parts.length >= 4 && parts.last == 'edit') {
            final taskId =
                parts[parts.length - 2]; // Get ID from second-to-last part
            return MaterialPageRoute(
              builder: (_) => EditTaskPage(taskId: taskId),
              settings: settings,
            );
          }

          // Otherwise it's a detail page
          final taskId = parts.last;
          return MaterialPageRoute(
            builder: (_) => TaskDetailPage(taskId: taskId),
            settings: settings,
          );
        }
        if (settings.name?.startsWith('/trainings/') == true) {
          final parts = settings.name!.split('/');

          // Check if it's an edit route (last part is 'edit')
          if (parts.length >= 4 && parts.last == 'edit') {
            final classId =
                parts[parts.length - 2]; // Get ID from second-to-last part
            return MaterialPageRoute(
              builder: (_) => EditClassPage(classId: classId),
              settings: settings,
            );
          }

          // Otherwise it's a detail page
          final classId = parts.last;
          return MaterialPageRoute(
            builder: (_) => ClassDetailPage(classId: classId),
            settings: settings,
          );
        }
        if (settings.name?.startsWith('/giving/') == true) {
          final parts = settings.name!.split('/');

          // Check if it's an edit route (last part is 'edit')
          if (parts.length >= 4 && parts.last == 'edit') {
            final givingId =
                parts[parts.length - 2]; // Get ID from second-to-last part
            return MaterialPageRoute(
              builder: (_) => EditGivingPage(givingId: givingId),
              settings: settings,
            );
          }

          // Otherwise it's a detail page (also use edit page for viewing)
          final givingId = parts.last;
          return MaterialPageRoute(
            builder: (_) => EditGivingPage(givingId: givingId),
            settings: settings,
          );
        }
        if (settings.name?.startsWith('/reports/training/') == true) {
          final parts = settings.name!.split('/');
          final classId = parts.last;
          return MaterialPageRoute(
            builder: (_) => ClassReportPage(classId: classId),
            settings: settings,
          );
        }
        if (settings.name?.startsWith('/teachings/') == true) {
          final parts = settings.name!.split('/');

          // Skip if it's the add route (handled by case statement)
          if (parts.length >= 3 && parts[2] == 'add') {
            return MaterialPageRoute(
              builder: (_) => const AddTeachingPage(),
              settings: settings,
            );
          }

          // Check if it's an edit route (last part is 'edit')
          if (parts.length >= 4 && parts.last == 'edit') {
            final teachingId =
                parts[parts.length - 2]; // Get ID from second-to-last part
            return MaterialPageRoute(
              builder: (_) => EditTeachingPage(teachingId: teachingId),
              settings: settings,
            );
          }

          // Otherwise it's a detail page
          final teachingId = parts.last;
          return MaterialPageRoute(
            builder: (_) => TeachingDetailPage(teachingId: teachingId),
            settings: settings,
          );
        }
        if (settings.name?.startsWith('/reports/member/') == true) {
          final parts = settings.name!.split('/');
          final memberId = parts.last;
          return MaterialPageRoute(
            builder: (_) => MemberReportPage(memberId: memberId),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route ${settings.name} not found')),
          ),
          settings: settings,
        );
    }
  }

  static Route<dynamic>? onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'The page you are looking for does not exist.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
