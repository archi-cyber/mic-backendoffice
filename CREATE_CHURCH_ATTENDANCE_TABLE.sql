-- Corrected church_attendance table with partial unique index and indexes
CREATE TABLE IF NOT EXISTS church_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  service_date DATE NOT NULL,
  service_type TEXT NOT NULL CHECK (service_type IN ('wednesday', 'sunday')),
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Partial unique index to enforce uniqueness for non-deleted rows
CREATE UNIQUE INDEX IF NOT EXISTS ux_church_attendance_member_date_type_not_deleted
  ON church_attendance(member_id, service_date, service_type)
  WHERE deleted_at IS NULL;

-- Indexes for performance (remove duplicate combined index if desired)
CREATE INDEX IF NOT EXISTS idx_church_attendance_member_id 
  ON church_attendance(member_id) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_church_attendance_service_date 
  ON church_attendance(service_date DESC) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_church_attendance_service_type 
  ON church_attendance(service_type) 
  WHERE deleted_at IS NULL;

-- Note: combined index is redundant with the unique index above; keep if needed for specific query plans
CREATE INDEX IF NOT EXISTS idx_church_attendance_member_date_type 
  ON church_attendance(member_id, service_date, service_type) 
  WHERE deleted_at IS NULL;

-- Enable RLS
ALTER TABLE church_attendance ENABLE ROW LEVEL SECURITY;

-- RLS policies for church_attendance
DROP POLICY IF EXISTS "Admins can manage all church attendance" ON church_attendance;
DROP POLICY IF EXISTS "Leaders can manage church attendance" ON church_attendance;
DROP POLICY IF EXISTS "Authenticated users can view church attendance" ON church_attendance;
DROP POLICY IF EXISTS "Members can view their own church attendance" ON church_attendance;

-- Admins can do everything
CREATE POLICY "Admins can manage all church attendance"
  ON church_attendance FOR ALL
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
CREATE POLICY "Leaders can manage church attendance"
  ON church_attendance FOR ALL
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
CREATE POLICY "Authenticated users can view church attendance"
  ON church_attendance FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM members m
      WHERE m.id = church_attendance.member_id
      AND m.is_active = true
    )
  );

-- Members can view their own attendance
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

-- Trigger function to update updated_at
CREATE OR REPLACE FUNCTION update_church_attendance_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_church_attendance_updated_at
  BEFORE UPDATE ON church_attendance
  FOR EACH ROW
  EXECUTE FUNCTION update_church_attendance_updated_at();

-- Function to check and update new comer status
CREATE OR REPLACE FUNCTION check_and_update_new_comer_status(member_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
  attendance_count INTEGER;
  three_months_ago DATE;
BEGIN
  three_months_ago := CURRENT_DATE - INTERVAL '90 days';
  SELECT COUNT(*)
  INTO attendance_count
  FROM church_attendance
  WHERE member_id = member_uuid
    AND service_date >= three_months_ago
    AND deleted_at IS NULL;
  IF attendance_count >= 9 THEN
    UPDATE members
    SET is_new_comer = false,
        updated_at = NOW()
    WHERE id = member_uuid
      AND is_new_comer = true;
    RETURN true;
  END IF;
  RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automatically check new comer status after attendance is recorded
CREATE OR REPLACE FUNCTION trigger_check_new_comer_status()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM members 
    WHERE id = NEW.member_id 
    AND is_new_comer = true
  ) THEN
    PERFORM check_and_update_new_comer_status(NEW.member_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_new_comer_after_attendance
  AFTER INSERT ON church_attendance
  FOR EACH ROW
  WHEN (NEW.deleted_at IS NULL)
  EXECUTE FUNCTION trigger_check_new_comer_status();

-- Comments
COMMENT ON TABLE church_attendance IS 'Tracks member attendance at Wednesday and Sunday church services';
COMMENT ON COLUMN church_attendance.service_type IS 'Type of service: wednesday or sunday';
COMMENT ON COLUMN church_attendance.service_date IS 'Date of the service';
COMMENT ON FUNCTION check_and_update_new_comer_status IS 'Checks if a new comer has 9+ attendances in 3 months and updates their status';
