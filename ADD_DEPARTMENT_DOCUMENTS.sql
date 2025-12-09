-- Add document columns to departments table
-- Run this in Supabase SQL Editor

-- Step 1: Add document columns to departments table
ALTER TABLE departments 
ADD COLUMN IF NOT EXISTS document_1_url TEXT,
ADD COLUMN IF NOT EXISTS document_1_name TEXT,
ADD COLUMN IF NOT EXISTS document_2_url TEXT,
ADD COLUMN IF NOT EXISTS document_2_name TEXT,
ADD COLUMN IF NOT EXISTS document_3_url TEXT,
ADD COLUMN IF NOT EXISTS document_3_name TEXT;

-- Step 2: Add comments for documentation
COMMENT ON COLUMN departments.document_1_url IS 'URL/path to first department document';
COMMENT ON COLUMN departments.document_1_name IS 'Original filename of first document';
COMMENT ON COLUMN departments.document_2_url IS 'URL/path to second department document';
COMMENT ON COLUMN departments.document_2_name IS 'Original filename of second document';
COMMENT ON COLUMN departments.document_3_url IS 'URL/path to third department document';
COMMENT ON COLUMN departments.document_3_name IS 'Original filename of third document';
