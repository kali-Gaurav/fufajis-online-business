-- ============================================================================
-- Migration 003: Create Delivery & Rider Schema
-- ============================================================================
-- Tracks rider assignments, delivery status, and real-time location

CREATE TABLE IF NOT EXISTS riders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  email VARCHAR(255),

  status VARCHAR(50) NOT NULL DEFAULT 'offline' CHECK (status IN ('offline', 'online', 'available', 'on_delivery')),
  current_latitude DECIMAL(10, 8),
  current_longitude DECIMAL(11, 8),
  current_load INT DEFAULT 0,
  load_capacity INT DEFAULT 30,

  total_deliveries INT DEFAULT 0,
  rating DECIMAL(3, 2) DEFAULT 5.0,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS delivery_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL,
  rider_id UUID NOT NULL REFERENCES riders(id) ON DELETE SET NULL,
  customer_id UUID NOT NULL,

  current_status VARCHAR(50) NOT NULL DEFAULT 'pending'
    CHECK (current_status IN ('pending_assignment', 'assigned', 'picked_up', 'on_way', 'delivered', 'failed_delivery', 'unassigned')),

  current_latitude DECIMAL(10, 8),
  current_longitude DECIMAL(11, 8),
  location_accuracy DECIMAL(10, 2),

  delivery_otp VARCHAR(10),
  otp_verified BOOLEAN DEFAULT false,
  verified_at TIMESTAMP,

  estimated_delivery TIMESTAMP,
  delivered_at TIMESTAMP,

  distance_remaining_km DECIMAL(10, 2),
  eta_minutes INT,

  is_delayed BOOLEAN DEFAULT false,
  delay_reason TEXT,

  proof_photo_url TEXT,
  signature_url TEXT,
  notes TEXT,

  assigned_at TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS delivery_assignments_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL,
  rider_id UUID,
  action VARCHAR(50) NOT NULL, -- 'assigned', 'unassigned', 'delivered', 'failed'
  details JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS delivery_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  address VARCHAR(500) NOT NULL,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_riders_status ON riders(status);
CREATE INDEX idx_riders_user_id ON riders(user_id);
CREATE INDEX idx_delivery_tracking_order_id ON delivery_tracking(order_id);
CREATE INDEX idx_delivery_tracking_rider_id ON delivery_tracking(rider_id);
CREATE INDEX idx_delivery_tracking_customer_id ON delivery_tracking(customer_id);
CREATE INDEX idx_delivery_tracking_status ON delivery_tracking(current_status);
CREATE INDEX idx_delivery_assignments_log_order_id ON delivery_assignments_log(order_id);
CREATE INDEX idx_delivery_assignments_log_created_at ON delivery_assignments_log(created_at);
CREATE INDEX idx_delivery_addresses_user_id ON delivery_addresses(user_id);

-- Enable RLS
ALTER TABLE riders ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_assignments_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_addresses ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Riders can view own profile"
  ON riders FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Riders can update own profile"
  ON riders FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Customers can view own delivery tracking"
  ON delivery_tracking FOR SELECT
  USING (customer_id = auth.uid());

CREATE POLICY "Customers can view own addresses"
  ON delivery_addresses FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Customers can create addresses"
  ON delivery_addresses FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Customers can update own addresses"
  ON delivery_addresses FOR UPDATE
  USING (user_id = auth.uid());
