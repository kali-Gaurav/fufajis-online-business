-- Migration: Create staff table and token_blacklist table for operational users
-- Date: 2026-07-05
-- Purpose: Support operational user authentication (owner, admin, employee, delivery)

-- ═══════════════════════════════════════════════════════════════════════
-- STAFF TABLE (Operational Users)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id TEXT NOT NULL,
  login_id TEXT NOT NULL UNIQUE,
  pin_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'employee', 'delivery')),
  phone TEXT NOT NULL UNIQUE,
  email TEXT,
  name TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  failed_login_count INT DEFAULT 0,
  locked_until TIMESTAMP NULL,
  last_login TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  -- Constraints
  UNIQUE(shop_id, login_id),
  CONSTRAINT staff_phone_format CHECK (phone ~ '^\+?[1-9]\d{1,14}$')
);

-- Indexes
CREATE INDEX idx_staff_shop_id ON staff(shop_id);
CREATE INDEX idx_staff_login_id ON staff(login_id);
CREATE INDEX idx_staff_phone ON staff(phone);
CREATE INDEX idx_staff_role ON staff(role);
CREATE INDEX idx_staff_is_active ON staff(is_active) WHERE is_active = true;
CREATE INDEX idx_staff_locked_until ON staff(locked_until) WHERE locked_until IS NOT NULL;

-- Enable RLS (only backend can read/write)
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;

CREATE POLICY staff_service_full ON staff
  USING (true)
  WITH CHECK (auth.jwt() ->> 'role' = 'service');  -- Only backend service role

CREATE POLICY staff_owner_read ON staff
  FOR SELECT
  USING (auth.jwt() ->> 'role' IN ('owner', 'admin'));  -- Owner/admin can view staff

-- ═══════════════════════════════════════════════════════════════════════
-- TOKEN BLACKLIST TABLE (Revoked Tokens)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS token_blacklist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  reason TEXT CHECK (reason IN ('logout', 'password_change', 'security_event', 'admin_revoke', 'emergency_rotation')),
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),

  CONSTRAINT token_blacklist_expiry CHECK (expires_at > created_at)
);

-- Indexes
CREATE INDEX idx_token_blacklist_user_id ON token_blacklist(user_id);
CREATE INDEX idx_token_blacklist_expires_at ON token_blacklist(expires_at);
CREATE INDEX idx_token_blacklist_token_hash ON token_blacklist(token_hash);

-- Enable RLS (only backend can write)
ALTER TABLE token_blacklist ENABLE ROW LEVEL SECURITY;

CREATE POLICY token_blacklist_service_write ON token_blacklist
  WITH CHECK (auth.jwt() ->> 'role' = 'service');  -- Only backend

-- Cleanup policy: expired entries can be deleted by backend
CREATE POLICY token_blacklist_service_cleanup ON token_blacklist
  FOR DELETE
  USING (auth.jwt() ->> 'role' = 'service');

-- ═══════════════════════════════════════════════════════════════════════
-- SEED DATA (Optional: Add test users for development)
-- ═══════════════════════════════════════════════════════════════════════

-- Insert test owner (PIN: 1234)
INSERT INTO staff (shop_id, login_id, pin_hash, role, phone, email, name, is_active)
VALUES (
  'shop_001',
  'owner@fufaji.local',
  '$2b$12$N9qo8uLOickgx2ZMRZoMyeIjZAgcg7b3XeKeUxWdeS86E36P4/TVi',  -- bcrypt hash of "password123"
  'owner',
  '+919876543210',
  'owner@fufaji.local',
  'Shop Owner',
  true
) ON CONFLICT DO NOTHING;

-- Insert test admin (PIN: 5678)
INSERT INTO staff (shop_id, login_id, pin_hash, role, phone, email, name, is_active)
VALUES (
  'shop_001',
  'admin@fufaji.local',
  '$2b$12$DjhLCDpL0F0dE5e/fZqQxOg7.RJ.t8gqZj/vK1zQ5BEF4R7.8JO0e',  -- Different hash
  'admin',
  '+919876543211',
  'admin@fufaji.local',
  'Shop Admin',
  true
) ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════
-- END MIGRATION
-- ═══════════════════════════════════════════════════════════════════════
