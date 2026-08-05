
DROP INDEX IF EXISTS "ux_church_services_date_name_active";
CREATE UNIQUE INDEX "ux_church_services_date_name_active"
  ON "church_services" ("service_date", "name")
  WHERE "deleted_at" IS NULL;

DROP INDEX IF EXISTS "ux_church_attendance_member_service_active";
CREATE UNIQUE INDEX "ux_church_attendance_member_service_active"
  ON "church_attendance" ("member_id", "church_service_id")
  WHERE "deleted_at" IS NULL;

DROP INDEX IF EXISTS "ux_sunday_school_member_date_active";
CREATE UNIQUE INDEX "ux_sunday_school_member_date_active"
  ON "sunday_school_attendance" ("member_id", "attendance_date")
  WHERE "deleted_at" IS NULL;

DROP INDEX IF EXISTS "ux_department_members_one_main";
CREATE UNIQUE INDEX "ux_department_members_one_main"
  ON "department_members" ("member_id")
  WHERE "is_main" = true;

DROP INDEX IF EXISTS "ux_teaching_listeners_active";
CREATE UNIQUE INDEX "ux_teaching_listeners_active"
  ON "teaching_listeners" ("teaching_id", "member_id")
  WHERE "deleted_at" IS NULL;

-- Index de performance sur les lignes vivantes uniquement

CREATE INDEX IF NOT EXISTS "idx_members_active_name"
  ON "members" ("last_name", "first_name")
  WHERE "deleted_at" IS NULL AND "is_active" = true;

CREATE INDEX IF NOT EXISTS "idx_church_attendance_date_active"
  ON "church_attendance" ("service_date" DESC)
  WHERE "deleted_at" IS NULL;

CREATE INDEX IF NOT EXISTS "idx_tasks_open"
  ON "tasks" ("due_date", "status")
  WHERE "deleted_at" IS NULL
    AND "archived_at" IS NULL
    AND "status" IN ('pending', 'in_progress');

CREATE INDEX IF NOT EXISTS "idx_notifications_unread"
  ON "notifications" ("member_id", "created_at" DESC)
  WHERE "is_read" = false;

-- Recherche insensible a la casse sur le nom des membres
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS "idx_members_search_trgm"
  ON "members" USING gin (
    (lower("first_name") || ' ' || lower("last_name")) gin_trgm_ops
  )
  WHERE "deleted_at" IS NULL;