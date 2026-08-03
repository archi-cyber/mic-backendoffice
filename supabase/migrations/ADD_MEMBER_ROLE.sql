-- Add role field to members table
-- Run this in Supabase SQL Editor

-- Step 1: Add role column to members table
ALTER TABLE members 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'member' 
CHECK (role IN ('admin', 'leader', 'member'));

-- Step 2: Create index for role filtering
CREATE INDEX IF NOT EXISTS idx_members_role ON members(role);

-- Step 3: Update existing members to have default role (if any exist)
UPDATE members 
SET role = 'member' 
WHERE role IS NULL;

-- Step 4: Make role NOT NULL after setting defaults
ALTER TABLE members 
ALTER COLUMN role SET NOT NULL;
