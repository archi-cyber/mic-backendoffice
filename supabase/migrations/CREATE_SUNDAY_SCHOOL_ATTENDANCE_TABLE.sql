-- Sunday school attendance table
CREATE TABLE IF NOT EXISTS sunday_school_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  attendance_date DATE NOT NULL,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Partial unique index to enforce uniqueness for non-deleted rows
CREATE UNIQUE INDEX IF NOT EXISTS ux_sunday_school_attendance_member_date_not_deleted
  ON sunday_school_attendance(member_id, attendance_date)
  WHERE deleted_at IS NULL;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_sunday_school_attendance_member_id 
  ON sunday_school_attendance(member_id) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_sunday_school_attendance_date 
  ON sunday_school_attendance(attendance_date DESC) 
  WHERE deleted_at IS NULL;

-- Enable RLS
ALTER TABLE sunday_school_attendance ENABLE ROW LEVEL SECURITY;

-- RLS policies for sunday_school_attendance
DROP POLICY IF EXISTS "Admins can manage all sunday school attendance" ON sunday_school_attendance;
DROP POLICY IF EXISTS "Leaders can manage sunday school attendance" ON sunday_school_attendance;
DROP POLICY IF EXISTS "Authenticated users can view sunday school attendance" ON sunday_school_attendance;
DROP POLICY IF EXISTS "Members can view their own sunday school attendance" ON sunday_school_attendance;

-- Admins can do everything
CREATE POLICY "Admins can manage all sunday school attendance"
  ON sunday_school_attendance FOR ALL
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

-- Leaders can manage attendance
CREATE POLICY "Leaders can manage sunday school attendance"
  ON sunday_school_attendance FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role IN ('admin', 'leader')
      AND is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role IN ('admin', 'leader')
      AND is_active = true
    )
  );

-- Authenticated users can view attendance
CREATE POLICY "Authenticated users can view sunday school attendance"
  ON sunday_school_attendance FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM members m
      WHERE m.id = sunday_school_attendance.member_id
      AND m.is_active = true
    )
  );

-- Members can view their own attendance
CREATE POLICY "Members can view their own sunday school attendance"
  ON sunday_school_attendance FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = auth.uid()
      AND u.member_id = sunday_school_attendance.member_id
      AND u.is_active = true
    )
  );

-- Trigger function to update updated_at
CREATE OR REPLACE FUNCTION update_sunday_school_attendance_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_sunday_school_attendance_updated_at
  BEFORE UPDATE ON sunday_school_attendance
  FOR EACH ROW
  EXECUTE FUNCTION update_sunday_school_attendance_updated_at();

-- Comments
COMMENT ON TABLE sunday_school_attendance IS 'Tracks member attendance at Sunday school (for children only)';
COMMENT ON COLUMN sunday_school_attendance.attendance_date IS 'Date of the Sunday school session';
