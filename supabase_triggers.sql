-- =====================================================
-- FILE: supabase_triggers.sql
-- FUFAJI LOOP 2 - TRIGGERS & FUNCTIONS
-- =====================================================

-- =====================================================
-- FUNCTION: AUTO UPDATE updated_at
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGERS: updated_at AUTO UPDATE
-- =====================================================

CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON catalog_products
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_variants_updated_at
BEFORE UPDATE ON catalog_variants
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_inventory_updated_at
BEFORE UPDATE ON shop_inventory
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- FUNCTION: COMPUTE stock_available
-- stock_available = stock_total - stock_reserved - stock_damaged
-- =====================================================

CREATE OR REPLACE FUNCTION compute_stock_available()
RETURNS TRIGGER AS $$
BEGIN
    NEW.stock_available =
        GREATEST(
            NEW.stock_total - NEW.stock_reserved - NEW.stock_damaged,
            0
        );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGER: AUTO COMPUTE INVENTORY
-- =====================================================

CREATE TRIGGER trg_compute_stock_available
BEFORE INSERT OR UPDATE ON shop_inventory
FOR EACH ROW
EXECUTE FUNCTION compute_stock_available();

-- =====================================================
-- FUNCTION: PREVENT INVALID INVENTORY
-- =====================================================

CREATE OR REPLACE FUNCTION validate_inventory_values()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.stock_total < 0 THEN
        RAISE EXCEPTION 'stock_total cannot be negative';
    END IF;

    IF NEW.stock_reserved < 0 THEN
        RAISE EXCEPTION 'stock_reserved cannot be negative';
    END IF;

    IF NEW.stock_damaged < 0 THEN
        RAISE EXCEPTION 'stock_damaged cannot be negative';
    END IF;

    IF NEW.stock_reserved > NEW.stock_total THEN
        RAISE EXCEPTION 'stock_reserved cannot exceed stock_total';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_inventory
BEFORE INSERT OR UPDATE ON shop_inventory
FOR EACH ROW
EXECUTE FUNCTION validate_inventory_values();

-- =====================================================
-- FUNCTION: VALIDATE VARIANT PRICING
-- =====================================================

CREATE OR REPLACE FUNCTION validate_variant_pricing()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.mrp <= 0 THEN
        RAISE EXCEPTION 'MRP must be greater than 0';
    END IF;

    IF NEW.default_selling_price <= 0 THEN
        RAISE EXCEPTION 'Selling price must be greater than 0';
    END IF;

    IF NEW.default_selling_price > NEW.mrp THEN
        RAISE EXCEPTION 'Selling price cannot exceed MRP';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_variant_pricing
BEFORE INSERT OR UPDATE ON catalog_variants
FOR EACH ROW
EXECUTE FUNCTION validate_variant_pricing();

-- =====================================================
-- FUNCTION: INVENTORY PRICING VALIDATION
-- =====================================================

CREATE OR REPLACE FUNCTION validate_inventory_pricing()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.buy_price IS NOT NULL AND NEW.buy_price < 0 THEN
        RAISE EXCEPTION 'Buy price cannot be negative';
    END IF;

    IF NEW.selling_price IS NOT NULL AND NEW.selling_price < 0 THEN
        RAISE EXCEPTION 'Selling price cannot be negative';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_inventory_pricing
BEFORE INSERT OR UPDATE ON shop_inventory
FOR EACH ROW
EXECUTE FUNCTION validate_inventory_pricing();

-- =====================================================
-- FUNCTION: AUTO UPDATE SEARCH VECTOR
-- =====================================================

CREATE OR REPLACE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector :=
        to_tsvector(
            CASE
                WHEN NEW.language = 'hi' THEN 'simple'
                ELSE 'english'
            END,
            COALESCE(NEW.token, '')
        );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_search_vector
BEFORE INSERT OR UPDATE ON product_search_index
FOR EACH ROW
EXECUTE FUNCTION update_search_vector();

-- =====================================================
-- FUNCTION: AUDIT PRICE CHANGES
-- Auto-log variant price changes into product_pricing_history
-- =====================================================

CREATE OR REPLACE FUNCTION audit_variant_price_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (
        OLD.mrp IS DISTINCT FROM NEW.mrp OR
        OLD.default_selling_price IS DISTINCT FROM NEW.default_selling_price
    ) THEN
        INSERT INTO product_pricing_history (
            variant_id,
            mrp_old,
            mrp_new,
            selling_price_old,
            selling_price_new,
            reason,
            changed_at
        )
        VALUES (
            NEW.id,
            OLD.mrp,
            NEW.mrp,
            OLD.default_selling_price,
            NEW.default_selling_price,
            'Auto price update trigger',
            CURRENT_TIMESTAMP
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_variant_price_changes
AFTER UPDATE ON catalog_variants
FOR EACH ROW
EXECUTE FUNCTION audit_variant_price_changes();

-- =====================================================
-- FUNCTION: SOFT DELETE PROTECTION
-- Prevent physical deletes for critical tables
-- =====================================================

CREATE OR REPLACE FUNCTION prevent_hard_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Hard delete not allowed. Use soft delete via is_deleted flag.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_product_delete
BEFORE DELETE ON catalog_products
FOR EACH ROW
EXECUTE FUNCTION prevent_hard_delete();

-- =====================================================
-- FUNCTION: AUTO GENERATE PRODUCT CODE
-- Example: PROD-OIL-0001
-- =====================================================

CREATE OR REPLACE FUNCTION generate_product_code(category_slug TEXT, sequence_num INT)
RETURNS TEXT AS $$
BEGIN
    RETURN 'PROD-' || UPPER(category_slug) || '-' || LPAD(sequence_num::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCTION: AUTO GENERATE VARIANT CODE
-- Example: VAR-OIL-0001-500ML
-- =====================================================

CREATE OR REPLACE FUNCTION generate_variant_code(category_slug TEXT, sequence_num INT, size_label TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN 'VAR-' || UPPER(category_slug) || '-' || LPAD(sequence_num::TEXT, 4, '0') || '-' || UPPER(size_label);
END;
$$ LANGUAGE plpgsql;
