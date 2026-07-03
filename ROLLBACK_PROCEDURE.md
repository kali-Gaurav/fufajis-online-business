# Emergency Rollback Procedure

**Use this when:**
- Sync failures spike
- Inventory drift detected
- Payment issues arise
- Data corruption suspected

**Timeline:** 5-10 minutes to full rollback

---

# Scenario 1: Inventory Sync Failures

## Symptom
```
Firestore sync queue backlog growing
Dead letter jobs > 10
Inventory mismatch detected
```

## Immediate Action (< 1 minute)

**Step 1: Disable backend inventory API**
```bash
# SSH to Render backend
ssh render-backend.herokuapp.com

# Connect to PostgreSQL
psql $DATABASE_URL

# Disable feature flag
UPDATE feature_flags 
SET enabled = FALSE, enable_percentage = 0, updated_at = NOW()
WHERE flag_name = 'USE_BACKEND_INVENTORY_API';

# Verify disabled
SELECT flag_name, enabled, enable_percentage FROM feature_flags 
WHERE flag_name = 'USE_BACKEND_INVENTORY_API';
# Should show: enabled=FALSE, enable_percentage=0
```

**Step 2: Clear Firebase Remote Config (so Flutter clients get the flag update)**
```bash
# Clear cache (clients will refresh within 1 hour naturally)
# Or force update via Firebase Console:
# https://console.firebase.google.com/project/[PROJECT]/config
# → Edit "USE_BACKEND_INVENTORY_API" → Disabled
# → Publish
```

**Timeline:** ~30 seconds

## Verification (< 2 minutes)

**Step 3: Check that Flutter reverted to Firestore path**
```bash
# Monitor Flutter app logs
# Should see: "Using Firestore direct write path for inventory"

# Check Android Logcat (if available)
adb logcat | grep "inventory"
```

**Step 4: Verify dead letter queue stops growing**
```sql
-- Check every 30 seconds
SELECT status, COUNT(*) FROM sync_queue WHERE created_at > NOW() - INTERVAL '1 hour' GROUP BY status;

-- Should show: dead_letter count STABLE (not growing)
```

**Timeline:** ~2-3 minutes

## Recovery (< 30 minutes)

**Step 5: Investigate root cause**
```sql
-- What failed?
SELECT job_id, entity_id, last_error, attempt_count 
FROM sync_queue 
WHERE status = 'dead_letter' 
ORDER BY failed_at DESC 
LIMIT 20;

-- Example errors:
-- "Firestore quota exceeded" → Wait for quota reset
-- "Connection timeout" → Check network
-- "Permission denied" → Check Firebase credentials
```

**Step 6: Fix the issue**
```bash
# Example fixes:
# - Restart Firestore connector
# - Increase connection pool size
# - Check Firebase credentials expiry
# - Scale backend horizontally
```

**Step 7: Manual reconciliation (if needed)**
```sql
-- Trigger inventory reconciliation
SELECT * FROM reconcile_inventory();

-- This will:
-- 1. Compare PostgreSQL vs Firestore
-- 2. Auto-repair mismatches (PostgreSQL is authoritative)
-- 3. Log all repairs to audit_logs

-- Verify repair
SELECT COUNT(*) FROM audit_logs 
WHERE action = 'reconciliation_auto_repair' 
AND created_at > NOW() - INTERVAL '5 minutes';
```

---

# Scenario 2: Payment Verification Failures

## Symptom
```
Payment verification errors spiking
Razorpay signature validation failing
Orders stuck in "payment_pending" status
```

## Immediate Action (< 1 minute)

**Step 1: Disable backend payments API**
```sql
UPDATE feature_flags 
SET enabled = FALSE, enable_percentage = 0, updated_at = NOW()
WHERE flag_name = 'USE_BACKEND_PAYMENTS_API';
```

**Step 2: Verify in Firebase Console**
```
→ Remote Config
→ USE_BACKEND_PAYMENTS_API
→ Should show: Disabled (0%)
```

## Investigation

**Step 3: Check payment errors**
```sql
-- Find recent payment failures
SELECT
  p.id,
  p.order_id,
  p.gateway_payment_id,
  al.metadata
FROM payments p
JOIN audit_logs al ON al.entity_id = p.order_id
WHERE al.action LIKE 'fraud_attempt%'
  AND al.created_at > NOW() - INTERVAL '1 hour'
ORDER BY al.created_at DESC;

-- Likely issue: Razorpay credentials expired or wrong
```

**Step 4: Verify Razorpay credentials**
```bash
# Check environment variables
echo $RAZORPAY_KEY_ID
echo $RAZORPAY_KEY_SECRET

# If wrong/expired:
# 1. Go to Razorpay Dashboard
# 2. Copy new credentials
# 3. Update Render environment:
#    RAZORPAY_KEY_ID=<new key>
#    RAZORPAY_KEY_SECRET=<new secret>
# 4. Restart backend
```

## Recovery

**Step 5: Fix credentials, then re-enable gradually**
```sql
-- After fixing credentials:

-- Phase 1: Test with 5%
UPDATE feature_flags 
SET enabled = TRUE, enable_percentage = 5, updated_at = NOW()
WHERE flag_name = 'USE_BACKEND_PAYMENTS_API';

-- Monitor for 5 minutes
SELECT al.action, COUNT(*) FROM audit_logs al 
WHERE al.entity_type = 'payment' 
  AND al.created_at > NOW() - INTERVAL '5 minutes'
GROUP BY al.action;

-- If no fraud alerts after 5 min, expand to 50%
-- If fraud detected, rollback to 0%
```

---

# Scenario 3: Data Corruption Detected

## Symptom
```
Inventory negative: quantity < 0
Orders double-packed
Payment amounts mismatched
```

## Immediate Action (< 2 minutes)

**Step 1: Disable ALL commerce APIs (fail-safe)**
```sql
UPDATE feature_flags 
SET enabled = FALSE, enable_percentage = 0, updated_at = NOW()
WHERE flag_name LIKE 'USE_BACKEND_%_API';
```

**Step 2: Verify all flags disabled**
```sql
SELECT flag_name, enabled, enable_percentage 
FROM feature_flags 
WHERE flag_name LIKE 'USE_BACKEND_%_API';
-- All should show: enabled=FALSE
```

## Investigation

**Step 3: Find corrupted data**
```sql
-- Negative inventory
SELECT product_id, quantity FROM inventory WHERE quantity < 0;

-- Double-packed orders
SELECT order_id, COUNT(*) as pack_count 
FROM inventory_transactions 
WHERE reason = 'order_packed' 
GROUP BY order_id 
HAVING COUNT(*) > 1;

-- Mismatched payments
SELECT p.order_id, p.amount, o.total_amount 
FROM payments p 
JOIN orders o ON p.order_id = o.id 
WHERE p.amount != o.total_amount;
```

## Recovery (requires manual ops intervention)

**Step 4: Isolate the issue**
```sql
-- Find which transaction caused the problem
SELECT * FROM audit_logs 
WHERE entity_type IN ('inventory', 'order', 'payment')
  AND created_at > (NOW() - INTERVAL '1 hour')
ORDER BY created_at DESC 
LIMIT 50;

-- Identify the bad transaction
-- Example: order_pack at 2026-07-03 12:34:56
```

**Step 5: Rollback corrupted transaction (if possible)**
```sql
-- Example: Rollback invalid inventory deduction
BEGIN;

-- 1. Identify the bad inventory_transaction
SELECT * FROM inventory_transactions 
WHERE order_id = 'ord_corrupt' 
  AND reason = 'order_packed';

-- 2. Create reversal transaction
INSERT INTO inventory_transactions (
  product_id, quantity_change, reason, old_quantity, new_quantity, 
  order_id, created_by_user_id, created_at
)
SELECT
  product_id, 
  -quantity_change,  -- Reverse the change
  'corruption_recovery',
  new_quantity,  -- Was new, now old
  old_quantity,  -- Was old, now new
  order_id,
  'system',
  NOW()
FROM inventory_transactions
WHERE order_id = 'ord_corrupt' AND reason = 'order_packed'
LIMIT 1;

-- 3. Update inventory
UPDATE inventory SET quantity = (
  SELECT new_quantity FROM inventory_transactions
  WHERE order_id = 'ord_corrupt' 
    AND reason = 'corruption_recovery'
  LIMIT 1
) WHERE product_id = 'prod_X';

COMMIT;
```

**Step 6: Log incident**
```sql
INSERT INTO audit_logs (
  entity_type, entity_id, action, metadata, created_at
)
VALUES (
  'system', 'incident', 'data_corruption_recovery',
  '{"orders_affected": ["ord_corrupt"], "root_cause": "TBD", "recovery_time": "2026-07-03 13:45:00"}'::jsonb,
  NOW()
);
```

---

# Full Rollback Checklist

Use this for complete system rollback to Firestore-only mode:

```sql
-- Disable all backend commerce APIs
UPDATE feature_flags SET enabled = FALSE, enable_percentage = 0 
WHERE flag_name IN (
  'USE_BACKEND_INVENTORY_API',
  'USE_BACKEND_ORDERS_API',
  'USE_BACKEND_PAYMENTS_API'
);

-- Verify all disabled
SELECT flag_name, enabled, enable_percentage FROM feature_flags;

-- Stop all sync jobs (system will use old Firestore path)
UPDATE sync_queue SET status = 'cancelled' WHERE status IN ('pending', 'retry_pending');

-- Clear cache
SELECT pg_sleep(1);  -- Wait 1 second

-- Verify Flutter will revert
-- (clients check flags every 1 hour, or force refresh in app)
```

---

# Post-Rollback

## Verification Checklist
- [ ] All feature flags disabled
- [ ] Flutter app reverted to Firestore path
- [ ] No new sync errors
- [ ] No new audit log errors
- [ ] Inventory stable
- [ ] Orders stable
- [ ] Payments stable

## Communication
```
Notify team:
"Rolled back backend commerce APIs to diagnostic mode due to [REASON].
- Current: Firestore direct writes only
- Status: Stable
- ETA to re-enable: [TIME]
- Root cause: [INVESTIGATING]
```
```

## Root Cause Analysis
```markdown
# Incident Report: [DATE] [TIME] UTC

## What Happened
[Describe the issue]

## Timeline
- 12:34 - Issue detected
- 12:35 - Rollback initiated
- 12:40 - All systems stable

## Root Cause
[Investigation findings]

## Fix Applied
[What was changed]

## Prevention
[How to prevent recurrence]

## Re-enablement Plan
- Phase 1: 5% (datetime)
- Phase 2: 25% (datetime)
- Phase 3: 100% (datetime)
```

---

# Commands Reference

```bash
# Emergency disable all
psql $DATABASE_URL -c "UPDATE feature_flags SET enabled=FALSE, enable_percentage=0 WHERE enabled=TRUE;"

# Check current state
psql $DATABASE_URL -c "SELECT flag_name, enabled, enable_percentage FROM feature_flags;"

# Check DLQ
psql $DATABASE_URL -c "SELECT COUNT(*) FROM sync_queue WHERE status='dead_letter';"

# View recent errors
psql $DATABASE_URL -c "SELECT entity_type, action, COUNT(*) FROM audit_logs WHERE created_at > NOW() - INTERVAL '1 hour' GROUP BY entity_type, action ORDER BY count DESC;"

# Manual inventory reconciliation
psql $DATABASE_URL -c "SELECT * FROM reconcile_inventory();"

# Clear sync queue
psql $DATABASE_URL -c "UPDATE sync_queue SET status='cancelled' WHERE status IN ('pending', 'retry_pending');"
```

---

# Contact
- **Ops Lead:** [name]
- **Backend Lead:** [name]
- **On-Call:** [pagerduty link]

---

**Last Updated:** 2026-07-03
**Test Frequency:** Monthly
**Next Test:** 2026-08-03
