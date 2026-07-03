-- =====================================================
-- FILE: supabase_indexes.sql
-- FUFAJI LOOP 2 - INDEXES & CONSTRAINT OPTIMIZATION
-- =====================================================

-- =====================================================
-- SHOPS
-- =====================================================

CREATE UNIQUE INDEX idx_shops_shop_code
ON shops(shop_code);

CREATE INDEX idx_shops_is_active
ON shops(is_active);

COMMENT ON INDEX idx_shops_shop_code IS 'Fast shop lookup by shop_code';
COMMENT ON INDEX idx_shops_is_active IS 'Filter active shops';

-- =====================================================
-- CATEGORIES
-- =====================================================

CREATE UNIQUE INDEX idx_categories_slug
ON catalog_categories(slug);

CREATE INDEX idx_categories_active
ON catalog_categories(is_active);

CREATE INDEX idx_categories_display_order
ON catalog_categories(display_order);

COMMENT ON INDEX idx_categories_slug IS 'Unique category slug';
COMMENT ON INDEX idx_categories_active IS 'Filter active categories';
COMMENT ON INDEX idx_categories_display_order IS 'Category sorting';

-- =====================================================
-- BRANDS
-- =====================================================

CREATE UNIQUE INDEX idx_brands_name
ON catalog_brands(name);

CREATE INDEX idx_brands_active
ON catalog_brands(is_active);

COMMENT ON INDEX idx_brands_name IS 'Unique brand name';
COMMENT ON INDEX idx_brands_active IS 'Filter active brands';

-- =====================================================
-- CATALOG PRODUCTS
-- =====================================================

CREATE UNIQUE INDEX idx_products_product_code
ON catalog_products(product_code);

CREATE INDEX idx_products_brand_id
ON catalog_products(brand_id);

CREATE INDEX idx_products_category_id
ON catalog_products(category_id);

CREATE INDEX idx_products_active_deleted
ON catalog_products(is_active, is_deleted);

CREATE INDEX idx_products_updated_at
ON catalog_products(updated_at DESC);

CREATE INDEX idx_products_name_trgm
ON catalog_products USING gin(name gin_trgm_ops);

CREATE INDEX idx_products_hindi_name_trgm
ON catalog_products USING gin(hindi_name gin_trgm_ops);

COMMENT ON INDEX idx_products_product_code IS 'Unique product code lookup';
COMMENT ON INDEX idx_products_brand_id IS 'Filter products by brand';
COMMENT ON INDEX idx_products_category_id IS 'Filter products by category';
COMMENT ON INDEX idx_products_active_deleted IS 'Active product filtering';
COMMENT ON INDEX idx_products_updated_at IS 'Sync updates ordering';
COMMENT ON INDEX idx_products_name_trgm IS 'Typo-tolerant English product search';
COMMENT ON INDEX idx_products_hindi_name_trgm IS 'Typo-tolerant Hindi product search';

-- =====================================================
-- CATALOG VARIANTS
-- =====================================================

CREATE UNIQUE INDEX idx_variants_variant_code
ON catalog_variants(variant_code);

CREATE INDEX idx_variants_product_id
ON catalog_variants(product_id);

CREATE INDEX idx_variants_active
ON catalog_variants(is_active);

CREATE INDEX idx_variants_updated_at
ON catalog_variants(updated_at DESC);

CREATE INDEX idx_variants_barcode
ON catalog_variants(barcode);

COMMENT ON INDEX idx_variants_variant_code IS 'Unique SKU code lookup';
COMMENT ON INDEX idx_variants_product_id IS 'Variants under product family';
COMMENT ON INDEX idx_variants_active IS 'Filter active variants';
COMMENT ON INDEX idx_variants_updated_at IS 'Sync updates ordering';
COMMENT ON INDEX idx_variants_barcode IS 'Barcode scanning lookup';

-- =====================================================
-- SHOP INVENTORY
-- =====================================================

CREATE UNIQUE INDEX idx_inventory_shop_variant
ON shop_inventory(shop_id, variant_id);

CREATE INDEX idx_inventory_shop
ON shop_inventory(shop_id);

CREATE INDEX idx_inventory_variant
ON shop_inventory(variant_id);

CREATE INDEX idx_inventory_low_stock
ON shop_inventory(stock_available, low_stock_threshold);

CREATE INDEX idx_inventory_updated_at
ON shop_inventory(updated_at DESC);

COMMENT ON INDEX idx_inventory_shop_variant IS 'One variant per shop';
COMMENT ON INDEX idx_inventory_shop IS 'Filter inventory by shop';
COMMENT ON INDEX idx_inventory_variant IS 'Variant inventory lookup';
COMMENT ON INDEX idx_inventory_low_stock IS 'Low stock alerts';
COMMENT ON INDEX idx_inventory_updated_at IS 'Realtime inventory sync';

-- =====================================================
-- PRODUCT SEARCH INDEX
-- =====================================================

CREATE INDEX idx_search_product
ON product_search_index(product_id);

CREATE INDEX idx_search_variant
ON product_search_index(variant_id);

CREATE INDEX idx_search_token_btree
ON product_search_index(token);

CREATE INDEX idx_search_token_trgm
ON product_search_index USING gin(token gin_trgm_ops);

CREATE INDEX idx_search_weight
ON product_search_index(weight DESC);

CREATE INDEX idx_search_language
ON product_search_index(language);

CREATE INDEX idx_search_vector
ON product_search_index USING GIN(search_vector);

COMMENT ON INDEX idx_search_product IS 'Search by product family';
COMMENT ON INDEX idx_search_variant IS 'Search by variant';
COMMENT ON INDEX idx_search_token_btree IS 'Exact token search';
COMMENT ON INDEX idx_search_token_trgm IS 'Typo-tolerant token search';
COMMENT ON INDEX idx_search_weight IS 'Weighted ranking';
COMMENT ON INDEX idx_search_language IS 'Language-specific filtering';
COMMENT ON INDEX idx_search_vector IS 'Full-text search vector';

-- =====================================================
-- PRODUCT PRICING HISTORY
-- =====================================================

CREATE INDEX idx_pricing_history_variant
ON product_pricing_history(variant_id);

CREATE INDEX idx_pricing_history_changed_at
ON product_pricing_history(changed_at DESC);

CREATE INDEX idx_pricing_history_changed_by
ON product_pricing_history(changed_by);

COMMENT ON INDEX idx_pricing_history_variant IS 'Price history by variant';
COMMENT ON INDEX idx_pricing_history_changed_at IS 'Recent price changes';
COMMENT ON INDEX idx_pricing_history_changed_by IS 'Audit by admin user';

-- =====================================================
-- PRODUCT ALIASES
-- =====================================================

CREATE INDEX idx_aliases_product
ON product_aliases(product_id);

CREATE INDEX idx_aliases_active
ON product_aliases(is_active);

CREATE INDEX idx_aliases_text_trgm
ON product_aliases USING gin(alias_text gin_trgm_ops);

CREATE INDEX idx_aliases_hindi_trgm
ON product_aliases USING gin(alias_hindi gin_trgm_ops);

COMMENT ON INDEX idx_aliases_product IS 'Aliases by product';
COMMENT ON INDEX idx_aliases_active IS 'Filter active aliases';
COMMENT ON INDEX idx_aliases_text_trgm IS 'Typo-tolerant alias search';
COMMENT ON INDEX idx_aliases_hindi_trgm IS 'Typo-tolerant Hindi alias search';

-- =====================================================
-- PARTIAL INDEXES FOR SOFT DELETE OPTIMIZATION
-- =====================================================

CREATE INDEX idx_products_active_only
ON catalog_products(id)
WHERE is_active = TRUE AND is_deleted = FALSE;

CREATE INDEX idx_variants_active_only
ON catalog_variants(id)
WHERE is_active = TRUE;

COMMENT ON INDEX idx_products_active_only IS 'Fast lookup of active products only';
COMMENT ON INDEX idx_variants_active_only IS 'Fast lookup of active variants only';
