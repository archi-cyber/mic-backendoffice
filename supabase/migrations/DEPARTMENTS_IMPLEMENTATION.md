# Departments Module Implementation

## Overview
Complete CRUD functionality for departments with member management, role assignment, and business rule integration.

## Database Schema
```sql
CREATE TABLE departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE department_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('leader', 'subleader', 'member')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(department_id, member_id)
);
```

## Service Methods (`lib/services/department_service.dart`)

### CRUD Operations
- ✅ `createDepartment()` - Create a new department
- ✅ `getDepartments()` - Get all departments with filters, pagination
- ✅ `getDepartmentById()` - Get a single department by ID
- ✅ `updateDepartment()` - Update department information
- ✅ `deleteDepartment()` - Soft delete (sets is_active=false)

### Member Management
- ✅ `getDepartmentMembers()` - Get all members in a department with roles
- ✅ `addMemberToDepartment()` - Add member with role (leader/subleader/member)
- ✅ `removeMemberFromDepartment()` - Remove member from department

### Business Rules Integration
- ✅ When member assigned as Leader/Subleader → user.active=true, user.role=leader, default password, must_change_password=true
- ✅ When re-assigned as leader → user.active=true, existing password preserved
- ✅ When member no longer has leadership → user.active=false, password preserved
- ✅ Checks other department assignments before deactivation

## UI Screens

### 1. Departments List Page (`lib/screens/departments/departments_list_page.dart`)
**Features:**
- ✅ Search functionality
- ✅ Refresh indicator
- ✅ Modern card-based design
- ✅ Active/Inactive status display
- ✅ Navigation to department detail
- ✅ Floating action button to add new department
- ✅ Auto-refresh after creating a department

**Card Design:**
- Department icon with first letter
- Department name (bold)
- Description (if available)
- Inactive badge (if inactive)
- Tap to navigate to detail

### 2. Add Department Page (`lib/screens/departments/add_department_page.dart`)
**Features:**
- ✅ Form validation
- ✅ Department name (required)
- ✅ Description (optional, multi-line)
- ✅ Success/error feedback
- ✅ Returns result to trigger list refresh

### 3. Edit Department Page (`lib/screens/departments/edit_department_page.dart`)
**Features:**
- ✅ Pre-populated form with existing data
- ✅ Same fields as Add Department
- ✅ Update functionality
- ✅ Success/error feedback
- ✅ Returns result to trigger detail refresh

### 4. Department Detail Page (`lib/screens/departments/department_detail_page.dart`)
**Features:**
- ✅ Four tabs: Overview, Members, Tasks, Reports
- ✅ Edit button in app bar
- ✅ Delete option in menu
- ✅ Department information display

**Overview Tab:**
- ✅ Department description
- ✅ Stats cards (Members count, Tasks count)

**Members Tab:**
- ✅ List of all members with roles
- ✅ Add member button
- ✅ Role badges (Leader, Subleader, Member)
- ✅ Change role functionality
- ✅ Remove member functionality
- ✅ Navigate to member profile
- ✅ Refresh indicator
- ✅ Empty state

**Tasks Tab:**
- ✅ List of department tasks
- ✅ Navigate to task detail

**Reports Tab:**
- ✅ Placeholder for future reports

## Routes

### Route Names (`lib/core/routes/route_names.dart`)
- `RouteNames.departments` - `/departments`
- `RouteNames.departmentDetail` - `/departments/:id`
- `RouteNames.addDepartment` - `/departments/add`
- `RouteNames.editDepartment` - `/departments/:id/edit`

### Router Configuration (`lib/core/routes/app_router.dart`)
- ✅ All routes registered
- ✅ Dynamic route handling for department detail and edit

## Key Features

### 1. Member Role Management
- Three roles: Leader, Subleader, Member
- Color-coded role badges
- Change role functionality
- Role-based user activation/deactivation

### 2. Business Rules Integration
- **Leader Assignment:**
  - Activates user account
  - Sets user role to 'leader'
  - Sets default password
  - Sets must_change_password=true
  
- **Leader Removal:**
  - Checks if member has leadership in other departments
  - Deactivates user only if no leadership roles remain
  - Preserves password

- **Re-assignment:**
  - Reactivates user if previously deactivated
  - Preserves existing password

### 3. Soft Delete
- Departments are soft-deleted (is_active=false)
- Preserves data integrity
- Can be reactivated if needed

### 4. Member Assignment
- Add members to department
- Filter out already-assigned members
- Assign role during addition
- Remove members from department

## Usage Flow

1. **Create Department:**
   - Navigate to Departments List
   - Tap FAB (+)
   - Fill form (name required, description optional)
   - Save → Returns to list with refresh

2. **View Department:**
   - Tap department card in list
   - View department detail with Overview, Members, Tasks, Reports tabs

3. **Edit Department:**
   - From department detail, tap edit icon
   - Modify fields
   - Save → Returns to detail with refresh

4. **Delete Department:**
   - From department detail, tap menu → Delete
   - Confirm deletion
   - Returns to list

5. **Add Member:**
   - From Members tab, tap "Add Member"
   - Select member from dropdown
   - Select role (Member, Subleader, Leader)
   - Add → Member added with role

6. **Change Member Role:**
   - From Members tab, tap member menu → Change Role
   - Select new role
   - Update → Role changed, business rules applied

7. **Remove Member:**
   - From Members tab, tap member menu → Remove
   - Confirm removal
   - Member removed, business rules applied

## Role Badge Design

- **Leader:** Red badge with star icon
- **Subleader:** Primary color badge with star border icon
- **Member:** Gray badge with person icon

## Future Enhancements

- [ ] Department statistics/reports
- [ ] Bulk member operations
- [ ] Department hierarchy
- [ ] Department permissions
- [ ] Activity logs
