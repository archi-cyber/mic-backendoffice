-- Create newcomer history table for time-based newcomer reporting
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS new_comers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID REFERENCES members(id) ON DELETE SET NULL,
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  phone TEXT,
  newcomer_join_date DATE NOT NULL DEFAULT CURRENT_DATE,
  newcomer_intention TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

ALTER TABLE new_comers
DROP CONSTRAINT IF EXISTS new_comers_newcomer_intention_check;

ALTER TABLE new_comers
ADD CONSTRAINT new_comers_newcomer_intention_check
CHECK (
  newcomer_intention IS NULL
  OR newcomer_intention IN ('wants_to_stay', 'does_not_know_yet', 'just_passing')
);

CREATE INDEX IF NOT EXISTS idx_new_comers_join_date
  ON new_comers(newcomer_join_date DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_new_comers_member_id
  ON new_comers(member_id)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_new_comers_created_at
  ON new_comers(created_at DESC)
  WHERE deleted_at IS NULL;

ALTER TABLE new_comers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all new_comers" ON new_comers;
DROP POLICY IF EXISTS "Leaders can manage new_comers" ON new_comers;
DROP POLICY IF EXISTS "Authenticated users can view new_comers" ON new_comers;

CREATE POLICY "Admins can manage all new_comers"
  ON new_comers FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
        AND role = 'admin'
        AND is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
        AND role = 'admin'
        AND is_active = true
    )
  );

CREATE POLICY "Leaders can manage new_comers"
  ON new_comers FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
        AND role IN ('admin', 'leader')
        AND is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
        AND role IN ('admin', 'leader')
        AND is_active = true
    )
  );

CREATE POLICY "Authenticated users can view new_comers"
  ON new_comers FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND deleted_at IS NULL
  );

CREATE OR REPLACE FUNCTION update_new_comers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_new_comers_updated_at ON new_comers;
CREATE TRIGGER update_new_comers_updated_at
  BEFORE UPDATE ON new_comers
  FOR EACH ROW
  EXECUTE FUNCTION update_new_comers_updated_at();

COMMENT ON TABLE new_comers IS 'History of members created as newcomers, used for newcomer reports';
COMMENT ON COLUMN new_comers.newcomer_join_date IS 'Date the person joined as newcomer';
COMMENT ON COLUMN new_comers.member_id IS 'Linked member record if the person was created from members';
