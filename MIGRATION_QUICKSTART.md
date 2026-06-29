# Packing Migration - Quick Start

**Problem**: Delivery can't find packed orders (2 disconnected collections)  
**Solution**: Consolidate into single `fulfillment_tasks` collection  
**Time**: 5-10 minutes (+ validation)

---

## 3-STEP PROCESS

### STEP 1: DRY RUN (Test without changes)

```dart
import 'package:fufaji_online_business/migrations/run_packing_migration.dart';

void main() async {
  // Test migration without making changes
  await PackingMigrationRunner.runFullMigration(dryRun: true);
}
```

**Expected output**:
```
[STEP 1] Migrating fulfillment_tasks_v2 → fulfillment_tasks
  Success: true
  Migrated: 42
  Skipped: 0
  Errors: 0

[STEP 2] Validating migration results
  Valid: true
  Total Orders: 42
  Valid Tasks: 42
  Missing Tasks: 0
```

### STEP 2: ACTUAL MIGRATION (Keep v2 for safety)

Once dry run passes, run the actual migration:

```dart
void main() async {
  // Migrate but keep v2 for safety (can rollback)
  await PackingMigrationRunner.runFullMigration(deleteV2OnSuccess: false);
}
```

**Expected output**: Same as dry run, but data is now migrated.

### STEP 3: VALIDATE & DELETE (Optional cleanup)

After 7 days of monitoring:

```dart
void main() async {
  // Migrate and delete v2 (final cleanup)
  await PackingMigrationRunner.runFullMigration(deleteV2OnSuccess: true);
}
```

---

## DETAILED WALKTHROUGH

### Prerequisites
- Firebase initialized
- Cloud Firestore accessible  
- Sufficient Firestore quota (~10 write ops per task)

### Step 1: Import the runner

```dart
import 'package:fufaji_online_business/migrations/run_packing_migration.dart';
```

### Step 2: Run the migration

```dart
void main() async {
  try {
    // Option A: Dry run (no changes)
    await PackingMigrationRunner.runFullMigration(dryRun: true);

    // Option B: Actual migration (keep v2)
    // await PackingMigrationRunner.runFullMigration(deleteV2OnSuccess: false);

    // Option C: Full migration (delete v2)
    // await PackingMigrationRunner.runFullMigration(deleteV2OnSuccess: true);
  } catch (e) {
    print('Migration failed: $e');
  }
}
```

### Step 3: Check the output

Look for these indicators:

**✓ Success**:
```
[STEP 1] Migrating...
  Success: true
  Migrated: N (where N > 0)
  Errors: 0

[STEP 2] Validating...
  Valid: true
  Missing Tasks: 0
```

**✗ Failure**:
```
[STEP 1] Migrating...
  Success: false
  Errors: 1
  
Errors:
  - Task abc123: Permission denied
```

---

## COMMON SCENARIOS

### Scenario 1: No V2 Tasks (Already Migrated)

```
[STEP 1] Migrating fulfillment_tasks_v2 → fulfillment_tasks
  Migrated: 0
  Skipped: 0
  Message: No v2 tasks found - exiting cleanly
```

**Action**: No migration needed. You're good to go.

---

### Scenario 2: Some Tasks Already Migrated

```
[STEP 1] Migrating fulfillment_tasks_v2 → fulfillment_tasks
  Migrated: 10
  Skipped: 5
  Message: Migration complete: 10 migrated, 5 skipped, 0 errors
```

**Action**: Safe to run again. Skipped tasks won't be re-migrated.

---

### Scenario 3: Migration Errors

```
[STEP 1] Migrating fulfillment_tasks_v2 → fulfillment_tasks
  Migrated: 5
  Skipped: 0
  Errors: 2
  
Errors:
  - Task xyz001: Firestore permission denied
  - Task xyz002: Invalid data structure
```

**Action**: 
1. Check Firestore rules (permissions)
2. Inspect the problematic tasks in console
3. Fix root cause
4. Re-run migration (safe to retry)

---

### Scenario 4: Validation Fails

```
[STEP 2] Validating migration results
  Valid: false
  Missing Tasks: 2
  
Missing Order IDs:
  - order_abc123
  - order_def456
```

**Action**:
1. Check order `order_abc123` in console
2. Verify `fulfillmentTaskId` is present
3. Check if task was migrated to `fulfillment_tasks`
4. Investigate why it wasn't found

---

## MONITORING CHECKLIST

After running the migration:

- [ ] Check Firestore quota usage (shouldn't spike)
- [ ] Monitor CloudFunctions logs (no errors)
- [ ] Test delivery task creation (should work)
- [ ] Run a test order through packing workflow
- [ ] Verify no orders stuck in "packed" status
- [ ] Check that new orders use unified collection

---

## TROUBLESHOOTING

### Problem: "Firestore permission denied"

**Cause**: User doesn't have Firestore access  
**Solution**: 
1. Check you're logged in to the correct Firebase project
2. Verify Firestore security rules allow the operation
3. Consider running as admin/cloud function

### Problem: "Migration timeout"

**Cause**: Too many documents, network issues  
**Solution**:
1. Check internet connection
2. Increase Firestore quota
3. Run again (migration will resume from where it stopped)

### Problem: "Validation failed - missing tasks"

**Cause**: Tasks weren't migrated correctly  
**Solution**:
1. Check Firestore console for broken data
2. Restore from backup
3. Fix root cause in migration service
4. Re-run migration

### Problem: "Can't delete v2 collection"

**Cause**: Permission or data structure issues  
**Solution**:
1. Manually delete via Firestore console
2. Or wait and retry later
3. Not critical - v2 is disabled anyway

---

## QUICK TEST

After migration, verify everything works:

```dart
void test() async {
  // 1. Create a test order & packing task
  final packing = PackingWorkflowService();
  final task = await packing.createFulfillmentTask(
    orderId: 'test_order_123',
    shopId: 'test_shop_123',
    branchId: 'test_branch_123',
    items: [
      {
        'id': 'item_1',
        'productId': 'prod_123',
        'productName': 'Test Product',
        'quantity': 1,
      }
    ],
  );
  
  print('Created task: ${task['id']}');
  assert(task['status'] == 'new');
  
  // 2. Run through workflow
  await packing.assignToEmployee(
    taskId: task['id'],
    employeeId: 'emp_test_123',
    employeeName: 'Test Employee',
  );
  
  await packing.markItemPicked(
    taskId: task['id'],
    itemId: 'item_1',
    quantity: 1,
  );
  
  await packing.requestQualityCheck(task['id']);
  
  await packing.verifyItems(
    taskId: task['id'],
    verifiedBy: 'qc_test_123',
  );
  
  await packing.markCompleted(task['id']);
  
  // 3. Verify everything
  final completed = await packing.getTask(task['id']);
  print('Final status: ${completed['status']}');
  assert(completed['status'] == 'completed');
  
  print('✓ Packing workflow works correctly');
}
```

---

## WHEN TO RUN

### Recommended Timing
- During low-traffic period (early morning)
- After backing up Firestore
- With team on standby for monitoring
- On a Thursday (gives weekend to recover if issues)

### Can you run it during business hours?
- **Yes**, but monitor closely
- No downtime required for migration
- Packing operations can continue
- Recommend monitoring for 24h post-migration

---

## NEXT STEPS

1. **Run migration** (dry run first)
2. **Monitor** CloudFunctions logs for 24h
3. **Validate** delivery task creation
4. **Check** no orders stuck in "packed"
5. **Wait** 7 days (for safety)
6. **Delete** v2 collection

---

## SUPPORT

If you hit issues:

1. **Check logs**: CloudFunctions / Firestore console
2. **Read**: `PACKING_CONSOLIDATION_P0_FIX.md`
3. **Inspect**: Data in Firestore console
4. **Rollback**: Restore from backup if needed
5. **Retry**: Migration is safe to run again

---

## FILE REFERENCE

```
lib/migrations/run_packing_migration.dart
  ├─ PackingMigrationRunner.runFullMigration()
  └─ PackingMigrationRunner.validateOnly()

lib/services/packing_migration_service.dart
  ├─ migrateTasksV2ToUnified()
  ├─ validateMigration()
  ├─ deleteV2Collection()
  └─ completeMigration()
```

---

**Time to Complete**: 5-10 minutes (+ 24h monitoring)  
**Risk Level**: LOW (migration is idempotent)  
**Impact**: CRITICAL (fixes order delivery)  

🚀 **Ready to run?** See STEP 1 above!
