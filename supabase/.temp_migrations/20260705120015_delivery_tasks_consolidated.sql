-- P0 FIX: Consolidate delivery service into single source of truth
-- BEFORE: Split across 7 services (workflow_engine, task_service, tracking_service, ledger_service, last_mile_service, etc.)
-- AFTER: Single delivery_tasks table with unified state machine

-- Delivery status enum
CREATE TYPE delivery_status AS ENUM (
  'assigned',      -- Task created, waiting for rider
  'picked_up',     -- Rider picked up from shop
  'in_transit',    -- On the way to customer
  'delivered',     -- Completed successfully
  'failed',        -- Delivery failed (customer unavailable, etc)
  'cancelled'      -- Cancelled by shop/customer
);

-- Consolidated delivery tasks table
CREATE TABLE delivery_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  customer_id UUID,

  -- Core delivery info
  status delivery_status NOT NULL DEFAULT 'assigned',
  delivery_fee DECIMAL(10, 2) NOT NULL,
  estimated_distance DECIMAL(8, 2),
  delivery_address TEXT,
  customer_phone TEXT,
  delivery_type VARCHAR(50) DEFAULT 'standard', -- standard, express, scheduled

  -- Rider assignment
  assigned_rider_id UUID REFERENCES delivery_agents(id),
  assigned_rider_name VARCHAR(255),
  assigned_rider_phone VARCHAR(20),

  -- Location tracking
  pickup_latitude DECIMAL(10, 8),
  pickup_longitude DECIMAL(11, 8),
  current_latitude DECIMAL(10, 8),
  current_longitude DECIMAL(11, 8),
  delivery_latitude DECIMAL(10, 8),
  delivery_longitude DECIMAL(11, 8),
  failure_latitude DECIMAL(10, 8),
  failure_longitude DECIMAL(11, 8),

  -- Proof of delivery
  proof_image_url TEXT,
  delivery_notes TEXT,

  -- Failure tracking
  failure_count INT DEFAULT 0,
  last_failure_reason TEXT,

  -- Timestamps
  created_at TIMESTAMP DEFAULT NOW(),
  assigned_at TIMESTAMP,
  picked_up_at TIMESTAMP,
  in_transit_at TIMESTAMP,
  delivered_at TIMESTAMP,
  failed_at TIMESTAMP,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX idx_delivery_tasks_order_id ON delivery_tasks(order_id);
CREATE INDEX idx_delivery_tasks_shop_id ON delivery_tasks(shop_id);
CREATE INDEX idx_delivery_tasks_status ON delivery_tasks(status);
CREATE INDEX idx_delivery_tasks_rider_id ON delivery_tasks(assigned_rider_id);
CREATE INDEX idx_delivery_tasks_rider_status ON delivery_tasks(assigned_rider_id, status);
CREATE INDEX idx_delivery_tasks_created_at ON delivery_tasks(created_at DESC);

-- Table for delivery task status history (audit trail)
CREATE TABLE delivery_task_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_task_id UUID NOT NULL REFERENCES delivery_tasks(id) ON DELETE CASCADE,
  from_status delivery_status,
  to_status delivery_status NOT NULL,
  changed_at TIMESTAMP DEFAULT NOW(),
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  reason TEXT
);

CREATE INDEX idx_delivery_status_history_task_id ON delivery_task_status_history(delivery_task_id);

-- View for rider's active deliveries (P0 FIX for query mismatch)
-- BEFORE: WHERE status == 'assigned' (failed because packing stores 'packed')
-- AFTER: WHERE status IN ['assigned', 'picked_up', 'in_transit']
CREATE VIEW rider_active_deliveries AS
SELECT
  dt.*,
  o.customer_name,
  o.customer_phone AS order_customer_phone,
  o.total_amount,
  o.delivery_address AS order_delivery_address
FROM delivery_tasks dt
JOIN orders o ON dt.order_id = o.id
WHERE dt.status IN ('assigned', 'picked_up', 'in_transit')
  AND dt.assigned_rider_id IS NOT NULL;

-- Function to validate and record status transitions
CREATE OR REPLACE FUNCTION record_delivery_status_change(
  p_task_id UUID,
  p_to_status delivery_status,
  p_reason TEXT DEFAULT NULL,
  p_latitude DECIMAL(10, 8) DEFAULT NULL,
  p_longitude DECIMAL(11, 8) DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  task_id UUID
) AS $$
DECLARE
  v_current_status delivery_status;
  v_valid_transition BOOLEAN;
BEGIN
  -- Get current status
  SELECT status INTO v_current_status FROM delivery_tasks WHERE id = p_task_id;

  IF v_current_status IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Delivery task not found'::TEXT, p_task_id;
    RETURN;
  END IF;

  -- Validate transition
  v_valid_transition := (
    (v_current_status = 'assigned' AND p_to_status IN ('picked_up', 'failed', 'cancelled')) OR
    (v_current_status = 'picked_up' AND p_to_status IN ('in_transit', 'failed', 'cancelled')) OR
    (v_current_status = 'in_transit' AND p_to_status IN ('delivered', 'failed', 'cancelled')) OR
    (v_current_status = 'failed' AND p_to_status = 'assigned')
  );

  IF NOT v_valid_transition THEN
    RETURN QUERY SELECT FALSE,
      'Invalid transition: ' || v_current_status::TEXT || ' → ' || p_to_status::TEXT,
      p_task_id;
    RETURN;
  END IF;

  -- Record status history
  INSERT INTO delivery_task_status_history (
    delivery_task_id, from_status, to_status, reason, latitude, longitude
  ) VALUES (p_task_id, v_current_status, p_to_status, p_reason, p_latitude, p_longitude);

  -- Update task status
  UPDATE delivery_tasks
  SET status = p_to_status, updated_at = NOW()
  WHERE id = p_task_id;

  RETURN QUERY SELECT TRUE, 'Delivery status updated successfully'::TEXT, p_task_id;
END;
$$ LANGUAGE plpgsql;

-- SUMMARY OF CONSOLIDATION:
--
-- BEFORE (SPLIT):
-- - delivery_service.dart (agent assignment)
-- - delivery_workflow_engine.dart (state machine - client side!)
-- - delivery_task_service.dart (task CRUD)
-- - delivery_tracking_service.dart (location updates)
-- - delivery_ledger_service.dart (ledger tracking)
-- - delivery_last_mile_service.dart (POD)
-- - unified_delivery_service.dart (client-side consolidation attempt)
--
-- AFTER (CONSOLIDATED):
-- - Single delivery_tasks table in PostgreSQL (source of truth)
-- - Supabase Edge Functions for all operations:
--   * delivery-task-create (create task when order packed)
--   * delivery-task-assign (assign to rider)
--   * delivery-task-transition (update status)
-- - Firestore synced read-only from PostgreSQL
-- - All state machine validation on server
--
-- BENEFITS:
-- 1. Single source of truth (PostgreSQL)
-- 2. Server-side state machine enforcement
-- 3. Atomic transactions prevent race conditions
-- 4. Audit trail for all changes
-- 5. Rider queries now match correctly (status IN clause)
-- 6. No more split logic across multiple files
