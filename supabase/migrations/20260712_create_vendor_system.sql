-- Phase 5B: Vendor/Seller Portal System
-- Date: 2026-07-12

-- ============================================================================
-- VENDORS TABLE
-- ============================================================================
-- Registered sellers/vendors in the marketplace
CREATE TABLE vendors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Basic Info
  name VARCHAR NOT NULL,
  email VARCHAR NOT NULL UNIQUE,
  phone VARCHAR,
  description TEXT,
  logo_url VARCHAR,
  banner_url VARCHAR,

  -- Business Details
  business_name VARCHAR NOT NULL,
  business_type VARCHAR, -- 'individual', 'shop', 'wholesale', 'brand'
  business_registration_number VARCHAR,
  tax_id VARCHAR,
  gstin VARCHAR,

  -- Addresses
  address JSONB, -- {street, city, state, pincode, country}
  billing_address JSONB,

  -- Banking
  bank_account_holder_name VARCHAR,
  bank_account_number VARCHAR,
  bank_ifsc_code VARCHAR,
  upi_id VARCHAR,

  -- Ratings & Reputation
  rating DECIMAL(3,2) DEFAULT 0.0,
  total_reviews INT DEFAULT 0,
  total_orders INT DEFAULT 0,
  response_time_hours DECIMAL(5,2),
  return_rate DECIMAL(5,2) DEFAULT 0.0,

  -- Status & Verification
  status VARCHAR DEFAULT 'pending', -- 'pending', 'approved', 'suspended', 'rejected'
  verification_status VARCHAR DEFAULT 'unverified', -- 'unverified', 'verified', 'rejected'
  document_verification_status VARCHAR DEFAULT 'pending', -- 'pending', 'verified', 'rejected'
  verification_date TIMESTAMP,
  rejection_reason TEXT,
  suspension_reason TEXT,
  suspended_until TIMESTAMP,

  -- Commission Settings
  commission_percentage DECIMAL(5,2) DEFAULT 0.0, -- Commision % shop keeps
  monthly_fee DECIMAL(10,2) DEFAULT 0.0,
  processing_fee_percentage DECIMAL(5,2) DEFAULT 0.0,

  -- Account Details
  total_commission_earned DECIMAL(12,2) DEFAULT 0.0,
  total_commission_paid DECIMAL(12,2) DEFAULT 0.0,
  balance DECIMAL(12,2) DEFAULT 0.0,
  total_products INT DEFAULT 0,

  -- Timestamps
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  CONSTRAINT rating_valid CHECK (rating >= 0.0 AND rating <= 5.0),
  CONSTRAINT commission_valid CHECK (commission_percentage >= 0.0 AND commission_percentage <= 100.0)
);

-- Indexes
CREATE INDEX idx_vendors_status ON vendors(status);
CREATE INDEX idx_vendors_verification_status ON vendors(verification_status);
CREATE INDEX idx_vendors_rating ON vendors(rating);
CREATE INDEX idx_vendors_created_at ON vendors(created_at);
CREATE INDEX idx_vendors_email ON vendors(email);

-- ============================================================================
-- VENDOR COMMISSIONS TABLE
-- ============================================================================
-- Track commissions earned by vendors per order
CREATE TABLE vendor_commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,

  -- Order Details
  order_total DECIMAL(10,2) NOT NULL,
  vendor_commission_percentage DECIMAL(5,2) NOT NULL,
  commission_amount DECIMAL(10,2) NOT NULL,
  processing_fee DECIMAL(10,2) DEFAULT 0.0,
  vendor_net_amount DECIMAL(10,2) NOT NULL,

  -- Payment Status
  status VARCHAR DEFAULT 'pending', -- 'pending', 'processed', 'paid', 'disputed'
  paid_at TIMESTAMP,
  payout_id UUID,

  -- Timestamps
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_vendor_commissions_vendor ON vendor_commissions(vendor_id);
CREATE INDEX idx_vendor_commissions_order ON vendor_commissions(order_id);
CREATE INDEX idx_vendor_commissions_status ON vendor_commissions(status);
CREATE INDEX idx_vendor_commissions_created_at ON vendor_commissions(created_at);

-- ============================================================================
-- VENDOR PAYOUTS TABLE
-- ============================================================================
-- Track settlement/payout requests and status
CREATE TABLE vendor_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,

  -- Payout Details
  total_amount DECIMAL(12,2) NOT NULL,
  commission_count INT NOT NULL, -- How many commissions in this payout
  status VARCHAR DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed', 'refunded'
  payout_method VARCHAR DEFAULT 'bank', -- 'bank', 'upi', 'wallet'

  -- Razorpay Integration
  razorpay_payout_id VARCHAR UNIQUE,
  razorpay_settlement_id VARCHAR,
  failure_reason TEXT,

  -- Dates
  requested_at TIMESTAMP,
  processed_at TIMESTAMP,
  failed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_vendor_payouts_vendor ON vendor_payouts(vendor_id);
CREATE INDEX idx_vendor_payouts_status ON vendor_payouts(status);
CREATE INDEX idx_vendor_payouts_created_at ON vendor_payouts(created_at);
CREATE INDEX idx_vendor_payouts_razorpay_id ON vendor_payouts(razorpay_payout_id);

-- ============================================================================
-- VENDOR DISPUTES TABLE
-- ============================================================================
-- Track disputes/conflicts raised by vendors
CREATE TABLE vendor_disputes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  commission_id UUID REFERENCES vendor_commissions(id) ON DELETE SET NULL,

  -- Dispute Details
  dispute_type VARCHAR NOT NULL, -- 'commission', 'payment', 'order', 'product', 'other'
  subject VARCHAR NOT NULL,
  description TEXT NOT NULL,
  status VARCHAR DEFAULT 'open', -- 'open', 'in_review', 'resolved', 'closed'
  resolution TEXT,

  -- Evidence
  attachments JSONB, -- [{url, type, uploaded_at}, ...]
  evidence_from_vendor JSONB,
  evidence_from_admin JSONB,

  -- Dates
  resolution_date TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_vendor_disputes_vendor ON vendor_disputes(vendor_id);
CREATE INDEX idx_vendor_disputes_status ON vendor_disputes(status);
CREATE INDEX idx_vendor_disputes_type ON vendor_disputes(dispute_type);
CREATE INDEX idx_vendor_disputes_created_at ON vendor_disputes(created_at);

-- ============================================================================
-- VENDOR ANALYTICS TABLE
-- ============================================================================
-- Performance metrics and KPIs for vendors
CREATE TABLE vendor_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID NOT NULL UNIQUE REFERENCES vendors(id) ON DELETE CASCADE,

  -- Sales Metrics
  total_sales DECIMAL(12,2) DEFAULT 0.0,
  total_sales_this_month DECIMAL(12,2) DEFAULT 0.0,
  total_orders_this_month INT DEFAULT 0,
  avg_order_value DECIMAL(10,2) DEFAULT 0.0,
  sales_trend_percentage DECIMAL(5,2) DEFAULT 0.0, -- % change vs previous month

  -- Performance Metrics
  on_time_delivery_rate DECIMAL(5,2) DEFAULT 0.0,
  return_rate DECIMAL(5,2) DEFAULT 0.0,
  cancellation_rate DECIMAL(5,2) DEFAULT 0.0,
  customer_satisfaction_score DECIMAL(3,2) DEFAULT 0.0,
  response_time_hours DECIMAL(5,2) DEFAULT 0.0,

  -- Commission & Payout
  total_commission_this_month DECIMAL(10,2) DEFAULT 0.0,
  pending_payout_amount DECIMAL(10,2) DEFAULT 0.0,
  payout_frequency_days INT DEFAULT 30, -- How often they request payouts

  -- Health Score (0-100)
  vendor_health_score INT DEFAULT 0,

  -- Calculated at
  calculated_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_vendor_analytics_vendor ON vendor_analytics(vendor_id);
CREATE INDEX idx_vendor_analytics_health_score ON vendor_analytics(vendor_health_score);
CREATE INDEX idx_vendor_analytics_calculated_at ON vendor_analytics(calculated_at);

-- ============================================================================
-- VENDOR REVIEWS TABLE
-- ============================================================================
-- Reviews & ratings given to vendors by customers
CREATE TABLE vendor_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,

  -- Review Content
  rating INT NOT NULL, -- 1-5
  comment TEXT,
  title VARCHAR,

  -- Aspect Ratings
  product_quality_rating INT,
  delivery_speed_rating INT,
  customer_service_rating INT,
  packaging_rating INT,

  -- Review Status
  verified_purchase BOOLEAN DEFAULT TRUE,
  helpful_count INT DEFAULT 0,
  status VARCHAR DEFAULT 'published', -- 'draft', 'published', 'rejected'

  -- Timestamps
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  CONSTRAINT rating_valid CHECK (rating >= 1 AND rating <= 5)
);

CREATE INDEX idx_vendor_reviews_vendor ON vendor_reviews(vendor_id);
CREATE INDEX idx_vendor_reviews_rating ON vendor_reviews(rating);
CREATE INDEX idx_vendor_reviews_created_at ON vendor_reviews(created_at);
CREATE INDEX idx_vendor_reviews_verified ON vendor_reviews(verified_purchase);

-- ============================================================================
-- PRODUCTS TABLE MODIFICATIONS
-- ============================================================================
-- Add vendor_id to products table to track which vendor owns each product
ALTER TABLE products ADD COLUMN vendor_id UUID REFERENCES vendors(id) ON DELETE SET NULL;
CREATE INDEX idx_products_vendor ON products(vendor_id);

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_reviews ENABLE ROW LEVEL SECURITY;

-- Vendors: Vendor sees own, owner/admin see all
CREATE POLICY vendors_select_policy ON vendors
  FOR SELECT
  USING (
    id IN (SELECT vendor_id FROM vendors WHERE id = auth.uid())
    OR (SELECT role FROM users WHERE id = auth.uid()) IN ('owner', 'admin')
  );

CREATE POLICY vendors_update_policy ON vendors
  FOR UPDATE
  USING (
    id IN (SELECT vendor_id FROM vendors WHERE id = auth.uid())
    OR (SELECT role FROM users WHERE id = auth.uid()) IN ('owner', 'admin')
  );

-- Vendor Commissions: Vendor sees own, owner/admin see all
CREATE POLICY vendor_commissions_select_policy ON vendor_commissions
  FOR SELECT
  USING (
    vendor_id IN (SELECT id FROM vendors WHERE id = auth.uid())
    OR (SELECT role FROM users WHERE id = auth.uid()) IN ('owner', 'admin')
  );

-- ============================================================================
-- TRIGGER FUNCTIONS
-- ============================================================================

-- Update vendor balance when commission is paid
CREATE OR REPLACE FUNCTION update_vendor_balance_on_payout()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'paid' AND OLD.status != 'paid' THEN
    UPDATE vendors
    SET balance = balance + NEW.vendor_net_amount,
        total_commission_paid = total_commission_paid + NEW.vendor_net_amount
    WHERE id = NEW.vendor_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_vendor_balance
AFTER UPDATE ON vendor_commissions
FOR EACH ROW
EXECUTE FUNCTION update_vendor_balance_on_payout();

-- Update vendor rating when review is published
CREATE OR REPLACE FUNCTION update_vendor_rating_on_review()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'published' AND OLD.status != 'published' THEN
    UPDATE vendors
    SET rating = (
      SELECT COALESCE(AVG(rating), 0.0)::DECIMAL(3,2) FROM vendor_reviews
      WHERE vendor_id = NEW.vendor_id AND status = 'published'
    ),
    total_reviews = (
      SELECT COUNT(*) FROM vendor_reviews
      WHERE vendor_id = NEW.vendor_id AND status = 'published'
    )
    WHERE id = NEW.vendor_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_vendor_rating
AFTER INSERT OR UPDATE ON vendor_reviews
FOR EACH ROW
EXECUTE FUNCTION update_vendor_rating_on_review();

-- ============================================================================
-- GRANTS
-- ============================================================================

GRANT SELECT ON vendors TO authenticated;
GRANT INSERT, UPDATE ON vendors TO authenticated;
GRANT SELECT, INSERT ON vendor_commissions TO authenticated;
GRANT SELECT ON vendor_payouts TO authenticated;
GRANT SELECT, INSERT, UPDATE ON vendor_disputes TO authenticated;
GRANT SELECT ON vendor_analytics TO authenticated;
GRANT SELECT, INSERT ON vendor_reviews TO authenticated;

COMMIT;
