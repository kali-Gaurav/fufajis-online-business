/**
 * PHASE A DATABASE MIGRATIONS
 * Core checkout and payment infrastructure
 *
 * Tables:
 * - products (inventory with stock tracking)
 * - reservations & reservation_items (atomic checkout holds)
 * - checkout_sessions (cart snapshots before payment)
 * - orders (final confirmed orders after payment)
 * - payments (payment transaction log with idempotency)
 * - coupons (discount codes with usage limits)
 * - users_addresses (delivery addresses)
 * - inventory_audit_log (audit trail)
 * - events (async event queue)
 * - idempotency_keys (duplicate request prevention)
 */

-- =====================================================
-- 0. SHOPS TABLE (Multi-location support)
-- =====================================================
CREATE TABLE IF NOT EXISTS shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,

    -- Location for shipping calculations
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    city VARCHAR(100),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_shops_location ON shops(latitude, longitude);

-- =====================================================
-- 1. PRODUCTS TABLE (Inventory with stock tracking)
-- =====================================================
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,

    -- Product details
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),

    -- Stock tracking (✅ FIX #4 requirement)
    total_quantity INT DEFAULT 0 CHECK (total_quantity >= 0),
    available_quantity INT DEFAULT 0 CHECK (available_quantity >= 0),
    reserved_quantity INT DEFAULT 0 CHECK (reserved_quantity >= 0),

    -- Metadata
    weight_kg DECIMAL(6, 2) CHECK (weight_kg IS NULL OR weight_kg >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_products_shop_id ON products(shop_id);
CREATE INDEX IF NOT EXISTS idx_products_available ON products(available_quantity) WHERE available_quantity > 0;

-- =====================================================
-- 2. RESERVATIONS TABLE (Atomic checkout holds)
-- =====================================================
CREATE TABLE IF NOT EXISTS reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    checkout_session_id UUID REFERENCES checkout_sessions(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,

    -- Status machine (✅ FIX #3, #4 requirement)
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'confirmed', 'expired', 'released')),
    -- Values: active, confirmed, expired, released

    -- Expiry tracking (✅ FIX #4: cleanup after 10 min)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    confirmed_at TIMESTAMP,
    expired_at TIMESTAMP,
    released_at TIMESTAMP,

    -- Reservation details
    total_items INT DEFAULT 0 CHECK (total_items >= 0)
);

CREATE INDEX IF NOT EXISTS idx_reservations_status ON reservations(status);
CREATE INDEX IF NOT EXISTS idx_reservations_expires ON reservations(expires_at) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_reservations_customer ON reservations(customer_id);
CREATE INDEX IF NOT EXISTS idx_reservations_order ON reservations(order_id);

-- =====================================================
-- 3. RESERVATION_ITEMS TABLE (Line items in reservation)
-- =====================================================
CREATE TABLE IF NOT EXISTS reservation_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reservation_id UUID NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),

    quantity INT NOT NULL,
    price_per_unit DECIMAL(10, 2),
    subtotal DECIMAL(12, 2),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_reservation_items_reservation ON reservation_items(reservation_id);
CREATE INDEX IF NOT EXISTS idx_reservation_items_product ON reservation_items(product_id);

-- =====================================================
-- 4. CHECKOUT_SESSIONS TABLE (Cart snapshots before payment)
-- =====================================================
CREATE TABLE IF NOT EXISTS checkout_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    shop_id UUID,

    -- Pricing (✅ FIX #1, #2 requirement: server-side calculations)
    subtotal DECIMAL(12, 2),
    discount_amount DECIMAL(12, 2) DEFAULT 0,
    shipping_fee DECIMAL(12, 2) DEFAULT 0,
    total_amount DECIMAL(12, 2),

    -- Coupon (✅ FIX #1)
    coupon_id UUID,
    coupon_code VARCHAR(50),

    -- Shipping (✅ FIX #2)
    delivery_type VARCHAR(20) DEFAULT 'standard',
    delivery_address_id UUID,
    estimated_delivery_date TIMESTAMP,

    -- Razorpay order
    razorpay_order_id VARCHAR(255),

    -- Idempotency
    idempotency_key VARCHAR(255) UNIQUE,

    -- Status
    status VARCHAR(50) DEFAULT 'inventory_reserved',

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_checkout_sessions_customer ON checkout_sessions(customer_id);
CREATE INDEX IF NOT EXISTS idx_checkout_sessions_status ON checkout_sessions(status);
CREATE INDEX IF NOT EXISTS idx_checkout_sessions_razorpay ON checkout_sessions(razorpay_order_id);

-- =====================================================
-- 5. ORDERS TABLE (Confirmed orders after payment)
-- =====================================================
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,

    -- Pricing (✅ FIX #1, #2: complete amounts)
    subtotal_amount DECIMAL(12, 2) CHECK (subtotal_amount >= 0),
    discount_amount DECIMAL(12, 2) DEFAULT 0 CHECK (discount_amount >= 0),
    shipping_fee DECIMAL(12, 2) DEFAULT 0 CHECK (shipping_fee >= 0),
    total_amount DECIMAL(12, 2) CHECK (total_amount >= 0),

    -- Coupon
    coupon_id UUID,

    -- Payment
    payment_order_id VARCHAR(255),
    payment_status VARCHAR(50) DEFAULT 'pending',

    -- Reservation link
    checkout_session_id UUID,
    reservation_id UUID,

    -- Delivery
    delivery_type VARCHAR(20),
    estimated_delivery_date TIMESTAMP,

    -- Status
    status VARCHAR(50) DEFAULT 'pending',

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_payment ON orders(payment_order_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at DESC);

-- =====================================================
-- 6. PAYMENTS TABLE (Payment transaction log)
-- =====================================================
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    razorpay_payment_id VARCHAR(255) UNIQUE,
    order_id UUID REFERENCES orders(id),

    status VARCHAR(50) DEFAULT 'completed',
    -- Values: completed, failed, refunded

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payments_razorpay ON payments(razorpay_payment_id);
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);

-- =====================================================
-- 7. COUPONS TABLE (✅ FIX #1: server-side validation)
-- =====================================================
CREATE TABLE IF NOT EXISTS coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,

    -- Discount details
    type VARCHAR(20) NOT NULL, -- percentage or fixed_amount
    discount_value DECIMAL(10, 2) NOT NULL,
    max_discount DECIMAL(12, 2),

    -- Validity
    valid_from TIMESTAMP,
    valid_to TIMESTAMP,
    is_active BOOLEAN DEFAULT true,

    -- Usage limits
    max_usage INT,
    used_count INT DEFAULT 0,

    -- Minimum order value
    min_order_value DECIMAL(12, 2),

    -- Category restrictions
    applicable_categories JSONB,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);
CREATE INDEX IF NOT EXISTS idx_coupons_active ON coupons(is_active) WHERE is_active = true;

-- =====================================================
-- 8. USERS_ADDRESSES TABLE (✅ FIX #2: shipping calculation)
-- =====================================================
CREATE TABLE IF NOT EXISTS users_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,

    -- Address details
    label VARCHAR(100),
    street_address VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),

    -- Coordinates for haversine (✅ FIX #2)
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),

    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_addresses_user ON users_addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_users_addresses_default ON users_addresses(user_id) WHERE is_default = true;

-- =====================================================
-- 9. INVENTORY_AUDIT_LOG TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS inventory_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,

    action VARCHAR(50),
    quantity INT,
    actor_id UUID,
    reason VARCHAR(255),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_inventory_audit_product ON inventory_audit_log(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_audit_created ON inventory_audit_log(created_at DESC);

-- =====================================================
-- 10. EVENTS TABLE (Async event queue)
-- =====================================================
CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL,
    aggregate_id UUID NOT NULL,
    partition_key UUID,

    payload JSONB,

    status VARCHAR(50) DEFAULT 'pending',
    -- Values: pending, processing, completed, failed, dlq

    priority INT DEFAULT 5,
    worker_id VARCHAR(100),

    attempt_count INT DEFAULT 0,
    max_attempts INT DEFAULT 3,

    scheduled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,

    error_message TEXT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_events_status ON events(status, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_events_partition ON events(partition_key, created_at);
CREATE INDEX IF NOT EXISTS idx_events_priority ON events(priority, created_at) WHERE status = 'pending';

-- =====================================================
-- 11. IDEMPOTENCY_KEYS TABLE (Duplicate request prevention)
-- =====================================================
CREATE TABLE IF NOT EXISTS idempotency_keys (
    idempotency_key VARCHAR(255) PRIMARY KEY,

    operation_type VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100),
    entity_id UUID,

    user_id UUID,

    response_status INT,
    response_body JSONB,

    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_idempotency_keys_user ON idempotency_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_expires ON idempotency_keys(expires_at);

-- =====================================================
-- 12. REFUND_REQUESTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS refund_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id),

    reason VARCHAR(255),
    status VARCHAR(50) DEFAULT 'pending',

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_refund_requests_order ON refund_requests(order_id);
CREATE INDEX IF NOT EXISTS idx_refund_requests_status ON refund_requests(status);
