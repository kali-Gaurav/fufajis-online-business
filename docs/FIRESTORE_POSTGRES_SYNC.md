# Firestore → Postgres Streaming Sync

This document describes `functions/firestore_sync.js`, which keeps the
Supabase/RDS Postgres database (see [docs/POSTGRES_SCHEMA.md](POSTGRES_SCHEMA.md))
in near-real-time sync with Firestore, the system of record for realtime app
state. It complements, but does not replace, the one-time historical backfill
in `scripts/migration/migrate.js` (see `docs/MIGRATION_RUNBOOK.md`, task #29).

## Why both a backfill script *and* streaming triggers?

| | `scripts/migration/migrate.js` | `functions/firestore_sync.js` |
|---|---|---|
| Trigger | Manual, operator-run | Automatic, on every Firestore write |
| Scope | All historical documents, paged | One document at a time |
| Use case | Initial cutover, periodic full reconciliation | Ongoing, low-latency sync |
| Idempotency | `ON CONFLICT (firestore_id\|firebase_uid) DO UPDATE` | Same — both use the identical conflict keys, so they're safe to run together |

Both paths converge on the same Postgres rows via the same conflict columns
(`firestore_id` for most tables, `firebase_uid` for `users`), so the backfill
can always be re-run (e.g. nightly) as a reconciliation safety net without
fighting the streaming triggers — last write wins, and both sources are
deriving from the same Firestore documents.

## Architecture

```mermaid
flowchart LR
    subgraph Firestore
        U[users/{uid}]
        C[categories/{id}]
        P[products/{id}]
        A["users/{uid}/addresses/{id}"]
        O[orders/{id}]
    end

    subgraph "Cloud Functions (firestore_sync.js)"
        SU[syncUserToPostgres]
        SC[syncCategoryToPostgres]
        SP[syncProductToPostgres]
        SA[syncAddressToPostgres]
        SO[syncOrderToPostgres]
    end

    PG[(Postgres: users, categories,\nproducts, addresses, orders,\norder_items, order_status_history)]

    U -- onWrite --> SU --> PG
    C -- onWrite --> SC --> PG
    P -- onWrite --> SP --> PG
    A -- onWrite (collection group) --> SA --> PG
    O -- onWrite --> SO --> PG

    SU -. resolveId .-> PG
    SP -. resolveId(vendor,category) .-> PG
    SA -. resolveId(user) .-> PG
    SO -. resolveId(user,vendor,driver,address,product) .-> PG
```

Each trigger:
1. Reads the changed document (`change.after`).
2. Maps Firestore field names to Postgres columns, reusing the exact same
   field-aliasing conventions as the corresponding `scripts/migration/migrators/*.js`
   file (e.g. `vendorId`/`vendor_id`/`ownerId` all map to `products.vendor_id`).
3. Resolves any foreign keys (`vendor_id`, `category_id`, `user_id`, etc.) by
   looking up the referenced row's Postgres `id` via its `firestore_id` /
   `firebase_uid`.
4. Upserts via `ON CONFLICT (<conflict column>) DO UPDATE` (`sync_transform.js#pgUpsert`).
5. On document delete, soft-deletes (`is_active = false` / `active = false`)
   for `users`, `categories`, `products`; hard-deletes for `addresses`
   (no soft-delete column, and addresses have no downstream FK dependents
   once an order references them by `address_id`, which is preserved).

## Collection → table map

| Firestore path | Postgres table | Conflict column | Notes |
|---|---|---|---|
| `users/{uid}` | `users` | `firebase_uid` | Soft-delete on doc delete (`is_active = false`). |
| `categories/{id}` | `categories` | `firestore_id` | `parent_id` resolved via `categories.firestore_id`; if the parent hasn't synced yet, `parent_id` is left `null` and will self-heal on the parent's own write (or via `migrate.js --only=categories` reconciliation). |
| `products/{id}` | `products` | `firestore_id` | `vendor_id`/`category_id` resolved via `users`/`categories`. **Does not write `inventory`/`change_requests`/`inventory_events`** — those remain governed exclusively by the Phase 13 approval flow (tasks #116-122); this trigger only mirrors the `products.stock_quantity` snapshot that Firestore already holds. |
| `users/{uid}/addresses/{id}` | `addresses` | `firestore_id` | Collection-group style path (per-user subcollection). Skips (logs a warning) if the parent user hasn't synced yet — self-heals on next address write or via backfill. |
| `orders/{id}` | `orders` + `order_items` + `order_status_history` | `firestore_id` (orders) | `user_id`/`vendor_id`/`driver_id`/`address_id` resolved via `users`/`addresses`. `order_items` are replaced wholesale on every write (delete-then-reinsert) since Firestore embeds the full item array. `order_status_history` gets a new row only when `order_status` actually changes between `before` and `after`. |

## Ordering, idempotency, and retries

- **Idempotency**: every upsert is keyed on a stable identifier
  (`firestore_id` or `firebase_uid`), so duplicate or out-of-order delivery
  (Cloud Functions v1 triggers do not guarantee exactly-once or in-order
  delivery) converges to the same final row — Postgres ends up reflecting
  whichever Firestore write was *processed last*, not necessarily the one
  that happened last in wall-clock time. For the fields synced here
  (catalog/profile/order snapshot data, not financial ledgers), eventual
  consistency is acceptable.
- **Out-of-order FK resolution**: if a `product` write arrives before its
  `vendor`'s first `user` sync, `vendor_id` is simply left `null` for that
  pass. The next time either document is written, `resolveId` will find the
  now-synced row and fill it in. For a cold-start (first-ever sync), run
  `node scripts/migration/migrate.js` once to seed all tables in
  dependency order (`users` → `categories` → `products`/`addresses` →
  `orders`), after which the streaming triggers keep things current.
- **Errors**: each trigger returns a resolved promise (`return null`) even
  on partial failure inside `order_items`/`order_status_history` (caught,
  logged, transaction rolled back) so Cloud Functions doesn't endlessly
  retry a doc that will never map cleanly — failures are visible in
  Cloud Functions logs / `docs/...` debugging per
  [Twilio debugging skill pattern], and can be re-driven via
  `migrate.js --only=<name>` if a doc is stuck.
- **Financial fields**: `wallet_transactions`, `inventory_events`, and
  `change_requests` are **not** synced by this module — they are written
  directly by their owning services (`audit_service.dart` dual-write,
  `InventoryChangeRequestService`, `OrderWorkflowEngine`) which already
  write Postgres and Firestore together inside the same business
  transaction. Streaming-syncing them here would risk double-writes or
  racing the authoritative write path.

## Cold start / reconnect

`getPgPool()` (in `aws_services.js`, now exported for reuse) lazily creates a
`pg.Pool` with `max: 3` on first use per function instance. Each of the five
triggers in `firestore_sync.js` shares this same pool/module cache within a
warm instance, so steady-state connection usage stays bounded even under
concurrent writes across collections.

## Adding a new synced collection

1. Add a `functions.firestore.document('<collection>/{id}').onWrite(...)`
   export in `firestore_sync.js`, following the existing pattern: map fields
   with `sync_transform.js` helpers, resolve FKs via `resolveId`, then
   `pgUpsert`.
2. Add a corresponding entry to the collection → table map above and to
   [docs/POSTGRES_SCHEMA.md](POSTGRES_SCHEMA.md) if it's a new table.
3. If the collection should also be covered by the historical backfill, add
   a matching migrator under `scripts/migration/migrators/`.
4. Register the export in `functions/index.js` (already done automatically
   via `Object.assign(exports, require('./firestore_sync'))`).
