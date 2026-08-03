-- Media Team service schedule: one row per service date, assignments per role/member.

CREATE TABLE IF NOT EXISTS service_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  service_date DATE NOT NULL,
  notes TEXT,
  created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT service_schedules_department_date_unique UNIQUE (department_id, service_date)
);

CREATE TABLE IF NOT EXISTS service_schedule_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES service_schedules(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (
    role IN (
      'projection',
      'call_recording',
      'principal_cameraman',
      'secondary_cameraman',
      'photographer'
    )
  ),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  is_done BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT service_schedule_assignments_unique UNIQUE (schedule_id, role, member_id)
);

CREATE INDEX IF NOT EXISTS idx_service_schedules_department_id
  ON service_schedules(department_id);

CREATE INDEX IF NOT EXISTS idx_service_schedules_service_date
  ON service_schedules(service_date DESC);

CREATE INDEX IF NOT EXISTS idx_service_schedule_assignments_schedule_id
  ON service_schedule_assignments(schedule_id);

CREATE INDEX IF NOT EXISTS idx_service_schedule_assignments_role
  ON service_schedule_assignments(schedule_id, role);

ALTER TABLE service_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_schedule_assignments ENABLE ROW LEVEL SECURITY;

-- service_schedules policies
DROP POLICY IF EXISTS "Admins manage service schedules" ON service_schedules;
DROP POLICY IF EXISTS "Dept members view service schedules" ON service_schedules;
DROP POLICY IF EXISTS "Dept leaders create service schedules" ON service_schedules;
DROP POLICY IF EXISTS "Dept leaders update service schedules" ON service_schedules;
DROP POLICY IF EXISTS "Dept leaders delete service schedules" ON service_schedules;

CREATE POLICY "Admins manage service schedules"
  ON service_schedules FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'admin' AND is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'admin' AND is_active = true
    )
  );

CREATE POLICY "Dept members view service schedules"
  ON service_schedules FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND (
      EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid() AND role IN ('admin', 'leader') AND is_active = true
      )
      OR EXISTS (
        SELECT 1
        FROM users u
        JOIN department_members dm ON u.member_id = dm.member_id
        WHERE u.id = auth.uid()
          AND dm.department_id = service_schedules.department_id
          AND u.is_active = true
      )
    )
  );

CREATE POLICY "Dept leaders create service schedules"
  ON service_schedules FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND created_by = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM users u
      JOIN department_members dm ON u.member_id = dm.member_id
      WHERE u.id = auth.uid()
        AND dm.department_id = service_schedules.department_id
        AND dm.role IN ('leader', 'subleader')
        AND u.is_active = true
    )
  );

CREATE POLICY "Dept leaders update service schedules"
  ON service_schedules FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM users u
      JOIN department_members dm ON u.member_id = dm.member_id
      WHERE u.id = auth.uid()
        AND dm.department_id = service_schedules.department_id
        AND dm.role IN ('leader', 'subleader')
        AND u.is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM users u
      JOIN department_members dm ON u.member_id = dm.member_id
      WHERE u.id = auth.uid()
        AND dm.department_id = service_schedules.department_id
        AND dm.role IN ('leader', 'subleader')
        AND u.is_active = true
    )
  );

CREATE POLICY "Dept leaders delete service schedules"
  ON service_schedules FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM users u
      JOIN department_members dm ON u.member_id = dm.member_id
      WHERE u.id = auth.uid()
        AND dm.department_id = service_schedules.department_id
        AND dm.role IN ('leader', 'subleader')
        AND u.is_active = true
    )
  );

-- service_schedule_assignments policies
DROP POLICY IF EXISTS "Admins manage service schedule assignments" ON service_schedule_assignments;
DROP POLICY IF EXISTS "Dept members view service schedule assignments" ON service_schedule_assignments;
DROP POLICY IF EXISTS "Dept leaders manage service schedule assignments" ON service_schedule_assignments;

CREATE POLICY "Admins manage service schedule assignments"
  ON service_schedule_assignments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'admin' AND is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'admin' AND is_active = true
    )
  );

CREATE POLICY "Dept members view service schedule assignments"
  ON service_schedule_assignments FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM service_schedules ss
      WHERE ss.id = service_schedule_assignments.schedule_id
        AND (
          EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid() AND role IN ('admin', 'leader') AND is_active = true
          )
          OR EXISTS (
            SELECT 1
            FROM users u
            JOIN department_members dm ON u.member_id = dm.member_id
            WHERE u.id = auth.uid()
              AND dm.department_id = ss.department_id
              AND u.is_active = true
          )
        )
    )
  );

CREATE POLICY "Dept leaders manage service schedule assignments"
  ON service_schedule_assignments FOR ALL
  USING (
    EXISTS (
      SELECT 1
      FROM service_schedules ss
      JOIN users u ON u.id = auth.uid()
      JOIN department_members dm ON u.member_id = dm.member_id
      WHERE ss.id = service_schedule_assignments.schedule_id
        AND dm.department_id = ss.department_id
        AND dm.role IN ('leader', 'subleader')
        AND u.is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM service_schedules ss
      JOIN users u ON u.id = auth.uid()
      JOIN department_members dm ON u.member_id = dm.member_id
      WHERE ss.id = service_schedule_assignments.schedule_id
        AND dm.department_id = ss.department_id
        AND dm.role IN ('leader', 'subleader')
        AND u.is_active = true
    )
  );

CREATE OR REPLACE FUNCTION update_service_schedules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_service_schedules_updated_at ON service_schedules;
CREATE TRIGGER update_service_schedules_updated_at
  BEFORE UPDATE ON service_schedules
  FOR EACH ROW
  EXECUTE FUNCTION update_service_schedules_updated_at();

COMMENT ON TABLE service_schedules IS 'Media team service dates with optional notes';
COMMENT ON TABLE service_schedule_assignments IS 'Member assignments per role for a service date';
