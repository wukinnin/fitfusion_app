-- ============================================================================
-- FITFUSION: SEED FIRST ADMIN ACCOUNT
-- Target: Supabase (PostgreSQL)
--
-- INSTRUCTIONS (2-step process):
--
-- STEP 1: Create the auth user via Supabase Dashboard
--   1. Go to Authentication → Users in the Supabase dashboard
--   2. Click "Add user" → "Create new user"
--   3. Enter:
--        Email:    <your admin email>
--        Password: <your admin password>
--        Check "Auto Confirm User" (skips email verification)
--   4. Click "Create user"
--   5. Copy the UUID shown in the user list (the "UID" column)
--
-- STEP 2: Run this SQL (replace the placeholders)
--   1. Go to SQL Editor
--   2. Replace <UUID> with the UUID from Step 1
--   3. Replace <EMAIL> with the same email from Step 1
--   4. Click "Run"
--
-- IMPORTANT: Also set app_metadata so the trigger recognizes future
-- admin logins correctly. Run the update below as well.
-- ============================================================================

-- Insert into admin_users table
INSERT INTO public.admin_users (id, email, role, created_at, updated_at)
VALUES (
  '<UUID>',          -- UUID from Supabase Auth dashboard
  '<EMAIL>',         -- same email used in Step 1
  'admin',
  NOW(),
  NOW()
);

-- Update auth.users app_metadata to mark this user as admin
-- This ensures the trigger routes correctly for any future operations
UPDATE auth.users
SET raw_app_meta_data = raw_app_meta_data || '{"role": "admin"}'::jsonb
WHERE id = '<UUID>';


-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After running, verify with:
--
-- SELECT * FROM public.admin_users;
-- SELECT id, email, raw_app_meta_data FROM auth.users WHERE email = '<EMAIL>';
--
-- Expected:
--   admin_users: 1 row with your email and role='admin'
--   auth.users:  raw_app_meta_data contains {"role": "admin"}
