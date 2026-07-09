-- Seed data for staging environment testing
-- Includes sample admins and employees for privileged auth testing

-- Ensure users exist in public.users first if auth is linked
-- (Assuming they are created via the Auth API in a real test, 
-- but here we might just insert mock credentials for Edge Function testing)

INSERT INTO security.privileged_credentials (user_id, email, role, password_hash, status)
VALUES 
  ('admin-mock-123', 'admin@fufaji.local', 'admin', 'mock_hash_replace_later', 'active'),
  ('employee-mock-456', 'employee@fufaji.local', 'employee', 'mock_hash_replace_later', 'active')
ON CONFLICT DO NOTHING;
