-- ============================================================
-- Fufaji Enterprise Architecture — Core Schema
-- Migration 001: Core business tables (Supabase/PostgreSQL)
--
-- This is the "master" business database. Firestore remains the
-- system of record for realtime/offline features (chat, live
-- tracking, notifications). Writes here happen via gradual
-- dual-write from the Flutter app / Cloud Functions.
-- ============================================================

-- Enable extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- users
-- Mirrors Firebase Auth users + app-level profile/role data.
-- ------------------------------------------------------------
create table if not exists users (
  id              uuid primary key default gen_random_uuid(),
  firebase_uid    text unique not null,
  phone           text unique,
  email           text,
  name            text,
  role            text not null default 'customer'
                    check (role in ('customer','employee','rider','dispatcher','branchManager','owner','superAdmin','admin','shopOwner','deliveryAgent','supplier','franchiseOwner')),
  branch_id       uuid,
  shop_id         uuid,
  wallet_balance  numeric(12,2) not null default 0,
  cod_limit       numeric(12,2) not null default 0,
  loyalty_points  integer not null default 0,
  referral_code   text unique,
  referred_by     text,
  is_active       boolean not null default true,
  is_verified     boolean not null default false,
  metadata        jsonb default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ------------------------------------------------------------
-- addresses
-- ------------------------------------------------------------
create table if not exists addresses (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  label         text,
  line1         text not null,
  line2         text,
  landmark      text,
  city          text,
  state         text,
  pincode       text,
  latitude      double precision,
  longitude     double precision,
  is_default    boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ------------------------------------------------------------
-- categories
-- ------------------------------------------------------------
create table if not exists categories (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  name_hi       text,
  slug          text unique not null,
  parent_id     uuid references categories(id) on delete set null,
  icon_url      text,
  display_order integer not null default 0,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ------------------------------------------------------------
-- products
-- ------------------------------------------------------------
create table if not exists products (
  id              uuid primary key default gen_random_uuid(),
  firestore_id    text unique,
  vendor_id       uuid references users(id) on delete set null,
  shop_id         uuid,
  category_id     uuid references categories(id) on delete set null,
  name            text not null,
  name_hi         text,
  description     text,
  barcode         text,
  sku             text,
  unit            text,
  mrp             numeric(12,2) not null default 0,
  price           numeric(12,2) not null default 0,
  stock           integer not null default 0,
  low_stock_threshold integer not null default 5,
  image_url       text,
  status          text not null default 'active'
                    check (status in ('active','inactive','out_of_stock','discontinued')),
  attributes      jsonb default '{}'::jsonb,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ------------------------------------------------------------
-- orders
-- ------------------------------------------------------------
create table if not exists orders (
  id              uuid primary key default gen_random_uuid(),
  firestore_id    text unique,
  order_number    text unique not null,
  user_id         uuid references users(id) on delete set null,
  vendor_id       uuid references users(id) on delete set null,
  shop_id         uuid,
  driver_id       uuid references users(id) on delete set null,
  branch_id       uuid,
  address_id      uuid references addresses(id) on delete set null,
  order_status    text not null default 'pending'
                    check (order_status in (
                      'pending','confirmed','preparing','ready_for_pickup',
                      'out_for_delivery','delivered','cancelled','refunded'
                    )),
  payment_status  text not null default 'pending'
                    check (payment_status in ('pending','paid','failed','refunded','partial_refund')),
  payment_method  text,
  subtotal        numeric(12,2) not null default 0,
  discount        numeric(12,2) not null default 0,
  delivery_fee    numeric(12,2) not null default 0,
  tax             numeric(12,2) not null default 0,
  total           numeric(12,2) not null default 0,
  coupon_code     text,
  notes           text,
  cancelled_reason text,
  placed_at       timestamptz not null default now(),
  delivered_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ------------------------------------------------------------
-- order_items
-- ------------------------------------------------------------
create table if not exists order_items (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid not null references orders(id) on delete cascade,
  product_id    uuid references products(id) on delete set null,
  product_name  text not null,
  unit_price    numeric(12,2) not null default 0,
  quantity      integer not null default 1,
  subtotal      numeric(12,2) not null default 0,
  metadata      jsonb default '{}'::jsonb,
  created_at    timestamptz not null default now()
);

-- ------------------------------------------------------------
-- order_status_history
-- Append-only log of every status transition (workflow engine).
-- ------------------------------------------------------------
create table if not exists order_status_history (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references orders(id) on delete cascade,
  from_status     text,
  to_status       text not null,
  changed_by      uuid references users(id) on delete set null,
  reason          text,
  created_at      timestamptz not null default now()
);

-- ------------------------------------------------------------
-- wallet_transactions
-- ------------------------------------------------------------
create table if not exists wallet_transactions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  order_id      uuid references orders(id) on delete set null,
  type          text not null
                  check (type in ('credit','debit','referralBonus','refund','adjustment','topup')),
  amount        numeric(12,2) not null,
  balance_after numeric(12,2) not null,
  description   text,
  metadata      jsonb default '{}'::jsonb,
  created_at    timestamptz not null default now()
);

-- ------------------------------------------------------------
-- delivery_tracking
-- ------------------------------------------------------------
create table if not exists delivery_tracking (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references orders(id) on delete cascade,
  driver_id       uuid references users(id) on delete set null,
  status          text not null default 'assigned'
                    check (status in (
                      'assigned','accepted','arrived_pickup','picked_up',
                      'arrived_dropoff','delivered','failed','cancelled'
                    )),
  latitude        double precision,
  longitude       double precision,
  proof_image_url text,
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ------------------------------------------------------------
-- reviews
-- ------------------------------------------------------------
create table if not exists reviews (
  id            uuid primary key default gen_random_uuid(),
  product_id    uuid not null references products(id) on delete cascade,
  user_id       uuid not null references users(id) on delete cascade,
  order_id      uuid references orders(id) on delete set null,
  rating        integer not null check (rating between 1 and 5),
  comment       text,
  image_urls    text[],
  is_verified_purchase boolean not null default false,
  created_at    timestamptz not null default now()
);

-- ------------------------------------------------------------
-- notifications
-- ------------------------------------------------------------
create table if not exists notifications (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references users(id) on delete cascade,
  title         text not null,
  body          text,
  type          text,
  data          jsonb default '{}'::jsonb,
  is_read       boolean not null default false,
  created_at    timestamptz not null default now()
);

-- ------------------------------------------------------------
-- support_tickets
-- ------------------------------------------------------------
create table if not exists support_tickets (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  order_id      uuid references orders(id) on delete set null,
  subject       text not null,
  description   text,
  status        text not null default 'open'
                  check (status in ('open','in_progress','resolved','closed')),
  priority      text not null default 'normal'
                  check (priority in ('low','normal','high','urgent')),
  assigned_to   uuid references users(id) on delete set null,
  resolution    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ------------------------------------------------------------
-- coupons
-- ------------------------------------------------------------
create table if not exists coupons (
  id              uuid primary key default gen_random_uuid(),
  code            text unique not null,
  description     text,
  discount_type   text not null check (discount_type in ('percentage','flat')),
  discount_value  numeric(12,2) not null,
  min_order_value numeric(12,2) not null default 0,
  max_discount    numeric(12,2),
  usage_limit     integer,
  usage_count     integer not null default 0,
  per_user_limit  integer default 1,
  valid_from      timestamptz,
  valid_until     timestamptz,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ------------------------------------------------------------
-- inventory_logs
-- ------------------------------------------------------------
create table if not exists inventory_logs (
  id            uuid primary key default gen_random_uuid(),
  product_id    uuid not null references products(id) on delete cascade,
  changed_by    uuid references users(id) on delete set null,
  change_type   text not null
                  check (change_type in ('restock','sale','adjustment','return','damage')),
  quantity_change integer not null,
  stock_after   integer not null,
  reason        text,
  reference_id  uuid,
  created_at    timestamptz not null default now()
);

-- ------------------------------------------------------------
-- audit_logs
-- Dual-written from AuditService (Supabase + Firestore).
-- ------------------------------------------------------------
create table if not exists audit_logs (
  id            uuid primary key default gen_random_uuid(),
  firestore_id  text,
  user_id       uuid references users(id) on delete set null,
  user_name     text,
  action        text not null,
  description   text,
  target_id     uuid,
  target_type   text,
  branch_id     uuid,
  old_value     jsonb,
  new_value     jsonb,
  ip_address    text,
  device_info   jsonb,
  metadata      jsonb default '{}'::jsonb,
  created_at    timestamptz not null default now()
);

-- ------------------------------------------------------------
-- kyc_documents
-- ------------------------------------------------------------
create table if not exists kyc_documents (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  doc_type      text not null
                  check (doc_type in ('aadhaar','pan','gst','license','shop_proof','bank_proof','other')),
  doc_number    text,
  file_url      text,
  status        text not null default 'pending'
                  check (status in ('pending','verified','rejected')),
  rejection_reason text,
  reviewed_by   uuid references users(id) on delete set null,
  reviewed_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ------------------------------------------------------------
-- updated_at trigger helper
-- ------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

do $$
declare
  t text;
begin
  for t in select unnest(array[
    'users','addresses','categories','products','orders',
    'delivery_tracking','support_tickets','coupons','kyc_documents'
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
