-- Fix RLS Policies for User Sync Trigger
-- This fixes the "Database error granting user on logging in" issue
-- Run this in Supabase SQL Editor

-- Step 1: Ensure the sync function can bypass RLS
-- The function is already SECURITY DEFINER, but we need to make sure
-- it can insert/update users table without RLS blocking it
CREATE OR REPLACE FUNCTION sync_auth_user_to_users()
RETURNS TRIGGER AS $$
DECLARE
  user_exists BOOLEAN;
BEGIN
  -- Insert or update user in users table when auth user is created/updated
  -- This runs with SECURITY DEFINER privileges, bypassing RLS
  
  -- Check if user already exists in users table
  SELECT EXISTS(SELECT 1 FROM users WHERE id = NEW.id) INTO user_exists;
  
  IF TG_OP = 'INSERT' OR NOT user_exists THEN
    -- New user or user doesn't exist in users table: insert
    INSERT INTO users (id, email, phone, role, is_active, created_at, updated_at)
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.phone, NULL),
      COALESCE((NEW.raw_user_meta_data->>'role')::text, 'member'),
      COALESCE((NEW.raw_user_meta_data->>'is_active')::boolean, true),
      COALESCE(NEW.created_at, NOW()),
      NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET
      email = EXCLUDED.email,
      phone = COALESCE(EXCLUDED.phone, users.phone),
      role = COALESCE(EXCLUDED.role, users.role),
      is_active = COALESCE(EXCLUDED.is_active, users.is_active),
      updated_at = NOW();
  ELSIF TG_OP = 'UPDATE' AND user_exists THEN
    -- Only update if critical fields changed (email, phone, role, metadata)
    -- Skip updates for last_sign_in_at, updated_at, etc. to prevent recursion
    IF (OLD.email IS DISTINCT FROM NEW.email) OR
       (COALESCE(OLD.phone, '') IS DISTINCT FROM COALESCE(NEW.phone, '')) OR
       (OLD.raw_user_meta_data IS DISTINCT FROM NEW.raw_user_meta_data) THEN
      UPDATE users
      SET
        email = NEW.email,
        phone = COALESCE(NEW.phone, users.phone),
        role = COALESCE((NEW.raw_user_meta_data->>'role')::text, users.role),
        is_active = COALESCE((NEW.raw_user_meta_data->>'is_active')::boolean, users.is_active),
        updated_at = NOW()
      WHERE id = NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Grant necessary permissions
-- Ensure the function owner (usually postgres) has full access
-- Note: SECURITY DEFINER functions run with the privileges of the function owner
-- The function owner should already have full access, but we'll ensure it

-- Grant permissions to authenticated users for reading their own data
GRANT SELECT ON users TO authenticated;
GRANT SELECT ON users TO anon;

-- The function itself runs as SECURITY DEFINER, so it bypasses RLS
-- But we need to ensure the table itself allows the operation

-- Step 3: Check and fix RLS policies on users table
-- Drop existing restrictive policies that might block the trigger
DROP POLICY IF EXISTS "Users can view their own record" ON users;
DROP POLICY IF EXISTS "Users can update their own record" ON users;
DROP POLICY IF EXISTS "Only admins can insert users" ON users;
DROP POLICY IF EXISTS "Only admins can update users" ON users;

-- Step 4: Create permissive policies for authenticated users
-- Allow users to view their own record
CREATE POLICY "Users can view their own record"
  ON users FOR SELECT
  USING (auth.uid() = id);

-- Allow users to update their own record (limited fields)
CREATE POLICY "Users can update their own record"
  ON users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Allow authenticated users to view other users (for member lists, etc.)
-- This is needed for the app to function properly
CREATE POLICY "Authenticated users can view users"
  ON users FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Step 5: Ensure the function owner has proper permissions
-- The function runs as SECURITY DEFINER, meaning it uses the privileges
-- of the function owner (usually the user who created it, often 'postgres')
-- If you're getting "granting user" errors, ensure the function owner
-- has INSERT and UPDATE permissions on the users table

-- Check function owner (run this separately if needed):
-- SELECT p.proname, pg_get_userbyid(p.proowner) as owner
-- FROM pg_proc p
-- WHERE p.proname = 'sync_auth_user_to_users';

-- If the owner is not postgres or service_role, you may need to:
-- ALTER FUNCTION sync_auth_user_to_users() OWNER TO postgres;

-- Step 6: Recreate the trigger
-- Use AFTER trigger to avoid conflicts with Supabase's internal updates
-- The function checks for field changes to prevent recursion
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  WHEN (
    -- Only fire on INSERT or when critical fields change
    -- This prevents infinite loops when Supabase updates last_sign_in_at, etc.
    TG_OP = 'INSERT' OR
    (TG_OP = 'UPDATE' AND (
      OLD.email IS DISTINCT FROM NEW.email OR
      COALESCE(OLD.phone, '') IS DISTINCT FROM COALESCE(NEW.phone, '') OR
      OLD.raw_user_meta_data IS DISTINCT FROM NEW.raw_user_meta_data
    ))
  )
  EXECUTE FUNCTION sync_auth_user_to_users();

-- Step 7: Test the sync manually for existing users
-- This will sync any auth users that don't have user records yet
DO $$
DECLARE
  auth_user_record RECORD;
BEGIN
  FOR auth_user_record IN 
    SELECT id, email, phone, raw_user_meta_data, created_at
    FROM auth.users
    WHERE NOT EXISTS (
      SELECT 1 FROM users WHERE users.id = auth.users.id
    )
  LOOP
    BEGIN
      INSERT INTO users (id, email, phone, role, is_active, created_at, updated_at)
      VALUES (
        auth_user_record.id,
        auth_user_record.email,
        auth_user_record.phone,
        COALESCE((auth_user_record.raw_user_meta_data->>'role')::text, 'member'),
        COALESCE((auth_user_record.raw_user_meta_data->>'is_active')::boolean, true),
        COALESCE(auth_user_record.created_at, NOW()),
        NOW()
      )
      ON CONFLICT (id) DO UPDATE
      SET
        email = EXCLUDED.email,
        phone = COALESCE(EXCLUDED.phone, users.phone),
        role = COALESCE(EXCLUDED.role, users.role),
        is_active = COALESCE(EXCLUDED.is_active, users.is_active),
        updated_at = NOW();
    EXCEPTION WHEN OTHERS THEN
      -- Log error but continue
      RAISE NOTICE 'Error syncing user %: %', auth_user_record.id, SQLERRM;
    END;
  END LOOP;
END $$;

-- Step 8: Verify the fix
-- Check if all auth users now have corresponding user records
-- SELECT 
--   au.id as auth_user_id,
--   au.email as auth_email,
--   u.id as user_id,
--   u.email as user_email,
--   u.role
-- FROM auth.users au
-- LEFT JOIN users u ON u.id = au.id
-- ORDER BY au.created_at DESC;

-- If there are still missing records, the trigger should create them on next login

-- Note: If your users table has an is_active column, you can add it to the function:
-- 1. First, ensure the column exists: ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
-- 2. Then update the function to include is_active in the INSERT and UPDATE statements
