-- Phase 1: Database Foundation
-- Migration 001: Create security schema and metadata table
-- Purpose: Establish the security schema and track all migrations

-- Create security schema (isolated from business logic)
CREATE SCHEMA IF NOT EXISTS security;

-- Create schema metadata table (tracks all migrations)
CREATE TABLE IF NOT EXISTS security.schema_metadata (
  id SERIAL PRIMARY KEY,
  version TEXT NOT NULL UNIQUE,
  migration_name TEXT NOT NULL,
  description TEXT,
  applied_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  applied_by TEXT DEFAULT 'system',
  rollback_function TEXT,

  CONSTRAINT valid_version_format CHECK (version ~ '^\d+\.\d+\.\d+$')
);

-- Track this migration
INSERT INTO security.schema_metadata (version, migration_name, description)
VALUES (
  '1.0.0',
  '001_create_security_schema',
  'Create security schema and schema metadata table for tracking migrations'
) ON CONFLICT (version) DO NOTHING;

-- Create helper function for checking schema version
CREATE OR REPLACE FUNCTION security.get_schema_version()
RETURNS TEXT AS $$
  SELECT version FROM security.schema_metadata
  ORDER BY applied_at DESC LIMIT 1;
$$ LANGUAGE sql;

-- Create helper to list all applied migrations
CREATE OR REPLACE FUNCTION security.list_migrations()
RETURNS TABLE (
  version TEXT,
  migration_name TEXT,
  description TEXT,
  applied_at TIMESTAMP WITH TIME ZONE
) AS $$
  SELECT version, migration_name, description, applied_at
  FROM security.schema_metadata
  ORDER BY applied_at DESC;
$$ LANGUAGE sql;

-- Grant schema access to authenticated users (for RLS)
GRANT USAGE ON SCHEMA security TO authenticated;

-- Allow service role full access
GRANT ALL PRIVILEGES ON SCHEMA security TO service_role;

COMMIT;
