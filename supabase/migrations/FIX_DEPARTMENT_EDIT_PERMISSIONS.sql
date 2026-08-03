-- Fix Department Edit Permissions
-- This script ensures that only admins, leaders, and subleaders of a specific department
-- can edit that department. Regular members cannot see or use the edit button.

-- ============================================================================
-- HELPER FUNCTION: Check if user is leader or subleader of a specific department
-- ============================================================================
CREATE OR REPLACE FUNCTION is_department_leader_or_subleader(department_id_param UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Admin always has access
  IF is_admin() THEN
    RETURN true;
  END IF;
  
  -- Check if user is a leader or subleader of this specific department
  RETURN EXISTS (
    SELECT 1
    FROM users u
    JOIN department_members dm ON u.member_id = dm.member_id
    WHERE u.id = auth.uid()
    AND u.is_active = true
    AND dm.department_id = department_id_param
    AND dm.role IN ('leader', 'subleader')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- HELPER FUNCTION: Check if user is leader (not subleader) of a specific department
-- ============================================================================
CREATE OR REPLACE FUNCTION is_department_leader_only(department_id_param UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Admin always has access
  IF is_admin() THEN
    RETURN true;
  END IF;
  
  -- Check if user is a leader (not subleader) of this specific department
  RETURN EXISTS (
    SELECT 1
    FROM users u
    JOIN department_members dm ON u.member_id = dm.member_id
    WHERE u.id = auth.uid()
    AND u.is_active = true
    AND dm.department_id = department_id_param
    AND dm.role = 'leader'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- UPDATE DEPARTMENTS TABLE RLS POLICIES
-- ============================================================================
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Admins can manage all departments" ON departments;
DROP POLICY IF EXISTS "Leaders can manage departments" ON departments;
DROP POLICY IF EXISTS "Authenticated users can view departments" ON departments;

-- Admins can do everything
CREATE POLICY "Admins can manage all departments"
  ON departments FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Department leaders and subleaders can update their own departments
CREATE POLICY "Department leaders and subleaders can update their departments"
  ON departments FOR UPDATE
  USING (is_department_leader_or_subleader(id))
  WITH CHECK (is_department_leader_or_subleader(id));

-- Department leaders can delete their own departments (not subleaders)
CREATE POLICY "Department leaders can delete their departments"
  ON departments FOR DELETE
  USING (is_department_leader_only(id));

-- All authenticated users can view active departments
CREATE POLICY "Authenticated users can view departments"
  ON departments FOR SELECT
  USING (auth.uid() IS NOT NULL AND is_active = true);

-- ============================================================================
-- NOTES
-- ============================================================================
-- 1. Admins can manage all departments (create, update, delete)
-- 2. Leaders and subleaders can only update departments they lead
-- 3. Only leaders (not subleaders) can delete departments
-- 4. All authenticated users can view active departments
-- 5. The Flutter app should check canEditDepartment() before showing edit button
-- 6. The Flutter app should check canDeleteDepartment() before showing delete button
