-- Migrate tags to belong to a single department (for existing DBs that already have tags table).
-- Run this only if you already ran CREATE_PROJECTS_AND_TAGS_TABLES.sql with the old global tags.
-- New installs: use the updated CREATE_PROJECTS_AND_TAGS_TABLES.sql which already has tags.department_id.

-- 1. Add department_id as nullable first
ALTER TABLE tags
  ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES departments(id) ON DELETE CASCADE;

-- 2. Backfill: set all existing tags to the first department (change subquery if needed)
UPDATE tags
SET department_id = (SELECT id FROM departments WHERE is_active = true ORDER BY created_at ASC NULLS LAST LIMIT 1)
WHERE department_id IS NULL;

-- 3. Drop old UNIQUE(name) if it exists
ALTER TABLE tags DROP CONSTRAINT IF EXISTS tags_name_key;

-- 4. Set NOT NULL (fails if any tag still has NULL department_id)
ALTER TABLE tags ALTER COLUMN department_id SET NOT NULL;

-- 5. Add unique constraint per department (fails if duplicate (department_id, name) exist)
ALTER TABLE tags ADD CONSTRAINT tags_department_id_name_key UNIQUE (department_id, name);

-- 6. Index for filtering by department
CREATE INDEX IF NOT EXISTS idx_tags_department_id ON tags(department_id);

COMMENT ON COLUMN tags.department_id IS 'Each tag belongs to a single department.';
