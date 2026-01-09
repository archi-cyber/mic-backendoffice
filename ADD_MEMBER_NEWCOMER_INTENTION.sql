-- Add newcomer_intention field to members table
-- Run this in Supabase SQL Editor
-- 
-- This field tracks the intention of new comers:
-- - wants_to_stay: The newcomer wants to stay
-- - does_not_know_yet: The newcomer is not sure yet
-- - just_passing: The newcomer is just passing through

-- Add newcomer_intention column to members table
ALTER TABLE members 
ADD COLUMN IF NOT EXISTS newcomer_intention TEXT;

-- Add check constraint to ensure valid values
ALTER TABLE members 
DROP CONSTRAINT IF EXISTS members_newcomer_intention_check;

ALTER TABLE members 
ADD CONSTRAINT members_newcomer_intention_check 
CHECK (newcomer_intention IS NULL OR newcomer_intention IN ('wants_to_stay', 'does_not_know_yet', 'just_passing'));

-- Create index for filtering by intention
CREATE INDEX IF NOT EXISTS idx_members_newcomer_intention 
  ON members(newcomer_intention) 
  WHERE is_new_comer = true AND newcomer_intention IS NOT NULL;

-- Add comment
COMMENT ON COLUMN members.newcomer_intention IS 'Intention of new comer: wants_to_stay, does_not_know_yet, or just_passing. Only relevant when is_new_comer is true.';

