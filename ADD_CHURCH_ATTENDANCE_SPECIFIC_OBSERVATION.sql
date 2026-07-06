-- Optional per-member note for a church attendance row (date + service type).

ALTER TABLE church_attendance
  ADD COLUMN IF NOT EXISTS specific_observation TEXT;

COMMENT ON COLUMN church_attendance.specific_observation IS
  'Optional note for this member attendance (e.g. reason for absence)';
