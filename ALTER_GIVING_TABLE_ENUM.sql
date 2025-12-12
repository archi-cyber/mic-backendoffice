-- ============================================================================
-- ALTER GIVING TABLE - CREATE ENUM FOR TAG COLUMN
-- ============================================================================
-- This script creates an enum type for the giving table's tag column
-- and alters the table to use the enum type instead of a text/varchar column.
--
-- Tag values:
-- - construction
-- - special_op
-- - tithe
-- - offering
-- - gift
-- - other
--
-- ============================================================================

-- Step 1: Create the enum type for giving tags
CREATE TYPE giving_tag_enum AS ENUM (
  'construction',
  'special_op',
  'tithe',
  'offering',
  'gift',
  'other'
);

-- Step 2: Add a new column with the enum type (temporary)
ALTER TABLE giving
ADD COLUMN tag_enum giving_tag_enum;

-- Step 3: Migrate existing data from tag column to tag_enum column
-- This handles existing records by converting text values to enum values
UPDATE giving
SET tag_enum = CASE
  WHEN tag = 'construction' THEN 'construction'::giving_tag_enum
  WHEN tag = 'special_op' THEN 'special_op'::giving_tag_enum
  WHEN tag = 'tithe' THEN 'tithe'::giving_tag_enum
  WHEN tag = 'offering' THEN 'offering'::giving_tag_enum
  WHEN tag = 'gift' THEN 'gift'::giving_tag_enum
  WHEN tag = 'other' THEN 'other'::giving_tag_enum
  ELSE 'other'::giving_tag_enum  -- Default to 'other' for any invalid values
END
WHERE tag IS NOT NULL;

-- Step 4: Set default value for tag_enum (for any NULL values)
UPDATE giving
SET tag_enum = 'other'::giving_tag_enum
WHERE tag_enum IS NULL;

-- Step 5: Make tag_enum NOT NULL
ALTER TABLE giving
ALTER COLUMN tag_enum SET NOT NULL;

-- Step 6: Drop the old tag column
ALTER TABLE giving
DROP COLUMN tag;

-- Step 7: Rename tag_enum to tag
ALTER TABLE giving
RENAME COLUMN tag_enum TO tag;

-- Step 8: Add a comment to the column for documentation
COMMENT ON COLUMN giving.tag IS 'Category tag for the giving record. Enum: construction, special_op, tithe, offering, gift, other';

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- Run these queries to verify the changes:

-- Check the enum type exists:
-- SELECT typname, typtype, oid FROM pg_type WHERE typname = 'giving_tag_enum';

-- Check the column type:
-- SELECT column_name, data_type, udt_name 
-- FROM information_schema.columns 
-- WHERE table_name = 'giving' AND column_name = 'tag';

-- Check all distinct tag values in the table:
-- SELECT DISTINCT tag FROM giving ORDER BY tag;

-- ============================================================================
-- NOTES
-- ============================================================================
-- 1. This script assumes the giving table already exists
-- 2. If you have existing data with invalid tag values, they will be set to 'other'
-- 3. The enum ensures data integrity at the database level
-- 4. If you need to add new tag values in the future, use:
--   ALTER TYPE giving_tag_enum ADD VALUE 'new_tag_value';
-- 5. To drop the enum type (if needed):
--   DROP TYPE giving_tag_enum CASCADE;
--   (Note: This will also drop the column, so use with caution)
-- ============================================================================
