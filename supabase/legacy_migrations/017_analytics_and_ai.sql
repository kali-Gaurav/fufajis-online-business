-- ============================================================
-- Migration 017: Analytics & AI Engine Schema (Module 10)
-- 
-- Transitions Fufaji from real-time materialized view queries 
-- (which lock operational tables) to isolated physical analytics 
-- tables populated by batch-based aggregation.
-- ============================================================

-- Drop old materialized views to prevent conflicts
DROP MATERIALIZED VIEW IF EXISTS sales_analytics CASCADE;
DROP MATERIALIZED VIEW IF EXISTS delivery_analytics CASCADE;
DROP MATERIALIZED VIEW IF EXISTS vendor_analytics CASCADE;

-- 1. sales_analytics (Rollup of orders/revenue by shop, vendor, date)
CREATE TABLE IF NOT EXISTS sales_analytics (
    metric_id VARCHAR(128) PRIMARY KEY,
    shop_id VARCHAR(128),
    vendor_id VARCHAR(128),
    order_count INT NOT NULL DEFAULT 0,
    delivered_count INT NOT NULL DEFAULT 0,
    cancelled_count INT NOT NULL DEFAULT 0,
    revenue DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    avg_order_value DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    period VARCHAR(50) NOT NULL, -- 'daily', 'weekly', 'monthly', 'all_time'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. revenue_analytics (P&L tracking: gross, net, COGS, margins, discounts)
CREATE TABLE IF NOT EXISTS revenue_analytics (
    metric_id VARCHAR(128) PRIMARY KEY,
    metric_type VARCHAR(100) NOT NULL, -- 'gross_revenue', 'net_revenue', 'refunds', 'delivery_fees', 'tips', 'cogs', 'gross_profit'
    metric_value DOUBLE PRECISION NOT NULL,
    period VARCHAR(50) NOT NULL, -- 'daily', 'weekly', 'monthly', 'all_time'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. inventory_analytics (Stock status: turnover, low stock, dead stock)
CREATE TABLE IF NOT EXISTS inventory_analytics (
    metric_id VARCHAR(128) PRIMARY KEY,
    metric_type VARCHAR(100) NOT NULL, -- 'stock_turnover', 'out_of_stock_count', 'dead_stock_value', 'reorder_needed_count'
    metric_value DOUBLE PRECISION NOT NULL,
    period VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. delivery_analytics (Performance metrics of riders and routes)
CREATE TABLE IF NOT EXISTS delivery_analytics (
    metric_id VARCHAR(128) PRIMARY KEY,
    driver_id VARCHAR(128),
    assigned_count INT NOT NULL DEFAULT 0,
    delivered_count INT NOT NULL DEFAULT 0,
    cancelled_count INT NOT NULL DEFAULT 0,
    avg_delivery_minutes DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    period VARCHAR(50) NOT NULL, -- 'daily', 'weekly', 'monthly'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. payment_analytics (Success metrics: gateways, ratio, wallet usage)
CREATE TABLE IF NOT EXISTS payment_analytics (
    metric_id VARCHAR(128) PRIMARY KEY,
    metric_type VARCHAR(100) NOT NULL, -- 'success_rate', 'cod_ratio', 'refund_rate', 'wallet_usage_rate'
    metric_value DOUBLE PRECISION NOT NULL,
    period VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. ai_forecasts (Holt smoothing & Bedrock predictions)
CREATE TABLE IF NOT EXISTS ai_forecasts (
    forecast_id VARCHAR(128) PRIMARY KEY,
    prediction_type VARCHAR(100) NOT NULL, -- 'demand', 'revenue', 'stockout'
    prediction_window VARCHAR(50) NOT NULL, -- '7days', '30days'
    predicted_value DOUBLE PRECISION NOT NULL,
    confidence_score DOUBLE PRECISION NOT NULL,
    generated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. ai_recommendations (Prescriptive AI decisions with risk & rollback)
CREATE TABLE IF NOT EXISTS ai_recommendations (
    recommendation_id VARCHAR(128) PRIMARY KEY,
    recommendation_type VARCHAR(100) NOT NULL, -- 'reorder', 'pricing', 'delivery_routing', 'marketing'
    target_entity_type VARCHAR(100) NOT NULL, -- 'product', 'driver', 'campaign'
    target_entity_id VARCHAR(128) NOT NULL,
    recommended_action TEXT NOT NULL,
    confidence_score DOUBLE PRECISION NOT NULL,
    supporting_factors TEXT[] NOT NULL,
    expected_outcome TEXT,
    potential_risk TEXT,
    rollback_strategy TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'executed'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 8. ai_alerts (Model drift, fraud occurrences, anomalies)
CREATE TABLE IF NOT EXISTS ai_alerts (
    alert_id VARCHAR(128) PRIMARY KEY,
    alert_type VARCHAR(100) NOT NULL, -- 'anomaly', 'drift', 'hallucination_warning', 'reorder_needed', 'fraud'
    severity VARCHAR(50) NOT NULL, -- 'low', 'medium', 'high', 'critical'
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 9. vendor_analytics (Replacement for materialized view)
CREATE TABLE IF NOT EXISTS vendor_analytics (
    vendor_id VARCHAR(128) PRIMARY KEY,
    total_orders INT NOT NULL DEFAULT 0,
    delivered_orders INT NOT NULL DEFAULT 0,
    cancelled_orders INT NOT NULL DEFAULT 0,
    total_revenue DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    avg_rating DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    review_count INT NOT NULL DEFAULT 0,
    last_order_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_sales_analytics_shop ON sales_analytics(shop_id);
CREATE INDEX IF NOT EXISTS idx_revenue_analytics_type ON revenue_analytics(metric_type);
CREATE INDEX IF NOT EXISTS idx_inventory_analytics_type ON inventory_analytics(metric_type);
CREATE INDEX IF NOT EXISTS idx_delivery_analytics_driver ON delivery_analytics(driver_id);
CREATE INDEX IF NOT EXISTS idx_payment_analytics_type ON payment_analytics(metric_type);
CREATE INDEX IF NOT EXISTS idx_ai_forecasts_type ON ai_forecasts(prediction_type);
CREATE INDEX IF NOT EXISTS idx_ai_recommendations_type ON ai_recommendations(recommendation_type);
CREATE INDEX IF NOT EXISTS idx_ai_alerts_type ON ai_alerts(alert_type);
CREATE INDEX IF NOT EXISTS idx_vendor_analytics_id ON vendor_analytics(vendor_id);
