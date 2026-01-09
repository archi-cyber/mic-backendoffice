-- Add attendance_type field to church_attendance table
-- Run this in Supabase SQL Editor
-- 
-- This field tracks how a member attended:
-- - onsite: Member attended in person at the church
-- - online: Member attended online/virtually
-- - absent: Member was absent (for tracking purposes)

-- Add attendance_type column to church_attendance table
ALTER TABLE church_attendance 
ADD COLUMN IF NOT EXISTS attendance_type TEXT DEFAULT 'onsite';

-- Add check constraint to ensure valid values
ALTER TABLE church_attendance 
DROP CONSTRAINT IF EXISTS church_attendance_type_check;

ALTER TABLE church_attendance 
ADD CONSTRAINT church_attendance_type_check 
CHECK (attendance_type IN ('onsite', 'online', 'absent'));

-- Create index for filtering by attendance type
CREATE INDEX IF NOT EXISTS idx_church_attendance_type 
  ON church_attendance(attendance_type) 
  WHERE deleted_at IS NULL;

-- Update existing records to have default 'onsite' value
UPDATE church_attendance 
SET attendance_type = 'onsite' 
WHERE attendance_type IS NULL;

-- Make attendance_type NOT NULL after setting defaults
ALTER TABLE church_attendance 
ALTER COLUMN attendance_type SET NOT NULL;

-- Add comment
COMMENT ON COLUMN church_attendance.attendance_type IS 'How the member attended: onsite (in person), online (virtually), or absent (for tracking)';

