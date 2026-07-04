/**
 * Migration: Webhook Events Table for Retry + DLQ
 * Stores all incoming webhooks with retry tracking
 */

CREATE TABLE IF NOT EXISTS webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Event identification
  event_type VARCHAR(50) NOT NULL,
  razorpay_event_id VARCHAR(255) UNIQUE,
  source VARCHAR(50) DEFAULT 'razorpay',  -- razorpay, whatsapp, etc

  -- Raw payload
  payload JSONB NOT NULL,

  -- Processing status
  status VARCHAR(20) DEFAULT 'pending',
  -- Values: pending → processing → succeeded → failed → dlq

  -- Retry tracking
  retry_count INT DEFAULT 0,
  max_retries INT DEFAULT 6,
  next_retry_at TIMESTAMP,
  last_error TEXT,

  -- Processing details
  processed_by VARCHAR(100),  -- worker ID
  processed_at TIMESTAMP,

  -- Timeline
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_webhook_status ON webhook_events(status);
CREATE INDEX IF NOT EXISTS idx_webhook_retry ON webhook_events(status, next_retry_at)
  WHERE status IN ('pending', 'failed');
CREATE INDEX IF NOT EXISTS idx_webhook_razorpay ON webhook_events(razorpay_event_id);
CREATE INDEX IF NOT EXISTS idx_webhook_created ON webhook_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_dlq ON webhook_events(status)
  WHERE status = 'dlq';

-- Add column to orders to track webhook processing status
ALTER TABLE orders ADD COLUMN IF NOT EXISTS webhook_processed BOOLEAN DEFAULT false;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS webhook_processed_at TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_orders_webhook ON orders(webhook_processed);
