-- Diagnostic queries to check RLS issues for department_reports
-- Run these in Supabase SQL Editor to diagnose the issue

-- 1. Check if the current user exists and is active
SELECT 
  id,
  email,
  role,
  is_active,
  member_id
FROM users
WHERE id = auth.uid();

-- 2. Check if the current user is a leader/subleader of any department
SELECT 
  u.id as user_id,
  u.email,
  u.role as user_role,
  dm.role as department_role,
  d.id as department_id,
  d.name as department_name
FROM users u
JOIN department_members dm ON u.member_id = dm.member_id
JOIN departments d ON dm.department_id = d.id
WHERE u.id = auth.uid()
  AND dm.role IN ('leader', 'subleader')
  AND u.is_active = true;

-- 3. Check all department members and their roles
SELECT 
  d.name as department_name,
  m.first_name || ' ' || m.last_name as member_name,
  dm.role,
  u.id as user_id,
  u.email
FROM departments d
JOIN department_members dm ON d.id = dm.department_id
JOIN members m ON dm.member_id = m.id
LEFT JOIN users u ON m.id = u.member_id
WHERE d.is_active = true
ORDER BY d.name, dm.role;

-- 4. Test if you can insert a report (replace 'YOUR_DEPARTMENT_ID' with an actual department ID)
-- This will show you the exact error if RLS is blocking
/*
INSERT INTO department_reports (
  department_id,
  created_by,
  title,
  defined_objectives,
  positive_points,
  difficulties_encountered,
  suggestions
) VALUES (
  'YOUR_DEPARTMENT_ID'::uuid,  -- Replace with actual department ID
  auth.uid(),
  'Test Report',
  'Test objectives',
  'Test positive points',
  'Test difficulties',
  'Test suggestions'
);
*/
