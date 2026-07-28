-- SysteMIC Church Backoffice — consolidated public schema (end state)
-- Derived from repository root *.sql, supabase/migrations, and lib/services/*.dart
-- For fresh installs: run in Supabase SQL Editor after enabling pgcrypto/gen_random_uuid.
-- Does not create auth.users; sync trigger expects public.users.id = auth.users.id.

-- =============================================================================
-- ENUMS
-- =============================================================================

DO $$ BEGIN
  CREATE TYPE giving_tag_enum AS ENUM (
    'construction', 'special_op', 'tithe', 'offering', 'gift', 'other'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =============================================================================
-- DEPARTMENTS (before members.department_id FK)
-- =============================================================================

CREATE TABLE IF NOT EXISTS departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  document_1_url TEXT,
  document_1_name TEXT,
  document_2_url TEXT,
  document_2_name TEXT,
  document_3_url TEXT,
  document_3_name TEXT,
  task_penalty_amount INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- CORE: MEMBERS & AUTH PROFILE
-- =============================================================================

CREATE TABLE IF NOT EXISTS members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  birthday DATE,
  address TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  country TEXT,
  quarter TEXT,
  profession TEXT CHECK (profession IS NULL OR profession IN (
    'primary_school_student', 'secondary_school_student', 'university_student',
    'job_seeking', 'worker'
  )),
  level_of_study TEXT,
  sector_of_studies TEXT,
  domain_of_activity TEXT,
  key_skills TEXT[],
  last_diplomas TEXT,
  gender TEXT,
  marital_status TEXT,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN (
    'admin', 'leader', 'member', 'worker', 'sympathiser'
  )),
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  is_new_comer BOOLEAN NOT NULL DEFAULT false,
  newcomer_join_date DATE,
  newcomer_intention TEXT CHECK (newcomer_intention IS NULL OR newcomer_intention IN (
    'wants_to_stay', 'does_not_know_yet', 'just_passing'
  )),
  is_active BOOLEAN NOT NULL DEFAULT true,
  birthday_notifications_opt_out BOOLEAN NOT NULL DEFAULT false,
  photo_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_members_role ON members(role);
CREATE INDEX IF NOT EXISTS idx_members_profession ON members(profession) WHERE profession IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_members_is_new_comer ON members(is_new_comer)
  WHERE is_new_comer = true AND is_active = true;
CREATE INDEX IF NOT EXISTS idx_members_newcomer_intention ON members(newcomer_intention)
  WHERE is_new_comer = true AND newcomer_intention IS NOT NULL;

COMMENT ON TABLE members IS 'Church member profiles; soft-deleted via deleted_at + is_active=false';

-- users: app profile linked to Supabase Auth (id matches auth.users.id when synced)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  email TEXT,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'member',
  member_id UUID REFERENCES members(id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  must_change_password BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_member_id ON users(member_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

CREATE TABLE IF NOT EXISTS user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_token TEXT NOT NULL,
  platform TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, device_token)
);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON user_devices(user_id);

CREATE TABLE IF NOT EXISTS department_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('leader', 'subleader', 'member')),
  is_main BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (department_id, member_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_department_members_one_main_per_member
  ON department_members(member_id) WHERE is_main = true;
CREATE INDEX IF NOT EXISTS idx_department_members_is_main
  ON department_members(member_id, is_main) WHERE is_main = true;

CREATE TABLE IF NOT EXISTS department_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  defined_objectives TEXT NOT NULL,
  positive_points TEXT NOT NULL,
  difficulties_encountered TEXT NOT NULL,
  suggestions TEXT NOT NULL,
  comments TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_department_reports_department_id
  ON department_reports(department_id) WHERE deleted_at IS NULL;

-- =============================================================================
-- TRAINING (CLASSES) & SESSION ATTENDANCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS class_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  enrolled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (class_id, member_id)
);

CREATE TABLE IF NOT EXISTS sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  session_date TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_class_id ON sessions(class_id);

CREATE TABLE IF NOT EXISTS attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (session_id, member_id)
);

-- =============================================================================
-- EVENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  event_date DATE NOT NULL,
  event_time TIME,
  location TEXT,
  is_repeated BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS event_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  session_date TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS event_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  member_id UUID REFERENCES members(id) ON DELETE CASCADE,
  guest_name TEXT,
  guest_email TEXT,
  guest_phone TEXT,
  registered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT event_registrations_member_or_guest_check CHECK (
    (member_id IS NOT NULL AND guest_name IS NULL) OR
    (member_id IS NULL AND guest_name IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_event_registrations_guest_name ON event_registrations(guest_name);

CREATE TABLE IF NOT EXISTS event_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  session_id UUID REFERENCES event_sessions(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- CHURCH SERVICES & ATTENDANCE
-- =============================================================================

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
  ON church_services (service_date, name) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_church_services_service_date
  ON church_services (service_date DESC) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS church_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  church_service_id UUID NOT NULL REFERENCES church_services(id),
  service_date DATE NOT NULL,
  attendance_type TEXT NOT NULL DEFAULT 'onsite'
    CHECK (attendance_type IN ('onsite', 'online', 'absent')),
  specific_observation TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_church_attendance_member_service_not_deleted
  ON church_attendance (member_id, church_service_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_church_attendance_church_service_id
  ON church_attendance (church_service_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_church_attendance_member_id
  ON church_attendance(member_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_church_attendance_service_date
  ON church_attendance(service_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_church_attendance_type
  ON church_attendance(attendance_type) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS sunday_school_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  attendance_date DATE NOT NULL,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_sunday_school_attendance_member_date_not_deleted
  ON sunday_school_attendance(member_id, attendance_date) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS visitors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  address TEXT,
  visit_date DATE NOT NULL DEFAULT CURRENT_DATE,
  church_service_id UUID REFERENCES church_services(id),
  attendance_type TEXT NOT NULL DEFAULT 'onsite'
    CHECK (attendance_type IN ('onsite', 'online', 'absent')),
  notes TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_visitors_visit_date ON visitors(visit_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_visitors_church_service_id ON visitors(church_service_id) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS new_comers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID REFERENCES members(id) ON DELETE SET NULL,
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  phone TEXT,
  newcomer_join_date DATE NOT NULL DEFAULT CURRENT_DATE,
  newcomer_intention TEXT CHECK (
    newcomer_intention IS NULL OR newcomer_intention IN (
      'wants_to_stay', 'does_not_know_yet', 'just_passing'
    )
  ),
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- =============================================================================
-- TEACHINGS
-- =============================================================================

CREATE TABLE IF NOT EXISTS teachings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  teaching_date DATE NOT NULL,
  description TEXT,
  speaker TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS teaching_listeners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teaching_id UUID NOT NULL REFERENCES teachings(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (teaching_id, member_id)
);

-- =============================================================================
-- TASKS, PROJECTS, TAGS, PENALTIES
-- =============================================================================

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

CREATE TABLE IF NOT EXISTS tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (department_id, name)
);

CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID REFERENCES departments(id) ON DELETE CASCADE,
  member_id UUID REFERENCES members(id) ON DELETE CASCADE,
  project_id UUID REFERENCES projects(id) ON DELETE SET NULL,
  teaching_id UUID REFERENCES teachings(id) ON DELETE SET NULL,
  teaching_task_type TEXT CHECK (
    teaching_task_type IS NULL OR teaching_task_type IN ('mid', 'short', 'full')
  ),
  teaching_task_index INTEGER,
  penalty_amount_per_day INTEGER,
  archived_at TIMESTAMPTZ,
  title TEXT NOT NULL,
  description TEXT,
  due_date DATE,
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT tasks_department_or_member_check CHECK (
    (department_id IS NOT NULL AND member_id IS NULL) OR
    (department_id IS NULL AND member_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_tasks_member_id ON tasks(member_id);
CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_teaching_id ON tasks(teaching_id);

CREATE TABLE IF NOT EXISTS task_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (task_id, member_id)
);

CREATE TABLE IF NOT EXISTS task_tags (
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (task_id, tag_id)
);

CREATE TABLE IF NOT EXISTS task_penalty_settings (
  id TEXT PRIMARY KEY DEFAULT 'global',
  default_daily_penalty_amount INTEGER NOT NULL DEFAULT 100,
  blocking_threshold_amount INTEGER NOT NULL DEFAULT 3500,
  teaching_task_due_offset_days INTEGER NOT NULL DEFAULT 10,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

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

-- =============================================================================
-- FINANCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS giving (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  giver_name TEXT NOT NULL,
  member_id UUID REFERENCES members(id) ON DELETE SET NULL,
  amount NUMERIC(10, 2) NOT NULL,
  tag giving_tag_enum NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('expense', 'receiving')),
  notes TEXT,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_giving_member_id ON giving(member_id);
CREATE INDEX IF NOT EXISTS idx_giving_date ON giving(date);

-- =============================================================================
-- COMMUNICATIONS & SETTINGS
-- =============================================================================

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID REFERENCES members(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT,
  message TEXT,
  related_id UUID,
  related_type TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  read_at TIMESTAMPTZ,
  scheduled_for DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  is_global BOOLEAN NOT NULL DEFAULT true,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  target_member_ids UUID[],
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value JSONB,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS leader_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  feature_name TEXT NOT NULL,
  can_view BOOLEAN NOT NULL DEFAULT false,
  can_create BOOLEAN NOT NULL DEFAULT false,
  can_edit BOOLEAN NOT NULL DEFAULT false,
  can_delete BOOLEAN NOT NULL DEFAULT false,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (user_id, feature_name)
);

-- =============================================================================
-- MEDIA TEAM SERVICE SCHEDULE
-- =============================================================================

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
  role TEXT NOT NULL CHECK (role IN (
    'projection', 'call_recording', 'principal_cameraman',
    'secondary_cameraman', 'photographer'
  )),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  is_done BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT service_schedule_assignments_unique UNIQUE (schedule_id, role, member_id)
);

-- =============================================================================
-- KEY FUNCTIONS & TRIGGERS (subset; see DATABASE_SCHEMA.md for RLS policies)
-- =============================================================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin' AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_leader()
RETURNS BOOLEAN AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid()
      AND role IN ('admin', 'leader') AND is_active = true
  ) THEN RETURN true; END IF;
  RETURN EXISTS (
    SELECT 1 FROM users u
    JOIN department_members dm ON u.member_id = dm.member_id
    WHERE u.id = auth.uid() AND u.is_active = true
      AND dm.role IN ('leader', 'subleader')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_finance_leader()
RETURNS BOOLEAN AS $$
BEGIN
  IF is_admin() THEN RETURN true; END IF;
  RETURN EXISTS (
    SELECT 1 FROM users u
    JOIN department_members dm ON u.member_id = dm.member_id
    JOIN departments d ON dm.department_id = d.id
    WHERE u.id = auth.uid() AND u.role = 'leader' AND u.is_active = true
      AND LOWER(TRIM(d.name)) = 'finance' AND d.is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION current_user_member_id()
RETURNS UUID AS $$
  SELECT member_id FROM users WHERE id = auth.uid();
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION check_and_update_new_comer_status(member_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE attendance_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO attendance_count FROM church_attendance
  WHERE member_id = member_uuid
    AND service_date >= CURRENT_DATE - INTERVAL '90 days'
    AND deleted_at IS NULL;
  IF attendance_count >= 9 THEN
    UPDATE members SET is_new_comer = false, updated_at = NOW()
    WHERE id = member_uuid AND is_new_comer = true;
    RETURN true;
  END IF;
  RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION trigger_check_new_comer_status()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM members WHERE id = NEW.member_id AND is_new_comer = true) THEN
    PERFORM check_and_update_new_comer_status(NEW.member_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_new_comer_after_attendance ON church_attendance;
CREATE TRIGGER check_new_comer_after_attendance
  AFTER INSERT ON church_attendance FOR EACH ROW
  WHEN (NEW.deleted_at IS NULL)
  EXECUTE FUNCTION trigger_check_new_comer_status();

-- Teaching listener sync (post church_services migration)
CREATE OR REPLACE FUNCTION auto_populate_teaching_listeners(teaching_uuid UUID)
RETURNS INTEGER AS $$
DECLARE teaching_date_val DATE; inserted_count INTEGER := 0; current_user_id UUID; has_attendance BOOLEAN := false;
BEGIN
  SELECT teaching_date, created_by INTO teaching_date_val, current_user_id
  FROM teachings WHERE id = teaching_uuid AND deleted_at IS NULL;
  IF teaching_date_val IS NULL THEN RETURN 0; END IF;
  SELECT EXISTS (
    SELECT 1 FROM church_attendance ca
    INNER JOIN church_services cs ON cs.id = ca.church_service_id
    WHERE cs.service_date = teaching_date_val AND ca.deleted_at IS NULL AND cs.deleted_at IS NULL
  ) INTO has_attendance;
  IF NOT has_attendance THEN RETURN 0; END IF;
  INSERT INTO teaching_listeners (teaching_id, member_id, created_by, created_at, updated_at)
  SELECT teaching_uuid, ca.member_id, current_user_id, NOW(), NOW()
  FROM church_attendance ca
  INNER JOIN church_services cs ON cs.id = ca.church_service_id
  INNER JOIN members m ON m.id = ca.member_id
  WHERE cs.service_date = teaching_date_val AND ca.deleted_at IS NULL AND cs.deleted_at IS NULL
    AND ca.attendance_type IN ('onsite', 'online')
    AND m.role IN ('worker', 'leader', 'admin')
    AND NOT EXISTS (
      SELECT 1 FROM teaching_listeners tl
      WHERE tl.teaching_id = teaching_uuid AND tl.member_id = ca.member_id AND tl.deleted_at IS NULL
    )
  ON CONFLICT (teaching_id, member_id) DO NOTHING;
  GET DIAGNOSTICS inserted_count = ROW_COUNT;
  RETURN inserted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sync_teaching_listeners(teaching_uuid UUID)
RETURNS INTEGER AS $$
DECLARE teaching_date_val DATE; inserted_count INTEGER := 0; current_user_id UUID; has_attendance BOOLEAN := false;
BEGIN
  SELECT teaching_date INTO teaching_date_val FROM teachings WHERE id = teaching_uuid AND deleted_at IS NULL;
  IF teaching_date_val IS NULL THEN RETURN 0; END IF;
  SELECT EXISTS (
    SELECT 1 FROM church_attendance ca
    INNER JOIN church_services cs ON cs.id = ca.church_service_id
    WHERE cs.service_date = teaching_date_val AND ca.deleted_at IS NULL AND cs.deleted_at IS NULL
  ) INTO has_attendance;
  IF NOT has_attendance THEN RETURN 0; END IF;
  current_user_id := auth.uid();
  INSERT INTO teaching_listeners (teaching_id, member_id, created_by, created_at, updated_at)
  SELECT teaching_uuid, ca.member_id, current_user_id, NOW(), NOW()
  FROM church_attendance ca
  INNER JOIN church_services cs ON cs.id = ca.church_service_id
  INNER JOIN members m ON m.id = ca.member_id
  WHERE cs.service_date = teaching_date_val AND ca.deleted_at IS NULL AND cs.deleted_at IS NULL
    AND ca.attendance_type IN ('onsite', 'online')
    AND m.role IN ('worker', 'leader', 'admin')
    AND NOT EXISTS (
      SELECT 1 FROM teaching_listeners tl
      WHERE tl.teaching_id = teaching_uuid AND tl.member_id = ca.member_id AND tl.deleted_at IS NULL
    )
  ON CONFLICT (teaching_id, member_id) DO NOTHING;
  GET DIAGNOSTICS inserted_count = ROW_COUNT;
  RETURN inserted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION trigger_auto_populate_teaching_listeners()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.deleted_at IS NULL THEN PERFORM auto_populate_teaching_listeners(NEW.id); END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS auto_populate_listeners_on_teaching_create ON teachings;
CREATE TRIGGER auto_populate_listeners_on_teaching_create
  AFTER INSERT ON teachings FOR EACH ROW
  WHEN (NEW.deleted_at IS NULL)
  EXECUTE FUNCTION trigger_auto_populate_teaching_listeners();

-- Auth sync (public.users)
CREATE OR REPLACE FUNCTION sync_auth_user_to_users()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO users (id, email, phone, role, created_at, updated_at)
  VALUES (
    NEW.id, NEW.email, COALESCE(NEW.phone, NULL),
    COALESCE((NEW.raw_user_meta_data->>'role')::text, 'member'),
    COALESCE(NEW.created_at, NOW()), NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    phone = COALESCE(EXCLUDED.phone, users.phone),
    role = COALESCE(EXCLUDED.role, users.role),
    updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- NOTE: Enable RLS and apply policies from ENABLE_RLS_ALL_TABLES.sql and feature-specific SQL scripts.
