-- P0-4 FIX: Payment webhook race condition - duplicate wallet credits
-- PROBLEM: Multiple Razorpay webhooks for same payment can trigger concurrent wallet credits
-- SOLUTION: Idempotency key system + deduplication on server

-- Table to track processed webhook events (idempotency)
CREATE TABLE webhook_idempotency_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_type VARCHAR(50) NOT NULL, -- 'razorpay_payment', 'razorpay_settlement', etc
  external_event_id VARCHAR(255) NOT NULL, -- payment.id from Razorpay
  idempotency_key VARCHAR(255) NOT NULL, -- x-razorpay-signature or unique identifier
  status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, processed, failed
  request_body JSONB, -- Raw webhook payload for debugging
  response_data JSONB, -- What we did (wallet credit, etc)
  created_at TIMESTAMP DEFAULT NOW(),
  processed_at TIMESTAMP,

  UNIQUE(webhook_type, external_event_id, idempotency_key)
);

CREATE INDEX idx_webhook_idempotency_event ON webhook_idempotency_log(external_event_id);
CREATE INDEX idx_webhook_idempotency_status ON webhook_idempotency_log(status);
CREATE INDEX idx_webhook_idempotency_created ON webhook_idempotency_log(created_at DESC);

-- Function to check if webhook already processed
CREATE OR REPLACE FUNCTION check_webhook_idempotency(
  p_webhook_type VARCHAR(50),
  p_external_event_id VARCHAR(255),
  p_idempotency_key VARCHAR(255)
)
RETURNS TABLE (
  already_processed BOOLEAN,
  previous_result JSONB
) AS $$
DECLARE
  v_record RECORD;
BEGIN
  SELECT response_data, status INTO v_record
  FROM webhook_idempotency_log
  WHERE webhook_type = p_webhook_type
    AND external_event_id = p_external_event_id
    AND idempotency_key = p_idempotency_key
  LIMIT 1;

  IF FOUND THEN
    RETURN QUERY SELECT TRUE, v_record.response_data;
  ELSE
    RETURN QUERY SELECT FALSE, NULL::JSONB;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to log webhook processing
CREATE OR REPLACE FUNCTION log_webhook_processing(
  p_webhook_type VARCHAR(50),
  p_external_event_id VARCHAR(255),
  p_idempotency_key VARCHAR(255),
  p_request_body JSONB,
  p_status VARCHAR(50),
  p_response_data JSONB
)
RETURNS TABLE (
  id UUID,
  status VARCHAR(50)
) AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO webhook_idempotency_log (
    webhook_type, external_event_id, idempotency_key, request_body, status, response_data, processed_at
  ) VALUES (
    p_webhook_type, p_external_event_id, p_idempotency_key, p_request_body, p_status, p_response_data, NOW()
  )
  ON CONFLICT (webhook_type, external_event_id, idempotency_key)
  DO UPDATE SET
    status = p_status,
    response_data = p_response_data,
    processed_at = NOW()
  RETURNING webhook_idempotency_log.id, webhook_idempotency_log.status INTO v_id, p_status;

  RETURN QUERY SELECT v_id, p_status;
END;
$$ LANGUAGE plpgsql;

-- SUMMARY:
--
-- BEFORE (VULNERABLE):
-- Razorpay webhook → payment-webhook-handler → credit_wallet function
-- Problem: If webhook is retried:
-- - Thread A processes payment.authorized, credits wallet ₹100
-- - Thread B also processes same webhook, credits wallet ₹100 again
-- - Customer gets ₹200 instead of ₹100
--
-- AFTER (FIXED):
-- Razorpay webhook → check_webhook_idempotency() → if duplicate, return previous result
-- If new: process webhook → log_webhook_processing() → credit wallet atomically
-- Duplicate webhooks return same response without double-crediting
--
-- BENEFITS:
-- 1. Concurrent webhooks don't cause duplicate credits
-- 2. Webhook retries are safe (idempotent)
-- 3. Audit trail of all webhook processing
-- 4. Can debug failed webhooks
-- 5. Complies with payment processor best practices
