-- =====================================================
-- FILE: supabase_rls.sql
-- FUFAJI LOOP 2 - ROW LEVEL SECURITY POLICIES
-- =====================================================

-- =====================================================
-- ENABLE RLS ON ALL TABLES
-- =====================================================

ALTER TABLE shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_search_index ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_pricing_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_aliases ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- ROLE ASSUMPTIONS
-- =====================================================
-- anon            = public customer app
-- authenticated   = logged-in customer
-- service_role    = backend/admin/system
--
-- Custom JWT claim expected:
-- auth.jwt() ->> 'role'
-- Values:
-- owner, admin, manager, employee, customer

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN COALESCE(auth.jwt() ->> 'role', '') IN ('owner', 'admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_staff()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN COALESCE(auth.jwt() ->> 'role', '') IN ('owner', 'admin', 'manager', 'employee');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- SHOPS
-- Public readable
-- Admin writable
-- =====================================================

CREATE POLICY "shops_public_read"
ON shops
FOR SELECT
USING (TRUE);

CREATE POLICY "shops_admin_modify"
ON shops
FOR ALL
USING (is_admin())
WITH CHECK (is_admin());

-- =====================================================
-- CATEGORIES
-- Public readable
-- Admin writable
-- =====================================================

CREATE POLICY "categories_public_read"
ON catalog_categories
FOR SELECT
USING (is_active = TRUE);

CREATE POLICY "categories_admin_modify"
ON catalog_categories
FOR ALL
USING (is_admin())
WITH CHECK (is_admin());

-- =====================================================
-- BRANDS
-- Public readable
-- Admin writable
-- =====================================================

CREATE POLICY "brands_public_read"
ON catalog_brands
FOR SELECT
USING (is_active = TRUE);

CREATE POLICY "brands_admin_modify"
ON catalog_brands
FOR ALL
USING (is_admin())
WITH CHECK (is_admin());

-- =====================================================
-- PRODUCTS
-- Public reads active + non-deleted products
-- Admin/staff modify
-- =====================================================

CREATE POLICY "products_public_read"
ON catalog_products
FOR SELECT
USING (
    is_active = TRUE
    AND is_deleted = FALSE
);

CREATE POLICY "products_staff_modify"
ON catalog_products
FOR ALL
USING (is_staff())
WITH CHECK (is_staff());

-- =====================================================
-- VARIANTS
-- Public readable if active
-- Staff writable
-- =====================================================

CREATE POLICY "variants_public_read"
ON catalog_variants
FOR SELECT
USING (is_active = TRUE);

CREATE POLICY "variants_staff_modify"
ON catalog_variants
FOR ALL
USING (is_staff())
WITH CHECK (is_staff());

-- =====================================================
-- SHOP INVENTORY
-- Public readable for catalog display
-- Only staff can update inventory
-- =====================================================

CREATE POLICY "inventory_public_read"
ON shop_inventory
FOR SELECT
USING (TRUE);

CREATE POLICY "inventory_staff_modify"
ON shop_inventory
FOR INSERT
WITH CHECK (is_staff());

CREATE POLICY "inventory_staff_update"
ON shop_inventory
FOR UPDATE
USING (is_staff())
WITH CHECK (is_staff());

CREATE POLICY "inventory_admin_delete"
ON shop_inventory
FOR DELETE
USING (is_admin());

-- =====================================================
-- SEARCH INDEX
-- Public readable for search
-- Backend/admin only modify
-- =====================================================

CREATE POLICY "search_public_read"
ON product_search_index
FOR SELECT
USING (TRUE);

CREATE POLICY "search_admin_modify"
ON product_search_index
FOR ALL
USING (is_admin())
WITH CHECK (is_admin());

-- =====================================================
-- PRICING HISTORY
-- Admin only access
-- Immutable audit table
-- =====================================================

CREATE POLICY "pricing_admin_read"
ON product_pricing_history
FOR SELECT
USING (is_admin());

CREATE POLICY "pricing_admin_insert"
ON product_pricing_history
FOR INSERT
WITH CHECK (is_admin());

CREATE POLICY "pricing_block_update"
ON product_pricing_history
FOR UPDATE
USING (FALSE);

CREATE POLICY "pricing_block_delete"
ON product_pricing_history
FOR DELETE
USING (FALSE);

-- =====================================================
-- PRODUCT ALIASES
-- Public readable
-- Staff writable
-- =====================================================

CREATE POLICY "aliases_public_read"
ON product_aliases
FOR SELECT
USING (is_active = TRUE);

CREATE POLICY "aliases_staff_modify"
ON product_aliases
FOR ALL
USING (is_staff())
WITH CHECK (is_staff());

-- =====================================================
-- FUTURE MULTI-SHOP ISOLATION
-- (Disabled in MVP single-shop mode)
--
-- Example:
-- USING (shop_id = auth.jwt() ->> 'shop_id')
-- =====================================================

-- =====================================================
-- GRANTS
-- =====================================================

GRANT SELECT ON shops TO anon, authenticated;
GRANT SELECT ON catalog_categories TO anon, authenticated;
GRANT SELECT ON catalog_brands TO anon, authenticated;
GRANT SELECT ON catalog_products TO anon, authenticated;
GRANT SELECT ON catalog_variants TO anon, authenticated;
GRANT SELECT ON shop_inventory TO anon, authenticated;
GRANT SELECT ON product_search_index TO anon, authenticated;
GRANT SELECT ON product_aliases TO anon, authenticated;

GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
