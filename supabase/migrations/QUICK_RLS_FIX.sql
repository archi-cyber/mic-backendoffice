-- Quick RLS Fix for Member Creation
-- Run this in Supabase SQL Editor

-- Step 1: Drop the existing policy
DROP POLICY IF EXISTS "Only admins can insert members" ON members;

-- Step 2: Create a fixed policy that checks both users table and auth metadata
CREATE POLICY "Only admins can insert members"
  ON members FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      -- Check users table
      EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'pastor')
      ) OR
      -- Check auth.users metadata (if role is stored there)
      EXISTS (
        SELECT 1 FROM auth.users 
        WHERE id = auth.uid() 
        AND (raw_user_meta_data->>'role' IN ('admin', 'pastor'))
      )
    )
  );

-- Step 3: Also fix the update policy
DROP POLICY IF EXISTS "Only admins can update members" ON members;

CREATE POLICY "Only admins can update members"
  ON members FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    (
      EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'pastor')
      ) OR
      EXISTS (
        SELECT 1 FROM auth.users 
        WHERE id = auth.uid() 
        AND (raw_user_meta_data->>'role' IN ('admin', 'pastor'))
      )
    )
  );

-- Step 4: Fix the delete policy
DROP POLICY IF EXISTS "Only admins can delete members" ON members;

CREATE POLICY "Only admins can delete members"
  ON members FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    (
      EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'pastor')
      ) OR
      EXISTS (
        SELECT 1 FROM auth.users 
        WHERE id = auth.uid() 
        AND (raw_user_meta_data->>'role' IN ('admin', 'pastor'))
      )
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'pastor')
      ) OR
      EXISTS (
        SELECT 1 FROM auth.users 
        WHERE id = auth.uid() 
        AND (raw_user_meta_data->>'role' IN ('admin', 'pastor'))
      )
    )
  );

-- Step 5: IMPORTANT - Create your admin user in the users table
-- Replace 'YOUR_AUTH_USER_ID' with your actual Supabase Auth user ID
-- You can find it in Supabase Dashboard > Authentication > Users
-- Or run: SELECT id, email FROM auth.users;

-- Example (replace with your actual values):
-- INSERT INTO users (id, email, role, is_active)
-- VALUES (
--   'YOUR_AUTH_USER_ID_HERE',
--   'admin@example.com',
--   'admin',
--   true
-- )
-- ON CONFLICT (id) DO UPDATE
-- SET role = 'admin', is_active = true;

-- Step 6: Verify your user role
-- Run this to check if your user has admin role:
-- SELECT id, email, role, is_active 
-- FROM users 
-- WHERE id = auth.uid();

-- If the query returns nothing, you need to create the user record first (Step 5)
