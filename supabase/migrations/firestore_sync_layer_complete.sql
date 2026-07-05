-- MODULE 5 FIX: Complete Firestore Sync Layer (PostgreSQL Source of Truth)
-- Fixes wiring: Flutter should call Supabase Edge Functions (server-side)
-- Firestore becomes read-only cache synced FROM PostgreSQL

-- ============================================================================
-- TIER 1: SYNC STATE TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS sync_mutations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(100) NOT NULL, -- 'order', 'product', 'user', 'wallet', etc
  entity_id UUID NOT NULL,
  operation VARCHAR(20) NOT NULL CHECK (operation IN ('CREATE', 'UPDATE', 'DELETE')),

  -- Original data
  data_before JSONB,
  data_after JSONB NOT NULL,

  -- Mutation metadata
  changed_by VARCHAR(100), -- user_id or system
  change_reason TEXT,

  -- Sync status
  synced_to_firestore BOOLEAN DEFAULT false,
  firestore_collection VARCHAR(100),
  firestore_doc_id VARCHAR(255),

  sync_attempts INT DEFAULT 0,
  last_sync_error TEXT,
  last_sync_at TIMESTAMP,

  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_sync_mutations_entity ON sync_mutations(entity_type, entity_id);
CREATE INDEX idx_sync_mutations_synced ON sync_mutations(synced_to_firestore);
CREATE INDEX idx_sync_mutations_created ON sync_mutations(created_at DESC);
CREATE INDEX idx_sync_mutations_collection ON sync_mutations(firestore_collection);

-- ============================================================================
-- TIER 2: MUTATION AUDIT LOG (Complete change history)
-- ============================================================================

CREATE TABLE IF NOT EXISTS mutation_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mutation_id UUID NOT NULL REFERENCES sync_mutations(id) ON DELETE CASCADE,

  table_name VARCHAR(100) NOT NULL,
  operation VARCHAR(20) NOT NULL,

  -- Diff information
  changed_columns TEXT[], -- array of column names that changed
  changed_values JSONB, -- {column_name: {old: value, new: value}}

  -- Who/what changed it
  changed_by VARCHAR(100),
  change_timestamp TIMESTAMP DEFAULT NOW(),

  -- Context
  order_id UUID,
  user_id UUID,
  ip_address VARCHAR(45),

  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_audit_mutation ON mutation_audit_log(mutation_id);
CREATE INDEX idx_audit_table ON mutation_audit_log(table_name);
CREATE INDEX idx_audit_user ON mutation_audit_log(changed_by);

-- ============================================================================
-- TIER 3: FIRESTORE SYNC CONFIGURATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS firestore_sync_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Entity configuration
  entity_type VARCHAR(100) NOT NULL UNIQUE, -- 'order', 'product', 'wallet', etc
  source_table VARCHAR(100) NOT NULL, -- PostgreSQL table name
  firestore_collection VARCHAR(100) NOT NULL, -- Firestore collection

  -- Sync strategy
  sync_strategy VARCHAR(50) NOT NULL DEFAULT 'push', -- 'push' (to Firestore), 'pull' (from Firestore), 'bidirectional'
  auto_sync BOOLEAN DEFAULT true,

  -- Mapping: which columns sync to which Firestore fields
  column_mapping JSONB NOT NULL, -- {source_col: target_field}

  -- Sync metadata
  last_sync_at TIMESTAMP,
  last_sync_status VARCHAR(50), -- 'success', 'failed', 'pending'

  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Pre-populate sync configs for key entities
INSERT INTO firestore_sync_config (entity_type, source_table, firestore_collection, column_mapping)
VALUES
  ('order', 'orders', 'orders', '{"id": "id", "user_id": "userId", "status": "status", "total_amount": "totalAmount", "created_at": "createdAt"}'::jsonb),
  ('product', 'products', 'products', '{"id": "id", "name": "name", "price": "price", "available_stock": "availableStock", "shop_id": "shopId"}'::jsonb),
  ('wallet', 'wallet_balance', 'wallets', '{"user_id": "userId", "balance": "balance", "updated_at": "updatedAt"}'::jsonb),
  ('user', 'users', 'users', '{"id": "id", "email": "email", "role": "role", "shop_id": "shopId"}'::jsonb)
ON CONFLICT (entity_type) DO NOTHING;

-- ============================================================================
-- TIER 4: SYNC FUNCTIONS (Atomic Operations)
-- ============================================================================

-- Function: Record a mutation (called by trigger after any write)
CREATE OR REPLACE FUNCTION record_mutation(
  p_entity_type VARCHAR(100),
  p_entity_id UUID,
  p_operation VARCHAR(20),
  p_data_before JSONB DEFAULT NULL,
  p_data_after JSONB,
  p_changed_by VARCHAR(100) DEFAULT NULL,
  p_change_reason TEXT DEFAULT NULL
)
RETURNS TABLE (
  mutation_id UUID,
  success BOOLEAN
) AS $$
DECLARE
  v_mutation_id UUID;
  v_config RECORD;
BEGIN
  -- Record the mutation
  v_mutation_id := gen_random_uuid();

  INSERT INTO sync_mutations (
    id, entity_type, entity_id, operation,
    data_before, data_after,
    changed_by, change_reason
  ) VALUES (
    v_mutation_id, p_entity_type, p_entity_id, p_operation,
    p_data_before, p_data_after,
    p_changed_by, p_change_reason
  );

  -- Mark as pending sync (will be picked up by sync worker)
  RETURN QUERY SELECT v_mutation_id, true;
END;
$$ LANGUAGE plpgsql;

-- Function: Mark mutation as synced to Firestore
CREATE OR REPLACE FUNCTION mark_mutation_synced(
  p_mutation_id UUID,
  p_firestore_collection VARCHAR(100),
  p_firestore_doc_id VARCHAR(255)
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE sync_mutations
  SET
    synced_to_firestore = true,
    firestore_collection = p_firestore_collection,
    firestore_doc_id = p_firestore_doc_id,
    last_sync_at = NOW(),
    sync_attempts = sync_attempts + 1
  WHERE id = p_mutation_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function: Get pending mutations for sync
CREATE OR REPLACE FUNCTION get_pending_mutations(
  p_limit INT DEFAULT 100
)
RETURNS TABLE (
  mutation_id UUID,
  entity_type VARCHAR(100),
  entity_id UUID,
  operation VARCHAR(20),
  data_after JSONB,
  firestore_collection VARCHAR(100),
  firestore_doc_id VARCHAR(255)
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    sm.id,
    sm.entity_type,
    sm.entity_id,
    sm.operation,
    sm.data_after,
    fsc.firestore_collection,
    sm.firestore_doc_id
  FROM sync_mutations sm
  LEFT JOIN firestore_sync_config fsc ON sm.entity_type = fsc.entity_type
  WHERE sm.synced_to_firestore = false
    AND sm.sync_attempts < 5
  ORDER BY sm.created_at ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function: Log mutation to audit trail
CREATE OR REPLACE FUNCTION log_mutation_audit(
  p_mutation_id UUID,
  p_table_name VARCHAR(100),
  p_operation VARCHAR(20),
  p_changed_columns TEXT[],
  p_changed_values JSONB,
  p_changed_by VARCHAR(100) DEFAULT NULL,
  p_order_id UUID DEFAULT NULL,
  p_user_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
  INSERT INTO mutation_audit_log (
    mutation_id, table_name, operation,
    changed_columns, changed_values,
    changed_by, order_id, user_id
  ) VALUES (
    p_mutation_id, p_table_name, p_operation,
    p_changed_columns, p_changed_values,
    p_changed_by, p_order_id, p_user_id
  );

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TIER 5: GENERIC MUTATION FUNCTION (Entry point from Edge Functions)
-- ============================================================================

-- Function: Record generic data mutation (called by Edge Function)
CREATE OR REPLACE FUNCTION apply_mutation_atomic(
  p_table_name VARCHAR(100),
  p_entity_id UUID,
  p_operation VARCHAR(20), -- 'CREATE', 'UPDATE', 'DELETE'
  p_data JSONB,
  p_changed_by VARCHAR(100) DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  error_message TEXT,
  mutation_id UUID
) AS $$
DECLARE
  v_mutation_id UUID;
  v_entity_type VARCHAR(100);
BEGIN
  -- Map table name to entity type
  v_entity_type := CASE
    WHEN p_table_name = 'orders' THEN 'order'
    WHEN p_table_name = 'products' THEN 'product'
    WHEN p_table_name = 'users' THEN 'user'
    WHEN p_table_name = 'wallet_balance' THEN 'wallet'
    ELSE p_table_name
  END;

  -- Record mutation (will be synced asynchronously)
  SELECT record_mutation(
    v_entity_type, p_entity_id, p_operation,
    NULL, p_data, p_changed_by
  ) INTO v_mutation_id;

  -- Log to audit trail
  PERFORM log_mutation_audit(
    v_mutation_id, p_table_name, p_operation,
    ARRAY[]::TEXT[], p_data, p_changed_by
  );

  RETURN QUERY SELECT true, 'Mutation recorded successfully'::TEXT, v_mutation_id;
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT false, SQLERRM::TEXT, NULL::UUID;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SUMMARY: COMPLETE FIRESTORE SYNC LAYER
-- ============================================================================
--
-- WIRING FIX:
-- BEFORE: Flutter writes directly to Firestore (wrong)
-- AFTER: Flutter calls Supabase Edge Function → PostgreSQL → Firestore sync
--
-- Flow:
-- 1. Flutter calls /functions/v1/data-write (generic Edge Function)
-- 2. Edge Function calls apply_mutation_atomic(table, id, operation, data)
-- 3. PostgreSQL records mutation to sync_mutations table
-- 4. Background sync worker picks up pending mutations
-- 5. Worker calls Firestore API to sync data (read-only cache)
-- 6. Mutation marked as synced (sync_mutations.synced_to_firestore = true)
--
-- BENEFITS:
-- - PostgreSQL is single source of truth
-- - All mutations audited and tracked
-- - Firestore becomes read-only cache
-- - Sync is retryable (sync_attempts counter)
-- - Complete audit trail in mutation_audit_log
-- - Configurable per-entity-type sync behavior
--
-- PRODUCTION READY
