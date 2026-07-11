-- ============================================================================
-- COMPLETE RLS ENABLEMENT FOR ALL PUBLIC TABLES
-- Created: 2026-07-11
-- Purpose: Enable RLS on ALL remaining tables without policies
-- Status: CRITICAL - 27 tables still missing RLS after migration 09
-- ============================================================================

-- ============================================================================
-- ENABLE RLS ON ALL REMAINING TABLES
-- ============================================================================
-- This is a catch-all for any tables that weren't covered in previous migrations

-- Core Tables (if not already done)
ALTER TABLE IF EXISTS customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS audit_log ENABLE ROW LEVEL SECURITY;

-- Additional transactional tables
ALTER TABLE IF EXISTS orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS order_timeline ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS rider_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS delivery_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS delivery_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS delivery_notes ENABLE ROW LEVEL SECURITY;

-- Payment & Financial
ALTER TABLE IF EXISTS refund_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS payment_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS balance_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS cash_transactions ENABLE ROW LEVEL SECURITY;

-- Inventory & Stock
ALTER TABLE IF EXISTS stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS stock_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS inventory_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS inventory_snapshots ENABLE ROW LEVEL SECURITY;

-- Search & Analytics
ALTER TABLE IF EXISTS search_queries ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS user_search_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS page_views ENABLE ROW LEVEL SECURITY;

-- Chat & Messaging
ALTER TABLE IF EXISTS chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS notifications ENABLE ROW LEVEL SECURITY;

-- Admin & Support
ALTER TABLE IF EXISTS support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS support_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS staff_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS staff_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS staff_permissions ENABLE ROW LEVEL SECURITY;

-- Additional audit & compliance
ALTER TABLE IF EXISTS login_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS api_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS system_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS error_logs ENABLE ROW LEVEL SECURITY;

-- Miscellaneous
ALTER TABLE IF EXISTS settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS email_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS sms_queue ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- CREATE POLICIES FOR TABLES THAT DON'T HAVE THEM
-- ============================================================================

-- ============================================================================
-- CUSTOMERS TABLE (if not already done)
-- ============================================================================
DROP POLICY IF EXISTS "customers_select_own" ON customers;
CREATE POLICY "customers_select_own"
  ON customers FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "customers_update_own" ON customers;
CREATE POLICY "customers_update_own"
  ON customers FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================================
-- ORDERS TABLE
-- ============================================================================
DROP POLICY IF EXISTS "orders_customer_read" ON orders;
CREATE POLICY "orders_customer_read"
  ON orders FOR SELECT
  USING (customer_id = auth.uid());

DROP POLICY IF EXISTS "orders_shop_read" ON orders;
CREATE POLICY "orders_shop_read"
  ON orders FOR SELECT
  USING (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  );

DROP POLICY IF EXISTS "orders_customer_create" ON orders;
CREATE POLICY "orders_customer_create"
  ON orders FOR INSERT
  WITH CHECK (customer_id = auth.uid());

-- ============================================================================
-- DELIVERIES TABLE
-- ============================================================================
DROP POLICY IF EXISTS "deliveries_customer_read" ON deliveries;
CREATE POLICY "deliveries_customer_read"
  ON deliveries FOR SELECT
  USING (
    order_id IN (SELECT id FROM orders WHERE customer_id = auth.uid())
  );

DROP POLICY IF EXISTS "deliveries_rider_read" ON deliveries;
CREATE POLICY "deliveries_rider_read"
  ON deliveries FOR SELECT
  USING (rider_id = auth.uid());

DROP POLICY IF EXISTS "deliveries_rider_update" ON deliveries;
CREATE POLICY "deliveries_rider_update"
  ON deliveries FOR UPDATE
  USING (rider_id = auth.uid())
  WITH CHECK (rider_id = auth.uid());

-- ============================================================================
-- WALLETS TABLE
-- ============================================================================
DROP POLICY IF EXISTS "wallets_self_read" ON wallets;
CREATE POLICY "wallets_self_read"
  ON wallets FOR SELECT
  USING (customer_id = auth.uid());

DROP POLICY IF EXISTS "wallets_prevent_update" ON wallets;
CREATE POLICY "wallets_prevent_update"
  ON wallets FOR UPDATE
  USING (false);

-- ============================================================================
-- INVENTORY TABLE (legacy, not shop_inventory)
-- ============================================================================
DROP POLICY IF EXISTS "inventory_shop_owner_read" ON inventory;
CREATE POLICY "inventory_shop_owner_read"
  ON inventory FOR SELECT
  USING (
    product_id IN (
      SELECT id FROM products
      WHERE shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "inventory_shop_owner_update" ON inventory;
CREATE POLICY "inventory_shop_owner_update"
  ON inventory FOR UPDATE
  USING (
    product_id IN (
      SELECT id FROM products
      WHERE shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
    )
  );

-- ============================================================================
-- COUPONS TABLE
-- ============================================================================
DROP POLICY IF EXISTS "coupons_public_read" ON coupons;
CREATE POLICY "coupons_public_read"
  ON coupons FOR SELECT
  USING (is_active = true AND valid_from <= NOW() AND valid_until >= NOW());

DROP POLICY IF EXISTS "coupons_owner_read" ON coupons;
CREATE POLICY "coupons_owner_read"
  ON coupons FOR SELECT
  USING (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  );

-- ============================================================================
-- REFUNDS TABLE
-- ============================================================================
DROP POLICY IF EXISTS "refunds_customer_read" ON refunds;
CREATE POLICY "refunds_customer_read"
  ON refunds FOR SELECT
  USING (
    order_id IN (SELECT id FROM orders WHERE customer_id = auth.uid())
  );

DROP POLICY IF EXISTS "refunds_customer_create" ON refunds;
CREATE POLICY "refunds_customer_create"
  ON refunds FOR INSERT
  WITH CHECK (
    order_id IN (SELECT id FROM orders WHERE customer_id = auth.uid())
  );

-- ============================================================================
-- REVIEWS TABLE
-- ============================================================================
DROP POLICY IF EXISTS "reviews_public_read" ON reviews;
CREATE POLICY "reviews_public_read"
  ON reviews FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "reviews_customer_create" ON reviews;
CREATE POLICY "reviews_customer_create"
  ON reviews FOR INSERT
  WITH CHECK (customer_id = auth.uid());

DROP POLICY IF EXISTS "reviews_customer_update" ON reviews;
CREATE POLICY "reviews_customer_update"
  ON reviews FOR UPDATE
  USING (customer_id = auth.uid())
  WITH CHECK (customer_id = auth.uid());

-- ============================================================================
-- AUDIT_LOG TABLE
-- ============================================================================
DROP POLICY IF EXISTS "audit_log_admin_read" ON audit_log;
CREATE POLICY "audit_log_admin_read"
  ON audit_log FOR SELECT
  USING (false); -- Audit logs not exposed via API

-- ============================================================================
-- ORDER_ITEMS TABLE (if exists)
-- ============================================================================
DROP POLICY IF EXISTS "order_items_customer_read" ON order_items;
CREATE POLICY "order_items_customer_read"
  ON order_items FOR SELECT
  USING (
    order_id IN (SELECT id FROM orders WHERE customer_id = auth.uid())
  );

-- ============================================================================
-- STOCK_RESERVATIONS TABLE (if exists)
-- ============================================================================
DROP POLICY IF EXISTS "stock_reservations_service_role" ON stock_reservations;
CREATE POLICY "stock_reservations_service_role"
  ON stock_reservations FOR ALL
  USING (false); -- Service role only

-- ============================================================================
-- PAYMENT_LEDGER TABLE (if exists)
-- ============================================================================
DROP POLICY IF EXISTS "payment_ledger_user_read" ON payment_ledger;
CREATE POLICY "payment_ledger_user_read"
  ON payment_ledger FOR SELECT
  USING (
    user_id = auth.uid() OR
    related_user_id = auth.uid()
  );

-- ============================================================================
-- CHAT_MESSAGES TABLE (if exists)
-- ============================================================================
DROP POLICY IF EXISTS "chat_messages_participant_read" ON chat_messages;
CREATE POLICY "chat_messages_participant_read"
  ON chat_messages FOR SELECT
  USING (
    sender_id = auth.uid() OR
    receiver_id = auth.uid()
  );

-- ============================================================================
-- NOTIFICATIONS TABLE (if exists)
-- ============================================================================
DROP POLICY IF EXISTS "notifications_self_read" ON notifications;
CREATE POLICY "notifications_self_read"
  ON notifications FOR SELECT
  USING (user_id = auth.uid());

-- ============================================================================
-- SUPPORT_TICKETS TABLE (if exists)
-- ============================================================================
DROP POLICY IF EXISTS "support_tickets_creator_read" ON support_tickets;
CREATE POLICY "support_tickets_creator_read"
  ON support_tickets FOR SELECT
  USING (
    created_by = auth.uid() OR
    assigned_to = auth.uid()
  );

-- ============================================================================
-- SETTINGS TABLE (if exists - system settings)
-- ============================================================================
DROP POLICY IF EXISTS "settings_blocked" ON settings;
CREATE POLICY "settings_blocked"
  ON settings FOR ALL
  USING (false); -- System settings not exposed

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- All public tables should now have:
-- 1. RLS ENABLED
-- 2. Appropriate policies for access control
--
-- Verify with: SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname='public';
