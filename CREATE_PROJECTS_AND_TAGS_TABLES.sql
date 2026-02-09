-- Projects and Tags for Tasks
-- Run this in Supabase SQL Editor after the tasks table exists.
-- 1. Creates projects table (tied to department, person in charge, progression computed in app)
-- 2. Creates tags table (each tag belongs to a single department)
-- 3. Creates task_tags junction table
-- 4. Adds project_id to tasks
-- 5. RLS for projects, tags, task_tags

-- ============================================================================
-- 1. PROJECTS TABLE (one department per project)
-- ============================================================================
CREATE TABLE IF NOT EXISTS projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  person_in_charge_id UUID REFERENCES members(id) ON DELETE SET NULL,
  end_date DATE,
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_projects_department_id ON projects(department_id);
CREATE INDEX IF NOT EXISTS idx_projects_person_in_charge_id ON projects(person_in_charge_id);
CREATE INDEX IF NOT EXISTS idx_projects_end_date ON projects(end_date);

COMMENT ON TABLE projects IS 'Projects group tasks; progression is computed in app from completed/total tasks.';

-- ============================================================================
-- 2. TAGS TABLE (one department per tag; same tag name allowed in different departments)
-- ============================================================================
CREATE TABLE IF NOT EXISTS tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(department_id, name)
);

CREATE INDEX IF NOT EXISTS idx_tags_department_id ON tags(department_id);
CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);

COMMENT ON TABLE tags IS 'Tags belong to a single department; task_tags link tasks to tags.';
COMMENT ON COLUMN tags.color IS 'Optional hex color for the tag (e.g. #FF5733).';

-- ============================================================================
-- 3. TASK_TAGS (many-to-many)
-- ============================================================================
CREATE TABLE IF NOT EXISTS task_tags (
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (task_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_task_tags_task_id ON task_tags(task_id);
CREATE INDEX IF NOT EXISTS idx_task_tags_tag_id ON task_tags(tag_id);

-- ============================================================================
-- 4. ALTER TASKS: add optional project_id
-- ============================================================================
ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id);

COMMENT ON COLUMN tasks.project_id IS 'Optional project this task belongs to.';

-- ============================================================================
-- 5. RLS: PROJECTS
-- ============================================================================
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all projects" ON projects;
CREATE POLICY "Admins can manage all projects"
  ON projects FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Leaders can manage projects" ON projects;
CREATE POLICY "Leaders can manage projects"
  ON projects FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

DROP POLICY IF EXISTS "Authenticated users can view projects" ON projects;
CREATE POLICY "Authenticated users can view projects"
  ON projects FOR SELECT
  USING (auth.role() = 'authenticated');

-- ============================================================================
-- 6. RLS: TAGS
-- ============================================================================
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all tags" ON tags;
CREATE POLICY "Admins can manage all tags"
  ON tags FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Leaders can manage tags" ON tags;
CREATE POLICY "Leaders can manage tags"
  ON tags FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

DROP POLICY IF EXISTS "Authenticated users can view tags" ON tags;
CREATE POLICY "Authenticated users can view tags"
  ON tags FOR SELECT
  USING (auth.role() = 'authenticated');

-- ============================================================================
-- 7. RLS: TASK_TAGS
-- ============================================================================
ALTER TABLE task_tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all task tags" ON task_tags;
CREATE POLICY "Admins can manage all task tags"
  ON task_tags FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Leaders can manage task tags" ON task_tags;
CREATE POLICY "Leaders can manage task tags"
  ON task_tags FOR ALL
  USING (is_leader())
  WITH CHECK (is_leader());

DROP POLICY IF EXISTS "Authenticated users can view task tags" ON task_tags;
CREATE POLICY "Authenticated users can view task tags"
  ON task_tags FOR SELECT
  USING (auth.role() = 'authenticated');

-- ============================================================================
-- 8. Ensure projects table exists before tasks.project_id FK (if running on fresh DB)
-- If you get "relation projects does not exist", run projects CREATE first, then ALTER tasks.
-- ============================================================================
