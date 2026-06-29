-- ============================================================
-- Fufaji Enterprise Architecture
-- Migration 003: Row Level Security policies
--
-- Assumes Supabase is configured with Firebase Auth as a
-- third-party JWT provider, so auth.jwt() ->> 'sub' contains
-- the Firebase UID of the calling user. Service-role keys
-- (used by Cloud Functions) bypass RLS entirely.
-- ============================================================

-- ------------------------------------------------------------
-- Helper functions
-- ------------------------------------------------------------

-- Firebase UID of the currently authenticated user (or null for anon)
create or replace function current_firebase_uid()
returns text
language sql stable
as $$
  select coalesce(auth.jwt() ->> 'sub', '');
$$;

-- Internal users.id row for the currently authenticated user
create or replace function current_app_user_id()
returns uuid
language sql stable
as $$
  select id from users where firebase_uid = current_firebase_uid();
$$;

-- Role of the currently authenticated user
create or replace function current_app_role()
returns text
language sql stable
as $$
  select role from users where firebase_uid = current_firebase_uid();
$$;

-- True if the caller is an owner/superAdmin (full access roles)
create or replace function is_admin_role()
returns boolean
language sql stable
as $$
  select current_app_role() in ('owner','superAdmin');
$$;

-- True if the caller is staff (employee/rider/dispatcher/branchManager/owner/superAdmin)
create or replace function is_staff_role()
returns boolean
language sql stable
as $$
  select current_app_role() in
    ('employee','rider','dispatcher','branchManager','owner','superAdmin');
$$;

-- ------------------------------------------------------------
-- Enable RLS on all tables
-- ------------------------------------------------------------
alter table users                enable row level security;
alter table addresses            enable row level security;
alter table categories           enable row level security;
alter table products             enable row level security;
alter table orders               enable row level security;
alter table order_items          enable row level security;
alter table order_status_history enable row level security;
alter table wallet_transactions  enable row level security;
alter table delivery_tracking    enable row level security;
alter table reviews              enable row level security;
alter table notifications        enable row level security;
alter table support_tickets      enable row level security;
alter table coupons              enable row level security;
alter table inventory_logs       enable row level security;
alter table audit_logs           enable row level security;
alter table kyc_documents        enable row level security;

-- ------------------------------------------------------------
-- users
-- ------------------------------------------------------------
create policy users_select_own on users
  for select using (firebase_uid = current_firebase_uid() or is_admin_role());

create policy users_update_own on users
  for update using (firebase_uid = current_firebase_uid() or is_admin_role());

create policy users_admin_all on users
  for all using (is_admin_role());

-- ------------------------------------------------------------
-- addresses — customer owns their own addresses
-- ------------------------------------------------------------
create policy addresses_owner on addresses
  for all using (user_id = current_app_user_id() or is_admin_role());

-- ------------------------------------------------------------
-- categories — public read, admin write
-- ------------------------------------------------------------
create policy categories_read_all on categories
  for select using (true);

create policy categories_admin_write on categories
  for all using (is_admin_role());

-- ------------------------------------------------------------
-- products — public read (active only for customers), staff/admin manage
-- ------------------------------------------------------------
create policy products_read_active on products
  for select using (status = 'active' or is_staff_role());

create policy products_staff_write on products
  for all using (is_staff_role());

-- ------------------------------------------------------------
-- orders — customer reads/writes own orders; staff read shop/branch orders;
-- admins full access
-- ------------------------------------------------------------
create policy orders_customer_own on orders
  for select using (user_id = current_app_user_id());

create policy orders_customer_insert on orders
  for insert with check (user_id = current_app_user_id());

create policy orders_staff_shop on orders
  for select using (
    is_staff_role() and (
      vendor_id = current_app_user_id()
      or driver_id = current_app_user_id()
      or is_admin_role()
    )
  );

create policy orders_staff_update on orders
  for update using (
    is_staff_role() and (
      vendor_id = current_app_user_id()
      or driver_id = current_app_user_id()
      or is_admin_role()
    )
  );

create policy orders_admin_all on orders
  for all using (is_admin_role());

-- ------------------------------------------------------------
-- order_items — follow parent order visibility
-- ------------------------------------------------------------
create policy order_items_visibility on order_items
  for select using (
    exists (
      select 1 from orders o
      where o.id = order_items.order_id
        and (
          o.user_id = current_app_user_id()
          or o.vendor_id = current_app_user_id()
          or o.driver_id = current_app_user_id()
          or is_admin_role()
        )
    )
  );

create policy order_items_write on order_items
  for insert with check (
    exists (
      select 1 from orders o
      where o.id = order_items.order_id
        and (o.user_id = current_app_user_id() or is_staff_role())
    )
  );

-- ------------------------------------------------------------
-- order_status_history — read if you can read the order; staff write
-- ------------------------------------------------------------
create policy order_status_history_read on order_status_history
  for select using (
    exists (
      select 1 from orders o
      where o.id = order_status_history.order_id
        and (
          o.user_id = current_app_user_id()
          or o.vendor_id = current_app_user_id()
          or o.driver_id = current_app_user_id()
          or is_admin_role()
        )
    )
  );

create policy order_status_history_write on order_status_history
  for insert with check (is_staff_role() or is_admin_role());

-- ------------------------------------------------------------
-- wallet_transactions — customer reads own; admin full
-- ------------------------------------------------------------
create policy wallet_tx_owner on wallet_transactions
  for select using (user_id = current_app_user_id() or is_admin_role());

create policy wallet_tx_admin_write on wallet_transactions
  for insert with check (is_staff_role() or is_admin_role());

-- ------------------------------------------------------------
-- delivery_tracking — driver + order owner + admin
-- ------------------------------------------------------------
create policy delivery_tracking_visibility on delivery_tracking
  for select using (
    driver_id = current_app_user_id()
    or is_admin_role()
    or exists (
      select 1 from orders o
      where o.id = delivery_tracking.order_id
        and o.user_id = current_app_user_id()
    )
  );

create policy delivery_tracking_driver_write on delivery_tracking
  for all using (driver_id = current_app_user_id() or is_staff_role());

-- ------------------------------------------------------------
-- reviews — public read, owner writes own
-- ------------------------------------------------------------
create policy reviews_read_all on reviews
  for select using (true);

create policy reviews_owner_write on reviews
  for insert with check (user_id = current_app_user_id());

create policy reviews_owner_update on reviews
  for update using (user_id = current_app_user_id() or is_admin_role());

-- ------------------------------------------------------------
-- notifications — user reads own
-- ------------------------------------------------------------
create policy notifications_owner on notifications
  for all using (user_id = current_app_user_id() or is_admin_role());

-- ------------------------------------------------------------
-- support_tickets — customer own; staff assigned/admin
-- ------------------------------------------------------------
create policy support_tickets_owner on support_tickets
  for select using (
    user_id = current_app_user_id()
    or assigned_to = current_app_user_id()
    or is_staff_role()
  );

create policy support_tickets_owner_insert on support_tickets
  for insert with check (user_id = current_app_user_id());

create policy support_tickets_staff_update on support_tickets
  for update using (is_staff_role() or is_admin_role());

-- ------------------------------------------------------------
-- coupons — active coupons readable by all; admin manages
-- ------------------------------------------------------------
create policy coupons_read_active on coupons
  for select using (is_active = true or is_staff_role());

create policy coupons_admin_write on coupons
  for all using (is_admin_role());

-- ------------------------------------------------------------
-- inventory_logs — staff/admin only
-- ------------------------------------------------------------
create policy inventory_logs_staff on inventory_logs
  for all using (is_staff_role() or is_admin_role());

-- ------------------------------------------------------------
-- audit_logs — admin read; inserts allowed from any authenticated user
-- (writes are validated app-side; service role used for sensitive paths)
-- ------------------------------------------------------------
create policy audit_logs_admin_read on audit_logs
  for select using (is_admin_role());

create policy audit_logs_insert on audit_logs
  for insert with check (current_firebase_uid() <> '');

-- ------------------------------------------------------------
-- kyc_documents — owner + staff/admin
-- ------------------------------------------------------------
create policy kyc_documents_owner on kyc_documents
  for select using (user_id = current_app_user_id() or is_staff_role());

create policy kyc_documents_owner_insert on kyc_documents
  for insert with check (user_id = current_app_user_id());

create policy kyc_documents_staff_update on kyc_documents
  for update using (is_staff_role() or is_admin_role());
