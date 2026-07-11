-- Supplier System Database Schema
-- Phase 5B: Complete supplier management system
-- Date: 2026-07-11

-- ============================================================================
-- SUPPLIERS TABLE
-- ============================================================================
-- Stores supplier profiles, credentials, and performance metrics
CREATE TABLE suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identity
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name VARCHAR NOT NULL,
  email VARCHAR UNIQUE NOT NULL,
  phone VARCHAR NOT NULL,

  -- Location & Details
  address TEXT,
  city VARCHAR,
  state VARCHAR,
  pincode VARCHAR,
  gst_number VARCHAR UNIQUE,

  -- Bank Details (encrypted in application)
  bank_account_number VARCHAR,
  bank_ifsc_code VARCHAR,
  bank_account_name VARCHAR,

  -- Status & Verification
  status VARCHAR DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'suspended'
  is_verified BOOLEAN DEFAULT FALSE,
  verification_date TIMESTAMP,

  -- Performance Metrics
  rating DECIMAL(3,2) DEFAULT 0.0, -- 0-5 stars
  total_orders INT DEFAULT 0,
  completed_orders INT DEFAULT 0,
  on_time_delivery_rate DECIMAL(5,2) DEFAULT 0.0, -- percentage
  quality_score DECIMAL(5,2) DEFAULT 0.0, -- 0-100
  response_rate DECIMAL(5,2) DEFAULT 0.0, -- percentage

  -- Configuration
  auto_order_enabled BOOLEAN DEFAULT FALSE,
  preferred_delivery_day VARCHAR, -- 'monday', 'tuesday', etc
  min_order_value DECIMAL(10,2) DEFAULT 0.0,

  -- Financial
  total_revenue DECIMAL(12,2) DEFAULT 0.0,
  total_paid DECIMAL(12,2) DEFAULT 0.0,
  total_pending DECIMAL(12,2) DEFAULT 0.0,

  -- Timestamps
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  deleted_at TIMESTAMP
);

-- Indexes for supplier queries
CREATE INDEX idx_suppliers_status ON suppliers(status);
CREATE INDEX idx_suppliers_user_id ON suppliers(user_id);
CREATE INDEX idx_suppliers_email ON suppliers(email);
CREATE INDEX idx_suppliers_gst ON suppliers(gst_number);

-- ============================================================================
-- SUPPLIER REORDER RULES
-- ============================================================================
-- Defines auto-order triggers for each supplier
CREATE TABLE supplier_reorder_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,

  -- Trigger Configuration
  reorder_point INT NOT NULL, -- Order when stock falls below this
  order_quantity INT NOT NULL, -- Order this quantity
  lead_time_days INT DEFAULT 1, -- Expected delivery days

  -- Pricing
  unit_price DECIMAL(10,2) NOT NULL,
  discount_percentage DECIMAL(5,2) DEFAULT 0.0,
  min_order_qty INT DEFAULT 1,
  max_order_qty INT DEFAULT 1000,

  -- Status
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  UNIQUE(supplier_id, product_id, shop_id)
);

CREATE INDEX idx_reorder_rules_supplier ON supplier_reorder_rules(supplier_id);
CREATE INDEX idx_reorder_rules_product ON supplier_reorder_rules(product_id);
CREATE INDEX idx_reorder_rules_active ON supplier_reorder_rules(active);

-- ============================================================================
-- SUPPLIER ORDERS (POs)
-- ============================================================================
-- Purchase orders from shop to supplier
CREATE TABLE supplier_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_number VARCHAR UNIQUE NOT NULL,
  supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
  shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,

  -- Order Details
  items JSONB NOT NULL, -- [{product_id, quantity, unit_price, amount}, ...]
  total_amount DECIMAL(10,2) NOT NULL,
  tax_amount DECIMAL(10,2) DEFAULT 0.0,
  discount_amount DECIMAL(10,2) DEFAULT 0.0,
  final_amount DECIMAL(10,2) NOT NULL,

  -- Delivery
  expected_delivery_date DATE NOT NULL,
  actual_delivery_date DATE,
  delivery_notes TEXT,

  -- Status Tracking
  status VARCHAR DEFAULT 'draft', -- 'draft','confirmed','dispatched','received','cancelled'
  created_by UUID REFERENCES auth.users(id),
  confirmed_by UUID REFERENCES auth.users(id),

  -- Timestamps
  created_at TIMESTAMP DEFAULT NOW(),
  confirmed_at TIMESTAMP,
  received_at TIMESTAMP,
  cancelled_at TIMESTAMP,
  updated_at TIMESTAMP DEFAULT NOW(),

  CONSTRAINT positive_amount CHECK (final_amount > 0)
);

CREATE INDEX idx_supplier_orders_supplier ON supplier_orders(supplier_id);
CREATE INDEX idx_supplier_orders_shop ON supplier_orders(shop_id);
CREATE INDEX idx_supplier_orders_status ON supplier_orders(status);
CREATE INDEX idx_supplier_orders_date ON supplier_orders(expected_delivery_date);
CREATE INDEX idx_supplier_orders_po_number ON supplier_orders(po_number);

-- ============================================================================
-- SUPPLIER PAYMENTS
-- ============================================================================
-- Track payments from shop owner to supplier (via Razorpay)
CREATE TABLE supplier_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
  supplier_order_id UUID REFERENCES supplier_orders(id) ON DELETE SET NULL,

  -- Payment Details
  amount DECIMAL(10,2) NOT NULL,
  currency VARCHAR DEFAULT 'INR',
  description TEXT,

  -- Razorpay Integration
  razorpay_payment_id VARCHAR UNIQUE,
  razorpay_transfer_id VARCHAR UNIQUE, -- Transfer to supplier bank
  razorpay_settlement_id VARCHAR,

  -- Status
  status VARCHAR DEFAULT 'pending', -- 'pending','processing','success','failed'
  failure_reason TEXT,

  -- Timestamps
  initiated_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  CONSTRAINT positive_payment CHECK (amount > 0)
);

CREATE INDEX idx_supplier_payments_supplier ON supplier_payments(supplier_id);
CREATE INDEX idx_supplier_payments_status ON supplier_payments(status);
CREATE INDEX idx_supplier_payments_razorpay ON supplier_payments(razorpay_payment_id);
CREATE INDEX idx_supplier_payments_date ON supplier_payments(created_at);

-- ============================================================================
-- SUPPLIER METRICS
-- ============================================================================
-- Monthly performance metrics for each supplier
CREATE TABLE supplier_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
  shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  metric_month DATE NOT NULL, -- First day of month

  -- Performance Data
  total_orders INT DEFAULT 0,
  completed_orders INT DEFAULT 0,
  on_time_orders INT DEFAULT 0,
  late_orders INT DEFAULT 0,
  cancelled_orders INT DEFAULT 0,

  -- Quality
  damaged_items INT DEFAULT 0,
  returned_items INT DEFAULT 0,
  quality_issues INT DEFAULT 0,

  -- Calculated Scores
  on_time_rate DECIMAL(5,2) DEFAULT 0.0,
  quality_score DECIMAL(5,2) DEFAULT 0.0,
  reliability_score DECIMAL(5,2) DEFAULT 0.0,

  -- Financial
  total_amount DECIMAL(12,2) DEFAULT 0.0,
  total_paid DECIMAL(12,2) DEFAULT 0.0,

  created_at TIMESTAMP DEFAULT NOW(),
  calculated_at TIMESTAMP,

  UNIQUE(supplier_id, shop_id, metric_month)
);

CREATE INDEX idx_supplier_metrics_supplier ON supplier_metrics(supplier_id);
CREATE INDEX idx_supplier_metrics_month ON supplier_metrics(metric_month);

-- ============================================================================
-- SUPPLIER MESSAGES
-- ============================================================================
-- Real-time communication between owner and supplier
CREATE TABLE supplier_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
  shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,

  -- Message Content
  message TEXT NOT NULL,
  message_type VARCHAR DEFAULT 'text', -- 'text','order','payment','alert'
  related_order_id UUID REFERENCES supplier_orders(id),
  related_payment_id UUID REFERENCES supplier_payments(id),

  -- Attachments
  attachments JSONB, -- [{url, filename, type}, ...]

  -- Status
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMP,

  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_supplier_messages_supplier ON supplier_messages(supplier_id);
CREATE INDEX idx_supplier_messages_sender ON supplier_messages(sender_id);
CREATE INDEX idx_supplier_messages_unread ON supplier_messages(is_read);
CREATE INDEX idx_supplier_messages_date ON supplier_messages(created_at);

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Enable RLS
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_reorder_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_messages ENABLE ROW LEVEL SECURITY;

-- Suppliers: Only owner/admin can manage, supplier can view own
CREATE POLICY suppliers_owner_policy ON suppliers
  FOR SELECT
  USING (
    auth.uid() = user_id -- Supplier can see own profile
    OR (SELECT role FROM users WHERE id = auth.uid()) = 'owner' -- Owner can see all
  );

CREATE POLICY suppliers_insert_policy ON suppliers
  FOR INSERT
  WITH CHECK ((SELECT role FROM users WHERE id = auth.uid()) IN ('owner', 'admin'));

-- Supplier Orders: Owner can manage, supplier can view their orders
CREATE POLICY supplier_orders_select_policy ON supplier_orders
  FOR SELECT
  USING (
    supplier_id IN (SELECT id FROM suppliers WHERE user_id = auth.uid()) -- Supplier
    OR (SELECT role FROM users WHERE id = auth.uid()) = 'owner' -- Owner
  );

-- Supplier Payments: Similar access control
CREATE POLICY supplier_payments_select_policy ON supplier_payments
  FOR SELECT
  USING (
    supplier_id IN (SELECT id FROM suppliers WHERE user_id = auth.uid())
    OR (SELECT role FROM users WHERE id = auth.uid()) = 'owner'
  );

-- Supplier Messages: Owner and supplier involved can see
CREATE POLICY supplier_messages_select_policy ON supplier_messages
  FOR SELECT
  USING (
    sender_id = auth.uid() -- Sender
    OR supplier_id IN (SELECT id FROM suppliers WHERE user_id = auth.uid()) -- Supplier
    OR (SELECT role FROM users WHERE id = auth.uid()) = 'owner' -- Owner
  );

-- ============================================================================
-- FUNCTIONS FOR AUTO-CALCULATION
-- ============================================================================

-- Update supplier rating based on metrics
CREATE OR REPLACE FUNCTION update_supplier_rating()
RETURNS TRIGGER AS $$
BEGIN
  -- Calculate supplier rating from last 3 months
  UPDATE suppliers
  SET rating = (
    SELECT COALESCE(
      (
        SELECT AVG((on_time_rate * 0.5 + quality_score * 0.5) / 100.0 * 5.0)
        FROM supplier_metrics
        WHERE supplier_id = NEW.supplier_id
        AND metric_month >= NOW()::date - INTERVAL '3 months'
      ),
      0.0
    )
  )
  WHERE id = NEW.supplier_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_supplier_rating
AFTER INSERT OR UPDATE ON supplier_metrics
FOR EACH ROW
EXECUTE FUNCTION update_supplier_rating();

-- Calculate order amounts
CREATE OR REPLACE FUNCTION calculate_supplier_order_final_amount()
RETURNS TRIGGER AS $$
BEGIN
  NEW.final_amount = NEW.total_amount - NEW.tax_amount + NEW.discount_amount;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calculate_order_amount
BEFORE INSERT OR UPDATE ON supplier_orders
FOR EACH ROW
EXECUTE FUNCTION calculate_supplier_order_final_amount();

-- ============================================================================
-- AUDIT LOGGING
-- ============================================================================

-- Create audit table
CREATE TABLE supplier_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id UUID REFERENCES suppliers(id),
  action VARCHAR NOT NULL, -- 'created','updated','payment','order'
  details JSONB,
  performed_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_supplier_audit_supplier ON supplier_audit_log(supplier_id);
CREATE INDEX idx_supplier_audit_date ON supplier_audit_log(created_at);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON suppliers TO authenticated;
GRANT SELECT, INSERT, UPDATE ON supplier_orders TO authenticated;
GRANT SELECT, INSERT ON supplier_payments TO authenticated;
GRANT SELECT ON supplier_metrics TO authenticated;
GRANT SELECT, INSERT ON supplier_messages TO authenticated;

COMMIT;
