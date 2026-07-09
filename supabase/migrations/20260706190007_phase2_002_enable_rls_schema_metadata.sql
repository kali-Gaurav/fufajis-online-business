-- Phase 2: Security Layer
-- Migration 002: Enable RLS on schema_metadata
-- Purpose: The policies were created in the previous migration, but RLS was not explicitly enabled.

BEGIN;

ALTER TABLE security.schema_metadata ENABLE ROW LEVEL SECURITY;

-- Track this migration
INSERT INTO security.schema_metadata (version, migration_name, description)
VALUES (
  '2.1.0',
  '002_enable_rls_schema_metadata',
  'Enable RLS on schema_metadata table'
) ON CONFLICT (version) DO NOTHING;

COMMIT;
