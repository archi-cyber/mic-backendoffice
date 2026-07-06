-- Adds teaching-generated tasks and task penalty support.

ALTER TABLE tasks
ADD COLUMN IF NOT EXISTS teaching_id UUID REFERENCES teachings(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS teaching_task_type TEXT,
ADD COLUMN IF NOT EXISTS teaching_task_index INTEGER,
ADD COLUMN IF NOT EXISTS penalty_amount_per_day INTEGER,
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'tasks_teaching_task_type_check'
  ) THEN
    ALTER TABLE tasks
    ADD CONSTRAINT tasks_teaching_task_type_check
    CHECK (
      teaching_task_type IS NULL
      OR teaching_task_type IN ('mid', 'short', 'full')
    );
  END IF;
END $$;

ALTER TABLE departments
ADD COLUMN IF NOT EXISTS task_penalty_amount INTEGER;

CREATE TABLE IF NOT EXISTS task_penalty_settings (
  id TEXT PRIMARY KEY DEFAULT 'global',
  default_daily_penalty_amount INTEGER NOT NULL DEFAULT 100,
  blocking_threshold_amount INTEGER NOT NULL DEFAULT 3500,
  teaching_task_due_offset_days INTEGER NOT NULL DEFAULT 10,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO task_penalty_settings (
  id,
  default_daily_penalty_amount,
  blocking_threshold_amount,
  teaching_task_due_offset_days
)
VALUES ('global', 100, 3500, 10)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS task_penalties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  penalty_date DATE NOT NULL,
  amount INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (task_id, member_id, penalty_date)
);

CREATE TABLE IF NOT EXISTS task_penalty_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  note TEXT,
  paid_at TIMESTAMPTZ DEFAULT NOW(),
  recorded_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tasks_teaching_id ON tasks(teaching_id);
CREATE INDEX IF NOT EXISTS idx_task_penalties_member_id ON task_penalties(member_id);
CREATE INDEX IF NOT EXISTS idx_task_penalties_task_member ON task_penalties(task_id, member_id);
CREATE INDEX IF NOT EXISTS idx_task_penalty_payments_member_id ON task_penalty_payments(member_id);

ALTER TABLE task_penalty_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_penalties ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_penalty_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view penalty settings"
ON task_penalty_settings;
CREATE POLICY "Authenticated users can view penalty settings"
ON task_penalty_settings FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Authenticated users can view task penalties"
ON task_penalties;
CREATE POLICY "Authenticated users can view task penalties"
ON task_penalties FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Authenticated users can manage task penalties"
ON task_penalties;
CREATE POLICY "Authenticated users can manage task penalties"
ON task_penalties FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can view penalty payments"
ON task_penalty_payments;
CREATE POLICY "Authenticated users can view penalty payments"
ON task_penalty_payments FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Authenticated users can manage penalty payments"
ON task_penalty_payments;
CREATE POLICY "Authenticated users can manage penalty payments"
ON task_penalty_payments FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);
