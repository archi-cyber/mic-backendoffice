-- Add additional fields to members table
-- Run this in Supabase SQL Editor
-- 
-- This migration adds the following fields:
-- - quarter: Quarter information
-- - profession: Member's profession (enum: primary_school_student, secondary_school_student, university_student, job_seeking, worker)
-- - level_of_study: Educational level
-- - sector_of_studies: Sector/field of studies (for secondary and university students, job seeking, and workers)
-- - domain_of_activity: Domain of activity (for job seeking and workers)
-- - key_skills: Key skills (array of text)
-- - last_diplomas: Last diplomas or certifications

-- Step 1: Add quarter column to members table
ALTER TABLE members 
ADD COLUMN IF NOT EXISTS quarter TEXT;

-- Step 2: Add profession column to members table with CHECK constraint
ALTER TABLE members 
ADD COLUMN IF NOT EXISTS profession TEXT 
CHECK (profession IS NULL OR profession IN (
  'primary_school_student',
  'secondary_school_student', 
  'university_student',
  'job_seeking',
  'worker'
));

-- Step 3: Add level_of_study column to members table
ALTER TABLE members 
ADD COLUMN IF NOT EXISTS level_of_study TEXT;

-- Step 4: Add sector_of_studies column to members table
ALTER TABLE members 
ADD COLUMN IF NOT EXISTS sector_of_studies TEXT;

-- Step 5: Add domain_of_activity column to members table
ALTER TABLE members 
ADD COLUMN IF NOT EXISTS domain_of_activity TEXT;

-- Step 6: Add key_skills column to members table as TEXT array
ALTER TABLE members 
ADD COLUMN IF NOT EXISTS key_skills TEXT[];

-- Step 7: Add last_diplomas column to members table
ALTER TABLE members 
ADD COLUMN IF NOT EXISTS last_diplomas TEXT;

-- Step 8: Create indexes for common filtering/search operations
CREATE INDEX IF NOT EXISTS idx_members_profession ON members(profession) WHERE profession IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_members_level_of_study ON members(level_of_study) WHERE level_of_study IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_members_sector_of_studies ON members(sector_of_studies) WHERE sector_of_studies IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_members_domain_of_activity ON members(domain_of_activity) WHERE domain_of_activity IS NOT NULL;

-- Note: Age category (child, teenager, adult) is computed in the application
-- based on the birthday field, so no database column is needed for it.
