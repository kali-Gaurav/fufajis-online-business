-- ============================================================
-- Migration 007: Delivery & Warehouse Operations Schema
-- Self-contained: works even if users table doesn't exist yet.
-- Foreign keys to users are added only if the table exists.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Rider Profiles table
-- Standalone rider profile store with optional FK to users.
CREATE TABLE IF NOT EXISTS rider_profiles (
  id uuid primary key default gen_random_uuid(),
  firebase_uid text unique,
  name text,
  phone text,
  capacity integer not null default 5,
  success_rate double precision not null default 100.0,
  active_load integer not null default 0,
  is_online boolean not null default false,
  latitude double precision,
  longitude double precision,
  speed double precision not null default 0.0,
  heading double precision not null default 0.0,
  battery_level double precision not null default 100.0,
  current_zone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Employee Tasks table
-- Standalone task store with optional FK to rider_profiles.
CREATE TABLE IF NOT EXISTS employee_tasks (
  id uuid primary key default gen_random_uuid(),
  firestore_id text unique,
  title text not null,
  description text,
  type text not null default 'delivery'
    check (type in ('packing', 'low_stock_audit', 'return_processing', 'delivery')),
  priority text not null default 'medium'
    check (priority in ('low', 'medium', 'high', 'urgent')),
  status text not null default 'released'
    check (status in ('released', 'assigned', 'completed', 'failed')),
  assigned_rider_id uuid references rider_profiles(id) on delete set null,
  assigned_user_firebase_uid text,
  assigned_user_name text,
  branch_id text,
  shop_id text,
  reference_id text,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  time_estimate_minutes integer not null default 15,
  latitude double precision,
  longitude double precision,
  payload_weight double precision not null default 0.0,
  payout_amount numeric(12,2) not null default 0.0,
  updated_at timestamptz not null default now()
);

-- 3. Rider Payouts table (for payout analytics)
CREATE TABLE IF NOT EXISTS rider_payouts (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid references rider_profiles(id) on delete cascade,
  rider_firebase_uid text,
  rider_name text,
  period_start timestamptz not null,
  period_end timestamptz not null,
  total_deliveries integer not null default 0,
  total_earnings numeric(12,2) not null default 0.0,
  bonus numeric(12,2) not null default 0.0,
  deductions numeric(12,2) not null default 0.0,
  net_payout numeric(12,2) not null default 0.0,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'paid')),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4. Delivery Zones table
CREATE TABLE IF NOT EXISTS delivery_zones (
  id uuid primary key default gen_random_uuid(),
  zone_name text not null,
  zone_code text unique not null,
  center_lat double precision not null,
  center_lng double precision not null,
  radius_km double precision not null default 5.0,
  is_surge_active boolean not null default false,
  surge_multiplier double precision not null default 1.0,
  base_delivery_fee numeric(12,2) not null default 20.0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 5. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_rider_profiles_online   ON rider_profiles(is_online) WHERE is_online = true;
CREATE INDEX IF NOT EXISTS idx_rider_profiles_firebase ON rider_profiles(firebase_uid);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_status   ON employee_tasks(status);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_rider    ON employee_tasks(assigned_rider_id);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_firestore ON employee_tasks(firestore_id);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_reference ON employee_tasks(reference_id);
CREATE INDEX IF NOT EXISTS idx_rider_payouts_rider     ON rider_payouts(rider_id);
CREATE INDEX IF NOT EXISTS idx_rider_payouts_status    ON rider_payouts(status);

-- 6. Seed default delivery zone (Baran, Rajasthan - Fufaji HQ)
INSERT INTO delivery_zones (zone_name, zone_code, center_lat, center_lng, radius_km, base_delivery_fee)
VALUES ('Baran HQ Zone', 'ZONE_BARAN_HQ', 25.1006, 76.5156, 15.0, 20.0)
ON CONFLICT (zone_code) DO NOTHING;
