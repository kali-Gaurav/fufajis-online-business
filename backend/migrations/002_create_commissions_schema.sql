-- ============================================================================
-- Migration 002: Create Vendor Commissions Schema
-- ============================================================================
-- Tracks commissions, payouts, and vendor balances

CREATE TABLE IF NOT EXISTS vendor_commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL,
  vendor_id UUID NOT NULL,
  customer_id UUID NOT NULL,

  order_total DECIMAL(10, 2) NOT NULL,
  platform_fee DECIMAL(10, 2) NOT NULL DEFAULT 0,
  payment_gateway_fee DECIMAL(10, 2) NOT NULL DEFAULT 0,
  vendor_payout DECIMAL(10, 2) NOT NULL,
  shop_earnings DECIMAL(10, 2) NOT NULL DEFAULT 0,

  commission_rate DECIMAL(5, 2) NOT NULL DEFAULT 15,
  status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed', 'disputed')),

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS commission_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID NOT NULL,
  order_id UUID,
  commission_id UUID REFERENCES vendor_commissions(id) ON DELETE SET NULL,

  amount DECIMAL(10, 2) NOT NULL,
  direction VARCHAR(10) NOT NULL CHECK (direction IN ('debit', 'credit')),
  transaction_type VARCHAR(50) NOT NULL, -- 'order_commission', 'payout_processed', 'refund', 'adjustment'
  description TEXT,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vendor_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID NOT NULL,

  total_amount DECIMAL(10, 2) NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),

  razorpay_payout_id VARCHAR(255),
  razorpay_settlement_id VARCHAR(255),

  requested_at TIMESTAMP,
  processed_at TIMESTAMP,
  failure_reason TEXT,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vendors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  shop_name VARCHAR(255) NOT NULL,
  commission_rate DECIMAL(5, 2) DEFAULT 15,

  balance DECIMAL(12, 2) DEFAULT 0,
  balance_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  total_commissions_due DECIMAL(12, 2) DEFAULT 0,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_vendor_commissions_order_id ON vendor_commissions(order_id);
CREATE INDEX idx_vendor_commissions_vendor_id ON vendor_commissions(vendor_id);
CREATE INDEX idx_vendor_commissions_status ON vendor_commissions(status);
CREATE INDEX idx_commission_ledger_vendor_id ON commission_ledger(vendor_id);
CREATE INDEX idx_commission_ledger_created_at ON commission_ledger(created_at);
CREATE INDEX idx_vendor_payouts_vendor_id ON vendor_payouts(vendor_id);
CREATE INDEX idx_vendor_payouts_status ON vendor_payouts(status);

-- Enable RLS
ALTER TABLE vendor_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;

-- RLS Policies for vendors to view their own commissions
CREATE POLICY "Vendors can view own commissions"
  ON vendor_commissions FOR SELECT
  USING (vendor_id = auth.uid());

CREATE POLICY "Vendors can view own ledger"
  ON commission_ledger FOR SELECT
  USING (vendor_id = auth.uid());

CREATE POLICY "Vendors can view own payouts"
  ON vendor_payouts FOR SELECT
  USING (vendor_id = auth.uid());

CREATE POLICY "Vendors can view own profile"
  ON vendors FOR SELECT
  USING (user_id = auth.uid());
