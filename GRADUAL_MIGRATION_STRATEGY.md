# Gradual Migration Strategy — Firestore to Backend API

**Problem:** 
Current Flutter app writes directly to Firestore.
New backend expects API calls to PostgreSQL first.

If we flip the switch all at once:
- Old clients still write to Firestore
- New backend ignores Firestore
- Data diverges

**Solution:** Feature flags + gradual rollout

---

# Architecture

## Feature Flags (in PostgreSQL)

```sql
CREATE TABLE IF NOT EXISTS feature_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  flag_name VARCHAR(100) NOT NULL UNIQUE,
  enabled BOOLEAN DEFAULT FALSE,
  enable_percentage INT DEFAULT 0,  -- 0-100% rollout
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO feature_flags (flag_name, enabled, enable_percentage) VALUES
  ('BACKEND_COMMERCE_ENABLED', FALSE, 0),        -- Master flag
  ('USE_BACKEND_INVENTORY_API', FALSE, 0),       -- Inventory writes
  ('USE_BACKEND_ORDERS_API', FALSE, 0),          -- Order writes
  ('USE_BACKEND_PAYMENTS_API', FALSE, 0),        -- Payment writes
  ('DISABLE_FIRESTORE_DIRECT_WRITES', FALSE, 0);  -- Final kill switch
```

## Backend Feature Flag Service

**File:** `backend/src/services/feature-flags.js`

```javascript
const { db } = require('../db');

const flagCache = {}; // In-memory cache with TTL

async function isFeatureFlagEnabled(flagName, userId) {
  // Check cache first
  if (flagCache[flagName] && flagCache[flagName].expiresAt > Date.now()) {
    return flagCache[flagName].enabled;
  }

  // Query database
  const result = await db.query(
    `SELECT enabled, enable_percentage FROM feature_flags WHERE flag_name = $1`,
    [flagName]
  );

  if (result.rows.length === 0) {
    return false;
  }

  const { enabled, enable_percentage } = result.rows[0];

  if (!enabled) {
    return false;
  }

  // Percentage rollout (based on user ID hash)
  if (enable_percentage < 100) {
    const hash = userId.split('').reduce((h, c) => h + c.charCodeAt(0), 0);
    const userPercentage = hash % 100;
    return userPercentage < enable_percentage;
  }

  return true;
}

async function enableFeatureFlag(flagName, enablePercentage = 100) {
  await db.query(
    `UPDATE feature_flags SET enabled = TRUE, enable_percentage = $1, updated_at = NOW() WHERE flag_name = $2`,
    [enablePercentage, flagName]
  );

  // Clear cache
  delete flagCache[flagName];
}

module.exports = {
  isFeatureFlagEnabled,
  enableFeatureFlag,
};
```

---

# Rollout Timeline

## Phase 0 (Week 0): Deploy infrastructure
- ✅ Create backend APIs (inventory, orders, payments)
- ✅ Create feature flag table + service
- Deploy new backend code
- Feature flags all disabled (0%)

**Status:** Old and new stack coexist
- Flutter app: writes to Firestore directly
- Backend: APIs exist but unused
- No conflicts

---

## Phase 1 (Week 1): Test new backend
**Goal:** Validate backend with limited traffic

```sql
UPDATE feature_flags 
SET enabled = TRUE, enable_percentage = 10 
WHERE flag_name = 'USE_BACKEND_INVENTORY_API';
```

**What happens:**
- 10% of users' inventory adjustments go through backend API
- 90% still go to Firestore directly
- Backend writes to PostgreSQL → syncs to Firestore

**Monitoring:**
- Compare inventory accuracy: backend vs Firestore
- Check sync success rate
- Monitor error rates

**If successful:** Increase to 25%
**If problems:** Rollback to 0%

---

## Phase 2 (Week 2): Orders rollout
```sql
UPDATE feature_flags 
SET enabled = TRUE, enable_percentage = 50 
WHERE flag_name = 'USE_BACKEND_ORDERS_API';
```

**What happens:**
- 50% of packing operations use new backend
- Prevents double-packing via atomic transactions
- Orders still sync to Firestore for UI

**If successful:** Increase to 100%

---

## Phase 3 (Week 3): Payments rollout
```sql
UPDATE feature_flags 
SET enabled = TRUE, enable_percentage = 100 
WHERE flag_name = 'USE_BACKEND_PAYMENTS_API';
```

**What happens:**
- All payment verifications go through backend
- Razorpay signature validation enforced
- Zero payment fraud risk

---

## Phase 4 (Week 4): Kill Firestore direct writes
```sql
UPDATE feature_flags 
SET enabled = TRUE 
WHERE flag_name = 'DISABLE_FIRESTORE_DIRECT_WRITES';
```

**What happens:**
- Old code path blocked
- Only backend API writes allowed
- Firestore becomes pure cache

---

# Flutter Implementation

## Old way (before feature flags)
```dart
// DIRECT FIRESTORE WRITE
await firestore.collection('inventory').update({
  'productId': id,
  'quantity': newStock,
});
```

## New way (with feature flags)
```dart
// CHECK FLAG
final useBackendAPI = await remoteConfig.getBool('USE_BACKEND_INVENTORY_API');

if (useBackendAPI) {
  // NEW: API call
  final result = await api.post(
    '/admin/inventory/adjust',
    {'productId': id, 'quantity': change, 'reason': 'order_packed'}
  );
} else {
  // OLD: Firestore direct write
  await firestore.collection('inventory').update({
    'productId': id,
    'quantity': newStock,
  });
}
```

## Firebase Remote Config setup
```javascript
// In Flutter app: pubspec.yaml
firebase_remote_config: ^4.0.0

// In Dart:
final remoteConfig = FirebaseRemoteConfig.instance;
await remoteConfig.fetchAndActivate();

final flag = remoteConfig.getBool('USE_BACKEND_INVENTORY_API');
```

---

# Safe rollback strategy

At ANY point during migration, you can rollback:

```sql
-- Disable backend API
UPDATE feature_flags 
SET enabled = FALSE, enable_percentage = 0 
WHERE flag_name = 'USE_BACKEND_INVENTORY_API';

-- All traffic goes back to Firestore direct writes
```

**Recovery time:** ~5 minutes (after Flutter app refreshes config)

---

# Monitoring during migration

## Inventory accuracy check
```sql
-- Compare PostgreSQL inventory vs Firestore inventory
SELECT 
  p.id,
  inv.quantity as postgres_stock,
  fs.quantity as firestore_stock,
  ABS(inv.quantity - CAST(fs.quantity AS INT)) as divergence
FROM inventory inv
JOIN products p ON inv.product_id = p.id
LEFT JOIN firestore_view fs ON fs.product_id = p.id
WHERE ABS(inv.quantity - CAST(fs.quantity AS INT)) > 0
ORDER BY divergence DESC;
```

## Sync queue health
```sql
-- Check dead letter jobs
SELECT COUNT(*) as dead_letter_count FROM sync_queue WHERE status = 'dead_letter';

-- Check pending retries
SELECT COUNT(*) as pending_count FROM sync_queue WHERE status = 'retry_pending';
```

## Payment verification
```sql
-- Verify all payments are signed
SELECT COUNT(*) as unverified_count 
FROM payments 
WHERE signature_verified = FALSE;
```

---

# Success Criteria

✅ **Phase 1 (10%):**
- Inventory divergence < 0.1%
- Sync success rate > 99%
- No payment fraud attempts

✅ **Phase 2 (50%):**
- Zero overselling incidents
- Zero double-packing
- Order status matches Firestore

✅ **Phase 3 (100%):**
- All payments verified via backend
- Zero payment fraud
- Zero refund fraud

✅ **Phase 4 (Firestore kill):**
- Zero direct Firestore writes from critical screens
- All data flows through backend first
- Firestore is pure read-through cache

---

# Failure scenarios & recovery

### Scenario 1: Sync queue backlog
```
Event: Firestore sync fails for 10+ minutes
Impact: Data divergence (backend correct, UI stale)
Recovery: 
  1. Pause feature flag (100% rollback to Firestore direct)
  2. Investigate sync failure
  3. Manually retry dead letter jobs
  4. Re-enable flag at 10%
```

### Scenario 2: Payment fraud detected
```
Event: Signature spoofing attempt detected
Impact: Fraudulent payment recorded
Recovery:
  1. Disable BACKEND_PAYMENTS_API flag
  2. Audit all payments from phase
  3. Refund fraudulent transactions
  4. Fix backend code
  5. Re-enable at 10%
```

### Scenario 3: Inventory oversell (backend bug)
```
Event: 2 employees pack same item, stock goes negative
Impact: Negative inventory
Recovery:
  1. Disable BACKEND_ORDERS_API flag
  2. Rollback bad transactions
  3. Fix locking bug in backend
  4. Re-enable at 10%
```

---

# End state

After Phase 4:
- ✅ All commerce data writes through backend
- ✅ PostgreSQL is source of truth
- ✅ Firestore is cache (synced eventually)
- ✅ Flutter reads from Firestore cache
- ✅ Complete audit trail for all actions
- ✅ Zero fraud risk
- ✅ Zero overselling risk
- ✅ Atomic transactions guarantee consistency

**Result:** Fufaji is now production-grade e-commerce platform.

---

# Commands for ops/admins

```sql
-- Enable inventory API for 10% users
UPDATE feature_flags 
SET enabled = TRUE, enable_percentage = 10, updated_at = NOW()
WHERE flag_name = 'USE_BACKEND_INVENTORY_API';

-- Enable orders API for 50% users
UPDATE feature_flags 
SET enabled = TRUE, enable_percentage = 50, updated_at = NOW()
WHERE flag_name = 'USE_BACKEND_ORDERS_API';

-- Enable payments API for 100% users
UPDATE feature_flags 
SET enabled = TRUE, enable_percentage = 100, updated_at = NOW()
WHERE flag_name = 'USE_BACKEND_PAYMENTS_API';

-- Disable all feature flags (full rollback)
UPDATE feature_flags 
SET enabled = FALSE, enable_percentage = 0, updated_at = NOW();

-- Check current flag state
SELECT flag_name, enabled, enable_percentage, updated_at 
FROM feature_flags 
ORDER BY updated_at DESC;

-- Check sync queue health
SELECT status, COUNT(*) as count FROM sync_queue GROUP BY status;
```
