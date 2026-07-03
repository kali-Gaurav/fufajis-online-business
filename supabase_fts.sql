-- =====================================================
-- FILE: supabase_fts.sql
-- FUFAJI LOOP 2 - FULL TEXT SEARCH + TRIGRAM SEARCH
-- =====================================================

-- Required extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- =====================================================
-- ADD TSVECTOR COLUMN FOR SEARCH INDEX
-- =====================================================

ALTER TABLE product_search_index
ADD COLUMN IF NOT EXISTS search_vector tsvector;

COMMENT ON COLUMN product_search_index.search_vector IS
'Weighted tsvector for PostgreSQL full-text search';

-- =====================================================
-- BUILD SEARCH VECTOR
-- Weight Mapping:
-- A = 100 (brand)
-- B = 90  (product)
-- C = 80  (alias)
-- D = 70  (phonetic/regional/hindi)
-- =====================================================

CREATE OR REPLACE FUNCTION update_product_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector :=
        CASE
            WHEN NEW.token_type = 'brand' THEN
                setweight(to_tsvector('simple', unaccent(COALESCE(NEW.token, ''))), 'A')

            WHEN NEW.token_type = 'product' THEN
                setweight(to_tsvector('simple', unaccent(COALESCE(NEW.token, ''))), 'B')

            WHEN NEW.token_type = 'alias' THEN
                setweight(to_tsvector('simple', unaccent(COALESCE(NEW.token, ''))), 'C')

            ELSE
                setweight(to_tsvector('simple', unaccent(COALESCE(NEW.token, ''))), 'D')
        END;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_search_vector ON product_search_index;

CREATE TRIGGER trigger_update_search_vector
BEFORE INSERT OR UPDATE
ON product_search_index
FOR EACH ROW
EXECUTE FUNCTION update_product_search_vector();

-- Backfill existing rows
UPDATE product_search_index
SET token = token;

-- =====================================================
-- INDEXES FOR SEARCH
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_product_search_vector
ON product_search_index
USING GIN(search_vector);

CREATE INDEX IF NOT EXISTS idx_product_search_token_trgm
ON product_search_index
USING GIN(token gin_trgm_ops);

-- =====================================================
-- SEARCH FUNCTION (FTS + TRIGRAM HYBRID)
-- =====================================================

CREATE OR REPLACE FUNCTION search_products(
    search_query TEXT,
    similarity_threshold FLOAT DEFAULT 0.25,
    result_limit INT DEFAULT 20
)
RETURNS TABLE (
    product_id UUID,
    variant_id UUID,
    token TEXT,
    token_type token_type_enum,
    weight INT,
    rank REAL,
    similarity_score REAL,
    final_score REAL
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        psi.product_id,
        psi.variant_id,
        psi.token,
        psi.token_type,
        psi.weight,

        ts_rank_cd(
            psi.search_vector,
            websearch_to_tsquery('simple', unaccent(search_query))
        ) AS rank,

        similarity(
            lower(unaccent(psi.token)),
            lower(unaccent(search_query))
        ) AS similarity_score,

        (
            ts_rank_cd(
                psi.search_vector,
                websearch_to_tsquery('simple', unaccent(search_query))
            ) * 0.7
            +
            similarity(
                lower(unaccent(psi.token)),
                lower(unaccent(search_query))
            ) * 0.3
        ) AS final_score

    FROM product_search_index psi
    WHERE
        psi.search_vector @@ websearch_to_tsquery('simple', unaccent(search_query))
        OR similarity(
            lower(unaccent(psi.token)),
            lower(unaccent(search_query))
        ) >= similarity_threshold

    ORDER BY final_score DESC, psi.weight DESC
    LIMIT result_limit;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION search_products IS
'Hybrid FTS + trigram search for voice and typo-tolerant search';

-- =====================================================
-- PRODUCT SEARCH VIEW
-- Aggregates search results into products
-- =====================================================

CREATE OR REPLACE VIEW product_search_results AS
SELECT
    cp.id AS product_id,
    cp.product_code,
    cp.name,
    cp.hindi_name,
    cb.name AS brand_name,
    cc.name AS category_name,
    COUNT(psi.id) AS indexed_tokens
FROM catalog_products cp
LEFT JOIN catalog_brands cb ON cp.brand_id = cb.id
LEFT JOIN catalog_categories cc ON cp.category_id = cc.id
LEFT JOIN product_search_index psi ON psi.product_id = cp.id
WHERE cp.is_active = TRUE
AND cp.is_deleted = FALSE
GROUP BY cp.id, cb.name, cc.name;

-- =====================================================
-- SAMPLE SEARCH QUERIES
-- =====================================================

-- English:
-- SELECT * FROM search_products('amul milk');

-- Hindi:
-- SELECT * FROM search_products('दूध');

-- Voice typo:
-- SELECT * FROM search_products('amul milc');

-- Hinglish:
-- SELECT * FROM search_products('aashirvaad atta');

-- =====================================================
-- RECOMMENDED TOKEN STRATEGY
-- =====================================================
-- brand      → Amul, MDH, Tata
-- product    → milk, atta, turmeric powder
-- alias      → doodh, chai patti, aloo
-- phonetic   → dudh, aalu
-- regional   → kanda, batata
-- hindi      → दूध, आलू
-- =====================================================
