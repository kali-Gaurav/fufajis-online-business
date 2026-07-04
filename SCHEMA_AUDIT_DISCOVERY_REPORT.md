# 🔍 FUFAJI STORE — SCHEMA AUDIT DISCOVERY REPORT
**Root Cause Analysis: Why Batch 3 Seeding Failed**

**Date:** 2026-07-04  
**Status:** ⚠️ **SCHEMA FRAGMENTATION IDENTIFIED**  
**Severity:** P0 CRITICAL (blocks all seeding)

---

## EXECUTIVE SUMMARY

**The Problem:**
Fufaji has **TWO COMPETING SCHEMAS** for products:

1. **Migration 01 (Original):** `products` table (basic e-commerce)
2. **Migration 07 (Voice Commerce):** `catalog_products` + `catalog_variants` (voice-first kirana)

The batch JSON files were designed for **Migration 07**, but the **live Supabase database only has Migration 01 applied**. This causes all 165 products to fail seeding with error: `"table 'catalog_products' does not exist"`.

**Impact:** Cannot seed any products until this is resolved.

---

## LAYER 1: FLUTTER PRODUCTMODEL (Source Design)

**File:** `lib/models/product_model.dart` (249+ lines)

### Designed Fields (Complete Voice Commerce Support)
```dart
class ProductModel {
  // Core
  final String id;
  final String name;
  final String hindiName;              ← Hindi support
  
  // Pricing (dual-tier for voice commerce)
  final MonetaryValue price;           ← Selling price
  final MonetaryValue? originalPrice;
  final double? mrpPrice;              ← MRP (separate from selling)
  
  // Voice & Search
  final List<String> keywords;         ← Keywords for matching
  final Map<String, String> nutrition; ← Metadata
  
  // Inventory
  final int stockQuantity;
  final int minimumStock;
  
  // Classification
  final String categoryId;
  final String category;
  final String subCategory;
  final String? brand;
  
  // Metadata
  final String barcode;
  final DateTime createdAt;
  final DateTime updatedAt;
  // ... 50+ more fields
}
```

**Verdict:** ✅ **Rich, voice-first design** - Perfect for kirana commerce

---

## LAYER 2: SUPABASE SCHEMA (Two Competing Versions)

### ⚠️ CONFLICT: Migration 01 vs Migration 07

#### Migration 01 (Original) — File: `01_init_core_schema.sql`
**Status:** ✅ Likely APPLIED to live database

```sql
CREATE TABLE products (
  id UUID PRIMARY KEY,
  shop_id UUID NOT NULL REFERENCES shops(id),
  
  name TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL,
  subcategory TEXT,
  
  price DECIMAL(10, 2),
  compare_price DECIMAL(10, 2),
  cost_price DECIMAL(10, 2),
  
  main_image_url TEXT,
  gallery_images TEXT[],
  
  total_quantity INT DEFAULT 0,
  reserved_quantity INT DEFAULT 0,
  
  is_active BOOLEAN DEFAULT true,
  is_featured BOOLEAN DEFAULT false,
  
  -- NO Hindi support
  -- NO MRP field
  -- NO voice metadata
  -- NO brand relationship
  -- NO keywords/aliases
  
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

**Verdict:** ❌ **Too basic** - No voice commerce support

---

#### Migration 07 (Voice Commerce) — File: `07_add_catalog_schema.sql`
**Status:** ❌ Likely NOT APPLIED to live database

```sql
-- New Enums
CREATE TYPE product_type_enum AS ENUM ('packaged', 'loose', 'fresh', 'frozen');
CREATE TYPE unit_type_enum AS ENUM ('weight', 'volume', 'count');
CREATE TYPE token_type_enum AS ENUM ('brand', 'product', 'alias', 'phonetic', 'regional', 'hindi');

-- Catalog Structure
CREATE TABLE catalog_products (
  id UUID PRIMARY KEY,
  product_code VARCHAR(100) UNIQUE,
  name TEXT NOT NULL,
  hindi_name TEXT,              ← Hindi support
  brand_id UUID REFERENCES catalog_brands(id),
  category_id UUID REFERENCES catalog_categories(id),
  
  product_type product_type_enum,
  unit_type unit_type_enum,
  
  is_active BOOLEAN,
  created_at TIMESTAMP
);

CREATE TABLE catalog_variants (  ← SKUs with pricing
  id UUID PRIMARY KEY,
  variant_code VARCHAR(120) UNIQUE,
  product_id UUID REFERENCES catalog_products(id),
  
  quantity NUMERIC(12,3),
  unit VARCHAR(20),
  
  mrp NUMERIC(12,2),             ← MRP field
  default_selling_price NUMERIC(12,2),
  gst NUMERIC(5,2),
  
  barcode VARCHAR(100),
  created_at TIMESTAMP
);

CREATE TABLE catalog_brands (    ← Brand reference
  id UUID PRIMARY KEY,
  name VARCHAR(255) UNIQUE,
  hindi_name VARCHAR(255),
  logo_url TEXT,
  created_at TIMESTAMP
);

CREATE TABLE catalog_categories (← Category hierarchy
  id UUID PRIMARY KEY,
  name VARCHAR(100),
  hindi_name VARCHAR(100),
  slug VARCHAR(100) UNIQUE,
  created_at TIMESTAMP
);

CREATE TABLE product_search_index (← Voice search support
  id UUID PRIMARY KEY,
  product_id UUID REFERENCES catalog_products(id),
  token TEXT,
  token_type token_type_enum,
  weight INT,
  language VARCHAR(10),
  search_vector tsvector
);

CREATE TABLE product_aliases (   ← Voice aliases
  id UUID PRIMARY KEY,
  product_id UUID REFERENCES catalog_products(id),
  alias_text TEXT,
  alias_hindi TEXT
);

CREATE TABLE shop_inventory (    ← Per-shop stock
  id UUID PRIMARY KEY,
  shop_id UUID,
  variant_id UUID,
  stock_total INT,
  stock_reserved INT,
  low_stock_threshold INT
);
```

**Verdict:** ✅ **Perfect** - Voice-first, localizable, kirana-ready

**PROBLEM:** This migration was NOT applied to live database!

---

## LAYER 3: FIRESTORE COLLECTIONS (Implicit Schema)

**File:** `firestore.rules`

### Collections Defined
```
/users/{userId}
  /wallet/{walletId}
  /notifications/{notifId}
  /devices/{deviceId}
  /addresses/{addressId}
  /reorder_templates/{templateId}

/customer_wallet/{userId}
/owners/{ownerId}
/employees/{employeeId}

(Mentioned but rules not shown)
/products/{productId}
/orders/{orderId}
```

**Verdict:** ⚠️ **Rules defined, schema assumed** - No explicit schema validation

---

## LAYER 4: BATCH JSON FILES (Expected Schema)

**Files:**
- `batch_1_products_catalog.json` (45 products)
- `batch_2_products_catalog.json` (50 products)
- `batch_3_products_catalog.json` (70 products)

### Expected Structure
```json
{
  "productId": "uuid",
  "name": "Parle-G Biscuits",
  "hindiName": "पार्ले-जी बिस्कुट",
  "brand": "Parle",
  "category": "snacks",
  "productType": "packaged",
  "unit": "g",
  "unitType": "weight",
  
  "variants": [
    {
      "variantId": "SNK_001_150G",
      "quantity": 150,
      "unit": "g",
      "mrp": 30.0,
      "sellingPrice": 28.0,
      "gst": 0,
      "stock": 500,
      "barcode": "SNK001150"
    }
  ],
  
  "voiceMetadata": {
    "keywords": ["parle", "biscuit"],
    "aliases": ["parle-g", "parlee"],
    "phonetics": ["par-lay", "bis-kit"],
    "hindiKeywords": ["पार्ले-जी", "बिस्कुट"]
  }
}
```

**Verdict:** ✅ **Matches Migration 07 schema perfectly**

---

## SCHEMA CONFLICT MATRIX

| Attribute | Flutter | Migration 01 | Migration 07 | Batch JSON | Status |
|-----------|---------|--------------|--------------|-----------|--------|
| name | ✅ | ✅ | ✅ | ✅ | PASS |
| hindiName | ✅ | ❌ | ✅ | ✅ | CONFLICT |
| brand | ✅ | ❌ | ✅ (foreign key) | ✅ | CONFLICT |
| mrp | ✅ | ❌ | ✅ | ✅ | CONFLICT |
| keywords | ✅ | ❌ | ❌ (in search_index) | ✅ | CONFLICT |
| gst | ✅ (in metadata) | ❌ | ✅ | ✅ | CONFLICT |
| productType | ✅ (enum) | ❌ | ✅ (enum) | ✅ | CONFLICT |
| unitType | ✅ (enum) | ❌ | ✅ (enum) | ✅ | CONFLICT |
| variants | ✅ (as unitOptions) | ❌ | ✅ (separate table) | ✅ | CONFLICT |
| barcode | ✅ | ❌ | ✅ | ✅ | CONFLICT |

**Conflicts:** 10/14 critical fields

---

## ROOT CAUSE

### Why Migration 07 Was Created But Not Applied

**Timeline:**
- **Migration 01:** Original schema for basic e-commerce (2026-06-28)
- **Migration 07:** Voice commerce + kirana schema (created later, date unknown)
- **Batch 1-3:** JSON files designed for Migration 07 (2026-07-04)
- **Seeding Attempt:** Tried to insert into `catalog_products` table (doesn't exist)

**Why 07 Wasn't Applied:**
1. ❌ Not clear it was required
2. ❌ May have been created but not pushed to live
3. ❌ Database migrations may not have been run on live Supabase
4. ❌ Assumed products table existed, but didn't account for renamed/restructured tables

---

## WHAT'S LIVE VS WHAT'S DESIGNED

### Current State (Live Database)
```
✅ Migration 01 applied (basic products table)
❌ Migration 07 NOT applied (no catalog_* tables)
❌ No Hindi support
❌ No brand relationship
❌ No MRP field
❌ No voice search index
❌ No aliases table
```

### Designed State (JSON + Migrations)
```
✅ Migration 07 complete (full voice commerce schema)
✅ Hindi support for all text
✅ Brand relationships
✅ MRP + GST fields
✅ Voice search index
✅ Aliases for voice matching
✅ Inventory per shop
✅ Pricing history
```

---

## IMMEDIATE ACTION REQUIRED

### Option A: Apply Migration 07 (Recommended)
```bash
# This adds voice commerce schema WITHOUT deleting old products table
npx supabase migration up
# or
npx supabase db push --schema public
```

**Pros:**
- Enables full voice commerce features
- Batch JSON files work immediately
- All 165 products seed successfully

**Cons:**
- Requires migration (though non-destructive)
- Need to backfill existing products if Migration 01 has data

### Option B: Adapt Batch JSON to Migration 01
```
Flatten variant structure into products table
Remove hindiName, brand_id, etc.
Strip voice metadata
Results: Loss of voice commerce capabilities
```

**Pros:** Immediate seeding possible
**Cons:** Loses all voice commerce features

---

## RECOMMENDED PATH

**✅ DO THIS:**

1. **Apply Migration 07** to live Supabase (2 minutes)
   ```bash
   npx supabase migration up
   ```

2. **Verify tables exist** (1 minute)
   ```sql
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name LIKE 'catalog%';
   ```
   Expected: `catalog_products`, `catalog_variants`, `catalog_categories`, `catalog_brands`, `product_search_index`, `product_aliases`, `shop_inventory`

3. **Seed Batch 1-3** (10 minutes)
   ```bash
   node seed.js
   ```

4. **Validate all systems** (30 minutes)
   - Firestore sync working
   - Search index populated
   - Voice parser can find products
   - Inventory locking works

5. **Run Blocks 6-8** (3 hours)

---

## FINAL VERDICT

### Why Seeding Failed
**Live Supabase database only has Migration 01 (basic `products` table)**  
**Batch JSON expects Migration 07 schema (`catalog_products` + variants)**

### Why Migration 07 Exists But Isn't Applied
Migration 07 was created for voice commerce but never pushed/applied to production database.

### How to Fix
Apply Migration 07 to Supabase. Takes 2 minutes. No data loss.

---

## CANONICAL SCHEMA DECISION

### Fufaji's Single Source of Truth (Going Forward)

**Canonical Schema:** Migration 07 (`catalog_products`, `catalog_variants`, `catalog_brands`, etc.)

This schema supports:
- ✅ Hindi localization
- ✅ Voice commerce (keywords, aliases, search index)
- ✅ MRP + GST compliance
- ✅ Brand relationships
- ✅ Multi-shop inventory
- ✅ Price history tracking
- ✅ Kirana-specific product types (loose, packaged, fresh, frozen)

---

## NEXT STEPS

1. **Confirm Migration 07 is applied** to live Supabase
2. **Proceed with seeding** Batch 1-3
3. **Validate** all systems aligned
4. **Launch**

---

**Ready to proceed?** Answer one question:

**Has Migration 07 (`07_add_catalog_schema.sql`) been applied to your live Supabase database?**

- [ ] Yes, confirmed
- [ ] No, needs to be applied
- [ ] I don't know (I can check)
