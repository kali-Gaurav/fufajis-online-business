-- =====================================================
-- ENHANCED PRODUCTS SCHEMA
-- For Voice Commerce + Inventory Intelligence
-- =====================================================

-- Extend catalog_products with new fields
ALTER TABLE catalog_products
  ADD COLUMN IF NOT EXISTS search_tokens JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS phonetic_tokens JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS voice_enabled BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS voice_patterns JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS aliases JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS hindi_aliases JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS order_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS demand_score NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT NULL;

-- Create full-text search index (Hindi + English)
CREATE INDEX IF NOT EXISTS idx_products_fts_en
  ON catalog_products USING GIN (to_tsvector('english', name));

CREATE INDEX IF NOT EXISTS idx_products_fts_hi
  ON catalog_products USING GIN (to_tsvector('simple', hindi_name));

CREATE INDEX IF NOT EXISTS idx_products_voice_enabled
  ON catalog_products(voice_enabled)
  WHERE voice_enabled = TRUE AND is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_products_category_active
  ON catalog_products(category_id, is_active);

-- Trigger: Update demand score based on order_count
CREATE OR REPLACE FUNCTION update_product_demand_score()
RETURNS TRIGGER AS $$
BEGIN
  NEW.demand_score = LEAST(100, (NEW.order_count / 10.0));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_demand_score ON catalog_products;
CREATE TRIGGER trg_update_demand_score
  BEFORE INSERT OR UPDATE ON catalog_products
  FOR EACH ROW
  EXECUTE FUNCTION update_product_demand_score();

-- Trigger: Update updated_at timestamp
DROP TRIGGER IF EXISTS trg_update_products_timestamp ON catalog_products;
CREATE TRIGGER trg_update_products_timestamp
  BEFORE UPDATE ON catalog_products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- VOICE SEARCH TOKENS TABLE
-- Pre-computed search tokens for voice matching
-- =====================================================

CREATE TABLE IF NOT EXISTS voice_search_index (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES catalog_products(id) ON DELETE CASCADE,
  variant_id UUID NOT NULL REFERENCES catalog_variants(id) ON DELETE CASCADE,

  -- Search variants
  english_name VARCHAR(255),
  hindi_name VARCHAR(255),
  brand_name VARCHAR(255),

  -- Tokens for matching
  phonetic_tokens JSONB DEFAULT '[]',
  fuzzy_tokens JSONB DEFAULT '[]',
  voice_patterns JSONB DEFAULT '[]',

  -- Scoring metadata
  priority INT DEFAULT 5,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE(product_id, variant_id)
);

CREATE INDEX idx_voice_search_product_id
  ON voice_search_index(product_id);

-- =====================================================
-- VOICE ORDER MATCHING LOG (for AI learning)
-- =====================================================

CREATE TABLE IF NOT EXISTS voice_order_matches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id VARCHAR(255),
  audio_input TEXT,
  parsed_products JSONB,
  matched_products JSONB,
  confidence_score NUMERIC(3,2),
  was_correct BOOLEAN,
  feedback TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_voice_matches_user
  ON voice_order_matches(user_id, created_at DESC);

-- =====================================================
-- PRODUCT SEARCH MATERIALIZED VIEW
-- =====================================================

DROP MATERIALIZED VIEW IF EXISTS v_product_search CASCADE;

CREATE MATERIALIZED VIEW v_product_search AS
SELECT
  p.id,
  p.product_code,
  p.name,
  p.hindi_name,
  p.name AS search_text_en,
  p.hindi_name AS search_text_hi,
  c.name AS category,
  b.name AS brand,
  v.id AS variant_id,
  v.quantity,
  v.unit,
  v.mrp,
  v.default_selling_price,
  p.voice_enabled,
  p.aliases,
  p.hindi_aliases,
  p.phonetic_tokens,
  p.demand_score,
  p.rating,
  si.stock_total,
  si.stock_available,
  p.is_active
FROM catalog_products p
LEFT JOIN catalog_categories c ON p.category_id = c.id
LEFT JOIN catalog_brands b ON p.brand_id = b.id
LEFT JOIN catalog_variants v ON p.id = v.product_id
LEFT JOIN shop_inventory si ON v.id = si.variant_id
WHERE p.is_active = TRUE AND p.is_deleted = FALSE
  AND v.is_active = TRUE;

CREATE INDEX idx_v_product_search_category
  ON v_product_search(category);

CREATE INDEX idx_v_product_search_voice
  ON v_product_search(voice_enabled);

-- =====================================================
-- SYNC TRIGGER: Products to Firestore
-- =====================================================

CREATE OR REPLACE FUNCTION sync_product_to_firestore()
RETURNS TRIGGER AS $$
DECLARE
  variant_count INT;
BEGIN
  -- Only sync active products with variants
  SELECT COUNT(*) INTO variant_count
  FROM catalog_variants
  WHERE product_id = COALESCE(NEW.id, OLD.id) AND is_active = TRUE;

  IF variant_count > 0 THEN
    -- Log to sync_events for worker to handle
    INSERT INTO sync_events (
      event_type, entity_type, entity_id, payload, status,
      source_system, priority, created_at
    ) VALUES (
      'PRODUCT_UPDATED', 'product', COALESCE(NEW.id, OLD.id),
      jsonb_build_object(
        'product_id', COALESCE(NEW.id, OLD.id),
        'name', COALESCE(NEW.name, OLD.name),
        'hindi_name', COALESCE(NEW.hindi_name, OLD.hindi_name),
        'is_active', COALESCE(NEW.is_active, OLD.is_active)
      ),
      'pending', 'supabase', 5, CURRENT_TIMESTAMP
    );
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_product_to_firestore ON catalog_products;
CREATE TRIGGER trg_sync_product_to_firestore
  AFTER INSERT OR UPDATE ON catalog_products
  FOR EACH ROW
  EXECUTE FUNCTION sync_product_to_firestore();

-- =====================================================
-- PERMISSIONS
-- =====================================================

-- Public can read products (for catalog browsing)
ALTER TABLE catalog_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "public_read_active_products"
  ON catalog_products FOR SELECT
  USING (is_active = TRUE AND is_deleted = FALSE);

-- Only admins can write products
CREATE POLICY "admin_all_products"
  ON catalog_products FOR ALL
  USING (auth.jwt() ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() ->> 'role' = 'admin');

-- Public can read variants
ALTER TABLE catalog_variants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "public_read_active_variants"
  ON catalog_variants FOR SELECT
  USING (is_active = TRUE);

-- Admins write variants
CREATE POLICY "admin_all_variants"
  ON catalog_variants FOR ALL
  USING (auth.jwt() ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() ->> 'role' = 'admin');

COMMIT;
