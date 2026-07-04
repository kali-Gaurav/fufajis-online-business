-- =====================================================
-- FILE: supabase_schema.sql
-- FUFAJI LOOP 2 - MASTER SUPABASE SCHEMA
-- =====================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =====================================================
-- ENUMS
-- =====================================================

CREATE TYPE product_type_enum AS ENUM (
  'packaged',
  'loose',
  'fresh',
  'frozen'
);

CREATE TYPE unit_type_enum AS ENUM (
  'weight',
  'volume',
  'count'
);

CREATE TYPE token_type_enum AS ENUM (
  'brand',
  'product',
  'alias',
  'phonetic',
  'regional',
  'hindi'
);

-- SHOPS table removed as it already exists
-- =====================================================
-- CATEGORIES
-- =====================================================

CREATE TABLE catalog_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    hindi_name VARCHAR(100),
    slug VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- BRANDS
-- =====================================================

CREATE TABLE catalog_brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) UNIQUE NOT NULL,
    hindi_name VARCHAR(255),
    logo_url TEXT,
    country_of_origin VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- PRODUCT FAMILIES
-- =====================================================

CREATE TABLE catalog_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_code VARCHAR(100) UNIQUE NOT NULL,
    name TEXT NOT NULL,
    hindi_name TEXT,
    brand_id UUID REFERENCES catalog_brands(id),
    category_id UUID REFERENCES catalog_categories(id),

    product_type product_type_enum NOT NULL,
    unit_type unit_type_enum NOT NULL,

    description TEXT,

    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- PRODUCT VARIANTS / SKUs
-- =====================================================

CREATE TABLE catalog_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variant_code VARCHAR(120) UNIQUE NOT NULL,
    product_id UUID NOT NULL REFERENCES catalog_products(id) ON DELETE CASCADE,

    quantity NUMERIC(12,3) NOT NULL,
    unit VARCHAR(20) NOT NULL,

    mrp NUMERIC(12,2) NOT NULL,
    default_selling_price NUMERIC(12,2) NOT NULL,
    gst NUMERIC(5,2) DEFAULT 5.00,

    barcode VARCHAR(100),

    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- SHOP INVENTORY
-- Canonical inventory source
-- =====================================================

CREATE TABLE shop_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id),
    variant_id UUID NOT NULL REFERENCES catalog_variants(id),

    stock_total INT DEFAULT 0,
    stock_reserved INT DEFAULT 0,
    stock_available INT DEFAULT 0,
    stock_damaged INT DEFAULT 0,

    buy_price NUMERIC(12,2),
    selling_price NUMERIC(12,2),

    low_stock_threshold INT DEFAULT 10,
    reorder_threshold INT DEFAULT 20,
    reorder_quantity INT DEFAULT 50,

    last_restocked_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(shop_id, variant_id)
);

-- =====================================================
-- SEARCH INDEX
-- =====================================================

CREATE TABLE product_search_index (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    product_id UUID NOT NULL REFERENCES catalog_products(id) ON DELETE CASCADE,
    variant_id UUID REFERENCES catalog_variants(id) ON DELETE CASCADE,

    token TEXT NOT NULL,
    token_type token_type_enum NOT NULL,
    weight INT NOT NULL CHECK(weight >= 70 AND weight <= 100),
    language VARCHAR(10) DEFAULT 'en',

    search_vector tsvector,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- PRODUCT PRICING HISTORY
-- =====================================================

CREATE TABLE product_pricing_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    variant_id UUID NOT NULL REFERENCES catalog_variants(id),

    mrp_old NUMERIC(12,2),
    mrp_new NUMERIC(12,2),

    selling_price_old NUMERIC(12,2),
    selling_price_new NUMERIC(12,2),

    changed_by UUID,
    reason TEXT,

    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- PRODUCT ALIASES
-- =====================================================

CREATE TABLE product_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    product_id UUID NOT NULL REFERENCES catalog_products(id) ON DELETE CASCADE,

    alias_text TEXT NOT NULL,
    alias_hindi TEXT,

    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE catalog_products IS 'Master product families';
COMMENT ON TABLE catalog_variants IS 'Sellable SKU variants';
COMMENT ON TABLE shop_inventory IS 'Canonical inventory authority';
COMMENT ON TABLE product_search_index IS 'Voice + text search index';
COMMENT ON TABLE product_pricing_history IS 'Pricing audit trail';
COMMENT ON TABLE product_aliases IS 'Voice aliases and synonyms';
