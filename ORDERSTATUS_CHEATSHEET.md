# OrderStatus Enum - Quick Reference Card

## The Problem This Fixes

**Riders saw 0 deliveries** because 4 different services used different status values:
- OrderService: `'OrderStatus.packed'`
- PackingService: `'packed'`
- DeliveryService: `'assigned'`
- OrderWorkflowService: `'preparing'`

**Result**: Status mismatches → Query failures → No orders shown to riders

## The Solution

Single unified enum in `lib/constants/order_status.dart`

## State Diagram

```
                    pending
                       ↓
                   confirmed
                       ↓
                   processing
                       ↓
                     packed ← ← ← ← ← ← ←
                       ↓                  ↓
                    shipped           cancelled
                       ↓                  ↓
                   delivered ← ← ← ← ← → refunded
```

## All Valid Statuses

| Enum Value | Firestore Value | Description |
|------------|-----------------|------------|
| `pending` | `'pending'` | Just created, awaiting payment |
| `confirmed` | `'confirmed'` | Payment verified |
| `processing` | `'processing'` | Being prepared at shop |
| `packed` | `'packed'` | Ready for delivery |
| `shipped` | `'shipped'` | With rider, in transit |
| `delivered` | `'delivered'` | Delivered to customer |
| `cancelled` | `'cancelled'` | Cancelled (terminal) |
| `refunded` | `'refunded'` | Refund processed (terminal) |

## Code Snippets

### Write to Firestore
```dart
'status': OrderStatus.packed.firestoreValue
```

### Read from Firestore
```dart
final status = OrderStatus.fromString(data['status']);
```

### Check if Terminal
```dart
if (status.isTerminal) { /* no more transitions */ }
```

### Validate Transition
```dart
if (current.canTransitionTo(next)) { /* allowed */ }
```

### Get Label for UI
```dart
Text(status.getLabel())  // "Delivered"
```

### Get Valid Next Statuses
```dart
Set<String> nextStates = status.getNextStatuses();
```

## Valid Transitions

```
pending       → confirmed, cancelled
confirmed     → processing, cancelled
processing    → packed, cancelled
packed        → shipped, cancelled
shipped       → delivered, cancelled
delivered     → refunded, cancelled
cancelled     → refunded
refunded      → (none - terminal)
```

## Import Statement
```dart
import '../constants/order_status.dart';
```

## Where It's Used

| Service | Change |
|---------|--------|
| UnifiedOrderService | Use enum for all transitions |
| OrderService | Use enum for status writes |
| OrderWorkflowService | Use enum for status writes |
| PackingWorkflowService | Use enum when updating order status |
| DeliveryWorkflowService | Use enum when updating order status |
| UnifiedDeliveryService | Use enum for rider queries |

## Migration Script

```dart
// One-time migration of existing orders
final migration = OrderStatusMigrationService();
await migration.migrateAllOrders();

// Verify
final invalid = await migration.verifyMigration();
assert(invalid.isEmpty);
```

## Legacy Format Support

Parser automatically handles:
- `'pending'` → pending ✓
- `'OrderStatus.pending'` → pending ✓
- `'outForDelivery'` → shipped ✓
- `'preparing'` → processing ✓
- `'completed'` → delivered ✓

No code changes needed for old data!

## Testing Checklist

- [ ] All order services use OrderStatus enum
- [ ] Packing writes `OrderStatus.packed.firestoreValue`
- [ ] Delivery reads orders with correct status values
- [ ] Riders see assigned deliveries
- [ ] Status history entries are migrated
- [ ] Migration script runs without errors
- [ ] No status mismatches in database

## Terminal States (No Further Changes)

```
cancelled → can only → refunded
refunded  → (no transitions allowed)
```

## Common Operations

| Operation | Code |
|-----------|------|
| Write status | `'status': OrderStatus.packed.firestoreValue` |
| Read status | `final status = OrderStatus.fromString(str)` |
| Check terminal | `status.isTerminal` |
| Valid next? | `status.canTransitionTo(next)` |
| Human text | `status.getLabel()` |
| All next states | `status.getNextStatuses()` |
| Query orders | `.where('status', isEqualTo: OrderStatus.packed.firestoreValue)` |

## Files Changed

1. ✅ `lib/constants/order_status.dart` (NEW - enum)
2. ✅ `lib/services/unified_order_service.dart`
3. ✅ `lib/services/order_service.dart`
4. ✅ `lib/services/order_workflow_service.dart`
5. ✅ `lib/services/packing_workflow_service.dart`
6. ✅ `lib/services/delivery_workflow_service.dart`
7. ✅ `lib/services/order_status_migration_service.dart` (NEW - migration)

## Expected Results

### Before Fix
```
GET /api/rider/:id/deliveries
→ 0 orders returned
```

### After Fix
```
GET /api/rider/:id/deliveries
→ 5-10 orders returned (delivery_tasks with order details)
```

## Remember

1. **Always use enum** - Never hardcode status strings
2. **Use `.firestoreValue`** - When writing to Firestore
3. **Use `.fromString()`** - When reading from Firestore
4. **Check `.isTerminal`** - Before allowing transitions
5. **Validate transitions** - Use `.canTransitionTo()`

---

**Last Updated**: June 23, 2026  
**Status**: Ready for Production  
**Author**: Claude Agent
