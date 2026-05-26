-- Attendance type for visitor visit log (same values as church_attendance).

ALTER TABLE visitors
  ADD COLUMN IF NOT EXISTS attendance_type TEXT NOT NULL DEFAULT 'onsite';

ALTER TABLE visitors
  DROP CONSTRAINT IF EXISTS visitors_attendance_type_check;

ALTER TABLE visitors
  ADD CONSTRAINT visitors_attendance_type_check
  CHECK (attendance_type IN ('onsite', 'online', 'absent'));

COMMENT ON COLUMN visitors.attendance_type IS 'How the visitor attended this visit: onsite, online, or absent';
