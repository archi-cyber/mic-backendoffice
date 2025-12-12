-- Sync Auth Users to Users Table
-- This ensures that when a user logs in via Supabase Auth,
-- a corresponding record exists in the users table
-- Run this in Supabase SQL Editor

-- Step 1: Create a function to sync auth users to users table
CREATE OR REPLACE FUNCTION sync_auth_user_to_users()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert or update user in users table when auth user is created/updated
  -- Note: Only using columns that exist in the users table
  -- If is_active column exists, it should be added separately via ALTER TABLE
  INSERT INTO users (id, email, phone, role, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.phone, NULL),
    COALESCE((NEW.raw_user_meta_data->>'role')::text, 'member'),
    COALESCE(NEW.created_at, NOW()),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    phone = COALESCE(EXCLUDED.phone, users.phone),
    role = COALESCE(EXCLUDED.role, users.role),
    updated_at = NOW();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Create trigger to automatically sync on auth user creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION sync_auth_user_to_users();

-- Step 3: Sync existing auth users to users table
-- This will create user records for any existing auth users
INSERT INTO users (id, email, phone, role, created_at, updated_at)
SELECT 
  au.id,
  au.email,
  au.phone,
  COALESCE((au.raw_user_meta_data->>'role')::text, 'member') as role,
  COALESCE(au.created_at, NOW()) as created_at,
  NOW() as updated_at
FROM auth.users au
WHERE NOT EXISTS (
  SELECT 1 FROM users u WHERE u.id = au.id
)
ON CONFLICT (id) DO UPDATE
SET
  email = EXCLUDED.email,
  phone = COALESCE(EXCLUDED.phone, users.phone),
  role = COALESCE(EXCLUDED.role, users.role),
  updated_at = NOW();

-- Step 4: Verify the sync
-- Run this to see if all auth users have corresponding records in users table:
-- SELECT 
--   au.id as auth_user_id,
--   au.email as auth_email,
--   u.id as user_id,
--   u.email as user_email,
--   u.role
-- FROM auth.users au
-- LEFT JOIN users u ON u.id = au.id
-- WHERE u.id IS NULL;

-- If the above query returns any rows, those auth users don't have user records yet
-- They will be created automatically on next login due to the trigger
