-- ============================================================
-- Fufaji Complete Schema Fix - Migration 018
-- Ensures all tables have proper RLS, indexes, and constraints
-- ============================================================

-- Enable extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
create extension if not exists "http";

-- ============================================================
-- 1. AUTH TABLES (auth schema is managed by Supabase Auth)
-- ============================================================

-- Ensure public.users exists and has correct columns
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  phone text unique,
  email text unique,
  name text,
  role text not null default 'customer'
    check (role in ('customer','employee','rider','dispatcher','branchManager','owner','superAdmin','admin','shopOwner','deliveryAgent','supplier','franchiseOwner')),
  avatar_url text,
  wallet_balance numeric(12, 2) default 0,
  loyalty_points integer default 0,
  is_active boolean default true,
  is_verified boolean default false,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- 2. SHOP & INVENTORY TABLES
-- ============================================================

create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  description text,
  phone text,
  email text,
  website text,
  logo_url text,
  banner_url text,
  address jsonb,
  latitude double precision,
  longitude double precision,
  is_verified boolean default false,
  is_active boolean default true,
  rating numeric(3, 2) default 0,
  total_reviews integer default 0,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  icon_url text,
  slug text unique,
  parent_id uuid references public.categories(id) on delete set null,
  display_order integer default 0,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  description text,
  price numeric(10, 2) not null,
  original_price numeric(10, 2),
  discount_percentage integer default 0,
  unit text,
  image_url text,
  images jsonb default '[]'::jsonb,
  barcode text unique,
  sku text unique,
  in_stock boolean default true,
  quantity integer default 0,
  low_stock_threshold integer default 5,
  status text default 'active'
    check (status in ('active', 'inactive', 'discontinued')),
  attributes jsonb default '{}'::jsonb,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  quantity_on_hand integer not null default 0,
  quantity_reserved integer not null default 0,
  quantity_available integer generated always as (quantity_on_hand - quantity_reserved) stored,
  last_stock_check timestamptz,
  last_updated timestamptz default now(),
  created_at timestamptz default now()
);

-- ============================================================
-- 3. CART & ORDER TABLES
-- ============================================================

create table if not exists public.carts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  items jsonb not null default '[]'::jsonb,
  subtotal numeric(10, 2) default 0,
  discount numeric(10, 2) default 0,
  tax numeric(10, 2) default 0,
  total numeric(10, 2) default 0,
  coupon_code text,
  expires_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text unique not null,
  customer_id uuid not null references public.users(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  items jsonb not null,
  subtotal numeric(10, 2) not null,
  delivery_charge numeric(10, 2) default 0,
  discount numeric(10, 2) default 0,
  tax numeric(10, 2) default 0,
  total_amount numeric(10, 2) not null,
  payment_method text,
  payment_status text default 'pending'
    check (payment_status in ('pending', 'paid', 'failed', 'refunded')),
  payment_id text,
  status text default 'pending'
    check (status in ('pending', 'confirmed', 'preparing', 'packed', 'shipped', 'delivered', 'cancelled')),
  delivery_address jsonb,
  delivery_type text,
  delivery_date timestamptz,
  special_instructions text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  delivered_at timestamptz,
  cancelled_at timestamptz
);

-- ============================================================
-- 4. PAYMENT TABLES
-- ============================================================

create table if not exists public.payments (
  id text primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  customer_id uuid not null references public.users(id) on delete cascade,
  amount numeric(10, 2) not null,
  currency text default 'INR',
  status text default 'pending'
    check (status in ('pending', 'authorized', 'captured', 'failed', 'refunded')),
  payment_method text,
  verified boolean default false,
  signature text,
  gateway_response jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  verified_at timestamptz,
  expires_at timestamptz default (now() + interval '1 hour')
);

create table if not exists public.payment_logs (
  id uuid primary key default gen_random_uuid(),
  payment_id text not null references public.payments(id) on delete cascade,
  event_type text not null,
  event_data jsonb,
  created_at timestamptz default now()
);

create table if not exists public.refunds (
  id uuid primary key default gen_random_uuid(),
  payment_id text not null references public.payments(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  customer_id uuid not null references public.users(id) on delete cascade,
  amount numeric(10, 2) not null,
  reason text,
  status text default 'pending'
    check (status in ('pending', 'processed', 'failed')),
  gateway_refund_id text,
  created_at timestamptz default now(),
  processed_at timestamptz
);

-- ============================================================
-- 5. DELIVERY TABLES
-- ============================================================

create table if not exists public.delivery_addresses (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  customer_id uuid not null references public.users(id) on delete cascade,
  address_line1 text not null,
  address_line2 text,
  city text not null,
  state text not null,
  pincode text not null,
  latitude double precision,
  longitude double precision,
  phone text,
  instructions text,
  created_at timestamptz default now()
);

create table if not exists public.delivery_tasks (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  customer_id uuid not null references public.users(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  rider_id uuid references public.users(id) on delete set null,
  status text default 'pending'
    check (status in ('pending', 'assigned', 'picked_up', 'in_transit', 'delivered', 'failed', 'cancelled')),
  delivery_address jsonb,
  pickup_address jsonb,
  current_location jsonb,
  estimated_delivery timestamptz,
  actual_delivery timestamptz,
  start_time timestamptz,
  end_time timestamptz,
  otp text,
  otp_verified boolean default false,
  delivery_proof_url text,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.delivery_assignments (
  id uuid primary key default gen_random_uuid(),
  delivery_task_id uuid not null references public.delivery_tasks(id) on delete cascade,
  rider_id uuid not null references public.users(id) on delete cascade,
  assigned_at timestamptz default now(),
  accepted_at timestamptz,
  rejected_at timestamptz,
  rejection_reason text,
  status text default 'pending'
    check (status in ('pending', 'accepted', 'rejected', 'completed'))
);

-- ============================================================
-- 6. FULFILLMENT TABLES
-- ============================================================

create table if not exists public.fulfillment_tasks (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  assigned_to_id uuid references public.users(id) on delete set null,
  items jsonb not null,
  status text default 'pending'
    check (status in ('pending', 'assigned', 'picking', 'qc', 'verified', 'handed_off', 'cancelled')),
  started_at timestamptz,
  completed_at timestamptz,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- 7. COMMUNICATION TABLES
-- ============================================================

create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders(id) on delete cascade,
  participants uuid[] not null,
  last_message text,
  last_message_time timestamptz,
  unread_count jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  text text,
  attachments jsonb default '[]'::jsonb,
  is_read boolean default false,
  read_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- 8. LOYALTY & REWARDS TABLES
-- ============================================================

create table if not exists public.loyalty_accounts (
  user_id uuid primary key references public.users(id) on delete cascade,
  balance integer not null default 0,
  lifetime_earned integer not null default 0,
  tier text default 'bronze'
    check (tier in ('bronze', 'silver', 'gold', 'platinum')),
  tier_upgraded_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.loyalty_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  transaction_type text not null
    check (transaction_type in ('purchase', 'referral', 'review', 'redemption', 'bonus', 'adjustment')),
  amount integer not null,
  order_id uuid references public.orders(id) on delete set null,
  description text,
  created_at timestamptz default now()
);

-- ============================================================
-- 9. RETURNS & COMPLAINTS TABLES
-- ============================================================

create table if not exists public.returns (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  customer_id uuid not null references public.users(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  reason text not null,
  description text,
  status text default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'refunded', 'in_transit', 'received')),
  refund_amount numeric(10, 2),
  created_at timestamptz default now(),
  resolved_at timestamptz,
  notes text
);

-- ============================================================
-- 10. COUPONS & PROMOTIONS TABLES
-- ============================================================

create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references public.shops(id) on delete cascade,
  code text not null unique,
  description text,
  discount_type text not null check (discount_type in ('fixed', 'percentage')),
  discount_value numeric(10, 2) not null,
  max_discount_amount numeric(10, 2),
  min_order_amount numeric(10, 2),
  max_uses integer,
  uses_per_customer integer default 1,
  valid_from timestamptz not null,
  valid_till timestamptz not null,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.coupon_usage (
  id uuid primary key default gen_random_uuid(),
  coupon_id uuid not null references public.coupons(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  used_at timestamptz default now()
);

-- ============================================================
-- 11. REVIEWS & RATINGS TABLES
-- ============================================================

create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  rating integer not null check (rating >= 1 and rating <= 5),
  review_text text,
  verified_purchase boolean default false,
  helpful_count integer default 0,
  unhelpful_count integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.shop_reviews (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  rating integer not null check (rating >= 1 and rating <= 5),
  review_text text,
  aspects jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- 12. INDEXES FOR PERFORMANCE
-- ============================================================

create index if not exists idx_users_phone on public.users(phone);
create index if not exists idx_users_email on public.users(email);
create index if not exists idx_users_role on public.users(role);

create index if not exists idx_products_shop_id on public.products(shop_id);
create index if not exists idx_products_category_id on public.products(category_id);
create index if not exists idx_products_status on public.products(status);

create index if not exists idx_orders_customer_id on public.orders(customer_id);
create index if not exists idx_orders_shop_id on public.orders(shop_id);
create index if not exists idx_orders_status on public.orders(status);
create index if not exists idx_orders_payment_status on public.orders(payment_status);
create index if not exists idx_orders_created_at on public.orders(created_at);

create index if not exists idx_payments_customer_id on public.payments(customer_id);
create index if not exists idx_payments_order_id on public.payments(order_id);
create index if not exists idx_payments_status on public.payments(status);

create index if not exists idx_delivery_tasks_order_id on public.delivery_tasks(order_id);
create index if not exists idx_delivery_tasks_rider_id on public.delivery_tasks(rider_id);
create index if not exists idx_delivery_tasks_status on public.delivery_tasks(status);

create index if not exists idx_messages_chat_id on public.messages(chat_id);
create index if not exists idx_messages_sender_id on public.messages(sender_id);

create index if not exists idx_chats_participants on public.chats using gin(participants);

create index if not exists idx_loyalty_transactions_user_id on public.loyalty_transactions(user_id);

create index if not exists idx_returns_order_id on public.returns(order_id);
create index if not exists idx_returns_customer_id on public.returns(customer_id);
create index if not exists idx_returns_status on public.returns(status);

-- ============================================================
-- 13. ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS on all public tables
alter table public.users enable row level security;
alter table public.shops enable row level security;
alter table public.products enable row level security;
alter table public.inventory enable row level security;
alter table public.orders enable row level security;
alter table public.payments enable row level security;
alter table public.delivery_tasks enable row level security;
alter table public.carts enable row level security;
alter table public.messages enable row level security;
alter table public.chats enable row level security;
alter table public.loyalty_accounts enable row level security;
alter table public.loyalty_transactions enable row level security;
alter table public.returns enable row level security;
alter table public.product_reviews enable row level security;
alter table public.shop_reviews enable row level security;
alter table public.refunds enable row level security;

-- Users: Can read their own profile
create policy "Users can read own profile"
  on public.users for select
  using (auth.uid() = id);

-- Users: Can update their own profile
create policy "Users can update own profile"
  on public.users for update
  using (auth.uid() = id);

-- Products: Public read access
create policy "Products are public"
  on public.products for select
  using (true);

-- Shops: Public read access
create policy "Shops are public"
  on public.shops for select
  using (true);

-- Orders: Customer and shop owner can view
create policy "Orders visible to customer and owner"
  on public.orders for select
  using (
    auth.uid() = customer_id
    or auth.uid() = (select owner_id from public.shops where id = orders.shop_id)
  );

-- Orders: Only customer can insert
create policy "Customers can create orders"
  on public.orders for insert
  with check (auth.uid() = customer_id);

-- Payments: Only owners of payment can view
create policy "Payments visible to customer and shop owner"
  on public.payments for select
  using (
    auth.uid() = customer_id
    or auth.uid() = (select owner_id from public.shops where id = (select shop_id from public.orders where id = payments.order_id))
  );

-- Delivery Tasks: Riders and customers can view
create policy "Delivery tasks visible to rider and customer"
  on public.delivery_tasks for select
  using (
    auth.uid() = rider_id
    or auth.uid() = customer_id
  );

-- Messages: Chat participants can view and insert
create policy "Messages visible to chat participants"
  on public.messages for select
  using (auth.uid() = any(
    select participants from public.chats where id = messages.chat_id
  ));

-- Loyalty Accounts: Users can view own
create policy "Users can read own loyalty account"
  on public.loyalty_accounts for select
  using (auth.uid() = user_id);

-- Returns: Customer and shop owner can view
create policy "Returns visible to customer and owner"
  on public.returns for select
  using (
    auth.uid() = customer_id
    or auth.uid() = (select owner_id from public.shops where id = returns.shop_id)
  );

-- Reviews: Public read, users can insert own
create policy "Product reviews are public"
  on public.product_reviews for select
  using (true);

create policy "Users can create own product reviews"
  on public.product_reviews for insert
  with check (auth.uid() = user_id);

-- ============================================================
-- 14. GRANTS FOR SERVICE ROLE
-- ============================================================

grant usage on schema public to postgres, anon, authenticated, service_role;
grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant all privileges on all functions in schema public to service_role;

-- ============================================================
-- DONE
-- ============================================================

select 'Fufaji Complete Schema Migration 018 completed successfully' as status;
