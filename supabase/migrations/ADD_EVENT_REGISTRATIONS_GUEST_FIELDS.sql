-- Add guest fields to event_registrations table for non-member registrations
-- This allows leaders to register people who are not in the church system

-- Make member_id nullable to support guest registrations
ALTER TABLE event_registrations 
  ALTER COLUMN member_id DROP NOT NULL;

-- Add guest information fields
ALTER TABLE event_registrations 
  ADD COLUMN IF NOT EXISTS guest_name TEXT,
  ADD COLUMN IF NOT EXISTS guest_email TEXT,
  ADD COLUMN IF NOT EXISTS guest_phone TEXT;

-- Add constraint: either member_id or guest_name must be provided
ALTER TABLE event_registrations 
  ADD CONSTRAINT event_registrations_member_or_guest_check 
  CHECK (
    (member_id IS NOT NULL AND guest_name IS NULL) OR 
    (member_id IS NULL AND guest_name IS NOT NULL)
  );

-- Add index for guest searches
CREATE INDEX IF NOT EXISTS idx_event_registrations_guest_name 
  ON event_registrations(guest_name);

-- Add comment
COMMENT ON COLUMN event_registrations.guest_name IS 'Name of non-member guest registered for the event';
COMMENT ON COLUMN event_registrations.guest_email IS 'Email of non-member guest (optional)';
COMMENT ON COLUMN event_registrations.guest_phone IS 'Phone of non-member guest (optional)';
