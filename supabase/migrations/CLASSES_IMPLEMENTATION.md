# Classes Module Implementation

## Overview
Complete CRUD functionality for classes with sessions and attendance management.

## Database Schema
```sql
CREATE TABLE classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Service Methods (`lib/services/class_service.dart`)

### CRUD Operations
- ✅ `createClass()` - Create a new class
- ✅ `getClasses()` - Get all classes with filters, pagination, ordering
- ✅ `getClassById()` - Get a single class by ID
- ✅ `updateClass()` - Update class information
- ✅ `deleteClass()` - Soft delete (sets is_active=false)

### Session Management
- ✅ `generateSessions()` - On-demand generation of next N sessions
- ✅ `getClassSessions()` - Get all sessions for a class
- ✅ `getSessionById()` - Get a single session

### Attendance Management
- ✅ `getSessionAttendance()` - Get attendance records for a session
- ✅ `recordAttendance()` - Record bulk attendance for a session

### Member Management
- ✅ `getClassMembers()` - Get all members enrolled in a class

## UI Screens

### 1. Classes List Page (`lib/screens/classes/classes_list_page.dart`)
**Features:**
- ✅ Search functionality
- ✅ Refresh indicator
- ✅ Modern card-based design
- ✅ Active/Inactive status display
- ✅ Navigation to class detail
- ✅ Floating action button to add new class
- ✅ Auto-refresh after creating a class

**Card Design:**
- Class icon with colored background
- Class name (bold)
- Description (if available)
- Inactive badge (if inactive)
- Tap to navigate to detail

### 2. Add Class Page (`lib/screens/classes/add_class_page.dart`)
**Features:**
- ✅ Form validation
- ✅ Class name (required)
- ✅ Description (optional, multi-line)
- ✅ Department selection (optional dropdown)
- ✅ Success/error feedback
- ✅ Returns result to trigger list refresh

### 3. Edit Class Page (`lib/screens/classes/edit_class_page.dart`)
**Features:**
- ✅ Pre-populated form with existing data
- ✅ Same fields as Add Class
- ✅ Update functionality
- ✅ Success/error feedback
- ✅ Returns result to trigger detail refresh

### 4. Class Detail Page (`lib/screens/classes/class_detail_page.dart`)
**Features:**
- ✅ Two tabs: Sessions and Members
- ✅ Edit button in app bar
- ✅ Delete option in menu
- ✅ Class information display

**Sessions Tab:**
- ✅ List of all sessions with dates
- ✅ Generate sessions button (4, 8, or 12 weeks)
- ✅ On-demand session generation
- ✅ Navigate to attendance page
- ✅ Refresh indicator
- ✅ Empty state with generate option

**Members Tab:**
- ✅ List of enrolled members
- ✅ Member profile navigation
- ✅ Refresh indicator
- ✅ Empty state
- ✅ TODO: Add/remove members functionality

### 5. Attendance Page (`lib/screens/classes/attendance_page.dart`)
**Features:**
- ✅ Fast toggles for present/absent/late
- ✅ Bulk select mode
- ✅ Bulk mark all present/absent
- ✅ Optimistic UI updates
- ✅ Offline queueing support
- ✅ Load existing attendance records

## Routes

### Route Names (`lib/core/routes/route_names.dart`)
- `RouteNames.classes` - `/classes`
- `RouteNames.classDetail` - `/classes/:id`
- `RouteNames.addClass` - `/classes/add`
- `RouteNames.editClass` - `/classes/:id/edit`

### Router Configuration (`lib/core/routes/app_router.dart`)
- ✅ All routes registered
- ✅ Dynamic route handling for class detail and edit

## Key Features

### 1. On-Demand Session Generation
- Sessions are generated on-demand (not infinitely)
- Continues from last session date
- Configurable weeks between sessions
- Options: 4, 8, or 12 weeks

### 2. Department Association
- Classes can be optionally assigned to departments
- Department selection in add/edit forms
- Department can be changed or removed

### 3. Soft Delete
- Classes are soft-deleted (is_active=false)
- Preserves data integrity
- Can be reactivated if needed

### 4. Attendance Integration
- Sessions link to attendance records
- Members enrolled in class can have attendance tracked
- Bulk attendance recording supported

## Usage Flow

1. **Create Class:**
   - Navigate to Classes List
   - Tap FAB (+)
   - Fill form (name required, description optional, department optional)
   - Save → Returns to list with refresh

2. **View Class:**
   - Tap class card in list
   - View class detail with Sessions and Members tabs

3. **Edit Class:**
   - From class detail, tap edit icon
   - Modify fields
   - Save → Returns to detail with refresh

4. **Delete Class:**
   - From class detail, tap menu → Delete
   - Confirm deletion
   - Returns to list

5. **Generate Sessions:**
   - From Sessions tab, tap "Generate Next Sessions"
   - Select number of weeks (4, 8, or 12)
   - Sessions created on-demand

6. **Take Attendance:**
   - From Sessions tab, tap a session
   - Navigate to attendance page
   - Mark attendance for enrolled members
   - Save → Returns to sessions list

## Future Enhancements

- [ ] Add/remove members from class
- [ ] Class schedule configuration
- [ ] Session recurrence patterns
- [ ] Class capacity limits
- [ ] Class statistics/reports
- [ ] Bulk operations on classes
