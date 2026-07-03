# Fufaji Product Catalog System — Supabase Schema Documentation

**Version:** 1.0  
**Architecture:** LOOP 2 Production Schema  
**Database:** PostgreSQL (Supabase)  
**Search:** PostgreSQL FTS + pg_trgm  
**Inventory Authority:** Supabase Canonical  
**Shop Scope:** Single-Shop MVP (Multi-Shop Compatible)

---

## 1. Architecture Overview

Fufaji uses a hybrid architecture:

- **Supabase (Canonical Source of Truth)**
  - Product catalog
  - Inventory
  - Pricing
  - Search index
  - Audit history

- **Firestore (Operational Cache)**
  - Customer app reads
  - Real-time cart sync
  - Live order state

**Flow:**
```
Customer App → Firestore (fast reads) → Sync Engine → Supabase (master write authority)
```

---

## 2. ER Diagram

```
shops
  ↓
  └─ shop_inventory ─← catalog_variants ─← catalog_products
                                          ↗ ↑
                                    catalog_brands
                                          ↑
                                   catalog_categories

catalog_products
  ├─ product_aliases
  ├─ product_search_index
  └─ product_pricing_history (via variants)
```

---

## 3. Table Documentation

### shops

Represents shop/business entities.

| Column     | Type      | Description     |
|------------|-----------|-----------------|
| id         | UUID      | Primary key     |
| shop_code  | VARCHAR   | Unique shop ID  |
| name       | TEXT      | Shop name       |
| is_active  | BOOLEAN   | Active flag     |
| created_at | TIMESTAMP | Creation time   |

**Example:** `FUFAJI_MAIN_001`

---

### catalog_categories

Master product categories.

| Column        | Type      | Description          |
|---------------|-----------|----------------------|
| id            | UUID      | Primary key          |
| name          | VARCHAR   | Category name        |
| hindi_name    | VARCHAR   | Hindi name           |
| slug          | VARCHAR   | URL-safe unique key  |
| description   | TEXT      | Category description |
| is_active     | BOOLEAN   | Active status        |
| display_order | INT       | UI sorting order     |
| created_at    | TIMESTAMP | Creation time        |

**Examples:**
- Vegetables
- Fruits
- Dairy
- Oils
- Snacks

---

### catalog_brands

Brand registry.

| Column            | Type      | Description       |
|-------------------|-----------|-------------------|
| id                | UUID      | Primary key       |
| name              | VARCHAR   | Brand name        |
| hindi_name        | VARCHAR   | Hindi name        |
| logo_url          | TEXT      | Logo URL          |
| country_of_origin | VARCHAR   | Country           |
| is_active         | BOOLEAN   | Active status     |
| created_at        | TIMESTAMP | Creation time     |

**Examples:**
- Amul
- Tata
- MDH
- Lay's
- Nescafe

---

### catalog_products

Product families (3-level hierarchy: Category → Family → Variant).

| Column       | Type      | Description                   |
|--------------|-----------|-------------------------------|
| id           | UUID      | Primary key                   |
| product_code | VARCHAR   | Unique family code            |
| name         | TEXT      | English name                  |
| hindi_name   | TEXT      | Hindi name (Devanagari)       |
| brand_id     | UUID      | Foreign key → brands          |
| category_id  | UUID      | Foreign key → categories      |
| product_type | ENUM      | packaged / loose / fresh      |
| unit_type    | ENUM      | weight / volume / count       |
| description  | TEXT      | Product description           |
| is_active    | BOOLEAN   | Active status                 |
| is_deleted   | BOOLEAN   | Soft delete flag              |
| created_at   | TIMESTAMP | Creation time                 |
| updated_at   | TIMESTAMP | Last update time              |

**Product Code Format:** `PROD-{CATEGORY}-{NUMBER}`  
**Example:** `PROD-OIL-0001`

---

### catalog_variants

Sellable SKUs with pricing.

| Column                | Type      | Description                  |
|-----------------------|-----------|------------------------------|
| id                    | UUID      | Primary key                  |
| variant_code          | VARCHAR   | Unique SKU code              |
| product_id            | UUID      | Foreign key → products       |
| quantity              | NUMERIC   | Quantity value               |
| unit                  | VARCHAR   | Unit (kg, g, ml, L, piece)   |
| mrp                   | NUMERIC   | Maximum Retail Price         |
| default_selling_price | NUMERIC   | Default selling price        |
| gst                   | NUMERIC   | GST rate (default 5%)        |
| barcode               | VARCHAR   | EAN/UPC code (optional)      |
| is_active             | BOOLEAN   | Active status                |
| created_at            | TIMESTAMP | Creation time                |
| updated_at            | TIMESTAMP | Last update time             |

**Variant Code Format:** `VAR-{CATEGORY}-{NUMBER}-{SIZE}`  
**Example:** `VAR-OIL-0001-500ML`

**Constraint:** `mrp >= default_selling_price` (enforced by trigger)

---

### shop_inventory

Canonical inventory authority. Tracks stock + pricing per shop per variant.

| Column              | Type      | Description                |
|---------------------|-----------|----------------------------|
| id                  | UUID      | Primary key                |
| shop_id             | UUID      | Foreign key → shops        |
| variant_id          | UUID      | Foreign key → variants     |
| stock_total         | INT       | Total stock on hand        |
| stock_reserved      | INT       | Reserved by orders         |
| stock_damaged       | INT       | Damaged stock              |
| stock_available     | INT       | Computed (auto-trigger)    |
| buy_price           | NUMERIC   | Purchase/cost price        |
| selling_price       | NUMERIC   | Shop override selling price|
| low_stock_threshold | INT       | Low stock alert level      |
| reorder_threshold   | INT       | Triggers reorder process   |
| reorder_quantity    | INT       | Qty to reorder             |
| last_restocked_at   | TIMESTAMP | Last restock timestamp     |
| updated_at          | TIMESTAMP | Last update time           |

**Stock Formula (Auto-Computed):**
```
stock_available = MAX(stock_total - stock_reserved - stock_damaged, 0)
```

**Composite Key:** `(shop_id, variant_id)` — one entry per variant per shop

---

### product_search_index

Search token table for voice + text search.

| Column       | Type      | Description              |
|--------------|-----------|--------------------------|
| id           | UUID      | Primary key              |
| product_id   | UUID      | Foreign key → products   |
| variant_id   | UUID      | Foreign key → variants   |
| token        | TEXT      | Search keyword           |
| token_type   | ENUM      | Token classification     |
| weight       | INT       | Ranking priority (70-100)|
| language     | VARCHAR   | en / hi                  |
| search_vector| tsvector  | PostgreSQL FTS vector    |
| created_at   | TIMESTAMP | Creation time            |

**Token Types & Weights:**
- `brand` (100) — brand name
- `product` (90) — product name
- `alias` (80) — regional synonym
- `phonetic` (75) — phonetic variant
- `regional` (75) — regional name
- `hindi` (70) — Hindi keyword (Devanagari)

**Examples:**
- Token: `milk`, Type: `product`, Weight: 90
- Token: `दूध`, Type: `hindi`, Weight: 70
- Token: `doodh`, Type: `phonetic`, Weight: 75
- Token: `aloo`, Type: `alias`, Weight: 80

---

### product_pricing_history

Immutable pricing audit trail. Auto-populated by trigger on variant price updates.

| Column            | Type      | Description         |
|-------------------|-----------|---------------------|
| id                | UUID      | Primary key         |
| variant_id        | UUID      | Foreign key         |
| mrp_old           | NUMERIC   | Previous MRP        |
| mrp_new           | NUMERIC   | New MRP             |
| selling_price_old | NUMERIC   | Previous SP         |
| selling_price_new | NUMERIC   | New SP              |
| changed_by        | UUID      | Admin user ID       |
| reason            | TEXT      | Change reason       |
| changed_at        | TIMESTAMP | Timestamp           |

**Access:** Admin-only read; immutable (no updates/deletes)

---

### product_aliases

Voice search synonyms and regional names.

| Column      | Type      | Description        |
|-------------|-----------|-------------------|
| id          | UUID      | Primary key        |
| product_id  | UUID      | Foreign key        |
| alias_text  | TEXT      | English alias      |
| alias_hindi | TEXT      | Hindi alias        |
| is_active   | BOOLEAN   | Active status      |
| created_at  | TIMESTAMP | Creation time      |

**Examples:**
- `doodh` → milk
- `aloo` → potato
- `kanda` → onion
- `pyaaj` → onion (regional)

---

## 4. Search Architecture

### Full-Text Search (FTS)

Uses PostgreSQL's native `tsvector` + `websearch_to_tsquery()`.

**Good for:**
- Exact keyword matches
- Multi-word queries
- Language-specific tokenization

**Example:**
```sql
SELECT * FROM search_products('amul milk');
```

---

### Trigram Search (Fuzzy)

Uses `pg_trgm` extension for typo tolerance.

**Good for:**
- Voice transcription mistakes
- Misspellings
- Phonetic variants

**Example:**
```sql
SELECT * FROM search_products('amul milc');  -- typo
```

---

### Hybrid Scoring

Combines both for ranking.

**Formula:**
```
Final Score = (FTS Rank × 0.7) + (Trigram Similarity × 0.3)
```

**Results ranked by:**
1. Final score (descending)
2. Token weight (descending)

---

## 5. Inventory Architecture

### Canonical Authority

Supabase `shop_inventory` is the single source of truth for stock levels.

### Reservation Flow

```
Customer App
  ↓
Add to Cart (reserves stock)
  ↓
Checkout
  ↓
Payment Success (confirms reservation)
  ↓
Firestore updates stock_reserved
  ↓
Sync Engine
  ↓
Supabase updates stock_reserved
```

### Stock Status States

| State           | Formula                                    |
|-----------------|---------------------------------------------|
| Total           | Sum of all received stock                  |
| Reserved        | Sum of active orders + pending payments    |
| Damaged         | Physically damaged, unsellable             |
| Available       | Total - Reserved - Damaged (≥ 0)          |

**Example:**
```
Total Stock:    100 units
Reserved:       10 units (active carts)
Damaged:        2 units
Available:      88 units (displayable to customers)
```

---

## 6. Soft Delete Strategy

Products are **never hard-deleted** to maintain data integrity.

### Soft Delete Process

```sql
UPDATE catalog_products
SET is_deleted = TRUE,
    is_active = FALSE
WHERE id = ?;
```

### Benefits

- Preserves order history
- Maintains referential integrity
- Supports "restore" workflows
- Enables analytics on deleted products
- Trigger prevents accidental hard deletes

### Query Pattern

Always filter:
```sql
WHERE is_active = TRUE AND is_deleted = FALSE
```

---

## 7. CRUD Workflows

### Add Product

1. Insert or select brand
2. Insert or select category
3. Insert product family
4. Insert variants (multiple sizes/weights)
5. Insert search tokens (brand, product, aliases, phonetics, Hindi)
6. Insert aliases (regional names, synonyms)
7. Insert inventory entry (per shop)

### Update Product

**Updateable fields:**
- Variant pricing (triggers: pricing history log, search vector refresh)
- Inventory stock (triggers: auto-compute available, timestamps)
- Product metadata (triggers: updated_at)
- Aliases (triggers: search index refresh)

**Examples:**
```sql
-- Update price
UPDATE catalog_variants
SET default_selling_price = 450
WHERE id = ?;
→ Auto-logs to product_pricing_history

-- Update stock
UPDATE shop_inventory
SET stock_total = 150
WHERE variant_id = ?;
→ Auto-computes stock_available
```

### Delete Product

Soft delete only (hard deletes blocked by trigger):

```sql
UPDATE catalog_products
SET is_deleted = TRUE, is_active = FALSE
WHERE id = ?;
```

---

## 8. Example Queries

### Get Active Products

```sql
SELECT *
FROM catalog_products
WHERE is_active = TRUE
AND is_deleted = FALSE
ORDER BY created_at DESC;
```

### Get Product with Variants

```sql
SELECT
  p.name,
  p.hindi_name,
  v.variant_code,
  v.quantity,
  v.unit,
  v.mrp,
  v.default_selling_price
FROM catalog_products p
JOIN catalog_variants v ON p.id = v.product_id
WHERE p.id = '?'
AND p.is_deleted = FALSE;
```

### Get Inventory for a Variant

```sql
SELECT
  si.shop_id,
  si.stock_total,
  si.stock_available,
  si.low_stock_threshold,
  si.selling_price
FROM shop_inventory si
WHERE si.variant_id = '?';
```

### Low Stock Alert

```sql
SELECT
  si.shop_id,
  cv.variant_code,
  cp.name,
  si.stock_available,
  si.low_stock_threshold
FROM shop_inventory si
JOIN catalog_variants cv ON si.variant_id = cv.id
JOIN catalog_products cp ON cv.product_id = cp.id
WHERE si.stock_available <= si.low_stock_threshold;
```

### English Voice Search

```sql
SELECT * FROM search_products('amul milk') LIMIT 10;
```

### Hindi Voice Search

```sql
SELECT * FROM search_products('दूध') LIMIT 10;
```

### Hinglish Search (Typo-Tolerant)

```sql
SELECT * FROM search_products('aashirwad atta') LIMIT 10;
```

### Price History for Variant

```sql
SELECT *
FROM product_pricing_history
WHERE variant_id = '?'
ORDER BY changed_at DESC;
```

---

## 9. Production Guarantees

✅ **Data Integrity**
- UUID primary keys everywhere
- Soft deletes only
- Referential integrity via FKs
- Composite unique on (shop_id, variant_id)

✅ **Audit & History**
- Full pricing audit trail
- Updated timestamps auto-managed
- Created timestamps immutable
- Admin can track all changes

✅ **Search**
- Weighted FTS + trigram hybrid
- Typo-tolerant voice search
- Multi-language (EN + HI + Hinglish)
- Accent-insensitive (unaccent)

✅ **Security**
- Row-level security (RLS) enabled
- Admin-only writes
- Public read on active products
- Immutable pricing history (no deletes)

✅ **Scalability**
- 28 indexes optimizing common queries
- Partial indexes for soft deletes
- Composite indexes on FK + filtering
- GIN indexes for full-text search

✅ **Multi-Shop Ready**
- MVP: Single shop (FUFAJI_MAIN_001)
- Future: Filter by shop_id in RLS policies
- Schema supports multiple shops now

---

## 10. Deployment Order

Execute SQL files **in this exact order**:

1. **supabase_schema.sql** — Creates all 9 tables + 3 enums
2. **supabase_indexes.sql** — Creates 28 indexes + 2 partial indexes
3. **supabase_triggers.sql** — Creates 11 functions + 7 triggers
4. **supabase_rls.sql** — Enables RLS + 18 policies + 2 helper functions
5. **supabase_fts.sql** — Creates FTS functions + search view

**After deployment:**
```bash
-- Verify all tables exist
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';

-- Verify RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public';

-- Test FTS
SELECT * FROM search_products('milk');
```

**Schema ready for production after all 5 files execute successfully with no errors.**

---

## 11. Appendix: Reserved Words

These are system-reserved and should not be used as product/variant names:

- `delete`, `select`, `insert`, `update`
- `and`, `or`, `not`, `like`
- `group`, `order`, `where`, `having`

---

**End of Documentation**
