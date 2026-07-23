-- Migrate church attendance from (service_date + service_type) to church_services
-- (service_date + required name). Multiple services per day are allowed.
-- Run in Supabase SQL Editor.

-- 1) church_services table
CREATE TABLE IF NOT EXISTS church_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_date DATE NOT NULL,
  name TEXT NOT NULL,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_church_services_date_name_not_deleted
  ON church_services (service_date, name)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_church_services_service_date
  ON church_services (service_date DESC)
  WHERE deleted_at IS NULL;

ALTER TABLE church_services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage church services" ON church_services;
DROP POLICY IF EXISTS "Leaders can manage church services" ON church_services;
DROP POLICY IF EXISTS "Authenticated users can view church services" ON church_services;

CREATE POLICY "Admins can manage church services"
  ON church_services FOR ALL
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

CREATE POLICY "Leaders can manage church services"
  ON church_services FOR ALL
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

CREATE POLICY "Authenticated users can view church services"
  ON church_services FOR SELECT
  USING (auth.uid() IS NOT NULL AND deleted_at IS NULL);

CREATE OR REPLACE FUNCTION update_church_services_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_church_services_updated_at ON church_services;
CREATE TRIGGER update_church_services_updated_at
  BEFORE UPDATE ON church_services
  FOR EACH ROW
  EXECUTE FUNCTION update_church_services_updated_at();

COMMENT ON TABLE church_services IS
  'Church gatherings identified by date + name; multiple services per day allowed';

-- Seed from ALL attendance pairs (including soft-deleted) so later backfill can link them
INSERT INTO church_services (service_date, name)
SELECT DISTINCT
  ca.service_date,
  CASE ca.service_type
    WHEN 'sunday' THEN 'Sunday Service'
    WHEN 'wednesday' THEN 'Wednesday Service'
    ELSE INITCAP(COALESCE(ca.service_type, 'unknown')) || ' Service'
  END AS service_name
FROM church_attendance ca
WHERE ca.service_type IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM church_services cs
    WHERE cs.service_date = ca.service_date
      AND cs.deleted_at IS NULL
      AND cs.name = CASE ca.service_type
        WHEN 'sunday' THEN 'Sunday Service'
        WHEN 'wednesday' THEN 'Wednesday Service'
        ELSE INITCAP(COALESCE(ca.service_type, 'unknown')) || ' Service'
      END
  );

-- Also seed from visitors that have a service_type but no matching attendance service
INSERT INTO church_services (service_date, name)
SELECT DISTINCT
  v.visit_date,
  CASE v.service_type
    WHEN 'sunday' THEN 'Sunday Service'
    WHEN 'wednesday' THEN 'Wednesday Service'
    ELSE INITCAP(COALESCE(v.service_type, 'unknown')) || ' Service'
  END AS service_name
FROM visitors v
WHERE v.service_type IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM church_services cs
    WHERE cs.service_date = v.visit_date
      AND cs.deleted_at IS NULL
      AND cs.name = CASE v.service_type
        WHEN 'sunday' THEN 'Sunday Service'
        WHEN 'wednesday' THEN 'Wednesday Service'
        ELSE INITCAP(COALESCE(v.service_type, 'unknown')) || ' Service'
      END
  );

-- 3) Add church_service_id to attendance
ALTER TABLE church_attendance
  ADD COLUMN IF NOT EXISTS church_service_id UUID REFERENCES church_services(id);

UPDATE church_attendance ca
SET church_service_id = cs.id
FROM church_services cs
WHERE ca.church_service_id IS NULL
  AND ca.service_date = cs.service_date
  AND cs.deleted_at IS NULL
  AND cs.name = CASE ca.service_type
    WHEN 'sunday' THEN 'Sunday Service'
    WHEN 'wednesday' THEN 'Wednesday Service'
    ELSE INITCAP(COALESCE(ca.service_type, 'unknown')) || ' Service'
  END;

-- Any remaining orphans (unexpected service_type): create fallback services
INSERT INTO church_services (service_date, name)
SELECT DISTINCT
  ca.service_date,
  CASE ca.service_type
    WHEN 'sunday' THEN 'Sunday Service'
    WHEN 'wednesday' THEN 'Wednesday Service'
    ELSE INITCAP(COALESCE(ca.service_type, 'unknown')) || ' Service'
  END AS service_name
FROM church_attendance ca
WHERE ca.church_service_id IS NULL
  AND NOT EXISTS (
    SELECT 1
    FROM church_services cs
    WHERE cs.service_date = ca.service_date
      AND cs.deleted_at IS NULL
      AND cs.name = CASE ca.service_type
        WHEN 'sunday' THEN 'Sunday Service'
        WHEN 'wednesday' THEN 'Wednesday Service'
        ELSE INITCAP(COALESCE(ca.service_type, 'unknown')) || ' Service'
      END
  );

UPDATE church_attendance ca
SET church_service_id = cs.id
FROM church_services cs
WHERE ca.church_service_id IS NULL
  AND ca.service_date = cs.service_date
  AND cs.deleted_at IS NULL
  AND cs.name = CASE ca.service_type
    WHEN 'sunday' THEN 'Sunday Service'
    WHEN 'wednesday' THEN 'Wednesday Service'
    ELSE INITCAP(COALESCE(ca.service_type, 'unknown')) || ' Service'
  END;

-- Fail loudly if any attendance remains unlinked (including soft-deleted)
DO $$
DECLARE
  orphan_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO orphan_count
  FROM church_attendance
  WHERE church_service_id IS NULL;
  IF orphan_count > 0 THEN
    RAISE EXCEPTION
      'Migration blocked: % church_attendance rows still missing church_service_id',
      orphan_count;
  END IF;
END $$;

ALTER TABLE church_attendance
  ALTER COLUMN church_service_id SET NOT NULL;

DROP INDEX IF EXISTS ux_church_attendance_member_date_type_not_deleted;
DROP INDEX IF EXISTS idx_church_attendance_service_type;
DROP INDEX IF EXISTS idx_church_attendance_member_date_type;

CREATE UNIQUE INDEX IF NOT EXISTS ux_church_attendance_member_service_not_deleted
  ON church_attendance (member_id, church_service_id)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_church_attendance_church_service_id
  ON church_attendance (church_service_id)
  WHERE deleted_at IS NULL;

-- Drop legacy service_type (keep service_date denormalized for date filters)
ALTER TABLE church_attendance DROP CONSTRAINT IF EXISTS church_attendance_service_type_check;
ALTER TABLE church_attendance DROP COLUMN IF EXISTS service_type;

COMMENT ON COLUMN church_attendance.church_service_id IS
  'FK to church_services; identifies which gathering this attendance belongs to';
COMMENT ON COLUMN church_attendance.service_date IS
  'Denormalized service date (copied from church_services.service_date)';

-- 4) Visitors: church_service_id replaces service_type
ALTER TABLE visitors
  ADD COLUMN IF NOT EXISTS church_service_id UUID REFERENCES church_services(id);

UPDATE visitors v
SET church_service_id = cs.id
FROM church_services cs
WHERE v.church_service_id IS NULL
  AND v.service_type IS NOT NULL
  AND v.visit_date = cs.service_date
  AND cs.deleted_at IS NULL
  AND cs.name = CASE v.service_type
    WHEN 'sunday' THEN 'Sunday Service'
    WHEN 'wednesday' THEN 'Wednesday Service'
    ELSE INITCAP(COALESCE(v.service_type, 'unknown')) || ' Service'
  END;

ALTER TABLE visitors DROP CONSTRAINT IF EXISTS visitors_service_type_check;
DROP INDEX IF EXISTS idx_visitors_visit_date_service_type;
ALTER TABLE visitors DROP COLUMN IF EXISTS service_type;

CREATE INDEX IF NOT EXISTS idx_visitors_church_service_id
  ON visitors (church_service_id)
  WHERE deleted_at IS NULL;

COMMENT ON COLUMN visitors.church_service_id IS
  'Optional FK to church_services; NULL = visit not tied to a specific service';

-- 5) Teaching listener sync: any church service on the teaching date
-- Keep RETURNS INTEGER signatures; only update bodies to use church_service_id.
CREATE OR REPLACE FUNCTION auto_populate_teaching_listeners(teaching_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
  teaching_date_val DATE;
  inserted_count INTEGER := 0;
  current_user_id UUID;
  has_attendance BOOLEAN := false;
BEGIN
  SELECT teaching_date, created_by INTO teaching_date_val, current_user_id
  FROM teachings
  WHERE id = teaching_uuid AND deleted_at IS NULL;

  IF teaching_date_val IS NULL THEN
    RETURN 0;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM church_attendance ca
    INNER JOIN church_services cs ON cs.id = ca.church_service_id
    WHERE cs.service_date = teaching_date_val
      AND ca.deleted_at IS NULL
      AND cs.deleted_at IS NULL
  ) INTO has_attendance;

  IF NOT has_attendance THEN
    RETURN 0;
  END IF;

  INSERT INTO teaching_listeners (teaching_id, member_id, created_by, created_at, updated_at)
  SELECT
    teaching_uuid,
    ca.member_id,
    current_user_id,
    NOW(),
    NOW()
  FROM church_attendance ca
  INNER JOIN church_services cs ON cs.id = ca.church_service_id
  INNER JOIN members m ON m.id = ca.member_id
  WHERE cs.service_date = teaching_date_val
    AND ca.deleted_at IS NULL
    AND cs.deleted_at IS NULL
    AND ca.attendance_type IN ('onsite', 'online')
    AND m.role IN ('worker', 'leader', 'admin')
    AND NOT EXISTS (
      SELECT 1 FROM teaching_listeners tl
      WHERE tl.teaching_id = teaching_uuid
        AND tl.member_id = ca.member_id
        AND tl.deleted_at IS NULL
    )
  ON CONFLICT (teaching_id, member_id) DO NOTHING;

  GET DIAGNOSTICS inserted_count = ROW_COUNT;

  RETURN inserted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_teaching_listeners(teaching_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
  teaching_date_val DATE;
  inserted_count INTEGER := 0;
  current_user_id UUID;
  has_attendance BOOLEAN := false;
BEGIN
  SELECT teaching_date INTO teaching_date_val
  FROM teachings
  WHERE id = teaching_uuid AND deleted_at IS NULL;

  IF teaching_date_val IS NULL THEN
    RETURN 0;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM church_attendance ca
    INNER JOIN church_services cs ON cs.id = ca.church_service_id
    WHERE cs.service_date = teaching_date_val
      AND ca.deleted_at IS NULL
      AND cs.deleted_at IS NULL
  ) INTO has_attendance;

  IF NOT has_attendance THEN
    RETURN 0;
  END IF;

  current_user_id := auth.uid();

  INSERT INTO teaching_listeners (teaching_id, member_id, created_by, created_at, updated_at)
  SELECT
    teaching_uuid,
    ca.member_id,
    current_user_id,
    NOW(),
    NOW()
  FROM church_attendance ca
  INNER JOIN church_services cs ON cs.id = ca.church_service_id
  INNER JOIN members m ON m.id = ca.member_id
  WHERE cs.service_date = teaching_date_val
    AND ca.deleted_at IS NULL
    AND cs.deleted_at IS NULL
    AND ca.attendance_type IN ('onsite', 'online')
    AND m.role IN ('worker', 'leader', 'admin')
    AND NOT EXISTS (
      SELECT 1 FROM teaching_listeners tl
      WHERE tl.teaching_id = teaching_uuid
        AND tl.member_id = ca.member_id
        AND tl.deleted_at IS NULL
    )
  ON CONFLICT (teaching_id, member_id) DO NOTHING;

  GET DIAGNOSTICS inserted_count = ROW_COUNT;

  RETURN inserted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION auto_populate_teaching_listeners IS
  'Populates teaching_listeners from church attendance on the teaching date (any church service).';
COMMENT ON FUNCTION sync_teaching_listeners IS
  'Manually syncs teaching_listeners from church attendance on the teaching date (any church service).';
