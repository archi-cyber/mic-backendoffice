-- Update members table role constraint to include 'worker' and 'sympathiser'
-- Run this in Supabase SQL Editor

-- Step 1: Drop the existing check constraint (handles both named and auto-generated constraints)
DO $$
DECLARE
    constraint_name TEXT;
BEGIN
    -- Find the check constraint on the role column
    SELECT conname INTO constraint_name
    FROM pg_constraint
    WHERE conrelid = 'members'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%role%'
    LIMIT 1;
    
    -- Drop the constraint if found
    IF constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE members DROP CONSTRAINT %I', constraint_name);
        RAISE NOTICE 'Dropped constraint: %', constraint_name;
    ELSE
        -- Try dropping by common name as fallback
        BEGIN
            ALTER TABLE members DROP CONSTRAINT members_role_check;
            RAISE NOTICE 'Dropped constraint: members_role_check';
        EXCEPTION WHEN undefined_object THEN
            RAISE NOTICE 'Constraint not found, may have been dropped already';
        END;
    END IF;
END $$;

-- Step 2: Add the updated check constraint with all available roles
ALTER TABLE members 
ADD CONSTRAINT members_role_check 
CHECK (role IN ('admin', 'leader', 'member', 'worker', 'sympathiser'));

-- Step 3: Verify the constraint was added successfully
-- SELECT conname, pg_get_constraintdef(oid) 
-- FROM pg_constraint 
-- WHERE conrelid = 'members'::regclass AND conname = 'members_role_check';
