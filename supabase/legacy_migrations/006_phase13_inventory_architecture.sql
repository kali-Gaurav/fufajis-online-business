-- ============================================================
-- Phase 13A: Intelligent Inventory & Approval Architecture
-- Migration 006: Advanced Inventory, Packaging, and Event Ledger
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Product Master Schema (Enhancing existing `products` table)
-- Instead of dropping `products`, we alter it to add the missing fields requested in Phase 13.

ALTER TABLE products
ADD COLUMN IF NOT EXISTS brand text,
ADD COLUMN IF NOT EXISTS tax_code text,
ADD COLUMN IF NOT EXISTS active boolean not null default true;

ALTER TABLE products
RENAME COLUMN unit TO unit_type;

-- 2. Inventory Table
-- Separating stock from `products` into a dedicated `inventory` table.
CREATE TABLE IF NOT EXISTS inventory (
  inventory_id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  warehouse_id uuid, -- Can reference a future warehouses/branches table
  current_stock integer not null default 0,
  reserved_stock integer not null default 0,
  available_stock integer generated always as (current_stock - reserved_stock - damaged_stock) stored,
  damaged_stock integer not null default 0,
  packaging_stock integer not null default 0,
  reorder_level integer not null default 5,
  updated_at timestamptz not null default now()
);

-- 3. Packaging Tracking Table
CREATE TABLE IF NOT EXISTS package_processing (
  process_id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  quantity integer not null default 1,
  packed_quantity integer not null default 0,
  damaged_quantity integer not null default 0,
  packed_by uuid references users(id) on delete set null,
  verified_by uuid references users(id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending', 'picking', 'packed', 'verified', 'shipped')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4. Inventory Event Ledger
-- Never directly modify stock. Every action becomes an event.
CREATE TABLE IF NOT EXISTS inventory_events (
  event_id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  event_type text not null
    check (event_type in ('ORDER_CREATED', 'ORDER_CANCELLED', 'ITEM_PACKED', 'ITEM_DAMAGED', 'RETURN_RECEIVED', 'STOCK_ADDED', 'STOCK_REMOVED')),
  quantity_change integer not null,
  old_value integer,
  new_value integer,
  actor_id uuid references users(id) on delete set null,
  actor_role text,
  source text,
  approved_by uuid references users(id) on delete set null,
  timestamp timestamptz not null default now()
);

-- 5. Change Requests (Owner Approval Workflow)
CREATE TABLE IF NOT EXISTS change_requests (
  request_id uuid primary key default gen_random_uuid(),
  entity_type text not null, -- e.g., 'inventory', 'product'
  entity_id uuid not null,
  proposed_change jsonb not null, -- e.g., {"current_stock": 50, "reorder_level": 10}
  submitted_by uuid references users(id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references users(id) on delete set null,
  reviewed_at timestamptz,
  approval_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 6. Saved Queries (Excel-Level Intelligent Query System)
CREATE TABLE IF NOT EXISTS saved_queries (
  query_id uuid primary key default gen_random_uuid(),
  owner_id uuid references users(id) on delete cascade,
  query_name text not null,
  filter_json jsonb not null,
  created_at timestamptz not null default now()
);

-- 7. Bulk Operations
CREATE TABLE IF NOT EXISTS bulk_operations (
  operation_id uuid primary key default gen_random_uuid(),
  query_id uuid references saved_queries(query_id) on delete set null,
  operation_type text not null,
  operation_data jsonb not null,
  created_by uuid references users(id) on delete set null,
  approved_by uuid references users(id) on delete set null,
  executed_at timestamptz,
  created_at timestamptz not null default now()
);

-- 8. Inventory Version Control
CREATE TABLE IF NOT EXISTS inventory_versions (
  version_id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  snapshot_json jsonb not null,
  timestamp timestamptz not null default now()
);

-- 10. Automation Rules
CREATE TABLE IF NOT EXISTS automation_rules (
  rule_id uuid primary key default gen_random_uuid(),
  condition_json jsonb not null,
  action_json jsonb not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Add trigger for updated_at on new tables
do $$
declare
  t text;
begin
  for t in select unnest(array[
    'inventory', 'package_processing', 'change_requests', 'automation_rules'
  ])
  loop
    execute format(
      'drop trigger if exists trg_set_updated_at on %I; '
      'create trigger trg_set_updated_at before update on %I '
      'for each row execute function set_updated_at();',
      t, t
    );
  end loop;
end;
$$;
