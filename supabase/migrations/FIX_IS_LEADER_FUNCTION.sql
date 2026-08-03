-- Fix is_leader() function to include department leaders and subleaders
-- This matches the fix we made in the Dart PermissionHelper class
-- Run this in Supabase SQL Editor

-- ============================================================================
-- UPDATE is_leader() FUNCTION
-- ============================================================================
-- The function should return true if:
-- 1. User has role='admin' or role='leader' in users table, OR
-- 2. User is a leader or subleader in any department (via department_members table)
-- ============================================================================

CREATE OR REPLACE FUNCTION is_leader()
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if user has role='admin' or role='leader' in users table
  IF EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND role IN ('admin', 'leader')
    AND is_active = true
  ) THEN
    RETURN true;
  END IF;
  
  -- Also check if user is a leader or subleader in any department
  RETURN EXISTS (
    SELECT 1
    FROM users u
    JOIN department_members dm ON u.member_id = dm.member_id
    WHERE u.id = auth.uid()
    AND u.is_active = true
    AND dm.role IN ('leader', 'subleader')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON FUNCTION is_leader() IS 'Returns true if user is an admin, has role="leader" in users table, OR is a leader/subleader in any department. This ensures department leaders/subleaders are recognized as leaders even if they don''t have role="leader" in the users table.';
