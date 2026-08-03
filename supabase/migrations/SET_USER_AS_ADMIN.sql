-- Set a user as admin
-- Run this in Supabase SQL Editor
-- Replace 'user@example.com' with the actual email of the user you want to make admin

-- Method 1: Update by email
UPDATE users
SET 
  role = 'admin',
  is_active = true,
  updated_at = NOW()
WHERE email = 'user@example.com';

-- Method 2: Update by user ID (if you know the UUID)
-- UPDATE users
-- SET 
--   role = 'admin',
--   is_active = true,
--   updated_at = NOW()
-- WHERE id = 'user-uuid-here';

-- Method 3: Update multiple users at once (if needed)
-- UPDATE users
-- SET 
--   role = 'admin',
--   is_active = true,
--   updated_at = NOW()
-- WHERE email IN ('user1@example.com', 'user2@example.com');

-- Verify the update
SELECT id, email, role, is_active, created_at
FROM users
WHERE email = 'user@example.com';

-- Note: After updating the role in the users table, you may also want to update
-- the user's metadata in Supabase Auth. This can be done through the Supabase Dashboard
-- or via the Supabase Admin API.
