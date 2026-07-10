-- Iteration 6: Order Tracking & Real-Time Delivery
-- Migration for creating order tracking tables

-- order_tracking table
CREATE TABLE IF NOT EXISTS order_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID UNIQUE NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  delivery_agent_id UUID REFERENCES delivery_agents(id),
  current_status VARCHAR NOT NULL DEFAULT 'confirmed',
  estimated_delivery_time TIMESTAMP,
  actual_delivery_time TIMESTAMP,
  proof_of_delivery_photo_url TEXT,
  delivery_notes TEXT,
  customer_location_lat DECIMAL(10, 8),
  customer_location_lng DECIMAL(11, 8),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT valid_status CHECK (current_status IN ('confirmed', 'processing', 'packed', 'shipped', 'delivered', 'cancelled'))
);

CREATE INDEX IF NOT EXISTS idx_order_tracking_order_id ON order_tracking(order_id);
CREATE INDEX IF NOT EXISTS idx_order_tracking_agent_id ON order_tracking(delivery_agent_id);
CREATE INDEX IF NOT EXISTS idx_order_tracking_status ON order_tracking(current_status);
CREATE INDEX IF NOT EXISTS idx_order_tracking_customer_location ON order_tracking(customer_location_lat, customer_location_lng);
CREATE INDEX IF NOT EXISTS idx_order_tracking_created_at ON order_tracking(created_at DESC);

-- status_events table (order status change history)
CREATE TABLE IF NOT EXISTS status_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_tracking_id UUID NOT NULL REFERENCES order_tracking(id) ON DELETE CASCADE,
  status VARCHAR NOT NULL,
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  description TEXT,
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_status_events_tracking_id ON status_events(order_tracking_id);
CREATE INDEX IF NOT EXISTS idx_status_events_timestamp ON status_events(timestamp DESC);

-- agent_locations table (time-series data for real-time tracking)
CREATE TABLE IF NOT EXISTS agent_locations (
  id BIGSERIAL PRIMARY KEY,
  agent_id UUID NOT NULL REFERENCES delivery_agents(id) ON DELETE CASCADE,
  latitude DECIMAL(10, 8) NOT NULL,
  longitude DECIMAL(11, 8) NOT NULL,
  accuracy DECIMAL(5, 2),
  speed DECIMAL(5, 2),
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_agent_locations_agent_id_timestamp ON agent_locations(agent_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_agent_locations_timestamp ON agent_locations(timestamp DESC);

-- Retention policy: Keep only last 7 days
-- Run this job periodically:
-- DELETE FROM agent_locations WHERE timestamp < NOW() - INTERVAL '7 days';

-- support_tickets table
CREATE TABLE IF NOT EXISTS support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL,
  issue_type VARCHAR NOT NULL,
  description TEXT NOT NULL,
  status VARCHAR DEFAULT 'open',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resolved_at TIMESTAMP,

  CONSTRAINT valid_issue_type CHECK (issue_type IN ('missing', 'damaged', 'wrong', 'quantity', 'delivery')),
  CONSTRAINT valid_ticket_status CHECK (status IN ('open', 'in_progress', 'resolved', 'closed'))
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_order_id ON support_tickets(order_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_customer_id ON support_tickets(customer_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_created_at ON support_tickets(created_at DESC);

-- support_messages table (conversations within support tickets)
CREATE TABLE IF NOT EXISTS support_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  sender_type VARCHAR NOT NULL,
  sender_id UUID,
  sender_name VARCHAR,
  message TEXT NOT NULL,
  attachment_url TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT valid_sender_type CHECK (sender_type IN ('customer', 'support', 'agent'))
);

CREATE INDEX IF NOT EXISTS idx_support_messages_ticket_id ON support_messages(ticket_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_created_at ON support_messages(created_at DESC);

-- Row-Level Security (RLS) Policies

-- Enable RLS on all tables
ALTER TABLE order_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Customers can only see their own order tracking
CREATE POLICY order_tracking_customer_select ON order_tracking
  FOR SELECT
  USING (
    order_id IN (SELECT id FROM orders WHERE customer_id = auth.uid())
  );

-- RLS Policy: Agents can see orders assigned to them
CREATE POLICY order_tracking_agent_select ON order_tracking
  FOR SELECT
  USING (
    delivery_agent_id = auth.uid() OR
    order_id IN (SELECT id FROM orders WHERE customer_id = auth.uid())
  );

-- RLS Policy: Customers can only see their support tickets
CREATE POLICY support_tickets_customer_select ON support_tickets
  FOR SELECT
  USING (customer_id = auth.uid());

-- RLS Policy: Support team and customers can see messages for their tickets
CREATE POLICY support_messages_select ON support_messages
  FOR SELECT
  USING (
    ticket_id IN (
      SELECT id FROM support_tickets
      WHERE customer_id = auth.uid()
    )
  );

-- Create delivery_agents table updates if not exists
ALTER TABLE delivery_agents ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE delivery_agents ADD COLUMN IF NOT EXISTS on_time_rate DECIMAL(5, 2) DEFAULT 95.0;
ALTER TABLE delivery_agents ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR;
ALTER TABLE delivery_agents ADD COLUMN IF NOT EXISTS vehicle_plate VARCHAR;
ALTER TABLE delivery_agents ADD COLUMN IF NOT EXISTS current_workload INTEGER DEFAULT 0;

-- Verification queries (run to verify migration)
-- SELECT COUNT(*) as order_tracking_count FROM order_tracking;
-- SELECT COUNT(*) as status_events_count FROM status_events;
-- SELECT COUNT(*) as agent_locations_count FROM agent_locations;
-- SELECT COUNT(*) as support_tickets_count FROM support_tickets;
-- SELECT COUNT(*) as support_messages_count FROM support_messages;
