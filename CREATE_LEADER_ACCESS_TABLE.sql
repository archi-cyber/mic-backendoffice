-- Create leader_access table for granular feature access control
-- Run this in Supabase SQL Editor
-- This table allows admins to define specific feature access for each leader

CREATE TABLE IF NOT EXISTS leader_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  feature_name TEXT NOT NULL,
  can_view BOOLEAN NOT NULL DEFAULT false,
  can_create BOOLEAN NOT NULL DEFAULT false,
  can_edit BOOLEAN NOT NULL DEFAULT false,
  can_delete BOOLEAN NOT NULL DEFAULT false,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  -- Ensure one access record per user per feature
  UNIQUE(user_id, feature_name)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_leader_access_user_id 
  ON leader_access(user_id) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_leader_access_feature 
  ON leader_access(feature_name) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_leader_access_user_feature 
  ON leader_access(user_id, feature_name) 
  WHERE deleted_at IS NULL;

-- Enable RLS
ALTER TABLE leader_access ENABLE ROW LEVEL SECURITY;

-- RLS policies for leader_access
DROP POLICY IF EXISTS "Admins can manage all leader access" ON leader_access;
DROP POLICY IF EXISTS "Leaders can view their own access" ON leader_access;

-- Admins can do everything
CREATE POLICY "Admins can manage all leader access"
  ON leader_access FOR ALL
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

-- Leaders can view their own access records
CREATE POLICY "Leaders can view their own access"
  ON leader_access FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND user_id = auth.uid()
    AND deleted_at IS NULL
  );

-- Trigger function to update updated_at
CREATE OR REPLACE FUNCTION update_leader_access_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_leader_access_updated_at
  BEFORE UPDATE ON leader_access
  FOR EACH ROW
  EXECUTE FUNCTION update_leader_access_updated_at();

-- Comments
COMMENT ON TABLE leader_access IS 'Stores granular feature access permissions for leaders. Admins can define what each leader can do for each feature.';
COMMENT ON COLUMN leader_access.feature_name IS 'Name of the feature (e.g., members, events, visitors, departments, trainings, tasks, reports, attendance, giving, chat)';
COMMENT ON COLUMN leader_access.can_view IS 'Whether the leader can view this feature';
COMMENT ON COLUMN leader_access.can_create IS 'Whether the leader can create records in this feature';
COMMENT ON COLUMN leader_access.can_edit IS 'Whether the leader can edit records in this feature';
COMMENT ON COLUMN leader_access.can_delete IS 'Whether the leader can delete records in this feature';
