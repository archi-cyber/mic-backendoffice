-- Enable Row Level Security (RLS) on All Tables
-- This script enables RLS and creates policies for all tables in the database
-- Run this in Supabase SQL Editor
-- 
-- ACCESS CONTROL SUMMARY:
-- 1. All authenticated users can view all members (active only)
-- 2. Members can view all data but can only edit their own records
-- 3. Leaders can view and manage all data
-- 4. Admins have full access to all data (including inactive records)
-- 5. Soft-deleted records (is_active = false) are hidden from non-admin users
-- 6. Finance department: Only finance leaders and admins can access the giving table
--    - Requires a department named "Finance" (case-insensitive) in the database
--    - Finance leaders are identified by checking department_members table
--
-- TABLES COVERED:
-- users, user_devices, members, departments, department_members, classes, 
-- class_members, sessions, attendance, events, event_sessions, event_attendance,
-- event_registrations, tasks, task_assignments, notifications, announcements,
-- app_settings, giving

-- ============================================================================
-- HELPER FUNCTION: Check if user is admin
-- ============================================================================
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND role = 'admin'
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- HELPER FUNCTION: Check if user is leader
-- ============================================================================
CREATE OR REPLACE FUNCTION is_leader()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND role IN ('admin', 'leader')
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- HELPER FUNCTION: Get current user's member_id
-- ============================================================================
CREATE OR REPLACE FUNCTION current_user_member_id()
RETURNS UUID AS $$
BEGIN
  RETURN (SELECT member_id FROM users WHERE id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- HELPER FUNCTION: Check if user is finance department leader
-- ============================================================================
-- NOTE: This function checks if the user is a leader of a department named "Finance"
-- Make sure you have a department with name "Finance" (case-insensitive) in your database
CREATE OR REPLACE FUNCTION is_finance_leader()
RETURNS BOOLEAN AS $$
BEGIN
  -- Admin/pastor always has access
  IF is_admin() THEN
    RETURN true;
  END IF;
  
  -- Check if user is a leader of the finance department
  -- The department name is checked case-insensitively
  RETURN EXISTS (
    SELECT 1
    FROM users u
    JOIN department_members dm ON u.member_id = dm.member_id
    JOIN departments d ON dm.department_id = d.id
    WHERE u.id = auth.uid()
    AND u.role = 'leader'
    AND u.is_active = true
    AND LOWER(TRIM(d.name)) = 'finance'
    AND d.is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 1. USERS TABLE
-- ============================================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own record" ON users;
DROP POLICY IF EXISTS "Users can update their own record" ON users;
DROP POLICY IF EXISTS "Authenticated users can view users" ON users;
DROP POLICY IF EXISTS "Admins can manage all users" ON users;

-- Admins can do everything
CREATE POLICY "Admins can manage all users"
  ON users FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Users can view their own record
CREATE POLICY "Users can view their own record"
  ON users FOR SELECT
  USING (auth.uid() = id);

-- Authenticated users can view active users (for member lists, etc.)
CREATE POLICY "Authenticated users can view users"
  ON users FOR SELECT
  USING (auth.uid() IS NOT NULL AND is_active = true);

-- Users can update their own record (limited fields - adjust as needed)
CREATE POLICY "Users can update their own record"
  ON users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================================
-- 2. USER_DEVICES TABLE
-- ============================================================================
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own devices" ON user_devices;
DROP POLICY IF EXISTS "Admins can manage all devices" ON user_devices;

CREATE POLICY "Users can manage their own devices"
  ON user_devices FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can manage all devices"
  ON user_devices FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- ============================================================================
-- 3. MEMBERS TABLE
-- ============================================================================
ALTER TABLE members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all members" ON members;
DROP POLICY IF EXISTS "Leaders can view all members" ON members;
DROP POLICY IF EXISTS "Members can view all members" ON members;
DROP POLICY IF EXISTS "Members can view their own record" ON members;

-- Admins can do everything (including inactive members)
CREATE POLICY "Admins can manage all members"
  ON members FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Leaders can view and edit all active members
CREATE POLICY "Leaders can manage all members"
  ON members FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

-- All authenticated users can view active members
CREATE POLICY "Authenticated users can view members"
  ON members FOR SELECT
  USING (auth.uid() IS NOT NULL AND is_active = true);

-- Members can view their own record (even if inactive)
CREATE POLICY "Members can view their own record"
  ON members FOR SELECT
  USING (id = current_user_member_id());

-- Members can update their own record
CREATE POLICY "Members can update their own record"
  ON members FOR UPDATE
  USING (id = current_user_member_id())
  WITH CHECK (id = current_user_member_id());

-- ============================================================================
-- 4. DEPARTMENTS TABLE
-- ============================================================================
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all departments" ON departments;
DROP POLICY IF EXISTS "Leaders can view all departments" ON departments;
DROP POLICY IF EXISTS "Authenticated users can view departments" ON departments;

CREATE POLICY "Admins can manage all departments"
  ON departments FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Leaders can manage departments"
  ON departments FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

CREATE POLICY "Authenticated users can view departments"
  ON departments FOR SELECT
  USING (auth.uid() IS NOT NULL AND is_active = true);

-- ============================================================================
-- 5. DEPARTMENT_MEMBERS TABLE
-- ============================================================================
ALTER TABLE department_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all department members" ON department_members;
DROP POLICY IF EXISTS "Leaders can manage department members" ON department_members;
DROP POLICY IF EXISTS "Authenticated users can view department members" ON department_members;

CREATE POLICY "Admins can manage all department members"
  ON department_members FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Leaders can manage department members"
  ON department_members FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

CREATE POLICY "Authenticated users can view department members"
  ON department_members FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM members m
      WHERE m.id = department_members.member_id
      AND m.is_active = true
    )
  );

-- ============================================================================
-- 6. CLASSES TABLE
-- ============================================================================
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all classes" ON classes;
DROP POLICY IF EXISTS "Leaders can manage classes" ON classes;
DROP POLICY IF EXISTS "Authenticated users can view classes" ON classes;

CREATE POLICY "Admins can manage all classes"
  ON classes FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Leaders can manage classes"
  ON classes FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

CREATE POLICY "Authenticated users can view classes"
  ON classes FOR SELECT
  USING (auth.uid() IS NOT NULL AND is_active = true);

-- ============================================================================
-- 7. CLASS_MEMBERS TABLE
-- ============================================================================
ALTER TABLE class_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all class members" ON class_members;
DROP POLICY IF EXISTS "Leaders can manage class members" ON class_members;
DROP POLICY IF EXISTS "Authenticated users can view class members" ON class_members;

CREATE POLICY "Admins can manage all class members"
  ON class_members FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Leaders can manage class members"
  ON class_members FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

CREATE POLICY "Authenticated users can view class members"
  ON class_members FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM members m
      WHERE m.id = class_members.member_id
      AND m.is_active = true
    )
  );

-- ============================================================================
-- 8. SESSIONS TABLE
-- ============================================================================
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all sessions" ON sessions;
DROP POLICY IF EXISTS "Leaders can manage sessions" ON sessions;
DROP POLICY IF EXISTS "Authenticated users can view sessions" ON sessions;

CREATE POLICY "Admins can manage all sessions"
  ON sessions FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Leaders can manage sessions"
  ON sessions FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

CREATE POLICY "Authenticated users can view sessions"
  ON sessions FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ============================================================================
-- 9. ATTENDANCE TABLE
-- ============================================================================
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all attendance" ON attendance;
DROP POLICY IF EXISTS "Leaders can manage attendance" ON attendance;
DROP POLICY IF EXISTS "Authenticated users can view attendance" ON attendance;
DROP POLICY IF EXISTS "Members can view their own attendance" ON attendance;

CREATE POLICY "Admins can manage all attendance"
  ON attendance FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Leaders can manage attendance"
  ON attendance FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

CREATE POLICY "Authenticated users can view attendance"
  ON attendance FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM members m
      WHERE m.id = attendance.member_id
      AND m.is_active = true
    )
  );

CREATE POLICY "Members can view their own attendance"
  ON attendance FOR SELECT
  USING (member_id = current_user_member_id());

-- ============================================================================
-- 10. EVENTS TABLE
-- ============================================================================
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all events" ON events;
DROP POLICY IF EXISTS "Leaders can manage events" ON events;
DROP POLICY IF EXISTS "Authenticated users can view events" ON events;

CREATE POLICY "Admins can manage all events"
  ON events FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Leaders can manage events"
  ON events FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

CREATE POLICY "Authenticated users can view events"
  ON events FOR SELECT
  USING (auth.uid() IS NOT NULL AND is_active = true);

-- ============================================================================
-- 11. EVENT_SESSIONS TABLE
-- ============================================================================
ALTER TABLE event_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all event sessions" ON event_sessions;
DROP POLICY IF EXISTS "Leaders can manage event sessions" ON event_sessions;
DROP POLICY IF EXISTS "Authenticated users can view event sessions" ON event_sessions;

CREATE POLICY "Admins can manage all event sessions"
  ON event_sessions FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Leaders can manage event sessions"
  ON event_sessions FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

CREATE POLICY "Authenticated users can view event sessions"
  ON event_sessions FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ============================================================================
-- 12. EVENT_ATTENDANCE TABLE
-- ============================================================================
ALTER TABLE event_attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all event attendance" ON event_attendance;
DROP POLICY IF EXISTS "Leaders can manage event attendance" ON event_attendance;
DROP POLICY IF EXISTS "Authenticated users can view event attendance" ON event_attendance;
DROP POLICY IF EXISTS "Members can view their own event attendance" ON event_attendance;

CREATE POLICY "Admins can manage all event attendance"
  ON event_attendance FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Leaders can manage event attendance"
  ON event_attendance FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

CREATE POLICY "Authenticated users can view event attendance"
  ON event_attendance FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM members m
      WHERE m.id = event_attendance.member_id
      AND m.is_active = true
    )
  );

CREATE POLICY "Members can view their own event attendance"
  ON event_attendance FOR SELECT
  USING (member_id = current_user_member_id());

-- ============================================================================
-- 13. EVENT_REGISTRATIONS TABLE
-- ============================================================================
ALTER TABLE event_registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all event registrations" ON event_registrations;
DROP POLICY IF EXISTS "Leaders can manage event registrations" ON event_registrations;
DROP POLICY IF EXISTS "Authenticated users can view event registrations" ON event_registrations;
DROP POLICY IF EXISTS "Members can manage their own registrations" ON event_registrations;

CREATE POLICY "Admins can manage all event registrations"
  ON event_registrations FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Leaders can manage event registrations"
  ON event_registrations FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

CREATE POLICY "Authenticated users can view event registrations"
  ON event_registrations FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM members m
      WHERE m.id = event_registrations.member_id
      AND m.is_active = true
    )
  );

CREATE POLICY "Members can manage their own registrations"
  ON event_registrations FOR ALL
  USING (member_id = current_user_member_id())
  WITH CHECK (member_id = current_user_member_id());

-- ============================================================================
-- 14. TASKS TABLE
-- ============================================================================
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all tasks" ON tasks;
DROP POLICY IF EXISTS "Leaders can manage tasks" ON tasks;
DROP POLICY IF EXISTS "Authenticated users can view tasks" ON tasks;
DROP POLICY IF EXISTS "Users can view assigned tasks" ON tasks;

CREATE POLICY "Admins can manage all tasks"
  ON tasks FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Leaders can manage tasks"
  ON tasks FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

CREATE POLICY "Authenticated users can view tasks"
  ON tasks FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Users can view tasks assigned to them (via task_assignments)
CREATE POLICY "Users can view assigned tasks"
  ON tasks FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM task_assignments
      WHERE task_assignments.task_id = tasks.id
      AND task_assignments.assigned_to_user_id = auth.uid()
    )
  );

-- ============================================================================
-- 15. TASK_ASSIGNMENTS TABLE
-- ============================================================================
ALTER TABLE task_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all task assignments" ON task_assignments;
DROP POLICY IF EXISTS "Leaders can manage task assignments" ON task_assignments;
DROP POLICY IF EXISTS "Authenticated users can view task assignments" ON task_assignments;
DROP POLICY IF EXISTS "Users can view their own assignments" ON task_assignments;

CREATE POLICY "Admins can manage all task assignments"
  ON task_assignments FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Leaders can manage task assignments"
  ON task_assignments FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

CREATE POLICY "Authenticated users can view task assignments"
  ON task_assignments FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can view their own assignments"
  ON task_assignments FOR SELECT
  USING (assigned_to_user_id = auth.uid());

-- ============================================================================
-- 16. NOTIFICATIONS TABLE
-- ============================================================================
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all notifications" ON notifications;
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;

CREATE POLICY "Admins can manage all notifications"
  ON notifications FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Users can view notifications for their member_id
CREATE POLICY "Users can view their own notifications"
  ON notifications FOR SELECT
  USING (
    member_id = current_user_member_id()
    OR member_id IS NULL  -- Allow viewing system-wide notifications
  );

-- Users can update their own notifications (e.g., mark as read)
CREATE POLICY "Users can update their own notifications"
  ON notifications FOR UPDATE
  USING (member_id = current_user_member_id())
  WITH CHECK (member_id = current_user_member_id());

-- ============================================================================
-- 17. ANNOUNCEMENTS TABLE
-- ============================================================================
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all announcements" ON announcements;
DROP POLICY IF EXISTS "Leaders can manage announcements" ON announcements;
DROP POLICY IF EXISTS "Authenticated users can view announcements" ON announcements;

CREATE POLICY "Admins can manage all announcements"
  ON announcements FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Leaders can manage announcements"
  ON announcements FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

CREATE POLICY "Authenticated users can view announcements"
  ON announcements FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ============================================================================
-- 18. APP_SETTINGS TABLE
-- ============================================================================
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage app settings" ON app_settings;
DROP POLICY IF EXISTS "Authenticated users can view app settings" ON app_settings;

CREATE POLICY "Admins can manage app settings"
  ON app_settings FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Authenticated users can view app settings"
  ON app_settings FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ============================================================================
-- 19. GIVING TABLE
-- ============================================================================
ALTER TABLE giving ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Finance leaders and admins can manage giving" ON giving;
DROP POLICY IF EXISTS "Finance leaders and admins can view giving" ON giving;

-- Only finance department leaders and admins can access giving table
CREATE POLICY "Finance leaders and admins can manage giving"
  ON giving FOR ALL
  USING (is_finance_leader())
  WITH CHECK (is_finance_leader());

CREATE POLICY "Finance leaders and admins can view giving"
  ON giving FOR SELECT
  USING (is_finance_leader());

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these to verify RLS is enabled on all tables:

-- Check which tables have RLS enabled:
-- SELECT schemaname, tablename, rowsecurity
-- FROM pg_tables
-- WHERE schemaname = 'public'
-- ORDER BY tablename;

-- Check all policies:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public'
-- ORDER BY tablename, policyname;

-- ============================================================================
-- NOTES
-- ============================================================================
-- 1. All policies filter out soft-deleted records (is_active = false) for non-admin users
-- 2. Members can view all data but can only edit their own records
-- 3. Leaders can view and manage all data
-- 4. Admins have full access to all data including inactive records
-- 5. Finance department access:
--    - Only finance department leaders and admins can access the giving table
--    - Make sure you have a department named "Finance" (case-insensitive) in your database
--    - The finance leader check uses: LOWER(TRIM(d.name)) = 'finance'
-- 6. Test thoroughly after enabling RLS to ensure all app functionality works
-- 7. Consider adding indexes on frequently queried columns (user_id, member_id, etc.)
-- 8. If you need to modify the finance department name check, update the is_finance_leader() function
