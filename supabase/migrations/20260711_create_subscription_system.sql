-- Phase 5B: Subscription & Recurring Orders System
-- Date: 2026-07-11

-- ============================================================================
-- SUBSCRIPTIONS TABLE
-- ============================================================================
-- Stores recurring order subscriptions per customer
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Customer Info
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,

  -- Subscription Items (JSONB: [{product_id, quantity, unit_price}, ...])
  items JSONB NOT NULL,

  -- Frequency & Delivery
  frequency VARCHAR NOT NULL, -- 'weekly', 'biweekly', 'monthly'
  next_delivery_date DATE,

  -- Pricing & Discounts
  base_amount DECIMAL(10,2) NOT NULL,
  discount_percentage DECIMAL(5,2) DEFAULT 0.0,
  discount_amount DECIMAL(10,2) DEFAULT 0.0,
  total_amount DECIMAL(10,2) NOT NULL,

  -- Payment
  payment_method_id UUID,
  currency VARCHAR DEFAULT 'INR',

  -- Status & Lifecycle
  status VARCHAR DEFAULT 'active', -- 'active', 'paused', 'cancelled'
  cancellation_reason TEXT,
  paused_until DATE,

  -- Analytics
  total_orders INT DEFAULT 0,
  total_spent DECIMAL(12,2) DEFAULT 0.0,
  churn_risk DECIMAL(3,2) DEFAULT 0.0, -- 0.0-1.0 probability
  predicted_lifetime_value DECIMAL(10,2),
  last_order_at TIMESTAMP,

  -- Timestamps
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  cancelled_at TIMESTAMP,

  CONSTRAINT churn_risk_valid CHECK (churn_risk >= 0.0 AND churn_risk <= 1.0)
);

-- Indexes
CREATE INDEX idx_subscriptions_customer ON subscriptions(customer_id);
CREATE INDEX idx_subscriptions_shop ON subscriptions(shop_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_next_delivery ON subscriptions(next_delivery_date);
CREATE INDEX idx_subscriptions_churn_risk ON subscriptions(churn_risk);

-- ============================================================================
-- SUBSCRIPTION ORDERS TABLE
-- ============================================================================
-- Links subscriptions to orders created from them
CREATE TABLE subscription_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,

  -- Status of this particular recurring order
  status VARCHAR DEFAULT 'pending', -- 'pending', 'confirmed', 'delivered', 'failed'
  failure_reason TEXT,

  -- Tracking
  created_at TIMESTAMP DEFAULT NOW(),
  ordered_at TIMESTAMP,
  delivered_at TIMESTAMP,

  UNIQUE(order_id)
);

CREATE INDEX idx_subscription_orders_subscription ON subscription_orders(subscription_id);
CREATE INDEX idx_subscription_orders_order ON subscription_orders(order_id);
CREATE INDEX idx_subscription_orders_status ON subscription_orders(status);
CREATE INDEX idx_subscription_orders_date ON subscription_orders(created_at);

-- ============================================================================
-- SUBSCRIPTION HISTORY TABLE
-- ============================================================================
-- Audit trail of subscription modifications
CREATE TABLE subscription_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,

  action VARCHAR NOT NULL, -- 'created', 'updated', 'paused', 'resumed', 'cancelled'
  old_values JSONB,
  new_values JSONB,
  reason TEXT,

  performed_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_subscription_history_subscription ON subscription_history(subscription_id);
CREATE INDEX idx_subscription_history_action ON subscription_history(action);

-- ============================================================================
-- SUBSCRIPTION ANALYTICS TABLE
-- ============================================================================
-- Monthly analytics and churn prediction per subscription
CREATE TABLE subscription_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL UNIQUE REFERENCES subscriptions(id) ON DELETE CASCADE,

  -- Churn Indicators
  churn_risk_score DECIMAL(3,2),
  days_since_last_order INT,
  order_skip_count INT DEFAULT 0,
  payment_failure_count INT DEFAULT 0,

  -- Retention Metrics
  retention_score DECIMAL(3,2),
  satisfaction_score DECIMAL(3,2),
  retention_offer_given BOOLEAN DEFAULT FALSE,
  retention_offer_accepted BOOLEAN DEFAULT FALSE,
  retention_offer_amount DECIMAL(10,2),

  -- Predicted Metrics
  predicted_lifetime_value DECIMAL(10,2),
  predicted_monthly_value DECIMAL(10,2),
  confidence_score DECIMAL(3,2),

  -- Calculated at
  calculated_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_subscription_analytics_subscription ON subscription_analytics(subscription_id);
CREATE INDEX idx_subscription_analytics_churn_risk ON subscription_analytics(churn_risk_score);
CREATE INDEX idx_subscription_analytics_retention ON subscription_analytics(retention_score);

-- ============================================================================
-- RETENTION OFFERS TABLE
-- ============================================================================
-- Track offers sent to retain at-risk subscriptions
CREATE TABLE retention_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,

  -- Offer Details
  offer_type VARCHAR NOT NULL, -- 'discount', 'free_delivery', 'extended_pause', 'gift'
  discount_percentage DECIMAL(5,2),
  discount_amount DECIMAL(10,2),
  description TEXT,

  -- Status
  status VARCHAR DEFAULT 'pending', -- 'pending', 'sent', 'accepted', 'rejected', 'expired'
  sent_at TIMESTAMP,
  expires_at TIMESTAMP,
  accepted_at TIMESTAMP,

  -- Analytics
  reason_code VARCHAR, -- 'price_sensitive', 'infrequent_use', 'competitor', 'life_event'
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_retention_offers_subscription ON retention_offers(subscription_id);
CREATE INDEX idx_retention_offers_status ON retention_offers(status);
CREATE INDEX idx_retention_offers_expires ON retention_offers(expires_at);

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE retention_offers ENABLE ROW LEVEL SECURITY;

-- Subscriptions: Customer sees own, owner sees all
CREATE POLICY subscriptions_select_policy ON subscriptions
  FOR SELECT
  USING (
    customer_id = auth.uid() -- Customer sees own subscriptions
    OR (SELECT role FROM users WHERE id = auth.uid()) IN ('owner', 'admin') -- Owner/admin see all
  );

CREATE POLICY subscriptions_insert_policy ON subscriptions
  FOR INSERT
  WITH CHECK (
    customer_id = auth.uid() -- Customer creates own subscription
    OR (SELECT role FROM users WHERE id = auth.uid()) IN ('owner', 'admin')
  );

CREATE POLICY subscriptions_update_policy ON subscriptions
  FOR UPDATE
  USING (
    customer_id = auth.uid()
    OR (SELECT role FROM users WHERE id = auth.uid()) IN ('owner', 'admin')
  );

-- Subscription Orders: Linked to subscription access
CREATE POLICY subscription_orders_select_policy ON subscription_orders
  FOR SELECT
  USING (
    subscription_id IN (
      SELECT id FROM subscriptions
      WHERE customer_id = auth.uid()
    )
    OR (SELECT role FROM users WHERE id = auth.uid()) IN ('owner', 'admin')
  );

-- ============================================================================
-- TRIGGER FUNCTIONS
-- ============================================================================

-- Update subscription total when items change
CREATE OR REPLACE FUNCTION update_subscription_total_amount()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.items IS NOT NULL THEN
    NEW.total_amount = NEW.base_amount - NEW.discount_amount;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_subscription_amount
BEFORE INSERT OR UPDATE ON subscriptions
FOR EACH ROW
EXECUTE FUNCTION update_subscription_total_amount();

-- Auto-update churn risk based on analytics
CREATE OR REPLACE FUNCTION update_churn_risk_from_analytics()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE subscriptions
  SET churn_risk = NEW.churn_risk_score
  WHERE id = NEW.subscription_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_churn_risk
AFTER INSERT OR UPDATE ON subscription_analytics
FOR EACH ROW
EXECUTE FUNCTION update_churn_risk_from_analytics();

-- ============================================================================
-- GRANTS
-- ============================================================================

GRANT SELECT, INSERT, UPDATE ON subscriptions TO authenticated;
GRANT SELECT, INSERT ON subscription_orders TO authenticated;
GRANT SELECT ON subscription_history TO authenticated;
GRANT SELECT ON subscription_analytics TO authenticated;
GRANT SELECT, INSERT, UPDATE ON retention_offers TO authenticated;

COMMIT;
