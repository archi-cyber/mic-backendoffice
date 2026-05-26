-- Optional: tie a visitor log entry to a specific church service (sunday / wednesday).
-- Nullable for existing rows (match any service on that visit_date).

ALTER TABLE visitors
  ADD COLUMN IF NOT EXISTS service_type TEXT;

ALTER TABLE visitors
  DROP CONSTRAINT IF EXISTS visitors_service_type_check;

ALTER TABLE visitors
  ADD CONSTRAINT visitors_service_type_check
  CHECK (service_type IS NULL OR service_type IN ('sunday', 'wednesday'));

CREATE INDEX IF NOT EXISTS idx_visitors_visit_date_service_type
  ON visitors(visit_date, service_type)
  WHERE deleted_at IS NULL;

COMMENT ON COLUMN visitors.service_type IS 'Church service when visit was logged: sunday or wednesday; NULL = any service that day';
