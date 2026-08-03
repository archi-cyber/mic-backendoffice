# RLS Policy Fix for Member Creation

## Problem
The RLS policy is blocking member creation because it can't verify the user's role. This happens when:
1. The user's role is stored in Supabase Auth metadata but not in the `users` table
2. The helper functions aren't finding the user record
3. The user hasn't been created in the `users` table yet

## Quick Fix

Run these SQL statements in your Supabase SQL Editor to fix the RLS policies:

### Option 1: Temporarily Allow All Authenticated Users (For Testing)

```sql
-- Drop existing policy
DROP POLICY IF EXISTS "Only admins can insert members" ON members;

-- Create a more permissive policy for testing
CREATE POLICY "Authenticated users can insert members (testing)"
  ON members FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
```

**⚠️ WARNING**: This allows any authenticated user to create members. Use only for testing!

### Option 2: Check Auth Metadata Directly (Recommended)

```sql
-- Drop existing policy
DROP POLICY IF EXISTS "Only admins can insert members" ON members;

-- Create policy that checks both users table and auth metadata
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
      -- Check auth.users metadata
      EXISTS (
        SELECT 1 FROM auth.users 
        WHERE id = auth.uid() 
        AND (raw_user_meta_data->>'role' IN ('admin', 'pastor'))
      )
    )
  );
```

### Option 3: Use Service Role for Admin Operations

If you're using the service role key for admin operations, you can bypass RLS:

1. In your Flutter app, use the service role key for admin operations (stored securely)
2. Or create a database function that bypasses RLS:

```sql
-- Create function that bypasses RLS for member creation
CREATE OR REPLACE FUNCTION create_member(member_data JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_member_id UUID;
BEGIN
  INSERT INTO members (
    first_name, last_name, email, phone, birthday,
    address, city, state, zip_code, country, gender,
    marital_status, is_active, birthday_notifications_opt_out
  )
  VALUES (
    member_data->>'first_name',
    member_data->>'last_name',
    member_data->>'email',
    member_data->>'phone',
    (member_data->>'birthday')::DATE,
    member_data->>'address',
    member_data->>'city',
    member_data->>'state',
    member_data->>'zip_code',
    member_data->>'country',
    member_data->>'gender',
    member_data->>'marital_status',
    COALESCE((member_data->>'is_active')::BOOLEAN, true),
    COALESCE((member_data->>'birthday_notifications_opt_out')::BOOLEAN, false)
  )
  RETURNING id INTO new_member_id;
  
  RETURN new_member_id;
END;
$$;
```

Then call it from your app:
```dart
final result = await SupabaseService.client.rpc('create_member', params: {
  'member_data': memberData,
});
```

## Recommended Solution

**For production**, use **Option 2** and ensure:

1. **Set user role in Supabase Auth metadata** when creating admin users:
   ```sql
   -- Update auth user metadata
   UPDATE auth.users 
   SET raw_user_meta_data = jsonb_build_object('role', 'admin')
   WHERE email = 'admin@example.com';
   ```

2. **Sync auth users to users table**:
   ```sql
   -- Create a trigger to sync auth users to users table
   CREATE OR REPLACE FUNCTION sync_auth_user_to_users()
   RETURNS TRIGGER AS $$
   BEGIN
     INSERT INTO users (id, email, phone, role, is_active)
     VALUES (
       NEW.id,
       NEW.email,
       NEW.phone,
       COALESCE(NEW.raw_user_meta_data->>'role', 'member'),
       true
     )
     ON CONFLICT (id) DO UPDATE
     SET 
       email = EXCLUDED.email,
       phone = EXCLUDED.phone,
       role = COALESCE(EXCLUDED.role, users.role),
       updated_at = NOW();
     RETURN NEW;
   END;
   $$ LANGUAGE plpgsql SECURITY DEFINER;

   CREATE TRIGGER on_auth_user_created
   AFTER INSERT OR UPDATE ON auth.users
   FOR EACH ROW
   EXECUTE FUNCTION sync_auth_user_to_users();
   ```

3. **Create your first admin user**:
   ```sql
   -- First, create the user in Supabase Auth (via dashboard or API)
   -- Then sync to users table:
   INSERT INTO users (id, email, role, is_active)
   VALUES (
     'YOUR_AUTH_USER_ID',
     'admin@example.com',
     'admin',
     true
   );
   ```

## Verification

After applying the fix, test member creation:

```sql
-- Check if you can insert (this should work if you're an admin)
INSERT INTO members (first_name, last_name, email, is_active)
VALUES ('Test', 'User', 'test@example.com', true)
RETURNING id;
```

If it still fails, check:
1. Are you authenticated? (`SELECT auth.uid();`)
2. What's your role? (`SELECT role FROM users WHERE id = auth.uid();`)
3. Is your role in auth metadata? (`SELECT raw_user_meta_data FROM auth.users WHERE id = auth.uid();`)
