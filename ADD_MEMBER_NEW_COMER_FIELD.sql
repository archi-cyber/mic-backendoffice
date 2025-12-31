-- Add is_new_comer field to members table
-- Run this in Supabase SQL Editor
-- 
-- This field tracks if a member is a new comer
-- New comers will be automatically promoted to members after attending 9+ services in 3 months

-- Add is_new_comer column to members table
ALTER TABLE members 
ADD COLUMN IF NOT EXISTS is_new_comer BOOLEAN DEFAULT false;

-- Create index for filtering new comers
CREATE INDEX IF NOT EXISTS idx_members_is_new_comer 
  ON members(is_new_comer) 
  WHERE is_new_comer = true AND is_active = true;

-- Update existing members to not be new comers (assuming they're already established)
-- You may want to adjust this based on your data
UPDATE members 
SET is_new_comer = false 
WHERE is_new_comer IS NULL;

-- Set default for any NULL values
ALTER TABLE members 
ALTER COLUMN is_new_comer SET DEFAULT false;

-- Add comment
COMMENT ON COLUMN members.is_new_comer IS 'Indicates if member is a new comer. Automatically set to false after 9+ service attendances in 3 months.';
