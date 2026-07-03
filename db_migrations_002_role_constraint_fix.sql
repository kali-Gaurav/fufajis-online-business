-- ============================================================================
-- Migration 002: Fix users.role CHECK constraint (Module 1, P0-1.3)
-- Date: 2026-07-02
--
-- PROBLEM: db_migrations_001_initial_schema.sql constrained users.role to
--   ('customer', 'owner', 'rider', 'employee', 'admin')
-- but the Dart UserRole enum has 12 values. Dual-writes (Firebase → Postgres)
-- fail with a check-constraint violation for any user whose role is
-- shopOwner, deliveryAgent, superAdmin, dispatcher, branchManager, supplier,
-- or franchiseOwner.
--
-- NOTE: supabase/migrations/003_update_role_constraint.sql.bak attempted this
-- but was parked — it created a brand-new users table (a no-op when the table
-- already exists) instead of altering the existing constraint, and used
-- invalid `CREATE TRIGGER IF NOT EXISTS` syntax. This migration supersedes it.
--
-- Idempotent: safe to run more than once.
-- ============================================================================

DO $$
DECLARE
  con RECORD;
BEGIN
  -- Drop every existing CHECK constraint on users.role, whatever it was named
  -- (inline CHECKs get auto-generated names like users_role_check).
  FOR con IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'users'
      AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) ILIKE '%role%'
  LOOP
    EXECUTE format('ALTER TABLE users DROP CONSTRAINT %I', con.conname);
    RAISE NOTICE 'Dropped constraint: %', con.conname;
  END LOOP;
END $$;

ALTER TABLE users
  ADD CONSTRAINT users_role_check CHECK (role IN (
    'customer',
    'shopOwner',
    'deliveryAgent',
    'admin',
    'employee',
    'owner',
    'superAdmin',
    'rider',
    'dispatcher',
    'branchManager',
    'supplier',
    'franchiseOwner'
  ));

COMMENT ON COLUMN users.role IS
  'User role — must match the Dart UserRole enum in lib/models/user_model.dart: '
  'customer, shopOwner, deliveryAgent, admin, employee, owner, superAdmin, '
  'rider, dispatcher, branchManager, supplier, franchiseOwner';
