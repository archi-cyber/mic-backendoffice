-- ============================================================================
-- RECREATE GIVING TABLE
-- ============================================================================
-- This script drops the existing giving table and recreates it according to
-- the requirements:
-- - giver_name: Name of the giver (member or external person)
-- - amount: Amount (negative for expenses, positive for receiving)
-- - tag: Enum (construction, special_op, tithe, offering, gift, other)
-- - type: 'expense' or 'receiving'
-- - notes: Optional description
-- - member_id: Optional reference to members table
-- - date: Date of the transaction
-- - created_at, updated_at: Timestamps
--
-- WARNING: This will DELETE all existing giving records!
-- Make sure to backup your data before running this script.
-- ============================================================================

-- Step 1: Drop existing RLS policies (if they exist)
DROP POLICY IF EXISTS "Finance leaders and admins can manage giving" ON giving;
DROP POLICY IF EXISTS "Finance leaders and admins can view giving" ON giving;

-- Step 2: Drop the giving table (CASCADE to handle any dependencies)
DROP TABLE IF EXISTS giving CASCADE;

-- Step 3: Drop the enum type if it exists (to recreate it fresh)
DROP TYPE IF EXISTS giving_tag_enum CASCADE;

-- Step 4: Create the enum type for giving tags
CREATE TYPE giving_tag_enum AS ENUM (
  'construction',
  'special_op',
  'tithe',
  'offering',
  'gift',
  'other'
);

-- Step 5: Create the giving table
CREATE TABLE giving (
  -- Primary key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Giver information
  giver_name TEXT NOT NULL,
  member_id UUID REFERENCES members(id) ON DELETE SET NULL,
  
  -- Transaction details
  amount NUMERIC(10, 2) NOT NULL,
  tag giving_tag_enum NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('expense', 'receiving')),
  notes TEXT,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Step 6: Add indexes for better query performance
CREATE INDEX idx_giving_member_id ON giving(member_id);
CREATE INDEX idx_giving_date ON giving(date);
CREATE INDEX idx_giving_type ON giving(type);
CREATE INDEX idx_giving_tag ON giving(tag);
CREATE INDEX idx_giving_created_at ON giving(created_at DESC);

-- Step 7: Add comments for documentation
COMMENT ON TABLE giving IS 'Giving records for tracking tithes, offerings, expenses, and other financial transactions';
COMMENT ON COLUMN giving.id IS 'Primary key (UUID)';
COMMENT ON COLUMN giving.giver_name IS 'Name of the giver (member or external person)';
COMMENT ON COLUMN giving.member_id IS 'Optional reference to members table if giver is a member';
COMMENT ON COLUMN giving.amount IS 'Amount of the transaction (negative for expenses, positive for receiving)';
COMMENT ON COLUMN giving.tag IS 'Category tag: construction, special_op, tithe, offering, gift, other';
COMMENT ON COLUMN giving.type IS 'Transaction type: expense or receiving';
COMMENT ON COLUMN giving.notes IS 'Optional description or notes about the transaction';
COMMENT ON COLUMN giving.date IS 'Date of the transaction';
COMMENT ON COLUMN giving.created_at IS 'Timestamp when the record was created';
COMMENT ON COLUMN giving.updated_at IS 'Timestamp when the record was last updated';

-- Step 8: Create a function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_giving_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 9: Create trigger to automatically update updated_at
CREATE TRIGGER trigger_update_giving_updated_at
  BEFORE UPDATE ON giving
  FOR EACH ROW
  EXECUTE FUNCTION update_giving_updated_at();

-- Step 10: Enable Row Level Security
ALTER TABLE giving ENABLE ROW LEVEL SECURITY;

-- Step 11: Create RLS policies
-- Note: This assumes the is_finance_leader() function exists
-- If it doesn't exist, you'll need to create it first (see ENABLE_RLS_ALL_TABLES.sql)

-- Policy for finance leaders and admins to manage (INSERT, UPDATE, DELETE)
CREATE POLICY "Finance leaders and admins can manage giving"
  ON giving FOR ALL
  USING (is_finance_leader())
  WITH CHECK (is_finance_leader());

-- Policy for finance leaders and admins to view (SELECT)
CREATE POLICY "Finance leaders and admins can view giving"
  ON giving FOR SELECT
  USING (is_finance_leader());

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these queries to verify the table was created correctly:

-- Check table structure:
-- SELECT 
--   column_name, 
--   data_type, 
--   udt_name,
--   is_nullable,
--   column_default
-- FROM information_schema.columns 
-- WHERE table_name = 'giving' 
-- ORDER BY ordinal_position;

-- Check enum type:
-- SELECT typname, typtype, oid 
-- FROM pg_type 
-- WHERE typname = 'giving_tag_enum';

-- Check indexes:
-- SELECT 
--   indexname, 
--   indexdef 
-- FROM pg_indexes 
-- WHERE tablename = 'giving';

-- Check RLS policies:
-- SELECT 
--   schemaname, 
--   tablename, 
--   policyname, 
--   permissive, 
--   roles, 
--   cmd, 
--   qual, 
--   with_check 
-- FROM pg_policies 
-- WHERE tablename = 'giving';

-- Check triggers:
-- SELECT 
--   trigger_name, 
--   event_manipulation, 
--   event_object_table, 
--   action_statement 
-- FROM information_schema.triggers 
-- WHERE event_object_table = 'giving';

-- ============================================================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================================================
-- Uncomment and modify these if you want to insert sample data:

-- INSERT INTO giving (giver_name, amount, tag, type, notes, date) VALUES
--   ('John Doe', 100.00, 'tithe', 'receiving', 'Weekly tithe', CURRENT_DATE),
--   ('Jane Smith', 50.00, 'offering', 'receiving', 'Sunday offering', CURRENT_DATE),
--   ('Church Supplies', -75.50, 'construction', 'expense', 'Building materials', CURRENT_DATE);

-- ============================================================================
-- NOTES
-- ============================================================================
-- 1. This script assumes:
--    - The members table exists
--    - The is_finance_leader() function exists (see ENABLE_RLS_ALL_TABLES.sql)
--    - The is_admin() function exists (used by is_finance_leader())
--
-- 2. If you need to add new tag values in the future:
--    ALTER TYPE giving_tag_enum ADD VALUE 'new_tag_value';
--
-- 3. The amount column uses NUMERIC(10, 2) which allows:
--    - Up to 10 digits total
--    - 2 decimal places
--    - Negative values for expenses
--
-- 4. The member_id is optional and uses ON DELETE SET NULL, so if a member
--    is deleted, the giving record remains but member_id becomes NULL.
--
-- 5. The date column defaults to CURRENT_DATE, but can be set to any date.
--
-- 6. All timestamps use TIMESTAMP WITH TIME ZONE for proper timezone handling.
--
-- 7. The updated_at column is automatically updated via trigger when a row
--    is updated.
--
-- 8. RLS policies ensure only finance department leaders and admins can
--    access the giving table.
--
-- ============================================================================
