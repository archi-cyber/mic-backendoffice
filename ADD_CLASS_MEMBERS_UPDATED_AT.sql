-- Add updated_at column to class_members table
-- This migration adds the updated_at timestamp field to track when class member enrollments are modified

ALTER TABLE class_members
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create a trigger to automatically update updated_at on row updates
CREATE OR REPLACE FUNCTION update_class_members_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if it exists and create new one
DROP TRIGGER IF EXISTS trigger_update_class_members_updated_at ON class_members;
CREATE TRIGGER trigger_update_class_members_updated_at
  BEFORE UPDATE ON class_members
  FOR EACH ROW
  EXECUTE FUNCTION update_class_members_updated_at();

-- Update existing rows to have updated_at set to created_at or NOW()
UPDATE class_members
SET updated_at = COALESCE(created_at, NOW())
WHERE updated_at IS NULL;
