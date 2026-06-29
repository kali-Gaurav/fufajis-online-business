-- ============================================================
-- Phase 13: Intelligent Inventory & Approval Architecture
-- Fufaji Online Business — PostgreSQL Schema (AWS RDS / Supabase)
-- ============================================================
-- All stock mutations go through inventory_events (event sourcing).
-- Direct INSERTs/UPDATEs to inventory are PROHIBITED from app layer.
-- Changes flow: Employee Action → change_requests → Owner Approve → inventory updated.
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- for full-text search on product names

-- ============================================================
-- 1. PRODUCT MASTER TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS products (
  product_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sku                VARCHAR(100) UNIQUE,
  barcode            VARCHAR(100),
  product_name       VARCHAR(500) NOT NULL,
  slug               VARCHAR(500),
  category_id        UUID,
  sub_category       VARCHAR(200),
  brand              VARCHAR(200),
  description        TEXT,
  unit_type          VARCHAR(50) DEFAULT 'piece', -- piece, kg, litre, dozen, etc.
  weight_grams       NUMERIC(10,2),
  tax_code           VARCHAR(20) DEFAULT 'GST_5',
  hsn_code           VARCHAR(20),
  price              NUMERIC(12,2) NOT NULL DEFAULT 0,
  original_price     NUMERIC(12,2),
  cost_price         NUMERIC(12,2),
  discount_pct       NUMERIC(5,2) DEFAULT 0,
  is_available       BOOLEAN NOT NULL DEFAULT TRUE,
  is_featured        BOOLEAN NOT NULL DEFAULT FALSE,
  is_on_sale         BOOLEAN NOT NULL DEFAULT FALSE,
  min_order_qty      INTEGER DEFAULT 1,
  max_order_qty      INTEGER,
  image_url          TEXT,
  shop_id            VARCHAR(200) NOT NULL,
  branch_id          VARCHAR(200),
  active             BOOLEAN NOT NULL DEFAULT TRUE,
  created_by         VARCHAR(200),
  updated_by         VARCHAR(200),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_shop     ON products(shop_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_sku      ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_barcode  ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_products_name_trgm ON products USING GIN (product_name gin_trgm_ops);

-- ============================================================
-- 2. INVENTORY (STOCK LEDGER VIEW)
-- ============================================================
CREATE TABLE IF NOT EXISTS inventory (
  inventory_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id         UUID NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
  shop_id            VARCHAR(200) NOT NULL,
  branch_id          VARCHAR(200),
  warehouse_location VARCHAR(200),           -- shelf/bin code
  current_stock      INTEGER NOT NULL DEFAULT 0 CHECK (current_stock >= 0),
  reserved_stock     INTEGER NOT NULL DEFAULT 0 CHECK (reserved_stock >= 0),
  packaging_stock    INTEGER NOT NULL DEFAULT 0 CHECK (packaging_stock >= 0),
  damaged_stock      INTEGER NOT NULL DEFAULT 0 CHECK (damaged_stock >= 0),
  available_stock    INTEGER GENERATED ALWAYS AS
                       (current_stock - reserved_stock - packaging_stock) STORED,
  reorder_level      INTEGER NOT NULL DEFAULT 10,
  reorder_qty        INTEGER NOT NULL DEFAULT 50,
  last_restocked_at  TIMESTAMPTZ,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(product_id, shop_id, branch_id)
);

CREATE INDEX IF NOT EXISTS idx_inventory_product  ON inventory(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_shop     ON inventory(shop_id);
CREATE INDEX IF NOT EXISTS idx_inventory_low_stock ON inventory(shop_id) WHERE current_stock <= reorder_level;

-- ============================================================
-- 3. INVENTORY EVENT LEDGER (IMMUTABLE — APPEND ONLY)
-- No row in this table is ever updated or deleted.
-- ============================================================
CREATE TABLE IF NOT EXISTS inventory_events (
  event_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id         UUID NOT NULL,
  shop_id            VARCHAR(200) NOT NULL,
  event_type         VARCHAR(50) NOT NULL,
  -- Types: ORDER_CREATED, ORDER_CANCELLED, ITEM_PACKED, ITEM_DAMAGED,
  --        RETURN_RECEIVED, STOCK_ADDED, STOCK_REMOVED, STOCK_ADJUSTED,
  --        BULK_UPDATE, APPROVAL_APPLIED, REORDER_RECEIVED
  quantity_change    INTEGER NOT NULL,       -- +ve = added, -ve = removed
  old_value          INTEGER,
  new_value          INTEGER,
  reference_id       VARCHAR(200),           -- order_id / task_id / request_id
  reference_type     VARCHAR(50),            -- 'order' | 'bulk_op' | 'manual'
  actor_id           VARCHAR(200) NOT NULL,
  actor_role         VARCHAR(50),            -- 'owner' | 'employee' | 'system'
  source             VARCHAR(100),           -- 'packing' | 'pos' | 'import' | 'api'
  approved_by        VARCHAR(200),
  notes              TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inv_events_product  ON inventory_events(product_id);
CREATE INDEX IF NOT EXISTS idx_inv_events_shop     ON inventory_events(shop_id);
CREATE INDEX IF NOT EXISTS idx_inv_events_type     ON inventory_events(event_type);
CREATE INDEX IF NOT EXISTS idx_inv_events_actor    ON inventory_events(actor_id);
CREATE INDEX IF NOT EXISTS idx_inv_events_created  ON inventory_events(created_at DESC);

-- ============================================================
-- 4. PACKAGING / PARCEL PROCESSING TRACKING
-- Auto-updated when employee marks items packed in the packing terminal.
-- ============================================================
CREATE TABLE IF NOT EXISTS package_processing (
  process_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id           VARCHAR(200) NOT NULL,
  fulfillment_task_id VARCHAR(200),
  product_id         UUID NOT NULL,
  shop_id            VARCHAR(200) NOT NULL,
  quantity_requested INTEGER NOT NULL DEFAULT 0,
  quantity_packed    INTEGER NOT NULL DEFAULT 0,
  quantity_damaged   INTEGER NOT NULL DEFAULT 0,
  quantity_missing   INTEGER GENERATED ALWAYS AS
                       (quantity_requested - quantity_packed - quantity_damaged) STORED,
  packed_by          VARCHAR(200),           -- employee_id
  verified_by        VARCHAR(200),           -- quality check employee
  status             VARCHAR(30) NOT NULL DEFAULT 'pending',
  -- pending | in_progress | packed | quality_checked | dispatched | returned
  packed_at          TIMESTAMPTZ,
  verified_at        TIMESTAMPTZ,
  notes              TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_package_order    ON package_processing(order_id);
CREATE INDEX IF NOT EXISTS idx_package_product  ON package_processing(product_id);
CREATE INDEX IF NOT EXISTS idx_package_status   ON package_processing(status);
CREATE INDEX IF NOT EXISTS idx_package_employee ON package_processing(packed_by);

-- ============================================================
-- 5. OWNER APPROVAL WORKFLOW — CHANGE REQUESTS
-- ============================================================
CREATE TABLE IF NOT EXISTS change_requests (
  request_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  entity_type        VARCHAR(50) NOT NULL,   -- 'product' | 'inventory' | 'pricing'
  entity_id          VARCHAR(200),           -- product_id or NULL for bulk
  filter_json        JSONB,                  -- query filter used to select products
  filter_description TEXT,
  proposed_change    JSONB NOT NULL,         -- {"field": "price", "newValue": 99}
  affected_count     INTEGER DEFAULT 0,
  submitted_by       VARCHAR(200) NOT NULL,  -- employee/owner user_id
  submitted_by_name  VARCHAR(200),
  submitted_by_role  VARCHAR(50),
  status             VARCHAR(30) NOT NULL DEFAULT 'pending',
  -- pending | approved | rejected | partially_applied | expired
  reviewed_by        VARCHAR(200),
  reviewed_by_name   VARCHAR(200),
  reviewed_at        TIMESTAMPTZ,
  approval_notes     TEXT,
  expires_at         TIMESTAMPTZ DEFAULT NOW() + INTERVAL '7 days',
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_change_req_status   ON change_requests(status);
CREATE INDEX IF NOT EXISTS idx_change_req_submitted ON change_requests(submitted_by);
CREATE INDEX IF NOT EXISTS idx_change_req_entity   ON change_requests(entity_type, entity_id);

-- ============================================================
-- 6. SAVED QUERIES (Excel-like filter presets)
-- ============================================================
CREATE TABLE IF NOT EXISTS saved_queries (
  query_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id           VARCHAR(200) NOT NULL,
  shop_id            VARCHAR(200),
  query_name         VARCHAR(200) NOT NULL,
  description        TEXT,
  filter_json        JSONB NOT NULL,
  -- Example: {"logic":"and","conditions":[{"field":"category","op":"equals","value":"Grocery"},
  --           {"field":"stockQuantity","op":"lessThan","value":50}]}
  is_pinned          BOOLEAN DEFAULT FALSE,
  last_run_at        TIMESTAMPTZ,
  run_count          INTEGER DEFAULT 0,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_saved_queries_owner ON saved_queries(owner_id);
CREATE INDEX IF NOT EXISTS idx_saved_queries_shop  ON saved_queries(shop_id);

-- ============================================================
-- 7. BULK OPERATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS bulk_operations (
  operation_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  query_id           UUID REFERENCES saved_queries(query_id),
  shop_id            VARCHAR(200) NOT NULL,
  operation_type     VARCHAR(50) NOT NULL,
  -- 'price_change' | 'stock_adjust' | 'availability_toggle' | 'reorder_level_set'
  filter_json        JSONB,                  -- products selected
  operation_data     JSONB NOT NULL,         -- {"field":"price","delta":5,"isPercent":true}
  affected_product_ids JSONB,               -- array of product_ids
  affected_count     INTEGER DEFAULT 0,
  created_by         VARCHAR(200) NOT NULL,
  created_by_name    VARCHAR(200),
  change_request_id  UUID REFERENCES change_requests(request_id),
  approved_by        VARCHAR(200),
  status             VARCHAR(30) NOT NULL DEFAULT 'pending',
  -- pending | approved | executing | executed | failed | rejected
  executed_at        TIMESTAMPTZ,
  failed_reason      TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bulk_ops_shop   ON bulk_operations(shop_id);
CREATE INDEX IF NOT EXISTS idx_bulk_ops_status ON bulk_operations(status);

-- ============================================================
-- 8. INVENTORY VERSIONS (Point-in-time snapshots for rollback)
-- ============================================================
CREATE TABLE IF NOT EXISTS inventory_versions (
  version_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id         UUID NOT NULL,
  shop_id            VARCHAR(200) NOT NULL,
  version_number     INTEGER NOT NULL,
  snapshot_json      JSONB NOT NULL,         -- full product + inventory row state
  change_type        VARCHAR(50),            -- what triggered this snapshot
  triggered_by       VARCHAR(200),
  change_request_id  UUID,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(product_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_inv_versions_product ON inventory_versions(product_id, created_at DESC);

-- ============================================================
-- 9. AUTOMATION RULES
-- ============================================================
CREATE TABLE IF NOT EXISTS automation_rules (
  rule_id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shop_id            VARCHAR(200) NOT NULL,
  rule_name          VARCHAR(200) NOT NULL,
  description        TEXT,
  condition_json     JSONB NOT NULL,
  -- {"field":"current_stock","op":"lessThan","ref":"reorder_level"}
  action_json        JSONB NOT NULL,
  -- {"type":"create_purchase_order","qty_formula":"reorder_qty","notify_owner":true}
  enabled            BOOLEAN NOT NULL DEFAULT TRUE,
  last_triggered_at  TIMESTAMPTZ,
  trigger_count      INTEGER DEFAULT 0,
  created_by         VARCHAR(200),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_automation_shop    ON automation_rules(shop_id, enabled);

-- ============================================================
-- 10. TRIGGER: auto-update inventory.updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_inventory_updated_at'
  ) THEN
    CREATE TRIGGER trg_inventory_updated_at
      BEFORE UPDATE ON inventory
      FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_products_updated_at'
  ) THEN
    CREATE TRIGGER trg_products_updated_at
      BEFORE UPDATE ON products
      FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_package_updated_at'
  ) THEN
    CREATE TRIGGER trg_package_updated_at
      BEFORE UPDATE ON package_processing
      FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  END IF;
END $$;

-- ============================================================
-- 11. TRIGGER: Auto-record inventory_event when inventory.current_stock changes
-- ============================================================
CREATE OR REPLACE FUNCTION record_stock_change_event()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.current_stock <> OLD.current_stock THEN
    INSERT INTO inventory_events (
      product_id, shop_id, event_type, quantity_change,
      old_value, new_value, actor_id, actor_role, source
    ) VALUES (
      NEW.product_id, NEW.shop_id,
      'STOCK_ADJUSTED',
      NEW.current_stock - OLD.current_stock,
      OLD.current_stock, NEW.current_stock,
      'system', 'system', 'trigger'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_inventory_stock_event'
  ) THEN
    CREATE TRIGGER trg_inventory_stock_event
      AFTER UPDATE OF current_stock ON inventory
      FOR EACH ROW EXECUTE FUNCTION record_stock_change_event();
  END IF;
END $$;

-- ============================================================
-- 12. TRIGGER: Auto-snapshot product on approval
-- ============================================================
CREATE OR REPLACE FUNCTION snapshot_product_on_approval()
RETURNS TRIGGER AS $$
DECLARE
  v_num INTEGER;
  v_snapshot JSONB;
BEGIN
  IF NEW.status = 'approved' AND OLD.status = 'pending' THEN
    SELECT COALESCE(MAX(version_number), 0) + 1
      INTO v_num
      FROM inventory_versions
     WHERE product_id = (NEW.entity_id)::UUID;

    SELECT to_jsonb(p.*) INTO v_snapshot FROM products p WHERE p.product_id = (NEW.entity_id)::UUID;

    INSERT INTO inventory_versions (
      product_id, shop_id, version_number, snapshot_json, change_type,
      triggered_by, change_request_id
    ) VALUES (
      (NEW.entity_id)::UUID,
      '',
      v_num,
      COALESCE(v_snapshot, '{}'::jsonb),
      'approval',
      NEW.reviewed_by,
      NEW.request_id
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_snapshot_on_approval'
  ) THEN
    CREATE TRIGGER trg_snapshot_on_approval
      AFTER UPDATE ON change_requests
      FOR EACH ROW EXECUTE FUNCTION snapshot_product_on_approval();
  END IF;
END $$;

-- ============================================================
-- VIEWS
-- ============================================================

-- Low stock view (for alerts & AI suggestions)
CREATE OR REPLACE VIEW v_low_stock AS
SELECT
  p.product_id, p.product_name, p.sku, p.category_id,
  i.shop_id, i.current_stock, i.reorder_level, i.reorder_qty,
  i.available_stock,
  (i.reorder_level - i.current_stock) AS deficit
FROM inventory i
JOIN products p ON p.product_id = i.product_id
WHERE i.current_stock <= i.reorder_level
  AND p.active = TRUE;

-- Packaging status summary
CREATE OR REPLACE VIEW v_packaging_status AS
SELECT
  pp.order_id, pp.shop_id, pp.status,
  COUNT(*) AS total_items,
  SUM(pp.quantity_requested) AS qty_requested,
  SUM(pp.quantity_packed) AS qty_packed,
  SUM(pp.quantity_damaged) AS qty_damaged
FROM package_processing pp
GROUP BY pp.order_id, pp.shop_id, pp.status;

-- Pending approval queue
CREATE OR REPLACE VIEW v_pending_approvals AS
SELECT
  cr.request_id, cr.entity_type, cr.filter_description,
  cr.proposed_change, cr.affected_count, cr.submitted_by_name,
  cr.submitted_by_role, cr.created_at,
  EXTRACT(EPOCH FROM (cr.expires_at - NOW())) / 3600 AS hours_until_expiry
FROM change_requests cr
WHERE cr.status = 'pending'
ORDER BY cr.created_at DESC;
