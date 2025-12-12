-- Fix RLS Policy for Notifications Table
-- This fixes the error: "members.user_id does not exist"
-- Run this in Supabase SQL Editor

-- Step 1: Drop existing policies on notifications table
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can insert their own notifications" ON notifications;

-- Step 2: Create fixed SELECT policy
-- This policy allows users to view notifications for their member_id
CREATE POLICY "Users can view their own notifications"
  ON notifications FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.member_id = notifications.member_id
    )
  );

-- Step 3: Create fixed UPDATE policy
CREATE POLICY "Users can update their own notifications"
  ON notifications FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.member_id = notifications.member_id
    )
  );

-- Step 4: Create fixed DELETE policy
CREATE POLICY "Users can delete their own notifications"
  ON notifications FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.member_id = notifications.member_id
    )
  );

-- Step 5: Create INSERT policy (for system/admin to create notifications)
-- Admins and system can create notifications for any member
-- Regular users can only create notifications for themselves
CREATE POLICY "Users can insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND
    (
      -- Admins can create notifications for anyone
      EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role IN ('admin', 'pastor')
      ) OR
      -- Regular users can only create notifications for themselves
      EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.member_id = notifications.member_id
      )
    )
  );

-- Step 6: Verify the policies
-- Run this to see all policies on notifications table:
-- SELECT * FROM pg_policies WHERE tablename = 'notifications';

-- Step 7: Test the fix
-- Try querying notifications (this should work now):
-- SELECT * FROM notifications 
-- WHERE member_id IN (
--   SELECT member_id FROM users WHERE id = auth.uid()
-- );
