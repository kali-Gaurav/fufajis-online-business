-- ============================================================
-- Fufaji Migration 019: Fix Role Constraint
-- Corrects migration 018's outdated role constraint
-- ============================================================
-- ISSUE: Migration 018 downgraded the role constraint from 12 roles to 5
-- This breaks any user created with roles like 'shopOwner', 'deliveryAgent', etc.
--
-- FIX: Restore the complete 12-role constraint from migration 001
-- ============================================================

-- Drop the incorrect constraint from migration 018
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;

-- Add the correct constraint with all 12 roles
ALTER TABLE public.users ADD CONSTRAINT users_role_check CHECK (
  role IN (
    'customer',        -- End users browsing/buying
    'employee',        -- Shop staff (picking, packing, etc.)
    'rider',           -- Delivery partners
    'dispatcher',      -- Route optimization & assignment
    'branchManager',   -- Branch operations lead
    'owner',           -- Shop owner
    'superAdmin',      -- System administrator
    'admin',           -- Administrator (added for flexibility)
    'shopOwner',       -- Alternative shop owner designation
    'deliveryAgent',   -- Alternative delivery designation
    'supplier',        -- Vendor/supplier partner
    'franchiseOwner'   -- Franchise partner
  )
);

-- Verify the fix
-- SELECT constraint_name, constraint_definition
-- FROM information_schema.table_constraints
-- WHERE table_name = 'users' AND constraint_type = 'CHECK';

-- Test: Create users with each role
-- INSERT INTO public.users (id, role) VALUES (gen_random_uuid(), 'shopOwner');
-- INSERT INTO public.users (id, role) VALUES (gen_random_uuid(), 'deliveryAgent');
-- INSERT INTO public.users (id, role) VALUES (gen_random_uuid(), 'admin');
-- All should succeed without constraint violations
