-- Idempotency Keys Table
-- Prevents duplicate operations when requests are retried
-- TTL-based cleanup per operation type

CREATE TABLE IF NOT EXISTS idempotency_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- The idempotency key sent by client
  idempotency_key VARCHAR(255) NOT NULL UNIQUE,
  -- What operation this key belongs to
  operation_type VARCHAR(50) NOT NULL,  -- 'inventory_adjust', 'order_pack', 'refund_initiate'
  -- Which entity was affected
  entity_type VARCHAR(50),               -- 'inventory', 'order', 'refund'
  entity_id VARCHAR(100),
  -- The response returned to client (for idempotent replay)
  response_status INT,
  response_body JSONB,
  -- Metadata
  user_id UUID,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  -- TTL cleanup based on operation type
  expires_at TIMESTAMP
);

-- Indexes for fast lookup
CREATE INDEX idx_idempotency_key_lookup ON idempotency_keys(idempotency_key);
CREATE INDEX idx_idempotency_key_cleanup ON idempotency_keys(expires_at) WHERE expires_at <= NOW();
CREATE INDEX idx_idempotency_entity ON idempotency_keys(entity_type, entity_id);

-- TTL Cleanup Job
-- Runs every hour to delete expired keys
-- Keeps storage reasonable and follows compliance rules
-- - Payments: 90 days (PCI-DSS requirement)
-- - Refunds: 180 days (regulatory requirement)
-- - Orders: 30 days
-- - Inventory: 7 days

CREATE OR REPLACE FUNCTION cleanup_expired_idempotency_keys()
RETURNS void AS $$
BEGIN
  DELETE FROM idempotency_keys
  WHERE expires_at < CURRENT_TIMESTAMP
  AND expires_at IS NOT NULL;

  RAISE NOTICE 'Cleaned up expired idempotency keys at %', CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Schedule cleanup (PostgreSQL pg_cron extension)
-- SELECT cron.schedule('cleanup_idempotency_keys', '0 * * * *', 'SELECT cleanup_expired_idempotency_keys()');

-- Insert Idempotency Record (with TTL)
-- Usage in app:
-- INSERT INTO idempotency_keys (
--   idempotency_key,
--   operation_type,
--   entity_type,
--   entity_id,
--   response_status,
--   response_body,
--   user_id,
--   expires_at
-- ) VALUES (
--   $1,
--   'inventory_adjust',
--   'inventory',
--   $2,
--   200,
--   $3,
--   $4,
--   NOW() + INTERVAL '7 days'  -- Inventory expires after 7 days
-- )
-- ON CONFLICT (idempotency_key) DO NOTHING;
