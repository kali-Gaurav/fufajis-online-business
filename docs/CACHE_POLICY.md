# Cache TTL & Eviction Policy

`CacheService` (`lib/services/cache_service.dart`) is a singleton with a
three-tier backing store, tried in order:

1. **Upstash Redis (REST API)** — primary, when `UPSTASH_REDIS_REST_URL`/
   `UPSTASH_REDIS_REST_TOKEN` (or `REDIS_REST_URL`/`REDIS_REST_TOKEN`) are
   configured and the ping/auth check passes. Wrapped in a
   `CircuitBreaker` (`UpstashRedis`, 3-failure threshold, 1-minute reset).
2. **Firestore (`cache` collection)** — fallback if Redis is unreachable or
   misconfigured.
3. **SharedPreferences (local, `cache_` prefix)** — final fallback if
   Firestore is also unreachable.

In addition, every read/write goes through an in-process **LRU memory
cache** (`LruMemoryCache`, capacity **500 entries**) for p99 latency — this
is the first tier checked on `get()` and is always populated on `set()`.

## TTL by key namespace

| Namespace | Key pattern | Default TTL | Rationale |
|---|---|---|---|
| Session | `session:<userId>` | 7 days | Matches typical "remember me" duration; refreshed on login. |
| Product | `product:<productId>` | 10 minutes | Short TTL to keep hot product reads fast while bounding staleness after price/stock edits. Explicitly invalidated via `invalidateProductCache()` on product update. |
| Cart | `cart:<userId>` | 30 days | Carts have no natural expiry from user behavior, but should not accumulate indefinitely in Firestore/local fallback. 30 days is long enough that no active shopper is affected; re-saved on every cart mutation so an active cart's TTL keeps renewing. Explicitly invalidated via `invalidateCart()` on checkout. |
| OTP | `otp:<identifier>` | 5 minutes | Standard OTP validity window (task #33 — moved from in-memory to Redis/cache_service). |
| Rate limit | `ratelimit:<key>` | window-defined (default 60s) | Counter expires at the end of its rate-limit window (`checkRateLimit`/`incrementRateLimit`). |
| Generic / Redis-native TTL | `_setWithTtl(key, value, ttlSeconds)` | caller-specified | On Redis, uses native `SET ... EX`. On the Firestore/local fallback tiers, an `_exp` sidecar key (`<key>_exp`) stores the expiry epoch (ms), checked lazily by `_getWithTtl()` — expired entries are deleted on next read. |
| Untimed (`set`/`get`) | any other key | none (persists until `remove`/`clearAll`) | Used only for data with an explicit lifecycle managed elsewhere (e.g. one-off pings). New call sites should prefer `_setWithTtl`/a dedicated helper with an explicit TTL rather than bare `set`. |

## Eviction policy

- **Memory tier (LRU, capacity 500):** least-recently-used eviction is
  automatic via `LruMemoryCache`. No TTL at this tier — entries are evicted
  purely by capacity pressure or explicit `remove`/`clearAll`. Safe because
  it's a read-through cache backed by the durable tiers below.
- **Redis tier:** TTL-bearing keys (`session:*`, `product:*`, `cart:*`,
  `otp:*`, `ratelimit:*`) expire natively via `EX`. Untimed keys persist
  until removed.
- **Firestore/local fallback tiers:** TTL is enforced lazily via the
  `<key>_exp` sidecar pattern — there is no background sweep. An expired
  key is only cleaned up the next time it's read via `_getWithTtl`. This is
  acceptable for session/product/cart/OTP data (read-heavy, self-cleaning on
  access) but means **stale `_exp` sidecars can accumulate in Firestore's
  `cache` collection** if a key is written once and never read again (e.g.
  an abandoned cart). `clearAll()` removes all `cache_*` local keys and all
  documents in the Firestore `cache` collection — use this for a full reset,
  not for routine eviction.
- **Explicit invalidation:** `invalidateSession`, `invalidateProductCache`,
  and `invalidateCart` remove both the value and its `_exp` sidecar
  immediately, and should be called whenever the underlying data changes
  (login/logout, product edit, checkout) rather than waiting on TTL expiry.

## Adding a new cached value

1. Pick a namespaced key pattern: `"<namespace>:<id>"`.
2. If the value should expire, use `_setWithTtl`/`_getWithTtl` with an
   explicit TTL constant (add it as a named default parameter, following
   the pattern of `cacheProduct`/`storeOTP`/`saveCart`).
3. Add an `invalidate<Thing>()` helper that removes both `<key>` and
   `<key>_exp`, and call it from whatever write path makes the cached value
   stale.
4. Document the new namespace/TTL in the table above.
