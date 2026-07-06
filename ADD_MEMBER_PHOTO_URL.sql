-- Add optional profile photo URL for members.
-- Also create a public Supabase Storage bucket named "member-photos" in the dashboard
-- (Storage → New bucket → name: member-photos → Public bucket).

ALTER TABLE members
ADD COLUMN IF NOT EXISTS photo_url TEXT;

COMMENT ON COLUMN members.photo_url IS 'Public URL of the member profile photo in Supabase Storage';
