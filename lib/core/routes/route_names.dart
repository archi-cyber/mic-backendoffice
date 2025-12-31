/// Centralized route name constants
/// Use these constants instead of hardcoding route strings
class RouteNames {
  RouteNames._(); // Private constructor to prevent instantiation

  // Main Routes
  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String home = '/home';

  // Auth Routes
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String changePassword = '/change-password';

  // Member Routes
  static const String members = '/members';
  static const String memberDetail = '/members/:id';
  static const String addMember = '/members/add';
  static const String editMember = '/members/:id/edit';

  // Attendance Routes
  static const String attendance = '/attendance';
  static const String attendanceDetail = '/attendance/:id';
  static const String markAttendance = '/attendance/mark';
  static const String churchAttendance = '/attendance/church';
  static const String churchAttendanceList = '/attendance/church/list';
  static const String sundaySchoolAttendance = '/attendance/sunday-school';
  static const String sundaySchoolAttendanceList =
      '/attendance/sunday-school/list';

  // Giving Routes
  static const String giving = '/giving';
  static const String givingDetail = '/giving/:id';
  static const String addGiving = '/giving/add';
  static const String editGiving = '/giving/:id/edit';

  // Events Routes
  static const String events = '/events';
  static const String eventDetail = '/events/:id';
  static const String addEvent = '/events/add';
  static const String editEvent = '/events/:id/edit';

  // Settings Routes
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String about = '/about';

  // Department Routes
  static const String departments = '/departments';
  static const String departmentDetail = '/departments/:id';
  static const String addDepartment = '/departments/add';
  static const String editDepartment = '/departments/:id/edit';
  static const String departmentReports = '/departments/:id/reports';
  static const String addDepartmentReport = '/departments/:id/reports/add';
  static const String editDepartmentReport = '/departments/reports/:id/edit';
  static const String departmentReportDetail = '/departments/reports/:id';

  // Class Routes
  static const String classes = '/classes';
  static const String classDetail = '/classes/:id';
  static const String addClass = '/classes/add';
  static const String editClass = '/classes/:id/edit';
  static const String sessions = '/classes/:id/sessions';
  static const String sessionDetail = '/sessions/:id';

  // Task Routes
  static const String tasks = '/tasks';
  static const String taskDetail = '/tasks/:id';
  static const String addTask = '/tasks/add';
  static const String editTask = '/tasks/:id/edit';

  // Report Routes
  static const String reports = '/reports';
  static const String memberReport = '/reports/member/:id';
  static const String classReport = '/reports/class/:id';

  // Chat/Announcement Routes
  static const String chat = '/chat';

  // Admin Routes
  static const String admin = '/admin';
}
