-- Fix RLS policies for department_reports table
-- Run this in Supabase SQL Editor if you're getting RLS errors

-- Drop all existing policies
DROP POLICY IF EXISTS "Admins can manage all department reports" ON department_reports;
DROP POLICY IF EXISTS "Users can view department reports for their departments" ON department_reports;
DROP POLICY IF EXISTS "Department leaders can create reports" ON department_reports;
DROP POLICY IF EXISTS "Department leaders can update their reports" ON department_reports;
DROP POLICY IF EXISTS "Department leaders can delete their reports" ON department_reports;

-- Admins can do everything
CREATE POLICY "Admins can manage all department reports"
  ON department_reports FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role = 'admin'
      AND is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role = 'admin'
      AND is_active = true
    )
  );

-- Users can view reports for departments they are members of
-- Also allows admins and leaders to view all reports
CREATE POLICY "Users can view department reports for their departments"
  ON department_reports
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND (
      -- Admins can view all reports
      EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid()
        AND role = 'admin'
        AND is_active = true
      )
      -- Leaders can view all reports
      OR EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid()
        AND role = 'leader'
        AND is_active = true
      )
      -- Regular users can view reports for departments they are members of
      OR EXISTS (
        SELECT 1
        FROM users u
        JOIN department_members dm ON u.member_id = dm.member_id
        WHERE u.id = auth.uid()
          AND dm.department_id = department_reports.department_id
          AND u.is_active = true
      )
    )
  );

-- Department leaders and subleaders can create reports
-- Note: This policy checks that created_by matches auth.uid() AND the user is a leader/subleader
CREATE POLICY "Department leaders can create reports"
  ON department_reports
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND created_by = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM users u
      JOIN department_members dm ON u.member_id = dm.member_id
      WHERE u.id = auth.uid()
        AND dm.department_id = department_reports.department_id
        AND dm.role IN ('leader', 'subleader')
        AND u.is_active = true
    )
  );

-- Department leaders and subleaders can update their own reports
CREATE POLICY "Department leaders can update their reports"
  ON department_reports
  FOR UPDATE
  USING (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM users u
      JOIN department_members dm ON u.member_id = dm.member_id
      WHERE u.id = auth.uid()
        AND dm.department_id = department_reports.department_id
        AND dm.role IN ('leader', 'subleader')
        AND u.is_active = true
    )
  )
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM users u
      JOIN department_members dm ON u.member_id = dm.member_id
      WHERE u.id = auth.uid()
        AND dm.department_id = department_reports.department_id
        AND dm.role IN ('leader', 'subleader')
        AND u.is_active = true
    )
  );

-- Department leaders and subleaders can delete their own reports
CREATE POLICY "Department leaders can delete their reports"
  ON department_reports
  FOR DELETE
  USING (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM users u
      JOIN department_members dm ON u.member_id = dm.member_id
      WHERE u.id = auth.uid()
        AND dm.department_id = department_reports.department_id
        AND dm.role IN ('leader', 'subleader')
        AND u.is_active = true
    )
  );

-- If you're still having issues, you can temporarily test with this more permissive policy:
-- (Remove this after testing and use the proper policies above)
-- 
-- CREATE POLICY "Temporary: Allow all authenticated users to create reports"
--   ON department_reports
--   FOR INSERT
--   WITH CHECK (auth.uid() IS NOT NULL AND created_by = auth.uid());
