-- Initial schema for Fufaji Store
-- This is a sample migration. Customize based on your actual database schema.

-- Create tables as needed
-- Example:
-- CREATE TABLE customers (
--   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--   email TEXT UNIQUE NOT NULL,
--   phone TEXT,
--   created_at TIMESTAMP DEFAULT now(),
--   updated_at TIMESTAMP DEFAULT now()
-- );

-- Enable RLS (Row Level Security)
-- ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Create RLS policies as needed
-- CREATE POLICY "Users can only see their own data" ON customers
--   FOR SELECT USING (auth.uid() = id);
