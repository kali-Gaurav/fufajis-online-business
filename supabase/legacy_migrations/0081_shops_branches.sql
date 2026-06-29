-- ============================================================
-- Migration 008: Shops & Branches
--
-- Backfills task #44 ("Backfill users.branch_id / users.shop_id").
--
-- The Flutter app's real data hierarchy (see lib/utils/db_seeder.dart,
-- lib/providers/employee_provider.dart, lib/providers/admin_provider.dart)
-- is Firestore `shops/{shopId}/branches/{branchId}/...` — Fufaji is a
-- multi-shop, multi-branch platform at the data-model level, even though
-- the customer-facing app currently renders a single-shop home screen.
--
-- `users.shop_id` / `users.branch_id`, `products.shop_id`, and
-- `orders.shop_id` / `orders.branch_id` were added in 001_core_schema.sql
-- as bare `uuid` columns with no corresponding tables. This migration:
--
--   1. Creates `shops` and `branches` tables (mirroring the Firestore
--      `shops/{id}` and `shops/{id}/branches/{id}` documents).
--   2. Adds FK constraints from users/products/orders to these new
--      tables (idempotent — only added if missing).
--   3. Seeds a default "Fufaji Store" shop + branch row so existing
--      single-shop data has somewhere to point, even before the
--      Firestore shops/branches migrator runs.
-- ============================================================

-- ------------------------------------------------------------
-- shops
-- Mirrors Firestore `shops/{shopId}`.
-- ------------------------------------------------------------
create table if not exists shops (
  id            uuid primary key default gen_random_uuid(),
  firestore_id  text unique,
  name          text not null default 'Fufaji Store',
  owner_id      uuid references users(id) on delete set null,
  phone         text,
  email         text,
  address       text,
  city          text,
  state         text,
  pincode       text,
  latitude      double precision,
  longitude     double precision,
  is_active     boolean not null default true,
  is_open       boolean not null default true,
  metadata      jsonb default '{}'::jsonb,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ------------------------------------------------------------
-- branches
-- Mirrors Firestore `shops/{shopId}/branches/{branchId}`.
-- ------------------------------------------------------------
create table if not exists branches (
  id            uuid primary key default gen_random_uuid(),
  firestore_id  text unique,
  shop_id       uuid references shops(id) on delete cascade,
  name          text not null,
  branch_code   text,
  manager_id    uuid references users(id) on delete set null,
  phone         text,
  address       text,
  city          text,
  state         text,
  pincode       text,
  latitude      double precision,
  longitude     double precision,
  is_active     boolean not null default true,
  metadata      jsonb default '{}'::jsonb,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists idx_branches_shop_id on branches(shop_id);

-- ------------------------------------------------------------
-- updated_at triggers for the new tables
-- ------------------------------------------------------------
do $$
declare
  t text;
begin
  for t in select unnest(array['shops','branches'])
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

-- ------------------------------------------------------------
-- FK constraints from existing bare-uuid columns
-- (added idempotently — skipped if already present, e.g. on rerun)
-- ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'users_shop_id_fkey'
  ) then
    alter table users
      add constraint users_shop_id_fkey
      foreign key (shop_id) references shops(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'users_branch_id_fkey'
  ) then
    alter table users
      add constraint users_branch_id_fkey
      foreign key (branch_id) references branches(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'products_shop_id_fkey'
  ) then
    alter table products
      add constraint products_shop_id_fkey
      foreign key (shop_id) references shops(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'orders_shop_id_fkey'
  ) then
    alter table orders
      add constraint orders_shop_id_fkey
      foreign key (shop_id) references shops(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'orders_branch_id_fkey'
  ) then
    alter table orders
      add constraint orders_branch_id_fkey
      foreign key (branch_id) references branches(id) on delete set null;
  end if;
end;
$$;

-- ------------------------------------------------------------
-- Seed a default shop + branch.
--
-- Fufaji currently operates as a single physical shop in the
-- customer-facing app (see memory: "Swiggy-style single-shop home
-- screen"), so every pre-existing row that has no Firestore
-- shops/{id} document to match against (i.e. shop_id/branch_id
-- still null after the migrator runs) is pointed at this default
-- row by backfill_shops_branches.js, rather than left orphaned.
-- ------------------------------------------------------------
insert into shops (firestore_id, name, is_active, is_open, metadata)
values ('__default__', 'Fufaji Store', true, true, '{"seeded": true, "note": "Default shop for pre-multi-shop data"}'::jsonb)
on conflict (firestore_id) do nothing;

insert into branches (firestore_id, shop_id, name, is_active, metadata)
select '__default__', s.id, 'Main Branch', true, '{"seeded": true, "note": "Default branch for pre-multi-branch data"}'::jsonb
from shops s
where s.firestore_id = '__default__'
on conflict (firestore_id) do nothing;
