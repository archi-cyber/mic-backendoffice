# Services Documentation

This document describes all the Supabase service classes and their endpoints.

## Overview

All services use the `SupabaseService.client` to interact with Supabase. Make sure to initialize Supabase before using any service:

```dart
await SupabaseService.initialize();
```

## Services

### 1. SupabaseService (`supabase_service.dart`)

Base service for Supabase initialization and client access.

**Methods:**
- `initialize({String? supabaseUrl, String? supabaseAnonKey})` - Initialize Supabase
- `get client` - Get Supabase client instance
- `get currentUser` - Get current authenticated user
- `get currentSession` - Get current session
- `get isAuthenticated` - Check if user is authenticated

---

### 2. AuthService (`auth_service.dart`)

Authentication operations.

**Endpoints:**
- `POST /auth/login` → `login(email, password)`
  - Returns: `{token, must_change_password, user}`
  
- `POST /auth/forgot-password` → `forgotPassword(email)`
  - Sends password reset link to email
  
- `POST /auth/reset-password` → `resetPassword(token, newPassword)`
  - Resets password using token
  
- `logout()` - Logout current user
- `getCurrentUser()` - Get current authenticated user

**Usage:**
```dart
// Login
final result = await AuthService.login(
  email: 'user@example.com',
  password: 'password123',
);
print('Must change password: ${result['must_change_password']}');

// Forgot password
await AuthService.forgotPassword(email: 'user@example.com');

// Reset password
await AuthService.resetPassword(
  token: 'reset-token',
  newPassword: 'newPassword123',
);
```

---

### 3. AdminService (`admin_service.dart`)

Admin user management operations.

**Endpoints:**
- `POST /admin/users` → `createAdminUser(email, password, role, metadata?)`
  - Creates admin/pastor/admin users
  
- `PATCH /users/:id/activate` → `activateUser(userId, isActive)`
  - Activate/deactivate user
  
- `PATCH /users/:id/force-reset` → `forcePasswordReset(userId, sendEmail?)`
  - Force password reset for user

**Usage:**
```dart
// Create admin user
await AdminService.createAdminUser(
  email: 'admin@church.com',
  password: 'securePassword',
  role: 'admin',
);

// Activate user
await AdminService.activateUser(
  userId: 'user-id',
  isActive: true,
);

// Force password reset
await AdminService.forcePasswordReset(
  userId: 'user-id',
  sendEmail: true,
);
```

---

### 4. MemberService (`member_service.dart`)

Member CRUD operations.

**Endpoints:**
- `POST /members` → `createMember(memberData)`
  - Create member (admin only) - auto-creates user (inactive)
  
- `GET /members` → `getMembers(filters?, limit?, offset?, orderBy?, ascending?)`
  - Get members with optional filters
  
- `GET /members/:id` → `getMemberById(memberId)`
  - Get member by ID
  
- `PATCH /members/:id` → `updateMember(memberId, updates)`
  - Update member
  
- `DELETE /members/:id` → `deleteMember(memberId)`
  - Soft delete member

**Usage:**
```dart
// Create member
final member = await MemberService.createMember(
  memberData: {
    'first_name': 'John',
    'last_name': 'Doe',
    'email': 'john@example.com',
    // ... other fields
  },
);

// Get members with filters
final members = await MemberService.getMembers(
  filters: {'is_active': true},
  limit: 20,
  offset: 0,
  orderBy: 'last_name',
);

// Update member
await MemberService.updateMember(
  memberId: 'member-id',
  updates: {'phone': '123-456-7890'},
);

// Delete member
await MemberService.deleteMember('member-id');
```

---

### 5. DepartmentService (`department_service.dart`)

Department management.

**Endpoints:**
- `POST /departments` → `createDepartment(departmentData)`
  - Create department
  
- `GET /departments` → `getDepartments(filters?, limit?, offset?)`
  - Get all departments
  
- `GET /departments/:id` → `getDepartmentById(departmentId)`
  - Get department by ID
  
- `POST /departments/:id/members` → `addMemberToDepartment(departmentId, memberId, role)`
  - Add member as leader/subleader/member
  
- `DELETE /departments/:id/members/:memberId` → `removeMemberFromDepartment(departmentId, memberId)`
  - Remove member (triggers deactivation check)

**Usage:**
```dart
// Create department
await DepartmentService.createDepartment(
  departmentData: {
    'name': 'Youth Ministry',
    'description': 'Youth activities',
  },
);

// Add member to department
await DepartmentService.addMemberToDepartment(
  departmentId: 'dept-id',
  memberId: 'member-id',
  role: 'leader',
);

// Remove member
await DepartmentService.removeMemberFromDepartment(
  departmentId: 'dept-id',
  memberId: 'member-id',
);
```

---

### 6. ClassService (`class_service.dart`)

Classes and sessions management.

**Endpoints:**
- `POST /classes` → `createClass(classData)`
  - Create class
  
- `GET /classes/:id` → `getClassById(classId)`
  - Get class by ID
  
- `POST /classes/:id/sessions/generate` → `generateSessions(classId, numberOfSessions, startDate?)`
  - Generate next N sessions
  
- `GET /sessions/:id` → `getSessionById(sessionId)`
  - Get session by ID
  
- `POST /sessions/:id/attendance` → `recordAttendance(sessionId, attendanceRecords)`
  - Record bulk attendance

**Usage:**
```dart
// Create class
await ClassService.createClass(
  classData: {
    'name': 'Sunday School',
    'description': 'Weekly Sunday class',
  },
);

// Generate sessions
final sessions = await ClassService.generateSessions(
  classId: 'class-id',
  numberOfSessions: 4,
  startDate: DateTime.now(),
);

// Record attendance
await ClassService.recordAttendance(
  sessionId: 'session-id',
  attendanceRecords: [
    {'member_id': 'member-1', 'status': 'present'},
    {'member_id': 'member-2', 'status': 'absent'},
  ],
);
```

---

### 7. EventService (`event_service.dart`)

Event management.

**Endpoints:**
- `POST /events` → `createEvent(eventData)`
  - Create event
  
- `GET /events` → `getEvents(filters?, limit?, offset?, fromDate?, toDate?)`
  - Get all events (visible to all members)
  
- `GET /events/:id` → `getEventById(eventId)`
  - Get event by ID
  
- `POST /events/:id/sessions` → `createEventSessions(eventId, sessionsData)`
  - Create event sessions
  
- `POST /events/:id/attendance` → `recordEventAttendance(eventId, attendanceRecords)`
  - Record attendance for event sessions

**Usage:**
```dart
// Create event
await EventService.createEvent(
  eventData: {
    'title': 'Christmas Service',
    'event_date': DateTime(2024, 12, 25).toIso8601String(),
    'description': 'Annual Christmas celebration',
  },
);

// Get events
final events = await EventService.getEvents(
  fromDate: DateTime.now(),
  toDate: DateTime.now().add(Duration(days: 30)),
);

// Record event attendance
await EventService.recordEventAttendance(
  eventId: 'event-id',
  attendanceRecords: [
    {
      'session_id': 'session-id',
      'member_id': 'member-id',
      'status': 'present',
    },
  ],
);
```

---

### 8. TaskService (`task_service.dart`)

Task and notification management.

**Endpoints:**
- `POST /departments/:deptId/tasks` → `createTask(departmentId, taskData)`
  - Create task for department
  
- `POST /tasks/:id/assign/:memberId` → `assignTask(taskId, memberId)`
  - Assign task and send notification
  
- `POST /tasks/:id/remind` → `remindTask(taskId, customMessage?)`
  - Send reminder notification
  
- `GET /notifications` → `getNotifications(memberId, isRead?, limit?, offset?)`
  - Get user's notifications
  
- `markNotificationAsRead(notificationId)` - Mark notification as read

**Usage:**
```dart
// Create task
await TaskService.createTask(
  departmentId: 'dept-id',
  taskData: {
    'title': 'Prepare Sunday service',
    'description': 'Set up equipment',
    'due_date': DateTime.now().add(Duration(days: 7)).toIso8601String(),
  },
);

// Assign task
await TaskService.assignTask(
  taskId: 'task-id',
  memberId: 'member-id',
);

// Get notifications
final notifications = await TaskService.getNotifications(
  memberId: 'member-id',
  isRead: false,
  limit: 20,
);
```

---

### 9. ReportService (`report_service.dart`)

Report generation.

**Endpoints:**
- `GET /reports/member/:memberId?from=&to=` → `getMemberReport(memberId, fromDate?, toDate?)`
  - Get member report with attendance and giving
  
- `GET /reports/class/:classId?from=&to=` → `getClassReport(classId, fromDate?, toDate?)`
  - Get class report with session and attendance data

**Usage:**
```dart
// Get member report
final memberReport = await ReportService.getMemberReport(
  memberId: 'member-id',
  fromDate: DateTime(2024, 1, 1),
  toDate: DateTime(2024, 12, 31),
);
print('Total attendance: ${memberReport['attendance']['total']}');
print('Total giving: ${memberReport['giving']['total']}');

// Get class report
final classReport = await ReportService.getClassReport(
  classId: 'class-id',
  fromDate: DateTime(2024, 1, 1),
  toDate: DateTime(2024, 12, 31),
);
```

---

### 10. ChatService (`chat_service.dart`)

Global announcements and chat.

**Endpoints:**
- `GET /chat` → `getAnnouncements(limit?, offset?, fromDate?)`
  - Get global announcement feed
  
- `POST /chat` → `createAnnouncement(title, message, isGlobal?, departmentId?, targetMemberIds?)`
  - Create announcement (leaders/admins only)

**Usage:**
```dart
// Get announcements
final announcements = await ChatService.getAnnouncements(
  limit: 20,
  offset: 0,
);

// Create announcement
await ChatService.createAnnouncement(
  title: 'Important Update',
  message: 'Service time changed to 10 AM',
  isGlobal: true,
);
```

---

## Error Handling

All services throw `Exception` with descriptive error messages. Wrap service calls in try-catch blocks:

```dart
try {
  final result = await AuthService.login(
    email: email,
    password: password,
  );
  // Handle success
} catch (e) {
  // Handle error
  print('Error: $e');
}
```

## Database Schema Requirements

These services assume the following Supabase tables exist:
- `users` - User accounts
- `members` - Member profiles
- `departments` - Department information
- `department_members` - Department membership
- `classes` - Class information
- `sessions` - Class sessions
- `attendance` - Session attendance
- `events` - Events
- `event_sessions` - Event sessions
- `event_attendance` - Event attendance
- `tasks` - Tasks
- `task_assignments` - Task assignments
- `notifications` - Notifications
- `announcements` - Announcements
- `giving` - Giving records

Make sure your Supabase database has these tables with appropriate columns and relationships.
