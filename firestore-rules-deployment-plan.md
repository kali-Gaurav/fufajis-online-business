# Firestore Rules Deployment Plan - DAY 2 (June 25)

## Overview
Deploy comprehensive Firestore security rules to production covering all 26+ collections in the Fufaji system.

**Current Status:**
- Comprehensive rules already written in `firestore.rules` (611 lines)
- Second comprehensive ruleset in `FIRESTORE_RULES_PRODUCTION.rules` (428 lines)
- `firebase.json` configured to deploy `firestore.rules` as the production rules

**Collections Covered:** 45+ collections with role-based access control

---

## Step 1: Collections Audit

Current firestore.rules covers these collections:

### Core Business (15 collections)
- [ ] users (+ wallet, notifications subcollections)
- [ ] customer_wallet
- [ ] owners
- [ ] employees
- [ ] orders (+ subcollections)
- [ ] products
- [ ] coupons
- [ ] inventory
- [ ] inventory_events
- [ ] delivery_tasks
- [ ] delivery_batches
- [ ] deliveries (legacy, deprecated)
- [ ] payments
- [ ] refunds
- [ ] returns

### Delivery Support (10+ deprecated collections consolidating into delivery_tasks)
- [ ] delivery_agents
- [ ] delivery_assignments
- [ ] delivery_otp
- [ ] delivery_locations
- [ ] delivery_tracking
- [ ] delivery_routes
- [ ] delivery_status
- [ ] delivery_history
- [ ] delivery_notifications
- [ ] delivery_preferences
- [ ] delivery_events
- [ ] delivery_exceptions
- [ ] delivery_sla_rules
- [ ] delivery_slots

### Operations & Admin (15 collections)
- [ ] work_queue
- [ ] approval_requests
- [ ] cash_audit
- [ ] change_requests
- [ ] bulk_operations
- [ ] purchase_requests
- [ ] supplier_quotes
- [ ] purchase_orders
- [ ] goods_receipts
- [ ] cache
- [ ] analytics
- [ ] alerts
- [ ] inventory_alerts
- [ ] webhook_events
- [ ] whatsapp_incoming
- [ ] report_trigger_queue
- [ ] low_stock_alerts
- [ ] settings
- [ ] audit_logs
- [ ] security_events
- [ ] wallet_transactions
- [ ] refund_requests
- [ ] transactions
- [ ] payment_disputes
- [ ] dead_letter_rds_sync
- [ ] webhook_logs
- [ ] reconciliation_queue
- [ ] payment_retry_queue
- [ ] payment_retries
- [ ] payment_retry_counters
- [ ] payment_reconciliation_log
- [ ] payment_orphans
- [ ] owner_notifications
- [ ] campaign_triggers
- [ ] cashback_triggers

---

## Step 2: Rule Validation Checklist

Key security patterns verified in current rules:

### Authentication & Authorization
- [x] All public rules check `isSignedIn()` where appropriate
- [x] Role-based access control via helper functions:
  - isOwner() / isFranchiseOwner()
  - isAdmin() / isSuperAdmin()
  - isCustomer()
  - isEmployee()
  - isRider()
  - isDispatcher()
  - isBranchManager()
  - isSupplier()
- [x] Global admin bypass for critical operations
- [x] Branch-level isolation via isBranchMatch()

### Collection-Level Security
- [x] Users: Own profile only, or admin
- [x] Orders: Customer, branch staff, or admin
- [x] Products: Public read, admin write
- [x] Inventory: Branch staff or admin
- [x] Payments: Customer, owner, or admin
- [x] Wallets: Backend only (no client write)
- [x] Delivery: Dispatcher, rider, customer, or admin
- [x] Admin collections: Admin only

### Backend-Only Collections (No Client Write)
- [x] Payments (write via Cloud Functions)
- [x] Wallet transactions (atomic operations only)
- [x] Refund requests (approval gate)
- [x] Audit logs (immutable)
- [x] Analytics (system generated)
- [x] All operational queues

---

## Step 3: Test Suite Design

### Critical Test Cases

#### Auth Tests
1. Unauthenticated user cannot read any collection
2. Authenticated user can read only their own profile
3. Admin can read all users

#### Order Tests
4. Customer can read own orders
5. Customer cannot read other customer's orders
6. Branch manager can read branch orders
7. Customer cannot create orders for another user
8. Backend only: clients cannot write to orders

#### Wallet Tests
9. Customer can read own wallet
10. Customer cannot write to own wallet
11. Admin cannot write to wallet (backend only)
12. Wallet transactions are immutable

#### Delivery Tests
13. Rider can read assigned delivery tasks
14. Dispatcher can read branch deliveries
15. Customer can read their delivery task
16. Rider cannot read unassigned deliveries

#### Product Tests
17. Public can browse products
18. Only admin can modify products
19. Product stock cannot be modified via client (backend only)

#### Inventory Tests
20. Branch staff can read branch inventory
21. Branch staff can update branch inventory
22. Cross-branch staff cannot read other branch inventory

#### Coupons Tests
23. Customer can read coupons
24. Only admin can create coupons
25. No rule exists for writes (should be backend-only)

#### Admin Collections
26. Non-admin cannot read audit logs
27. Non-admin cannot read analytics
28. Non-admin cannot read alerts
29. Non-admin cannot read security events

---

## Step 4: Pre-Deployment Verification

### Syntax Validation
```bash
# Check firestore.rules syntax
firebase rules:test

# Expected output: All rules valid
```

### Key Points to Verify
- [x] No syntax errors in rules
- [x] All helper functions defined
- [x] No circular dependencies in functions
- [x] All referenced collections exist
- [x] Role names match authentication token structure

---

## Step 5: Deployment Instructions

### Prerequisites
```bash
# 1. Ensure Firebase CLI is installed
firebase --version

# 2. Ensure logged in to Firebase
firebase login

# 3. Set project context
firebase use fufaji-online-business

# 4. List current rules (optional)
firebase firestore:describe-rules
```

### Deploy Production Rules
```bash
# Deploy Firestore rules from firestore.rules
firebase deploy --only firestore:rules

# Expected output:
# i  deploying firestore
# ✔  firestore rules deployed successfully
```

### Verify Deployment
```bash
# 1. Check current rules
firebase firestore:describe-rules

# 2. Compare with local rules
# Ensure output matches firestore.rules content

# 3. Check Firebase Console
# https://console.firebase.google.com/project/fufaji-online-business/firestore/rules
```

---

## Step 6: Post-Deployment Testing

### Manual Tests in Firebase Console

1. **Test User Access**
   - Login as customer
   - Try to read: /users/{ownerId} → DENIED
   - Try to read: /users/{ownerId}/wallet → DENIED
   - Try to read: /products/any → ALLOWED
   - Logout and check: All reads → DENIED

2. **Test Order Access**
   - Login as customer A
   - Try to read: /orders/{orderA} → ALLOWED
   - Try to read: /orders/{orderB} → DENIED
   - Try to write: /orders/{orderA} → DENIED

3. **Test Admin Access**
   - Login as admin
   - Try to read: /users/any → ALLOWED
   - Try to read: /audit_logs/any → ALLOWED
   - Try to write: /products/productA → ALLOWED
   - Try to write: /payments/paymentA → DENIED (backend only)

4. **Test Wallet Protection**
   - Login as customer
   - Try to write: /customer_wallet/{customerId} → DENIED
   - Try to read: /customer_wallet/{customerId} → ALLOWED

---

## Step 7: Monitoring & Incident Response

### After Deployment

**1. Monitor Firestore Logs**
- Firebase Console → Firestore → Logs
- Check for unexpected denials in first 30 minutes
- Verify no "permission denied" spam from legitimate users

**2. Monitor Backend Logs**
- Check Cloud Functions for retry patterns
- Verify backend-only collections still work via Admin SDK
- Watch for failed wallet operations

**3. Monitor Mobile App**
- Test all app flows on staging
- Verify no new "Permission Denied" errors
- Check network logs for denied requests

### If Rules Break Something

**Immediate Action:**
```bash
# Revert to previous rules
git checkout HEAD~ -- firestore.rules
firebase deploy --only firestore:rules
```

**Investigation:**
1. Check which collections are affected
2. Review rule change in PR
3. Identify denied operation type (read/write/create)
4. Check app code for rule violations
5. Decide: Fix app code or adjust rules

---

## Step 8: Rule Maintenance

### Regular Reviews
- [ ] Monthly: Check Firestore logs for permission patterns
- [ ] Quarterly: Audit rules for obsolete collections
- [ ] As features ship: Update rules for new collections

### Documentation Updates
- [ ] Add new collection rules to this doc
- [ ] Document new helper functions
- [ ] Update test cases for new features
- [ ] Version rules with release notes

---

## Deployment Checklist

### Pre-Deployment
- [ ] Rules syntax validated
- [ ] All 45+ collections reviewed
- [ ] No breaking changes to existing apps
- [ ] Backend code updated for role-based access
- [ ] Staging environment tested

### Deployment
- [ ] Firebase project set correctly
- [ ] Backup of current rules taken (via firebase.json)
- [ ] Rules deployed via CLI
- [ ] Deployment verified in Firebase Console
- [ ] No errors in deployment logs

### Post-Deployment (First 30 minutes)
- [ ] Customer app: Login works
- [ ] Customer app: Can read own orders
- [ ] Staff app: Can read branch data
- [ ] Admin dashboard: Can read all data
- [ ] Backend: Wallet operations work
- [ ] Backend: Payment functions work
- [ ] Firestore logs: No unexpected denials

### Monitoring (First 24 hours)
- [ ] App crash rate: Normal
- [ ] Permission denied errors: Zero or expected
- [ ] Backend retry loops: None
- [ ] Customer complaints: None

### Success Criteria
- [ ] All tests passing
- [ ] No new errors in Crashlytics
- [ ] Backend continues to work
- [ ] Admin dashboard fully functional
- [ ] No security bypass discovered

---

## Rollback Plan

If critical issue discovered:

1. **Immediate (within 5 minutes):**
   - Run: `firebase deploy --only firestore:rules` (with old rules)
   - Or: Use Firebase Console to manually revert

2. **Communication (within 15 minutes):**
   - Notify team of rollback
   - Document what broke
   - Create post-mortem issue

3. **Investigation (next 2 hours):**
   - Reproduce issue in test environment
   - Identify rule causing problem
   - Fix and re-test locally
   - Deploy again

---

## Timeline

- **8:00 AM** - Rules review and audit (30 min)
- **8:30 AM** - Test suite preparation (30 min)
- **9:00 AM** - Syntax validation (15 min)
- **9:15 AM** - Deploy to production (15 min)
- **9:30 AM** - Manual testing (45 min)
- **10:15 AM** - Monitoring setup (15 min)
- **10:30 AM** - Documentation update (30 min)
- **11:00 AM** - Team notification and sign-off (30 min)
- **12:00 PM** - Complete and close task

**Total: 4 hours**

---

## Next Steps After This Task

After Firestore rules are live:

1. **Wallet Bug Fix** - Fix wallet stock skip (P0 bug)
2. **APK Re-signing** - Create new APK with updated keystore
3. **Production Deploy** - Full system deployment

---

## References

- Firestore Rules Documentation: https://firebase.google.com/docs/firestore/security/start
- Current Rules: `firestore.rules` (611 lines)
- Current Rules (v2): `FIRESTORE_RULES_PRODUCTION.rules` (428 lines)
- Firebase Config: `firebase.json`
