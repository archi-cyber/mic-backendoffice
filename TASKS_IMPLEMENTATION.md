# Tasks Module Implementation

## Overview
Complete CRUD functionality for tasks with assignment management, status tracking, and priority levels.

## Database Schema
```sql
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  due_date DATE,
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE task_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(task_id, member_id)
);
```

## Service Methods (`lib/services/task_service.dart`)

### CRUD Operations
- ✅ `createTask()` - Create a new task for a department
- ✅ `getAllTasks()` - Get all tasks with optional filters (department, status, priority)
- ✅ `getDepartmentTasks()` - Get tasks for a specific department
- ✅ `getTaskById()` - Get a single task by ID
- ✅ `updateTask()` - Update task information
- ✅ `deleteTask()` - Delete task (hard delete, cascades to assignments)

### Assignment Management
- ✅ `assignTask()` - Assign task to member (creates assignment + notification)
- ✅ `getTaskAssignments()` - Get all assignments for a task
- ✅ `updateAssignmentStatus()` - Update assignment status
- ✅ `removeAssignment()` - Remove member from task

### Notifications
- ✅ `remindTask()` - Send reminder to all assignees
- ✅ `getNotifications()` - Get user notifications
- ✅ `markNotificationAsRead()` - Mark notification as read

## UI Screens

### 1. Tasks List Page (`lib/screens/tasks/tasks_list_page.dart`)
**Features:**
- ✅ Search functionality
- ✅ Filter by status and priority
- ✅ Refresh indicator
- ✅ Modern card-based design
- ✅ Priority badges (color-coded)
- ✅ Status badges (color-coded)
- ✅ Due date display (with overdue highlighting)
- ✅ Navigation to task detail
- ✅ Floating action button to add new task
- ✅ Auto-refresh after creating a task
- ✅ Department-scoped or all tasks

**Card Design:**
- Task title (bold)
- Description (if available)
- Priority badge (urgent=red, high=orange, medium=primary, low=gray)
- Status badge (completed=green, in_progress=primary, pending=yellow, cancelled=red)
- Due date with overdue indicator
- Tap to navigate to detail

### 2. Add Task Page (`lib/screens/tasks/add_task_page.dart`)
**Features:**
- ✅ Form validation
- ✅ Task title (required)
- ✅ Description (optional, multi-line)
- ✅ Department selection (required dropdown)
- ✅ Due date picker (optional)
- ✅ Priority selection (low, medium, high, urgent)
- ✅ Status selection (pending, in_progress, completed, cancelled)
- ✅ Success/error feedback
- ✅ Returns result to trigger list refresh

### 3. Edit Task Page (`lib/screens/tasks/edit_task_page.dart`)
**Features:**
- ✅ Pre-populated form with existing data
- ✅ Same fields as Add Task
- ✅ Update functionality
- ✅ Success/error feedback
- ✅ Returns result to trigger detail refresh

### 4. Task Detail Page (`lib/screens/tasks/task_detail_page.dart`)
**Features:**
- ✅ Task information display
- ✅ Status and priority badges
- ✅ Due date display
- ✅ Edit button in app bar
- ✅ Delete option in menu
- ✅ Send reminder button
- ✅ Assignments list with:
  - Member name and email
  - Assignment status (with update dropdown)
  - Remove assignment option
  - Navigate to member profile
- ✅ Assign to member button
- ✅ Auto-refresh after operations

## Routes

### Route Names (`lib/core/routes/route_names.dart`)
- `RouteNames.tasks` - `/tasks` (can accept departmentId as argument)
- `RouteNames.taskDetail` - `/tasks/:id`
- `RouteNames.addTask` - `/tasks/add` (can accept departmentId as argument)
- `RouteNames.editTask` - `/tasks/:id/edit`

### Router Configuration (`lib/core/routes/app_router.dart`)
- ✅ All routes registered
- ✅ Dynamic route handling for task detail and edit
- ✅ Department ID passed as argument when available

## Key Features

### 1. Priority Management
- Four priority levels: Low, Medium, High, Urgent
- Color-coded badges:
  - Urgent: Red
  - High: Orange
  - Medium: Primary color
  - Low: Gray

### 2. Status Management
- Four status levels: Pending, In Progress, Completed, Cancelled
- Color-coded badges:
  - Completed: Green
  - In Progress: Primary color
  - Pending: Yellow/Warning
  - Cancelled: Red

### 3. Assignment Management
- Assign multiple members to a task
- Individual assignment status tracking
- Update assignment status independently
- Remove assignments
- Automatic notifications on assignment

### 4. Due Date Tracking
- Optional due date
- Overdue highlighting (red, bold)
- Date picker for selection

### 5. Department Scoping
- Tasks belong to departments
- Can filter by department
- Department selection in add/edit forms

## Usage Flow

1. **Create Task:**
   - Navigate to Tasks List
   - Tap FAB (+)
   - Fill form (title required, department required, others optional)
   - Save → Returns to list with refresh

2. **View Task:**
   - Tap task card in list
   - View task detail with assignments

3. **Edit Task:**
   - From task detail, tap edit icon
   - Modify fields
   - Save → Returns to detail with refresh

4. **Delete Task:**
   - From task detail, tap menu → Delete
   - Confirm deletion
   - Returns to list

5. **Assign Task:**
   - From task detail, tap "Assign to Member"
   - Select member from list
   - Assignment created, notification sent

6. **Update Assignment Status:**
   - From task detail, tap assignment status badge
   - Select new status
   - Status updated

7. **Remove Assignment:**
   - From task detail, tap X on assignment
   - Confirm removal
   - Assignment removed

8. **Send Reminder:**
   - From task detail, tap reminder icon
   - Notification sent to all assignees

## Filtering and Search

- **Search:** By title or description
- **Status Filter:** All, Pending, In Progress, Completed, Cancelled
- **Priority Filter:** All, Low, Medium, High, Urgent
- Filters can be combined
- Clear filters option

## Notifications Integration

- Task assignment creates notification
- Task reminder sends notification to all assignees
- Notifications linked to tasks via `related_id` and `related_type`

## Future Enhancements

- [ ] Task comments/discussions
- [ ] Task attachments
- [ ] Task templates
- [ ] Recurring tasks
- [ ] Task dependencies
- [ ] Task time tracking
- [ ] Task reports/analytics
- [ ] Bulk task operations
