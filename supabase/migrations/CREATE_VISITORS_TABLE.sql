-- Create visitors table for tracking church visitors
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS visitors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  address TEXT,
  visit_date DATE NOT NULL DEFAULT CURRENT_DATE,
  notes TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_visitors_visit_date 
  ON visitors(visit_date DESC) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_visitors_created_at 
  ON visitors(created_at DESC) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_visitors_name 
  ON visitors(first_name, last_name) 
  WHERE deleted_at IS NULL;

-- Enable RLS
ALTER TABLE visitors ENABLE ROW LEVEL SECURITY;

-- RLS policies for visitors
DROP POLICY IF EXISTS "Admins can manage all visitors" ON visitors;
DROP POLICY IF EXISTS "Leaders can manage visitors" ON visitors;
DROP POLICY IF EXISTS "Authenticated users can view visitors" ON visitors;

-- Admins can do everything
CREATE POLICY "Admins can manage all visitors"
  ON visitors FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role = 'admin'
      AND is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role = 'admin'
      AND is_active = true
    )
  );

-- Leaders can manage visitors
CREATE POLICY "Leaders can manage visitors"
  ON visitors FOR ALL
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

-- Authenticated users can view visitors
CREATE POLICY "Authenticated users can view visitors"
  ON visitors FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND deleted_at IS NULL
  );

-- Trigger function to update updated_at
CREATE OR REPLACE FUNCTION update_visitors_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_visitors_updated_at
  BEFORE UPDATE ON visitors
  FOR EACH ROW
  EXECUTE FUNCTION update_visitors_updated_at();

-- Comments
COMMENT ON TABLE visitors IS 'Tracks information about visitors who visit the church';
COMMENT ON COLUMN visitors.visit_date IS 'Date when the visitor came to the church';
COMMENT ON COLUMN visitors.notes IS 'Additional notes about the visitor';
