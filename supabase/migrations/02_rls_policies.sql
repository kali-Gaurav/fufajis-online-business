-- ============================================================================
-- Row Level Security (RLS) Policies for Fufaji Store
-- Created: 2026-06-28
-- ============================================================================

-- ============================================================================
-- CUSTOMERS TABLE - RLS
-- ============================================================================
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Users can only see their own profile
CREATE POLICY "Users see own profile"
  ON customers FOR SELECT
  USING (auth.uid() = id);

-- Users can only update their own profile
CREATE POLICY "Users update own profile"
  ON customers FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Admins can see all customers
CREATE POLICY "Admins see all customers"
  ON customers FOR SELECT
  USING (
    (SELECT account_type FROM customers WHERE id = auth.uid()) = 'admin'
  );

-- ============================================================================
-- SHOPS TABLE - RLS
-- ============================================================================
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;

-- Public can see active shops
CREATE POLICY "Public see active shops"
  ON shops FOR SELECT
  USING (status = 'active');

-- Shop owners can see/edit their own shop
CREATE POLICY "Shop owners see own shop"
  ON shops FOR SELECT
  USING (owner_id = auth.uid());

CREATE POLICY "Shop owners edit own shop"
  ON shops FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Shop owners can insert their own shop
CREATE POLICY "Shop owners create shop"
  ON shops FOR INSERT
  WITH CHECK (owner_id = auth.uid());

-- ============================================================================
-- PRODUCTS TABLE - RLS
-- ============================================================================
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Public can see active products from active shops
CREATE POLICY "Public see active products"
  ON products FOR SELECT
  USING (
    is_active = true AND
    shop_id IN (
      SELECT id FROM shops WHERE status = 'active'
    )
  );

-- Shop owners can see/edit their own products
CREATE POLICY "Shop owners see own products"
  ON products FOR SELECT
  USING (
    shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY "Shop owners edit own products"
  ON products FOR UPDATE
  USING (
    shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
  );

-- Shop owners can insert products
CREATE POLICY "Shop owners insert products"
  ON products FOR INSERT
  WITH CHECK (
    shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
  );

-- ============================================================================
-- INVENTORY TABLE - RLS
-- ============================================================================
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;

-- Shop owners can see their own inventory
CREATE POLICY "Shop owners see own inventory"
  ON inventory FOR SELECT
  USING (
    product_id IN (
      SELECT id FROM products
      WHERE shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
      )
    )
  );

-- Shop owners can update their own inventory
CREATE POLICY "Shop owners update own inventory"
  ON inventory FOR UPDATE
  USING (
    product_id IN (
      SELECT id FROM products
      WHERE shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
      )
    )
  );

-- Service role (Edge Functions) can access all inventory
-- (RLS is bypassed for service_role by default)

-- ============================================================================
-- ORDERS TABLE - RLS
-- ============================================================================
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Customers see their own orders
CREATE POLICY "Customers see own orders"
  ON orders FOR SELECT
  USING (customer_id = auth.uid());

-- Shop owners see orders for their shop
CREATE POLICY "Shop owners see shop orders"
  ON orders FOR SELECT
  USING (
    shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
  );

-- Riders see assigned orders
CREATE POLICY "Riders see assigned orders"
  ON orders FOR SELECT
  USING (
    id IN (
      SELECT order_id FROM deliveries
      WHERE rider_id = auth.uid()
    )
  );

-- Customers can create orders
CREATE POLICY "Customers create orders"
  ON orders FOR INSERT
  WITH CHECK (customer_id = auth.uid());

-- Shop owners can update order status
CREATE POLICY "Shop owners update order status"
  ON orders FOR UPDATE
  USING (
    shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
  );

-- ============================================================================
-- DELIVERIES TABLE - RLS
-- ============================================================================
ALTER TABLE deliveries ENABLE ROW LEVEL SECURITY;

-- Customers see deliveries for their orders
CREATE POLICY "Customers see own deliveries"
  ON deliveries FOR SELECT
  USING (
    order_id IN (
      SELECT id FROM orders WHERE customer_id = auth.uid()
    )
  );

-- Riders see their assigned deliveries
CREATE POLICY "Riders see assigned deliveries"
  ON deliveries FOR SELECT
  USING (rider_id = auth.uid());

-- Riders can update their assigned deliveries
CREATE POLICY "Riders update assigned deliveries"
  ON deliveries FOR UPDATE
  USING (rider_id = auth.uid())
  WITH CHECK (rider_id = auth.uid());

-- Shop owners can see deliveries for their orders
CREATE POLICY "Shop owners see order deliveries"
  ON deliveries FOR SELECT
  USING (
    order_id IN (
      SELECT id FROM orders
      WHERE shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
      )
    )
  );

-- ============================================================================
-- WALLETS TABLE - RLS
-- ============================================================================
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

-- Users see their own wallet
CREATE POLICY "Users see own wallet"
  ON wallets FOR SELECT
  USING (customer_id = auth.uid());

-- Prevent direct wallet updates (use functions instead)
CREATE POLICY "Users cannot update wallet directly"
  ON wallets FOR UPDATE
  USING (false);

-- ============================================================================
-- WALLET TRANSACTIONS TABLE - RLS
-- ============================================================================
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

-- Users see their own wallet transactions
CREATE POLICY "Users see own wallet transactions"
  ON wallet_transactions FOR SELECT
  USING (
    wallet_id IN (
      SELECT id FROM wallets WHERE customer_id = auth.uid()
    )
  );

-- Prevent direct inserts (use functions instead)
CREATE POLICY "Users cannot insert transactions directly"
  ON wallet_transactions FOR INSERT
  WITH CHECK (false);

-- ============================================================================
-- COUPONS TABLE - RLS
-- ============================================================================
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;

-- Everyone can see active public coupons
CREATE POLICY "Public see active coupons"
  ON coupons FOR SELECT
  USING (is_active = true AND valid_from <= now() AND valid_until >= now());

-- Shop owners see their own coupons
CREATE POLICY "Shop owners see own coupons"
  ON coupons FOR SELECT
  USING (
    shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
  );

-- Shop owners can create coupons
CREATE POLICY "Shop owners create coupons"
  ON coupons FOR INSERT
  WITH CHECK (
    shop_id IN (
      SELECT id FROM shops WHERE owner_id = auth.uid()
    )
  );

-- ============================================================================
-- REFUNDS TABLE - RLS
-- ============================================================================
ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;

-- Customers see their own refunds
CREATE POLICY "Customers see own refunds"
  ON refunds FOR SELECT
  USING (
    requested_by = auth.uid() OR
    order_id IN (
      SELECT id FROM orders WHERE customer_id = auth.uid()
    )
  );

-- Shop owners see refunds for their orders
CREATE POLICY "Shop owners see refunds for orders"
  ON refunds FOR SELECT
  USING (
    order_id IN (
      SELECT id FROM orders
      WHERE shop_id IN (
        SELECT id FROM shops WHERE owner_id = auth.uid()
      )
    )
  );

-- Customers can request refunds
CREATE POLICY "Customers request refunds"
  ON refunds FOR INSERT
  WITH CHECK (requested_by = auth.uid());

-- ============================================================================
-- REVIEWS TABLE - RLS
-- ============================================================================
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Everyone can see reviews
CREATE POLICY "Public see reviews"
  ON reviews FOR SELECT
  USING (true);

-- Users can create reviews for their own orders
CREATE POLICY "Users create own reviews"
  ON reviews FOR INSERT
  WITH CHECK (customer_id = auth.uid());

-- Users can update their own reviews
CREATE POLICY "Users update own reviews"
  ON reviews FOR UPDATE
  USING (customer_id = auth.uid())
  WITH CHECK (customer_id = auth.uid());

-- ============================================================================
-- AUDIT LOG TABLE - RLS
-- ============================================================================
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Only admins can see audit logs
CREATE POLICY "Admins see audit logs"
  ON audit_log FOR SELECT
  USING (
    (SELECT account_type FROM customers WHERE id = auth.uid()) = 'admin'
  );

-- Service role can insert audit logs
-- (RLS bypassed for service_role)
