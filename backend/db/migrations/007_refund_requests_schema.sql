-- Refund Requests Schema
-- Handles refund lifecycle for payment recovery scenarios

-- REFUND_REQUESTS: Track refund requests and their status
CREATE TABLE IF NOT EXISTS refund_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Reference to order and payment
  order_id UUID NOT NULL REFERENCES orders(id),
  payment_id VARCHAR(100),  -- Razorpay payment ID (optional, may not exist yet)
  -- Refund reason
  reason TEXT NOT NULL,  -- e.g., "Payment received but stock unavailable", "Payment after cancellation"
  -- Status tracking
  status VARCHAR(50) DEFAULT 'pending',  -- pending, processing, completed, failed
  razorpay_refund_id VARCHAR(100),  -- Refund ID from Razorpay (once created)
  refund_amount_paise INT,  -- Amount refunded in paise (if partial)
  -- Processing
  attempted_at TIMESTAMP,
  completed_at TIMESTAMP,
  failure_reason TEXT,
  attempt_count INT DEFAULT 0,
  -- Audit
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for efficient refund processing
CREATE INDEX IF NOT EXISTS idx_refund_requests_status ON refund_requests(status);
CREATE INDEX IF NOT EXISTS idx_refund_requests_order_id ON refund_requests(order_id);
CREATE INDEX IF NOT EXISTS idx_refund_requests_payment_id ON refund_requests(payment_id);
CREATE INDEX IF NOT EXISTS idx_refund_requests_created_at ON refund_requests(created_at);

-- FUNCTION: Mark refund as completed
CREATE OR REPLACE FUNCTION complete_refund(
  refund_id UUID,
  razorpay_refund_id_param VARCHAR
)
RETURNS VOID AS $$
BEGIN
  UPDATE refund_requests
  SET
    status = 'completed',
    razorpay_refund_id = razorpay_refund_id_param,
    completed_at = CURRENT_TIMESTAMP,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = refund_id;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION: Mark refund as failed
CREATE OR REPLACE FUNCTION fail_refund(
  refund_id UUID,
  failure_msg TEXT
)
RETURNS VOID AS $$
BEGIN
  UPDATE refund_requests
  SET
    status = 'failed',
    failure_reason = failure_msg,
    updated_at = CURRENT_TIMESTAMP,
    attempt_count = attempt_count + 1
  WHERE id = refund_id;
END;
$$ LANGUAGE plpgsql;
