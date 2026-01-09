-- Add is_main column to department_members table
-- Run this in Supabase SQL Editor
-- This allows tracking which department is the main department for each worker

-- Add is_main column to department_members table
ALTER TABLE department_members
ADD COLUMN IF NOT EXISTS is_main BOOLEAN NOT NULL DEFAULT false;

-- Create index for performance when querying main departments
CREATE INDEX IF NOT EXISTS idx_department_members_is_main 
  ON department_members(member_id, is_main) 
  WHERE is_main = true;

-- Add comment to explain the column
COMMENT ON COLUMN department_members.is_main IS 'Indicates if this is the main department for the worker. Only one department per worker should be marked as main.';

-- Optional: Add a unique partial index to ensure only one main department per member
-- This constraint ensures data integrity at the database level
-- Note: This will prevent having multiple main departments for the same member
CREATE UNIQUE INDEX IF NOT EXISTS idx_department_members_one_main_per_member
  ON department_members(member_id)
  WHERE is_main = true;

-- Note: The application layer (DepartmentService.setMainDepartment) handles
-- unsetting the previous main department before setting a new one, but this
-- unique index provides an additional safeguard at the database level.
