# Firestore → Postgres Migration

One-time / re-runnable backfill of historical Firestore data into the
Supabase Postgres master database for Fufaji Store.

## Why

The app now dual-writes new data to both Firestore and Postgres, but
data created **before** the dual-write switch only exists in
Firestore. This script copies that historical data into Postgres so
the Postgres analytics views (`sales_analytics`, `vendor_analytics`,
`delivery_analytics`) and the rest of the Postgres-backed app see the
full history, not just new records.

## What it migrates

Run in this order (dependency order — later collections reference
earlier ones via foreign keys):

1. `shops` — Firestore `shops/{shopId}` → `shops` (matched on `firestore_id`)
2. `branches` — `shops/{shopId}/branches/{branchId}` (collection group) → `branches`,
   with `shop_id` resolved from the parent shop document
3. `users` — Firestore `users/{firebaseUid}` → `users` (matched on `firebase_uid`),
   including `shop_id` / `branch_id` resolved from `shopId` / `branchId` fields
4. `categories` — `categories/{id}` → `categories` (matched on `firestore_id`)
5. `addresses` — `users/{uid}/addresses/{id}` (collection group) → `addresses`
6. `products` — `products/{id}` → `products`, including `shop_id` resolved from `shopId`
7. `orders` — `orders/{id}` → `orders`, including `shop_id` / `branch_id`, plus
   embedded `items[]` → `order_items`, plus a seeded `order_status_history` row
   reflecting the order's current status
8. `reviews` — `reviews/{id}` or `products/{id}/reviews/{id}` → `reviews`
9. `wallet_transactions` — top-level or `users/{uid}/wallet_transactions/{id}` → `wallet_transactions`
10. `support_tickets` — `support_tickets/{id}` → `support_tickets`
11. `coupons` — `coupons/{id}` → `coupons` (matched on `code`)
12. `kyc_documents` — top-level or `users/{uid}/kyc_documents/{id}` → `kyc_documents`
13. `notifications` — top-level or `users/{uid}/notifications/{id}` → `notifications`
14. `inventory_logs` — top-level or `products/{id}/inventory_logs/{id}` → `inventory_logs`
15. `delivery_tracking` — top-level or `orders/{id}/tracking/{id}` → `delivery_tracking`

`shops` and `branches` run FIRST because `users`, `products`, and
`orders` all reference them via `shop_id` / `branch_id` foreign keys
(see `supabase/migrations/008_shops_branches.sql`). A default
`__default__` shop + "Main Branch" are seeded by that migration for
legacy data with no Firestore `shopId`/`branchId` field.

Every table is upserted on a stable key (`firestore_id`, `firebase_uid`
for users, or `code` for coupons) — **the script is safe to re-run**;
existing rows are updated, not duplicated.

Rows whose required parent (e.g. an address whose user wasn't
migrated, or a review for a product that doesn't exist in Postgres)
can't be resolved are **skipped** and counted in `documents_skipped`,
not written with broken foreign keys.

## Setup

1. Apply the new SQL migration (adds `firestore_id` columns + the
   `migration_runs` tracking table) if you haven't already:

   ```
   supabase/migrations/005_migration_compat.sql
   ```

2. Install dependencies:

   ```bash
   cd scripts/migration
   npm install
   ```

3. Copy `.env.example` to `.env` and fill in:

   - `GOOGLE_APPLICATION_CREDENTIALS` — path to a Firebase service
     account JSON with Firestore read access (e.g. exported from
     Firebase Console → Project Settings → Service Accounts).
   - `DATABASE_URL` — the Supabase Postgres connection string
     (Project Settings → Database → Connection string, "URI" /
     direct connection, not the pooled one if running long jobs).
   - `MIGRATION_BATCH_SIZE` (optional, default 200) — Firestore page size.
   - `MIGRATION_PG_CHUNK_SIZE` (optional, default 100) — reserved for
     future batched-write tuning.

   **Never commit `.env` or the service account JSON.**

## Running

```bash
cd scripts/migration

# 1. Always dry-run first — reads Firestore, maps rows, prints
#    seen/written/skipped counts, but writes NOTHING to Postgres.
npm run migrate:dry

# 2. Spot-check a single collection with a small limit
node migrate.js --dry-run --only=users --limit=20

# 3. Run a single collection for real
node migrate.js --only=users

# 4. Run everything for real (in dependency order)
npm run migrate
```

### CLI flags

| Flag | Description |
|---|---|
| `--dry-run` | Read & map documents, but never write to Postgres (every transaction is rolled back). |
| `--only=a,b,c` | Run only the named migrators (comma-separated, matching the `name` in `migrators/index.js`). |
| `--limit=N` | Stop each migrator after `N` source documents (useful for spot-checks). |

## Monitoring progress

Each run records one row per migrator in `migration_runs`:

```sql
select collection, status, documents_seen, documents_written, documents_skipped,
       last_doc_id, error, started_at, finished_at
from migration_runs
order by started_at desc;
```

A `status = 'failed'` row with a non-null `error` means the migrator
stopped early — check the error, fix the data/mapping issue, and
re-run with `--only=<that collection>` (it will resume cleanly thanks
to upserts).

## Known gaps / follow-up passes

- **`users.shop_id` / `users.branch_id`, `products.shop_id`,
  `orders.shop_id` / `orders.branch_id`**: on a fresh migration these
  are resolved automatically (see "What it migrates" above). If your
  database was migrated **before** `008_shops_branches.sql` and the
  `shops`/`branches` migrators were added, those columns will still be
  `null` on existing rows. Apply `008_shops_branches.sql` first, then
  run the standalone backfill script:

  ```bash
  cd scripts/migration
  npm run backfill:shops-branches:dry   # preview what would change
  npm run backfill:shops-branches       # apply
  ```

  See `backfill_shops_branches.js` — it syncs `shops`/`branches` from
  Firestore, then for each `users`/`products`/`orders` row with a null
  `shop_id` (or `branch_id`), re-resolves it from the source Firestore
  doc's `shopId`/`branchId` field, falling back to the seeded
  `__default__` shop/branch when no such field exists.
- **`categories.parent_id`**: if Firestore returns child categories
  before their parents, `parent_id` may be `null` on first pass.
  Re-run `node migrate.js --only=categories` a second time to fill in
  any remaining parent links once all categories exist. For a quicker,
  targeted fix that only touches `parent_id` (without re-mapping every
  category column), use the standalone backfill script instead:

  ```bash
  cd scripts/migration
  npm run backfill:category-parents:dry   # preview what would change
  npm run backfill:category-parents       # apply
  ```

  See `backfill_category_parents.js` — it reports how many categories
  still have `parent_id is null` with no parent reference in Firestore
  (top-level, expected) vs. how many were resolved vs. how many still
  reference a parent that hasn't been migrated yet (re-run later).
- **`order_status_history`**: Firestore doesn't retain a full status
  transition log, so each order gets a single seeded history row
  reflecting its *current* status only — not the full historical
  timeline.
- **`order_items` matching**: since legacy order items have no stable
  Firestore-level item id, reruns match existing rows by
  `(order_id, product_name, product_id)`. If a vendor sells two
  identical line items with the same product on the same order, a
  rerun may merge/update the wrong one — acceptable for a one-time
  backfill, but worth knowing.
- **Subcollection paths**: `addresses`, `wallet_transactions`,
  `kyc_documents`, `notifications`, `inventory_logs`, and
  `delivery_tracking` are read via `collectionGroup`, so they're
  picked up whether they live at the top level or nested under
  `users/*`, `products/*`, or `orders/*`. If your Firestore uses a
  different nesting, adjust the relevant `migrators/*.js` file's
  parent-id resolution.
