-- Add color column to tags (for existing DBs).
ALTER TABLE tags ADD COLUMN IF NOT EXISTS color TEXT;
COMMENT ON COLUMN tags.color IS 'Optional hex color for the tag (e.g. #FF5733).';
