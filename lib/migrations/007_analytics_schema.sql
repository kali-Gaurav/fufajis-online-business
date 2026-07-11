-- Iteration 7: Analytics & Business Intelligence
-- Database Schema Migration
-- Date: 2026-07-12
-- Purpose: Create tables for analytics, reporting, and business metrics

-- =====================================================================
-- ANALYTICS DAILY SUMMARIES
-- =====================================================================
CREATE TABLE IF NOT EXISTS analytics_daily (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE NOT NULL UNIQUE,
  total_revenue DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_orders INTEGER NOT NULL DEFAULT 0,
  total_customers INTEGER NOT NULL DEFAULT 0,
  new_customers INTEGER NOT NULL DEFAULT 0,
  returning_customers INTEGER NOT NULL DEFAULT 0,
  avg_order_value DECIMAL(10,2) NOT NULL DEFAULT 0,
  delivery_success_rate DECIMAL(5,2) NOT NULL DEFAULT 0,
  customer_satisfaction DECIMAL(3,2) NOT NULL DEFAULT 0,
  peak_hour INTEGER,
  peak_hour_orders INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_analytics_daily_date ON analytics_daily(date);

-- =====================================================================
-- ANALYTICS WEEKLY SUMMARIES
-- =====================================================================
CREATE TABLE IF NOT EXISTS analytics_weekly (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start DATE NOT NULL,
  week_end DATE NOT NULL,
  total_revenue DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_orders INTEGER NOT NULL DEFAULT 0,
  new_customers INTEGER NOT NULL DEFAULT 0,
  returning_customers INTEGER NOT NULL DEFAULT 0,
  avg_order_value DECIMAL(10,2),
  avg_delivery_time INTEGER,
  delivery_success_rate DECIMAL(5,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(week_start, week_end)
);

CREATE INDEX IF NOT EXISTS idx_analytics_weekly ON analytics_weekly(week_start, week_end);

-- =====================================================================
-- ANALYTICS MONTHLY SUMMARIES
-- =====================================================================
CREATE TABLE IF NOT EXISTS analytics_monthly (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  year INTEGER NOT NULL,
  month INTEGER NOT NULL,
  total_revenue DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_orders INTEGER NOT NULL DEFAULT 0,
  new_customers INTEGER NOT NULL DEFAULT 0,
  returning_customers INTEGER NOT NULL DEFAULT 0,
  avg_order_value DECIMAL(10,2),
  growth_vs_previous_month DECIMAL(5,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(year, month)
);

CREATE INDEX IF NOT EXISTS idx_analytics_monthly ON analytics_monthly(year, month);

-- =====================================================================
-- REVENUE BREAKDOWN BY CATEGORY & PAYMENT METHOD
-- =====================================================================
CREATE TABLE IF NOT EXISTS revenue_summary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE NOT NULL,
  category_id UUID REFERENCES product_categories(id),
  payment_method VARCHAR(20), -- card, upi, cash, wallet
  total_revenue DECIMAL(10,2) NOT NULL DEFAULT 0,
  order_count INTEGER NOT NULL DEFAULT 0,
  unit_count INTEGER NOT NULL DEFAULT 0,
  avg_order_value DECIMAL(10,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(date, category_id, payment_method)
);

CREATE INDEX IF NOT EXISTS idx_revenue_summary_date ON revenue_summary(date);
CREATE INDEX IF NOT EXISTS idx_revenue_summary_category ON revenue_summary(category_id);
CREATE INDEX IF NOT EXISTS idx_revenue_summary_payment ON revenue_summary(payment_method);

-- =====================================================================
-- CUSTOMER INSIGHTS & LIFETIME VALUE
-- =====================================================================
CREATE TABLE IF NOT EXISTS customer_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL UNIQUE REFERENCES customers(id),
  lifetime_value DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_orders INTEGER NOT NULL DEFAULT 0,
  avg_order_value DECIMAL(10,2) NOT NULL DEFAULT 0,
  first_order_date DATE,
  last_order_date DATE,
  days_since_last_order INTEGER,
  customer_segment VARCHAR(20) NOT NULL DEFAULT 'occasional', -- vip, regular, occasional, inactive
  churn_risk DECIMAL(3,2) DEFAULT 0, -- 0-1 probability
  repeat_purchase_rate DECIMAL(5,2) DEFAULT 0,
  avg_days_between_orders INTEGER,
  preferred_category_id UUID REFERENCES product_categories(id),
  preferred_payment_method VARCHAR(20),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_customer_insights_customer ON customer_insights(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_insights_segment ON customer_insights(customer_segment);
CREATE INDEX IF NOT EXISTS idx_customer_insights_ltv ON customer_insights(lifetime_value DESC);
CREATE INDEX IF NOT EXISTS idx_customer_insights_churn ON customer_insights(churn_risk DESC);

-- =====================================================================
-- DELIVERY PERFORMANCE METRICS
-- =====================================================================
CREATE TABLE IF NOT EXISTS delivery_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_id UUID NOT NULL UNIQUE REFERENCES order_tracking(id),
  order_id UUID NOT NULL REFERENCES orders(id),
  agent_id UUID NOT NULL REFERENCES delivery_agents(id),
  delivery_date DATE NOT NULL,
  fulfillment_time INTEGER, -- warehouse to agent (minutes)
  actual_delivery_time INTEGER, -- agent travel time (minutes)
  on_time BOOLEAN DEFAULT true,
  eta_accuracy DECIMAL(5,2), -- percentage accuracy
  customer_rating DECIMAL(3,2),
  delivery_feedback TEXT,
  issues_count INTEGER DEFAULT 0,
  issue_types TEXT[], -- array: ['damaged', 'late', 'missing', 'quality']
  customer_signature_url VARCHAR(500),
  proof_of_delivery_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_delivery_metrics_date ON delivery_metrics(delivery_date);
CREATE INDEX IF NOT EXISTS idx_delivery_metrics_agent ON delivery_metrics(agent_id);
CREATE INDEX IF NOT EXISTS idx_delivery_metrics_ontime ON delivery_metrics(on_time);
CREATE INDEX IF NOT EXISTS idx_delivery_metrics_rating ON delivery_metrics(customer_rating);

-- =====================================================================
-- INVENTORY ANALYTICS & METRICS
-- =====================================================================
CREATE TABLE IF NOT EXISTS inventory_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id),
  metric_date DATE NOT NULL,
  stock_level INTEGER NOT NULL DEFAULT 0,
  daily_sales INTEGER NOT NULL DEFAULT 0,
  weekly_sales INTEGER NOT NULL DEFAULT 0,
  monthly_sales INTEGER NOT NULL DEFAULT 0,
  turnover_rate DECIMAL(10,2), -- units sold / avg stock
  days_to_stockout INTEGER, -- forecast based on current velocity
  stock_value DECIMAL(12,2),
  expiry_date DATE,
  alert_status VARCHAR(20) DEFAULT 'in_stock', -- in_stock, low_stock, out_of_stock, expired, near_expiry
  reorder_quantity INTEGER,
  reorder_triggered BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(product_id, metric_date)
);

CREATE INDEX IF NOT EXISTS idx_inventory_metrics_date ON inventory_metrics(metric_date);
CREATE INDEX IF NOT EXISTS idx_inventory_metrics_product ON inventory_metrics(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_metrics_alert ON inventory_metrics(alert_status);
CREATE INDEX IF NOT EXISTS idx_inventory_metrics_expiry ON inventory_metrics(expiry_date);

-- =====================================================================
-- STAFF PERFORMANCE & PRODUCTIVITY
-- =====================================================================
CREATE TABLE IF NOT EXISTS staff_performance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES staff(id),
  performance_date DATE NOT NULL,
  shift_type VARCHAR(20) NOT NULL, -- morning, afternoon, evening, night
  orders_processed INTEGER DEFAULT 0,
  items_packed INTEGER DEFAULT 0,
  efficiency_score DECIMAL(3,2), -- 0-10 scale
  quality_score DECIMAL(3,2), -- 0-10 scale (accuracy)
  customer_feedback DECIMAL(3,2), -- 0-5 scale
  attendance_status VARCHAR(20) DEFAULT 'present', -- present, absent, half_day, late
  hours_worked DECIMAL(4,2),
  breaks_taken INTEGER DEFAULT 0,
  errors_count INTEGER DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(staff_id, performance_date)
);

CREATE INDEX IF NOT EXISTS idx_staff_performance_date ON staff_performance(performance_date);
CREATE INDEX IF NOT EXISTS idx_staff_performance_staff ON staff_performance(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_performance_efficiency ON staff_performance(efficiency_score DESC);
CREATE INDEX IF NOT EXISTS idx_staff_performance_shift ON staff_performance(shift_type);

-- =====================================================================
-- ANALYTICS ALERTS & NOTIFICATIONS
-- =====================================================================
CREATE TABLE IF NOT EXISTS analytics_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_date DATE NOT NULL,
  alert_type VARCHAR(50) NOT NULL, -- low_stock, delivery_failure, customer_churn, quality_issue, revenue_drop
  severity VARCHAR(20) NOT NULL DEFAULT 'medium', -- low, medium, high, critical
  message TEXT NOT NULL,
  affected_entity_id UUID, -- product_id, agent_id, customer_id, etc
  affected_entity_type VARCHAR(50), -- product, agent, customer, category
  value_before DECIMAL(12,2),
  value_after DECIMAL(12,2),
  threshold_value DECIMAL(12,2),
  resolution_status VARCHAR(20) DEFAULT 'open', -- open, acknowledged, in_progress, resolved, ignored
  resolved_by UUID REFERENCES auth.users(id),
  resolved_at TIMESTAMP,
  resolution_notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_analytics_alerts_date ON analytics_alerts(alert_date);
CREATE INDEX IF NOT EXISTS idx_analytics_alerts_type ON analytics_alerts(alert_type);
CREATE INDEX IF NOT EXISTS idx_analytics_alerts_severity ON analytics_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_analytics_alerts_status ON analytics_alerts(resolution_status);

-- =====================================================================
-- ORDER ISSUES & PROBLEMS TRACKING
-- =====================================================================
CREATE TABLE IF NOT EXISTS analytics_issues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  issue_date DATE NOT NULL,
  issue_type VARCHAR(50) NOT NULL, -- damaged, late, quality, missing, wrong_item, quantity_mismatch
  order_id UUID REFERENCES orders(id),
  delivery_id UUID REFERENCES order_tracking(id),
  severity VARCHAR(20) DEFAULT 'medium', -- low, medium, high, critical
  issue_count INTEGER DEFAULT 1,
  resolution_status VARCHAR(20) DEFAULT 'open', -- open, in_progress, resolved, escalated
  resolution_time INTEGER, -- minutes to resolve
  resolution_method VARCHAR(100), -- refund, replacement, partial_refund, store_credit
  resolution_amount DECIMAL(10,2),
  customer_feedback DECIMAL(3,2), -- satisfaction with resolution
  root_cause VARCHAR(200),
  preventive_action TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resolved_at TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_analytics_issues_date ON analytics_issues(issue_date);
CREATE INDEX IF NOT EXISTS idx_analytics_issues_type ON analytics_issues(issue_type);
CREATE INDEX IF NOT EXISTS idx_analytics_issues_status ON analytics_issues(resolution_status);
CREATE INDEX IF NOT EXISTS idx_analytics_issues_severity ON analytics_issues(severity);

-- =====================================================================
-- ANALYTICS REPORTS (Generated/Scheduled)
-- =====================================================================
CREATE TABLE IF NOT EXISTS analytics_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_name VARCHAR(100) NOT NULL,
  report_type VARCHAR(50) NOT NULL, -- daily, weekly, monthly, custom
  created_by UUID REFERENCES auth.users(id),
  generated_at TIMESTAMP NOT NULL,
  report_start_date DATE,
  report_end_date DATE,
  report_data JSONB, -- Full report data as JSON
  pdf_file_url VARCHAR(500),
  csv_file_url VARCHAR(500),
  email_sent_to TEXT[], -- array of emails
  email_sent_at TIMESTAMP,
  is_scheduled BOOLEAN DEFAULT false,
  schedule_frequency VARCHAR(20), -- daily, weekly, monthly
  schedule_time TIME,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_analytics_reports_type ON analytics_reports(report_type);
CREATE INDEX IF NOT EXISTS idx_analytics_reports_created ON analytics_reports(generated_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_reports_scheduled ON analytics_reports(is_scheduled);

-- =====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================================
ALTER TABLE analytics_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_weekly ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_monthly ENABLE ROW LEVEL SECURITY;
ALTER TABLE revenue_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_reports ENABLE ROW LEVEL SECURITY;

-- Store owner can see all analytics
CREATE POLICY "store_owner_read_analytics" ON analytics_daily
  AS PERMISSIVE FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM stores
      WHERE stores.owner_id = auth.uid()
    )
  );

CREATE POLICY "admin_read_analytics" ON analytics_daily
  AS PERMISSIVE FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM staff
      WHERE staff.id = auth.uid()
      AND staff.role IN ('admin', 'manager')
    )
  );

-- Customer can only see their own customer_insights
CREATE POLICY "customer_read_own_insights" ON customer_insights
  AS PERMISSIVE FOR SELECT
  USING (customer_id = auth.uid());

-- Agent can see delivery_metrics for their deliveries
CREATE POLICY "agent_read_own_delivery_metrics" ON delivery_metrics
  AS PERMISSIVE FOR SELECT
  USING (agent_id = auth.uid());

-- Staff can see their own performance metrics
CREATE POLICY "staff_read_own_performance" ON staff_performance
  AS PERMISSIVE FOR SELECT
  USING (staff_id = auth.uid());

CREATE POLICY "admin_read_staff_performance" ON staff_performance
  AS PERMISSIVE FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM staff
      WHERE staff.id = auth.uid()
      AND staff.role IN ('admin', 'manager')
    )
  );

-- =====================================================================
-- AUDIT LOGGING
-- =====================================================================
CREATE TABLE IF NOT EXISTS analytics_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  action VARCHAR(50), -- view_dashboard, generate_report, export_data, dismiss_alert
  table_name VARCHAR(50),
  record_id UUID,
  changes JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_analytics_audit_user ON analytics_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_audit_action ON analytics_audit_log(action);
CREATE INDEX IF NOT EXISTS idx_analytics_audit_created ON analytics_audit_log(created_at DESC);

-- =====================================================================
-- SUMMARY & VERIFICATION
-- =====================================================================

-- Verify all tables created
-- SELECT table_name FROM information_schema.tables
-- WHERE table_schema='public'
-- AND table_name LIKE 'analytics_%' OR table_name LIKE '%_summary' OR table_name LIKE '%_metrics'
-- ORDER BY table_name;

-- =====================================================================
-- MIGRATION COMPLETE
-- Tables created: 11 analytics tables + 1 audit log table
-- Indexes created: 40+
-- RLS policies configured: 6
-- =====================================================================
