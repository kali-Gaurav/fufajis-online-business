-- ============================================================================
-- Core Schema for Fufaji Store
-- Created: 2026-06-28
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "cube";
CREATE EXTENSION IF NOT EXISTS "earthdistance";

-- ============================================================================
-- CUSTOMERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT auth.uid(),
  email TEXT UNIQUE NOT NULL,
  phone TEXT NOT NULL,
  full_name TEXT NOT NULL,
  avatar_url TEXT,

  -- Account info
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),
  account_type TEXT DEFAULT 'customer' CHECK (account_type IN ('customer', 'shop_owner', 'rider', 'admin')),

  -- Wallet
  wallet_balance DECIMAL(10, 2) DEFAULT 0.00,
  loyalty_points INT DEFAULT 0,

  -- Address
  default_address_line TEXT,
  default_address_lat DECIMAL(10, 8),
  default_address_lng DECIMAL(11, 8),

  -- Metadata
  preferences JSONB DEFAULT '{}'::JSONB,
  device_tokens TEXT[] DEFAULT ARRAY[]::TEXT[],

  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  deleted_at TIMESTAMP
);

-- ============================================================================
-- SHOPS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS shops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,

  name TEXT NOT NULL,
  description TEXT,
  logo_url TEXT,
  cover_image_url TEXT,

  -- Location
  address_line TEXT NOT NULL,
  latitude DECIMAL(10, 8) NOT NULL,
  longitude DECIMAL(11, 8) NOT NULL,
  service_radius_km DECIMAL(5, 2) DEFAULT 5,

  -- Operations
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'closed')),
  opening_time TIME,
  closing_time TIME,

  -- Contact
  contact_phone TEXT,
  contact_email TEXT,

  -- Stats
  total_orders INT DEFAULT 0,
  rating DECIMAL(3, 2) DEFAULT 0,
  review_count INT DEFAULT 0,

  metadata JSONB DEFAULT '{}'::JSONB,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- ============================================================================
-- PRODUCTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,

  name TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL,
  subcategory TEXT,

  price DECIMAL(10, 2) NOT NULL,
  compare_price DECIMAL(10, 2),
  cost_price DECIMAL(10, 2),

  -- Images
  main_image_url TEXT,
  gallery_images TEXT[] DEFAULT ARRAY[]::TEXT[],

  -- Stock
  total_quantity INT DEFAULT 0,
  reserved_quantity INT DEFAULT 0,

  -- Status
  is_active BOOLEAN DEFAULT true,
  is_featured BOOLEAN DEFAULT false,

  -- SEO
  meta_title TEXT,
  meta_description TEXT,
  tags TEXT[] DEFAULT ARRAY[]::TEXT[],

  -- AI/Search
  embeddings VECTOR(1536), -- For semantic search

  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  deleted_at TIMESTAMP
);

-- ============================================================================
-- INVENTORY TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,

  quantity INT NOT NULL DEFAULT 0,
  reserved_quantity INT DEFAULT 0,
  available_quantity INT GENERATED ALWAYS AS (quantity - COALESCE(reserved_quantity, 0)) STORED,

  last_stock_check TIMESTAMP,
  reorder_level INT DEFAULT 10,

  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),

  UNIQUE(product_id)
);

-- ============================================================================
-- COUPONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID REFERENCES shops(id) ON DELETE CASCADE,

  code TEXT NOT NULL,
  description TEXT,

  -- Discount
  discount_type TEXT NOT NULL CHECK (discount_type IN ('fixed', 'percentage')),
  discount_value DECIMAL(10, 2) NOT NULL,
  max_discount DECIMAL(10, 2),

  -- Conditions
  min_order_value DECIMAL(10, 2),
  max_uses INT,
  max_uses_per_customer INT,

  -- Validity
  valid_from TIMESTAMP NOT NULL,
  valid_until TIMESTAMP NOT NULL,
  is_active BOOLEAN DEFAULT true,

  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- ============================================================================
-- ORDERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,

  -- Order details
  order_number TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN (
    'pending', 'confirmed', 'preparing', 'ready', 'assigned', 'picked_up', 'delivered', 'cancelled'
  )),

  -- Items
  items JSONB NOT NULL, -- {items: [{product_id, quantity, price}]}
  subtotal DECIMAL(10, 2) NOT NULL,

  -- Pricing
  discount_amount DECIMAL(10, 2) DEFAULT 0,
  coupon_code TEXT,
  delivery_fee DECIMAL(10, 2) DEFAULT 0,
  tax_amount DECIMAL(10, 2) DEFAULT 0,
  total_amount DECIMAL(10, 2) NOT NULL,

  -- Payment
  payment_method TEXT CHECK (payment_method IN ('wallet', 'card', 'razorpay', 'cod')),
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
  razorpay_order_id TEXT,
  razorpay_payment_id TEXT,

  -- Delivery
  delivery_address_line TEXT NOT NULL,
  delivery_lat DECIMAL(10, 8),
  delivery_lng DECIMAL(11, 8),
  delivery_instructions TEXT,

  -- Notes
  customer_notes TEXT,
  internal_notes TEXT,

  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  delivered_at TIMESTAMP,
  cancelled_at TIMESTAMP
);

-- ============================================================================
-- DELIVERIES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  rider_id UUID REFERENCES customers(id) ON DELETE SET NULL,

  status TEXT DEFAULT 'pending_assignment' CHECK (status IN (
    'pending_assignment', 'assigned', 'picked_up', 'in_transit', 'delivered', 'failed'
  )),

  -- Location tracking
  pickup_lat DECIMAL(10, 8),
  pickup_lng DECIMAL(11, 8),
  delivery_lat DECIMAL(10, 8),
  delivery_lng DECIMAL(11, 8),

  current_lat DECIMAL(10, 8),
  current_lng DECIMAL(11, 8),
  location_updated_at TIMESTAMP,

  -- Proof
  delivery_photo_url TEXT,
  signature_url TEXT,

  -- Metrics
  assigned_at TIMESTAMP,
  picked_up_at TIMESTAMP,
  delivered_at TIMESTAMP,
  attempted_at TIMESTAMP,

  estimated_delivery_time TIMESTAMP,
  actual_delivery_time TIMESTAMP,

  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- ============================================================================
-- WALLETS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL UNIQUE REFERENCES customers(id) ON DELETE CASCADE,

  balance DECIMAL(10, 2) DEFAULT 0,
  total_credited DECIMAL(10, 2) DEFAULT 0,
  total_debited DECIMAL(10, 2) DEFAULT 0,

  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- ============================================================================
-- WALLET TRANSACTIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,

  type TEXT NOT NULL CHECK (type IN ('credit', 'debit')),
  amount DECIMAL(10, 2) NOT NULL,
  reason TEXT, -- refund, bonus, payment, etc.

  balance_before DECIMAL(10, 2),
  balance_after DECIMAL(10, 2),

  created_at TIMESTAMP DEFAULT now()
);

-- ============================================================================
-- REFUNDS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,

  reason TEXT NOT NULL,
  requested_by UUID NOT NULL REFERENCES customers(id),

  amount DECIMAL(10, 2) NOT NULL,
  refund_method TEXT CHECK (refund_method IN ('wallet', 'original_payment')),

  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'processed')),
  approved_by UUID REFERENCES customers(id),

  created_at TIMESTAMP DEFAULT now(),
  processed_at TIMESTAMP
);

-- ============================================================================
-- RATINGS & REVIEWS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,

  rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,

  helpful_count INT DEFAULT 0,
  unhelpful_count INT DEFAULT 0,

  is_verified_purchase BOOLEAN DEFAULT true,

  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- ============================================================================
-- AUDIT LOG TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  table_name TEXT NOT NULL,
  record_id UUID,
  action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),

  user_id UUID REFERENCES customers(id),
  changes JSONB, -- {before: {...}, after: {...}}

  ip_address INET,
  user_agent TEXT,

  created_at TIMESTAMP DEFAULT now()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Customers
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customers_status ON customers(status);
CREATE INDEX idx_customers_account_type ON customers(account_type);

-- Shops
CREATE INDEX idx_shops_owner_id ON shops(owner_id);
CREATE INDEX idx_shops_status ON shops(status);
CREATE INDEX idx_shops_location ON shops USING GIST(ll_to_earth(latitude, longitude));

-- Products
CREATE INDEX idx_products_shop_id ON products(shop_id);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_is_active ON products(is_active);
CREATE INDEX idx_products_embeddings ON products USING ivfflat (embeddings vector_cosine_ops);

-- Inventory
CREATE INDEX idx_inventory_product_id ON inventory(product_id);

-- Orders
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_shop_id ON orders(shop_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_payment_status ON orders(payment_status);
CREATE INDEX idx_orders_created_at ON orders(created_at);

-- Deliveries
CREATE INDEX idx_deliveries_order_id ON deliveries(order_id);
CREATE INDEX idx_deliveries_rider_id ON deliveries(rider_id);
CREATE INDEX idx_deliveries_status ON deliveries(status);

-- Wallets
CREATE INDEX idx_wallet_transactions_wallet_id ON wallet_transactions(wallet_id);

-- Refunds
CREATE INDEX idx_refunds_order_id ON refunds(order_id);
CREATE INDEX idx_refunds_status ON refunds(status);

-- Audit
CREATE INDEX idx_audit_log_table_name ON audit_log(table_name);
CREATE INDEX idx_audit_log_user_id ON audit_log(user_id);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at);

-- ============================================================================
-- Create updated_at trigger
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_shops_updated_at BEFORE UPDATE ON shops
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_deliveries_updated_at BEFORE UPDATE ON deliveries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_wallets_updated_at BEFORE UPDATE ON wallets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- Enable realtime for live updates
-- ============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE deliveries;
ALTER PUBLICATION supabase_realtime ADD TABLE customers;
ALTER PUBLICATION supabase_realtime ADD TABLE products;


