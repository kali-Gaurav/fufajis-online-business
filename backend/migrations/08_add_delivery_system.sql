-- Migration: 08_add_delivery_system.sql
-- Purpose: Add delivery rider management, order tracking, and review system

BEGIN TRANSACTION;

-- Delivery Riders table
CREATE TABLE IF NOT EXISTS delivery_riders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  vehicle_type TEXT,
  vehicle_number TEXT,
  status TEXT DEFAULT 'inactive', -- inactive, active, on_delivery, break
  current_latitude FLOAT,
  current_longitude FLOAT,
  rating FLOAT DEFAULT 5.0,
  total_deliveries INT DEFAULT 0,
  earnings DECIMAL(10,2) DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Delivery Assignments table
CREATE TABLE IF NOT EXISTS delivery_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  rider_id UUID REFERENCES delivery_riders(id) ON DELETE SET NULL,
  assigned_at TIMESTAMP DEFAULT NOW(),
  pickup_at TIMESTAMP,
  delivered_at TIMESTAMP,
  estimated_delivery_time TIMESTAMP,
  status TEXT DEFAULT 'pending', -- pending, assigned, picked_up, in_transit, delivered, cancelled
  cancellation_reason TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Delivery Tracking table (GPS logs)
CREATE TABLE IF NOT EXISTS delivery_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id UUID NOT NULL REFERENCES delivery_assignments(id) ON DELETE CASCADE,
  latitude FLOAT NOT NULL,
  longitude FLOAT NOT NULL,
  accuracy FLOAT,
  speed FLOAT,
  timestamp TIMESTAMP DEFAULT NOW(),
  status TEXT
);

-- Reviews table
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating INT CHECK (rating >= 1 AND rating <= 5),
  title TEXT,
  comment TEXT,
  helpful_count INT DEFAULT 0,
  unhelpful_count INT DEFAULT 0,
  verified_purchase BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  CONSTRAINT unique_review_per_user UNIQUE(product_id, user_id)
);

-- Ratings Summary table
CREATE TABLE IF NOT EXISTS ratings_summary (
  product_id UUID PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
  average_rating FLOAT,
  total_reviews INT DEFAULT 0,
  rating_1_count INT DEFAULT 0,
  rating_2_count INT DEFAULT 0,
  rating_3_count INT DEFAULT 0,
  rating_4_count INT DEFAULT 0,
  rating_5_count INT DEFAULT 0,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Coupons table
CREATE TABLE IF NOT EXISTS coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  type TEXT CHECK (type IN ('percentage', 'fixed_amount')),
  discount_value DECIMAL(10,2) NOT NULL,
  max_usage INT,
  used_count INT DEFAULT 0,
  valid_from TIMESTAMP,
  valid_to TIMESTAMP,
  min_order_value DECIMAL(10,2),
  max_discount DECIMAL(10,2),
  applicable_categories TEXT[], -- array of category IDs, NULL means all
  created_by UUID REFERENCES users(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Order Events table (for order status history)
CREATE TABLE IF NOT EXISTS order_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  event_type TEXT CHECK (event_type IN ('created', 'confirmed', 'packed', 'shipped', 'delivered', 'cancelled', 'refunded')),
  timestamp TIMESTAMP DEFAULT NOW(),
  actor_id UUID REFERENCES users(id),
  details JSONB,
  CONSTRAINT event_order_unique UNIQUE(order_id, event_type, timestamp)
);

-- Search Queries table (for analytics)
CREATE TABLE IF NOT EXISTS search_queries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  query TEXT NOT NULL,
  result_count INT,
  clicked_product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  timestamp TIMESTAMP DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_delivery_riders_status ON delivery_riders(status);
CREATE INDEX IF NOT EXISTS idx_delivery_riders_user_id ON delivery_riders(user_id);
CREATE INDEX IF NOT EXISTS idx_delivery_assignments_order ON delivery_assignments(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_assignments_rider ON delivery_assignments(rider_id);
CREATE INDEX IF NOT EXISTS idx_delivery_assignments_status ON delivery_assignments(status);
CREATE INDEX IF NOT EXISTS idx_delivery_tracking_assignment ON delivery_tracking(assignment_id);
CREATE INDEX IF NOT EXISTS idx_delivery_tracking_timestamp ON delivery_tracking(timestamp);
CREATE INDEX IF NOT EXISTS idx_reviews_product ON reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_reviews_user ON reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_reviews_created ON reviews(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);
CREATE INDEX IF NOT EXISTS idx_coupons_active ON coupons(is_active, valid_to);
CREATE INDEX IF NOT EXISTS idx_order_events_order ON order_events(order_id);
CREATE INDEX IF NOT EXISTS idx_order_events_type ON order_events(event_type);
CREATE INDEX IF NOT EXISTS idx_search_queries_user ON search_queries(user_id);
CREATE INDEX IF NOT EXISTS idx_search_queries_timestamp ON search_queries(timestamp);

-- Add order_events trigger to auto-log status changes
CREATE OR REPLACE FUNCTION log_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO order_events (order_id, event_type, details)
    VALUES (NEW.id, 'status_changed', jsonb_build_object('old_status', OLD.status, 'new_status', NEW.status));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_status_changed AFTER UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION log_order_status_change();

COMMIT;
