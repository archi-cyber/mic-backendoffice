# Member Role Implementation

## Overview
Added a `role` field to the members table to allow members to have roles: `admin`, `leader`, or `member`.

## Database Changes

### SQL Migration
Run `ADD_MEMBER_ROLE.sql` in your Supabase SQL Editor to:
1. Add `role` column to `members` table
2. Set default value to `'member'`
3. Add CHECK constraint to ensure valid roles
4. Create index for performance

```sql
ALTER TABLE members 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'member' 
CHECK (role IN ('admin', 'leader', 'member'));
```

## Code Changes

### 1. Add Member Page (`lib/screens/members/add_member_page.dart`)
- Added role dropdown with options: Admin, Leader, Member
- Default role is 'member'
- Role is included when creating a new member

### 2. Members List Page (`lib/screens/members/members_list_page.dart`)
- Added role filter in filter dialog
- Displays role chip/badge next to each member
- Role chips are color-coded:
  - **Admin**: Red
  - **Leader**: Orange/Warning
  - **Member**: Gray

### 3. Member Profile Page (`lib/screens/members/member_profile_page.dart`)
- Displays role chip in profile header
- Shows role in profile information section
- Role is displayed with color-coded badge

## Role Values

- **`admin`**: Full administrative access
- **`leader`**: Leadership role with elevated permissions
- **`member`**: Regular member (default)

## UI Features

### Role Display
- Role chips are displayed with:
  - Color-coded background (light tint)
  - Colored border
  - Bold text in matching color
  - Rounded corners

### Filtering
- Users can filter members by role in the filter dialog
- Filter options:
  - All roles (default)
  - Admin only
  - Leader only
  - Member only

## Usage

1. **Run the SQL migration** (`ADD_MEMBER_ROLE.sql`) in Supabase
2. **Create members** with role selection in the Add Member page
3. **Filter members** by role in the Members List page
4. **View role** in member profile

## Notes

- The role field is separate from the `users` table role
- Member role can be used for display and filtering purposes
- Business logic for permissions should still check the `users` table role for authentication
- Existing members will default to 'member' role after migration
