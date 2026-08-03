-- Create teachings table and teaching_listeners tracking table
-- Run this in Supabase SQL Editor
-- This table tracks teachings and which members (workers, leaders, admins) have listened to them

-- Create teachings table
CREATE TABLE IF NOT EXISTS teachings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  teaching_date DATE NOT NULL,
  description TEXT,
  speaker TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Create teaching_listeners table to track which members listened to each teaching
CREATE TABLE IF NOT EXISTS teaching_listeners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teaching_id UUID NOT NULL REFERENCES teachings(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  -- Ensure one record per teaching per member
  UNIQUE(teaching_id, member_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_teachings_teaching_date 
  ON teachings(teaching_date DESC) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_teachings_created_at 
  ON teachings(created_at DESC) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_teaching_listeners_teaching_id 
  ON teaching_listeners(teaching_id) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_teaching_listeners_member_id 
  ON teaching_listeners(member_id) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_teaching_listeners_teaching_member 
  ON teaching_listeners(teaching_id, member_id) 
  WHERE deleted_at IS NULL;

-- Enable RLS
ALTER TABLE teachings ENABLE ROW LEVEL SECURITY;
ALTER TABLE teaching_listeners ENABLE ROW LEVEL SECURITY;

-- RLS policies for teachings
DROP POLICY IF EXISTS "Admins can manage all teachings" ON teachings;
DROP POLICY IF EXISTS "Leaders can manage teachings" ON teachings;
DROP POLICY IF EXISTS "Authenticated users can view teachings" ON teachings;

-- Admins can do everything
CREATE POLICY "Admins can manage all teachings"
  ON teachings FOR ALL
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

-- Leaders can manage teachings
CREATE POLICY "Leaders can manage teachings"
  ON teachings FOR ALL
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

-- Authenticated users can view teachings
CREATE POLICY "Authenticated users can view teachings"
  ON teachings FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND deleted_at IS NULL
  );

-- RLS policies for teaching_listeners
DROP POLICY IF EXISTS "Admins can manage all teaching listeners" ON teaching_listeners;
DROP POLICY IF EXISTS "Leaders can manage teaching listeners" ON teaching_listeners;
DROP POLICY IF EXISTS "Authenticated users can view teaching listeners" ON teaching_listeners;

-- Admins can do everything
CREATE POLICY "Admins can manage all teaching listeners"
  ON teaching_listeners FOR ALL
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

-- Leaders can manage teaching listeners
CREATE POLICY "Leaders can manage teaching listeners"
  ON teaching_listeners FOR ALL
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

-- Authenticated users can view teaching listeners
CREATE POLICY "Authenticated users can view teaching listeners"
  ON teaching_listeners FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND deleted_at IS NULL
  );

-- Trigger function to update updated_at
CREATE OR REPLACE FUNCTION update_teachings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_teachings_updated_at
  BEFORE UPDATE ON teachings
  FOR EACH ROW
  EXECUTE FUNCTION update_teachings_updated_at();

CREATE OR REPLACE FUNCTION update_teaching_listeners_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_teaching_listeners_updated_at
  BEFORE UPDATE ON teaching_listeners
  FOR EACH ROW
  EXECUTE FUNCTION update_teaching_listeners_updated_at();

-- Function to automatically populate teaching listeners from church attendance
-- This function checks if a teaching date matches a church attendance date (Sunday or Wednesday)
-- and automatically marks all attendees (who are workers, leaders, or admins) as having listened
-- If the teaching date doesn't match any church attendance, no auto-population occurs
CREATE OR REPLACE FUNCTION auto_populate_teaching_listeners(teaching_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
  teaching_date_val DATE;
  inserted_count INTEGER := 0;
  current_user_id UUID;
  has_attendance BOOLEAN := false;
BEGIN
  -- Get the teaching date and current user
  SELECT teaching_date, created_by INTO teaching_date_val, current_user_id
  FROM teachings
  WHERE id = teaching_uuid AND deleted_at IS NULL;
  
  IF teaching_date_val IS NULL THEN
    RETURN 0;
  END IF;
  
  -- Check if there's any church attendance on this date (Sunday or Wednesday)
  SELECT EXISTS (
    SELECT 1 FROM church_attendance
    WHERE service_date = teaching_date_val
      AND service_type IN ('sunday', 'wednesday')
      AND deleted_at IS NULL
  ) INTO has_attendance;
  
  -- Only auto-populate if there's church attendance on this date
  IF NOT has_attendance THEN
    RETURN 0;
  END IF;
  
  -- Insert teaching_listeners for all members who:
  -- 1. Attended church on the teaching date (service_type = 'sunday' or 'wednesday')
  -- 2. Have role 'worker', 'leader', or 'admin' in the members table
  -- Note: Includes all members regardless of active status
  INSERT INTO teaching_listeners (teaching_id, member_id, created_by, created_at, updated_at)
  SELECT 
    teaching_uuid,
    ca.member_id,
    current_user_id,
    NOW(),
    NOW()
  FROM church_attendance ca
  INNER JOIN members m ON m.id = ca.member_id
  WHERE ca.service_date = teaching_date_val
    AND ca.service_type IN ('sunday', 'wednesday')
    AND ca.deleted_at IS NULL
    AND m.role IN ('worker', 'leader', 'admin')
    AND NOT EXISTS (
      SELECT 1 FROM teaching_listeners tl
      WHERE tl.teaching_id = teaching_uuid
        AND tl.member_id = ca.member_id
        AND tl.deleted_at IS NULL
    )
  ON CONFLICT (teaching_id, member_id) DO NOTHING;
  
  GET DIAGNOSTICS inserted_count = ROW_COUNT;
  
  RETURN inserted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automatically populate listeners when a teaching is created
CREATE OR REPLACE FUNCTION trigger_auto_populate_teaching_listeners()
RETURNS TRIGGER AS $$
BEGIN
  -- Only auto-populate if teaching is not deleted
  IF NEW.deleted_at IS NULL THEN
    PERFORM auto_populate_teaching_listeners(NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER auto_populate_listeners_on_teaching_create
  AFTER INSERT ON teachings
  FOR EACH ROW
  WHEN (NEW.deleted_at IS NULL)
  EXECUTE FUNCTION trigger_auto_populate_teaching_listeners();

-- Function to manually sync teaching listeners for an existing teaching
-- This can be called to re-sync listeners if church attendance was added after teaching creation
-- Only syncs if the teaching date matches a church attendance date (Sunday or Wednesday)
CREATE OR REPLACE FUNCTION sync_teaching_listeners(teaching_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
  teaching_date_val DATE;
  inserted_count INTEGER := 0;
  current_user_id UUID;
  has_attendance BOOLEAN := false;
BEGIN
  -- Get the teaching date
  SELECT teaching_date INTO teaching_date_val
  FROM teachings
  WHERE id = teaching_uuid AND deleted_at IS NULL;
  
  IF teaching_date_val IS NULL THEN
    RETURN 0;
  END IF;
  
  -- Check if there's any church attendance on this date (Sunday or Wednesday)
  SELECT EXISTS (
    SELECT 1 FROM church_attendance
    WHERE service_date = teaching_date_val
      AND service_type IN ('sunday', 'wednesday')
      AND deleted_at IS NULL
  ) INTO has_attendance;
  
  -- Only sync if there's church attendance on this date
  IF NOT has_attendance THEN
    RETURN 0;
  END IF;
  
  -- Get current user (or use system user)
  current_user_id := auth.uid();
  
  -- Insert teaching_listeners for all members who attended church on that date
  INSERT INTO teaching_listeners (teaching_id, member_id, created_by, created_at, updated_at)
  SELECT 
    teaching_uuid,
    ca.member_id,
    current_user_id,
    NOW(),
    NOW()
  FROM church_attendance ca
  INNER JOIN members m ON m.id = ca.member_id
  WHERE ca.service_date = teaching_date_val
    AND ca.service_type IN ('sunday', 'wednesday')
    AND ca.deleted_at IS NULL
    AND m.role IN ('worker', 'leader', 'admin')
    AND NOT EXISTS (
      SELECT 1 FROM teaching_listeners tl
      WHERE tl.teaching_id = teaching_uuid
        AND tl.member_id = ca.member_id
        AND tl.deleted_at IS NULL
    )
  ON CONFLICT (teaching_id, member_id) DO NOTHING;
  
  GET DIAGNOSTICS inserted_count = ROW_COUNT;
  
  RETURN inserted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comments
COMMENT ON TABLE teachings IS 'Stores information about church teachings/sermons';
COMMENT ON COLUMN teachings.teaching_date IS 'Date when the teaching was delivered';
COMMENT ON COLUMN teachings.speaker IS 'Name of the person who delivered the teaching';
COMMENT ON TABLE teaching_listeners IS 'Tracks which members (workers, leaders, admins) have listened to each teaching';
COMMENT ON FUNCTION auto_populate_teaching_listeners IS 'Automatically populates teaching_listeners based on church attendance (Sunday or Wednesday) for the teaching date. Only syncs if the teaching date matches a church attendance date.';
COMMENT ON FUNCTION sync_teaching_listeners IS 'Manually syncs teaching_listeners for an existing teaching based on church attendance (Sunday or Wednesday). Only syncs if the teaching date matches a church attendance date.';
