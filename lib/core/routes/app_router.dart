import 'package:flutter/material.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/login_page.dart';
import '../../screens/auth/forgot_password_page.dart';
import '../../screens/auth/change_password_page.dart';
import '../../screens/home/dashboard_page.dart';
import '../../screens/members/members_list_page.dart';
import '../../screens/members/member_profile_page.dart';
import '../../screens/departments/departments_list_page.dart';
import '../../screens/departments/department_detail_page.dart';
import '../../screens/departments/add_department_page.dart';
import '../../screens/departments/edit_department_page.dart';
import '../../screens/events/events_list_page.dart';
import '../../screens/events/event_detail_page.dart';
import '../../screens/events/add_event_page.dart';
import '../../screens/events/edit_event_page.dart';
import '../../screens/tasks/tasks_list_page.dart';
import '../../screens/tasks/task_detail_page.dart';
import '../../screens/tasks/add_task_page.dart';
import '../../screens/tasks/edit_task_page.dart';
import '../../screens/classes/classes_list_page.dart';
import '../../screens/classes/class_detail_page.dart';
import '../../screens/classes/add_class_page.dart';
import '../../screens/classes/edit_class_page.dart';
import '../../screens/reports/reports_page.dart';
import '../../screens/chat/chat_page.dart';
import '../../screens/admin/admin_panel_page.dart';
import '../../screens/notifications/notifications_list_page.dart';
import '../../screens/members/add_member_page.dart';
import '../../screens/settings/birthday_notifications_settings_page.dart';
import '../../screens/settings/settings_page.dart';
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

      case RouteNames.changePassword:
        return MaterialPageRoute(
          builder: (_) => const ChangePasswordPage(),
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

      case RouteNames.addEvent:
        return MaterialPageRoute(
          builder: (_) => const AddEventPage(),
          settings: settings,
        );

      case RouteNames.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsPage(),
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

      default:
        // Handle dynamic routes with parameters
        if (settings.name?.startsWith('/members/') == true) {
          final memberId = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder: (_) => MemberProfilePage(memberId: memberId),
            settings: settings,
          );
        }
        if (settings.name?.startsWith('/departments/') == true) {
          final parts = settings.name!.split('/');

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
        if (settings.name?.startsWith('/classes/') == true) {
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
