-- Fix church_attendance RLS policies to check leader_access permissions
-- This ensures that leaders can only manage church attendance if they have been granted permission
-- Run this in Supabase SQL Editor

-- ============================================================================
-- HELPER FUNCTIONS: Check leader_access permissions
-- ============================================================================

-- Function to check if user has view permission for a feature
CREATE OR REPLACE FUNCTION has_leader_access_view(feature_name_param TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Admins have full access
  IF is_admin() THEN
    RETURN true;
  END IF;
  
  -- Check if user is a leader (has role='leader' OR is department leader/subleader)
  IF NOT is_leader() THEN
    RETURN false;
  END IF;
  
  -- Check leader_access table for view permission
  RETURN EXISTS (
    SELECT 1
    FROM leader_access
    WHERE user_id = auth.uid()
    AND feature_name = feature_name_param
    AND can_view = true
    AND deleted_at IS NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has create permission for a feature
CREATE OR REPLACE FUNCTION has_leader_access_create(feature_name_param TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Admins have full access
  IF is_admin() THEN
    RETURN true;
  END IF;
  
  -- Check if user is a leader (has role='leader' OR is department leader/subleader)
  IF NOT is_leader() THEN
    RETURN false;
  END IF;
  
  -- Check leader_access table for create permission
  RETURN EXISTS (
    SELECT 1
    FROM leader_access
    WHERE user_id = auth.uid()
    AND feature_name = feature_name_param
    AND can_create = true
    AND deleted_at IS NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has edit permission for a feature
CREATE OR REPLACE FUNCTION has_leader_access_edit(feature_name_param TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Admins have full access
  IF is_admin() THEN
    RETURN true;
  END IF;
  
  -- Check if user is a leader (has role='leader' OR is department leader/subleader)
  IF NOT is_leader() THEN
    RETURN false;
  END IF;
  
  -- Check leader_access table for edit permission
  RETURN EXISTS (
    SELECT 1
    FROM leader_access
    WHERE user_id = auth.uid()
    AND feature_name = feature_name_param
    AND can_edit = true
    AND deleted_at IS NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has delete permission for a feature
CREATE OR REPLACE FUNCTION has_leader_access_delete(feature_name_param TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Admins have full access
  IF is_admin() THEN
    RETURN true;
  END IF;
  
  -- Check if user is a leader (has role='leader' OR is department leader/subleader)
  IF NOT is_leader() THEN
    RETURN false;
  END IF;
  
  -- Check leader_access table for delete permission
  RETURN EXISTS (
    SELECT 1
    FROM leader_access
    WHERE user_id = auth.uid()
    AND feature_name = feature_name_param
    AND can_delete = true
    AND deleted_at IS NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can manage (create/edit/delete) a feature
CREATE OR REPLACE FUNCTION has_leader_access_manage(feature_name_param TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Admins have full access
  IF is_admin() THEN
    RETURN true;
  END IF;
  
  -- Check if user is a leader (has role='leader' OR is department leader/subleader)
  IF NOT is_leader() THEN
    RETURN false;
  END IF;
  
  -- Check leader_access table for create OR edit OR delete permission
  RETURN EXISTS (
    SELECT 1
    FROM leader_access
    WHERE user_id = auth.uid()
    AND feature_name = feature_name_param
    AND (can_create = true OR can_edit = true OR can_delete = true)
    AND deleted_at IS NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- UPDATE CHURCH_ATTENDANCE RLS POLICIES
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Admins can manage all church attendance" ON church_attendance;
DROP POLICY IF EXISTS "Leaders can manage church attendance" ON church_attendance;
DROP POLICY IF EXISTS "Authenticated users can view church attendance" ON church_attendance;
DROP POLICY IF EXISTS "Members can view their own church attendance" ON church_attendance;

-- Admins can do everything
CREATE POLICY "Admins can manage all church attendance"
  ON church_attendance FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Leaders can manage attendance if they have create/edit/delete permission in leader_access
CREATE POLICY "Leaders can manage church attendance"
  ON church_attendance FOR ALL
  USING (has_leader_access_manage('church_attendance'))
  WITH CHECK (has_leader_access_manage('church_attendance'));

-- Authenticated users can view attendance if they have view permission OR are viewing their own
CREATE POLICY "Authenticated users can view church attendance"
  ON church_attendance FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND (
      -- Admins can view all
      is_admin()
      OR
      -- Leaders with view permission can view all
      has_leader_access_view('church_attendance')
      OR
      -- Members can view their own
      EXISTS (
        SELECT 1 FROM users u
        WHERE u.id = auth.uid()
        AND u.member_id = church_attendance.member_id
        AND u.is_active = true
      )
    )
    AND EXISTS (
      SELECT 1 FROM members m
      WHERE m.id = church_attendance.member_id
      AND m.is_active = true
    )
  );

-- Members can view their own church attendance
CREATE POLICY "Members can view their own church attendance"
  ON church_attendance FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid()
      AND u.member_id = church_attendance.member_id
      AND u.is_active = true
    )
  );

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON FUNCTION has_leader_access_view(TEXT) IS 'Returns true if user is admin or has can_view permission for the specified feature in leader_access table';
COMMENT ON FUNCTION has_leader_access_create(TEXT) IS 'Returns true if user is admin or has can_create permission for the specified feature in leader_access table';
COMMENT ON FUNCTION has_leader_access_edit(TEXT) IS 'Returns true if user is admin or has can_edit permission for the specified feature in leader_access table';
COMMENT ON FUNCTION has_leader_access_delete(TEXT) IS 'Returns true if user is admin or has can_delete permission for the specified feature in leader_access table';
COMMENT ON FUNCTION has_leader_access_manage(TEXT) IS 'Returns true if user is admin or has can_create OR can_edit OR can_delete permission for the specified feature in leader_access table';
