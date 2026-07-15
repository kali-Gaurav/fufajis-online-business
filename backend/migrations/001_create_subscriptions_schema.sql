-- ============================================================================
-- Migration 001: Create Subscriptions Schema
-- ============================================================================
-- Creates tables for recurring subscription orders

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'cancelled')),
  frequency VARCHAR(20) NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly')),

  start_date TIMESTAMP NOT NULL,
  next_delivery_date TIMESTAMP NOT NULL,
  cancelled_at TIMESTAMP,
  cancellation_reason TEXT,

  delivery_address_id UUID,
  payment_method_id UUID,

  total_amount DECIMAL(10, 2) NOT NULL,
  base_amount DECIMAL(10, 2) NOT NULL,
  discount_percentage DECIMAL(5, 2) DEFAULT 0,
  discount_amount DECIMAL(10, 2) DEFAULT 0,

  churn_risk DECIMAL(3, 2) DEFAULT 0, -- 0-1 probability of churn
  predicted_lifetime_value DECIMAL(10, 2) DEFAULT 0,
  items_count INT DEFAULT 0,

  idempotency_key VARCHAR(255) UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS subscription_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  product_id UUID NOT NULL,
  quantity INT NOT NULL CHECK (quantity > 0),
  price DECIMAL(10, 2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_subscriptions_customer_id ON subscriptions(customer_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_next_delivery_date ON subscriptions(next_delivery_date);
CREATE INDEX idx_subscription_items_subscription_id ON subscription_items(subscription_id);

-- Enable RLS
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Customers can view own subscriptions"
  ON subscriptions FOR SELECT
  USING (customer_id = auth.uid());

CREATE POLICY "Customers can create subscriptions"
  ON subscriptions FOR INSERT
  WITH CHECK (customer_id = auth.uid());

CREATE POLICY "Customers can update own subscriptions"
  ON subscriptions FOR UPDATE
  USING (customer_id = auth.uid());

CREATE POLICY "Customers can view own subscription items"
  ON subscription_items FOR SELECT
  USING (subscription_id IN (SELECT id FROM subscriptions WHERE customer_id = auth.uid()));
