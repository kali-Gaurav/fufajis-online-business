-- Order Placement Database Schemas (Commerce Engine)

-- Table for tracking orders
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL,
    cart_id VARCHAR(128),
    payment_id VARCHAR(128),
    subtotal NUMERIC(10, 2) NOT NULL,
    discount NUMERIC(10, 2) DEFAULT 0.00,
    delivery_fee NUMERIC(10, 2) DEFAULT 0.00,
    final_amount NUMERIC(10, 2) NOT NULL,
    order_status VARCHAR(50) DEFAULT 'pending' CHECK (order_status IN ('pending', 'confirmed', 'processing', 'packed', 'outForDelivery', 'delivered', 'cancelled')),
    delivery_type VARCHAR(50) DEFAULT 'standard',
    scheduled_delivery_date TIMESTAMP WITH TIME ZONE,
    time_slot VARCHAR(50),
    delivery_address_json JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table for tracking order items
CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id VARCHAR(128) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    price NUMERIC(10, 2) NOT NULL,
    unit VARCHAR(50)
);

-- Table for order payment tracking
CREATE TABLE IF NOT EXISTS order_payments (
    payment_id VARCHAR(128) PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    payment_method VARCHAR(50) NOT NULL, -- e.g. 'UPI', 'CARD', 'COD', 'WALLET'
    payment_status VARCHAR(50) NOT NULL, -- e.g. 'SUCCESS', 'FAILED', 'REFUNDED'
    amount NUMERIC(10, 2) NOT NULL,
    transaction_reference TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table for tracking order status history (audit trail)
CREATE TABLE IF NOT EXISTS order_status_logs (
    id SERIAL PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL,
    changed_by_user_id VARCHAR(128),
    note TEXT,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table for order cancellations
CREATE TABLE IF NOT EXISTS order_cancellations (
    id SERIAL PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    cancelled_by_user_id VARCHAR(128) NOT NULL,
    reason TEXT NOT NULL,
    cancelled_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table for order refunds
CREATE TABLE IF NOT EXISTS order_refunds (
    id SERIAL PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    refund_amount NUMERIC(10, 2) NOT NULL,
    refund_status VARCHAR(50) NOT NULL, -- e.g. 'PENDING', 'PROCESSED', 'FAILED'
    reason TEXT,
    reference_id VARCHAR(128),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes to optimize queries
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_payments_order ON order_payments(order_id);
CREATE INDEX IF NOT EXISTS idx_order_status_logs_order ON order_status_logs(order_id);

