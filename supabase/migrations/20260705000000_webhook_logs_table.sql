-- ============================================================================
-- WEBHOOK LOGS TABLE
-- Date: 2026-07-05
-- Purpose: Audit trail for all webhook events (Razorpay, etc.)
--          Tracks signature validation, idempotency, and processing status
-- ============================================================================

CREATE TABLE IF NOT EXISTS webhook_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id TEXT NOT NULL,                   -- Razorpay event ID
  event_type TEXT NOT NULL,                 -- 'payment.authorized', 'payment.captured', etc.
  payment_id TEXT NOT NULL,                 -- Razorpay payment ID (idempotency key)
  order_id UUID,                            -- Reference to orders table (nullable)
  amount BIGINT NOT NULL,                   -- Amount in paise
  signature TEXT NOT NULL,                  -- Partial signature for audit
  signature_valid BOOLEAN NOT NULL,         -- Was HMAC signature valid?
  processed BOOLEAN DEFAULT FALSE,          -- Was event processed successfully?
  processed_at TIMESTAMP,                   -- When was it processed?
  processed_result TEXT,                    -- Result message
  error TEXT,                               -- Error message if failed
  received_at TIMESTAMP NOT NULL DEFAULT NOW(),
  retry_count INT DEFAULT 0,

  -- Constraints
  UNIQUE(payment_id)                        -- One payment = one successful transaction
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_webhook_logs_payment_id ON webhook_logs(payment_id);
CREATE INDEX IF NOT EXISTS idx_webhook_logs_event_id ON webhook_logs(event_id);
CREATE INDEX IF NOT EXISTS idx_webhook_logs_order_id ON webhook_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_webhook_logs_processed ON webhook_logs(processed, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_logs_received_at ON webhook_logs(received_at DESC);

-- ============================================================================
-- WEBHOOK LOGS TABLE COMMENTS (for documentation)
-- ============================================================================

COMMENT ON TABLE webhook_logs IS
  'Audit trail for all webhook events. Used for:
   - Signature validation verification
   - Idempotency checking (payment_id is unique)
   - Retry tracking
   - Post-incident investigation';

COMMENT ON COLUMN webhook_logs.event_id IS
  'Razorpay event ID - uniquely identifies the webhook event';

COMMENT ON COLUMN webhook_logs.event_type IS
  'Type of webhook event: payment.authorized, payment.captured, payment.failed, etc.';

COMMENT ON COLUMN webhook_logs.payment_id IS
  'Razorpay payment ID - used as idempotency key. UNIQUE constraint prevents double-processing.';

COMMENT ON COLUMN webhook_logs.order_id IS
  'Reference to orders table. Nullable because order might not be found during processing.';

COMMENT ON COLUMN webhook_logs.signature_valid IS
  'Whether the HMAC-SHA256 signature was valid. Invalid signatures are rejected.';

COMMENT ON COLUMN webhook_logs.processed IS
  'Whether the webhook event was processed successfully (order status updated, outbox event written).';

-- ============================================================================
-- MIGRATION VALIDATION
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE 'Migration: webhook_logs table created successfully';
END $$;
