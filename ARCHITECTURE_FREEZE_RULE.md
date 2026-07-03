# Architecture Freeze Rule — Enforcement Policy

## Effective Date: July 2, 2026

---

# The Rule

### NO direct Firestore writes for critical business data.

**Critical data:**
- Products (catalog, pricing)
- Inventory (stock, levels, transactions)
- Orders (status, items, fulfillment)
- Payments (status, amounts, reconciliation)
- Refunds (requests, payouts, settlements)

**ALL writes must go through backend API.**

---

# Why This Matters

Currently:
- 50+ files write directly to Firestore
- No transaction safety
- No inventory locks
- No payment verification
- No audit trail

Result:
- ✗ Overselling possible
- ✗ Refund fraud possible
- ✗ Payment fraud possible
- ✗ Data inconsistency

---

# Implementation

## For Code Reviews

**Checklist before approving any PR:**

```
ARCHITECTURE COMPLIANCE CHECK
=================================

[ ] Does this touch products/inventory/orders/payments?
    
    If NO → Approve
    
    If YES → Check:
    
    [ ] Does NOT contain: FirebaseFirestore.instance.collection('products')
    [ ] Does NOT contain: FirebaseFirestore.instance.collection('inventory')
    [ ] Does NOT contain: FirebaseFirestore.instance.collection('orders')
    [ ] Does NOT contain: FirebaseFirestore.instance.collection('payments')
    [ ] Does NOT contain: firestore...update(...) on critical data
    
    [ ] ALL writes go through ApiClient or ApiRepository
    [ ] Business logic is in backend API, not client
    
    If any check fails → Request changes
```

---

## For Developers

**Before writing code:**

Ask: "Does this write critical business data?"

| Question | Answer | Action |
|----------|--------|--------|
| Write to products? | YES | Use API only |
| Write to inventory? | YES | Use API only |
| Write to orders? | YES | Use API only |
| Write to payments? | YES | Use API only |
| Write to chat? | YES | Firestore OK |
| Write to notifications? | YES | Firestore OK |

---

# Examples

## ❌ VIOLATES RULE

```dart
// DON'T DO THIS
await FirebaseFirestore.instance
    .collection('orders')
    .doc(orderId)
    .update({'status': 'packed'});
```

**Problem:** Direct Firestore write, no transaction safety.

---

## ✅ FOLLOWS RULE

```dart
// DO THIS INSTEAD
final result = await ApiClient.instance.post(
  '/admin/orders/$orderId/pack',
  {'items': items, 'employeeId': employeeId},
);
```

**Why:** Backend handles validation, locking, and consistency.

---

# What Happens If Rule Is Broken

1. **PR is blocked** — Code review fails
2. **Developer must refactor** — Use API instead
3. **No exceptions** — This applies to ALL pull requests
4. **Timeline:** Enforce immediately

---

# Grace Period: None

**Effective immediately.**

Any new violations must be fixed before merge.

---

# Monitoring

Track violations in:
```
VIOLATIONS.md (week 1)
VIOLATIONS.md (week 2)
VIOLATIONS.md (week 3)
```

Goal: Zero new violations.

---

# Architecture During Migration

During the 4-sprint migration:

```
Week 1-2:  Build backend APIs
Week 2-3:  Refactor critical screens
Week 3-4:  Refactor services
Week 4-5:  Validation
```

During this time:
- ✅ New code must follow rule
- ✅ Old code gradually fixed
- ✅ No mixed approaches
- ✅ Clear migration timeline

---

# Questions?

Ask in architecture-sync on Slack.

**This is not optional.** This rule protects the business.
