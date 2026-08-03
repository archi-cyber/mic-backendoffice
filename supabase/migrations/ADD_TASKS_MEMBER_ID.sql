-- Add member_id column to tasks table for individual task assignments
-- This allows tasks to be assigned to either a department OR an individual member

-- Step 1: Make department_id nullable (since tasks can now be assigned to individuals)
ALTER TABLE tasks 
  ALTER COLUMN department_id DROP NOT NULL;

-- Step 2: Add member_id column with foreign key to members table
ALTER TABLE tasks 
  ADD COLUMN member_id UUID REFERENCES members(id) ON DELETE CASCADE;

-- Step 3: Add check constraint to ensure either department_id or member_id is set (but not both)
ALTER TABLE tasks 
  ADD CONSTRAINT tasks_department_or_member_check 
  CHECK (
    (department_id IS NOT NULL AND member_id IS NULL) OR 
    (department_id IS NULL AND member_id IS NOT NULL)
  );

-- Step 4: Add index on member_id for better query performance
CREATE INDEX IF NOT EXISTS idx_tasks_member_id ON tasks(member_id);

-- Step 5: Add comment to document the change
COMMENT ON COLUMN tasks.member_id IS 'Member ID when task is assigned to an individual (instead of a department). Either department_id or member_id must be set, but not both.';

