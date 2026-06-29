-- ============================================================
-- Phase 14: Unified Delivery Control Tower
-- Migration 008: Delivery Routes, Tasks, and Audit Events
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Delivery Routes Table
CREATE TABLE IF NOT EXISTS delivery_routes (
  id uuid primary key default gen_random_uuid(),
  route_name text not null,
  rider_id uuid references rider_profiles(id) on delete set null,
  status text not null default 'draft'
    check (status in ('draft', 'assigned', 'active', 'completed', 'cancelled')),
  total_distance double precision not null default 0.0,
  estimated_duration_minutes integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Delivery Tasks Table
CREATE TABLE IF NOT EXISTS delivery_tasks (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references delivery_routes(id) on delete cascade,
  order_id uuid references orders(id) on delete set null,
  stop_sequence integer not null default 0,
  status text not null default 'assigned'
    check (status in ('assigned', 'picked_up', 'out_for_delivery', 'delivered', 'failed', 'cancelled')),
  customer_name text,
  address text,
  latitude double precision,
  longitude double precision,
  proof_image_url text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. Delivery Events Table (Append-only Ledger)
CREATE TABLE IF NOT EXISTS delivery_events (
  id uuid primary key default gen_random_uuid(),
  route_id uuid references delivery_routes(id) on delete set null,
  task_id uuid references delivery_tasks(id) on delete set null,
  from_status text,
  to_status text not null,
  latitude double precision,
  longitude double precision,
  proof_image_url text,
  notes text,
  actor_id uuid, -- Reference to user UUID
  timestamp timestamptz not null default now()
);

-- 4. Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_delivery_routes_rider ON delivery_routes(rider_id);
CREATE INDEX IF NOT EXISTS idx_delivery_routes_status ON delivery_routes(status);
CREATE INDEX IF NOT EXISTS idx_delivery_tasks_route ON delivery_tasks(route_id);
CREATE INDEX IF NOT EXISTS idx_delivery_tasks_order ON delivery_tasks(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_tasks_status ON delivery_tasks(status);
CREATE INDEX IF NOT EXISTS idx_delivery_events_task ON delivery_events(task_id);

-- 5. Set updated_at trigger for tables
do $$
declare
  t text;
begin
  for t in select unnest(array[
    'delivery_routes', 'delivery_tasks'
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
