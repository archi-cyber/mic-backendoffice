-- Create department_reports table
CREATE TABLE IF NOT EXISTS department_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  defined_objectives TEXT NOT NULL,
  positive_points TEXT NOT NULL,
  difficulties_encountered TEXT NOT NULL,
  suggestions TEXT NOT NULL,
  comments TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_department_reports_department_id 
  ON department_reports(department_id) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_department_reports_created_by 
  ON department_reports(created_by) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_department_reports_created_at 
  ON department_reports(created_at DESC) 
  WHERE deleted_at IS NULL;

-- Enable RLS
ALTER TABLE department_reports ENABLE ROW LEVEL SECURITY;

-- RLS policies for department_reports
-- Drop existing policies if they exist
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

-- Trigger function to update updated_at
CREATE OR REPLACE FUNCTION update_department_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_department_reports_updated_at
  BEFORE UPDATE ON department_reports
  FOR EACH ROW
  EXECUTE FUNCTION update_department_reports_updated_at();

-- Comments
COMMENT ON TABLE department_reports IS 'Stores reports created by department leaders';
COMMENT ON COLUMN department_reports.defined_objectives IS 'Objectives defined for the department';
COMMENT ON COLUMN department_reports.positive_points IS 'Positive points or achievements';
COMMENT ON COLUMN department_reports.difficulties_encountered IS 'Difficulties or challenges faced';
COMMENT ON COLUMN department_reports.suggestions IS 'Suggestions for improvement';
COMMENT ON COLUMN department_reports.comments IS 'Additional comments or notes';