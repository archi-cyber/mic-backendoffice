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
  static const String upcomingBirthdays = '/members/birthdays';

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

  // Training Routes
  static const String classes = '/trainings';
  static const String classDetail = '/trainings/:id';
  static const String addClass = '/trainings/add';
  static const String editClass = '/trainings/:id/edit';
  static const String sessions = '/trainings/:id/sessions';
  static const String sessionDetail = '/sessions/:id';
  static const String takeAttendance = '/trainings/session/:id/attendance';

  // Task Routes
  static const String tasks = '/tasks';
  static const String taskDetail = '/tasks/:id';
  static const String addTask = '/tasks/add';
  static const String editTask = '/tasks/:id/edit';
  static const String manageProjects = '/tasks/projects';
  static const String addProject = '/tasks/projects/add';
  static const String editProject = '/tasks/projects/:id/edit';
  static const String manageTags = '/tasks/tags';

  // Service schedule (Media Team)
  static const String serviceSchedule = '/service-schedule';

  // Report Routes
  static const String reports = '/reports';
  static const String memberReport = '/reports/member/:id';
  static const String membersReport = '/reports/members';
  static const String trainingsReport = '/reports/trainings';
  static const String classReport = '/reports/training/:id';
  static const String newComerReport = '/reports/new-comers';

  // Chat/Announcement Routes
  static const String chat = '/chat';

  // Visitor Routes
  static const String visitors = '/visitors';
  static const String addVisitor = '/visitors/add';
  static const String editVisitor = '/visitors/:id/edit';

  // Teaching Routes
  static const String teachings = '/teachings';
  static const String teachingDetail = '/teachings/:id';
  static const String addTeaching = '/teachings/add';
  static const String editTeaching = '/teachings/:id/edit';

  // Admin Routes
  static const String admin = '/admin';
  static const String leaderAccess = '/settings/leader-access';
  static const String memberAccounts = '/settings/member-accounts';
  static const String birthdayNotificationsSettings =
      '/settings/birthday-notifications';

  // Common Routes
  static const String fileViewer = '/file-viewer';

  // Desktop/Web (width >= 500px) - app-on-its-own with sidebar
  static const String desktopLogin = '/desktop/login';
  static const String desktopSignup = '/desktop/signup';
  static const String desktopForgotPassword = '/desktop/forgot-password';
  static const String desktopResetPassword = '/desktop/reset-password';
  static const String desktopMain = '/desktop';
  // Nested routes inside desktop shell (sidebar + content)
  static const String desktopHome = '/desktop/home';
  static const String desktopMembers = '/desktop/members';
  static const String desktopFinance = '/desktop/finance';
  static const String desktopChat = '/desktop/chat';
  static const String desktopSettings = '/desktop/settings';
  static const String desktopNotifications = '/desktop/notifications';
  static const String desktopBirthdays = '/desktop/birthdays';
  static const String desktopEvents = '/desktop/events';
  static const String desktopTasks = '/desktop/tasks';
  static const String desktopTrainings = '/desktop/trainings';
  static const String desktopDepartments = '/desktop/departments';
  static const String desktopReports = '/desktop/reports';
  static const String desktopChurchAttendance = '/desktop/church-attendance';
  static const String desktopSundaySchool = '/desktop/sunday-school';
  static const String desktopVisitors = '/desktop/visitors';
  static const String desktopTeachings = '/desktop/teachings';
  static const String desktopSessions = '/desktop/sessions';
}
