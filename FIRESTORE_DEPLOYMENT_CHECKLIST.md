# Firestore Rules Deployment Checklist - June 25, 2026

**Project:** Fufaji Store  
**Task:** Deploy comprehensive Firestore security rules to production  
**Timeline:** 8:00 AM - 12:00 PM (4 hours)  
**Responsible:** Backend/Security Engineer

---

## PRE-DEPLOYMENT (Before 8:30 AM)

### Environment Setup
- [ ] Firebase CLI installed (`firebase --version` returns version)
- [ ] Logged into Firebase account (`firebase login` if needed)
- [ ] Project set to `fufaji-online-business` (`firebase use fufaji-online-business`)
- [ ] Git repository clean (no uncommitted changes)
- [ ] Current branch is `main` or appropriate release branch

### Rules Verification
- [ ] `firestore.rules` file exists and is readable
- [ ] `firebase.json` configured correctly (points to `firestore.rules`)
- [ ] Rules file has no syntax errors (`firebase rules:test --rules=firestore.rules`)
- [ ] All 45+ collections are covered with rules
- [ ] Helper functions are defined (isAdmin, isCustomer, etc.)
- [ ] No circular dependencies in helper functions
- [ ] Role-based access control rules are correct
- [ ] Backend-only collections have `allow write: if false;`

### Test Environment
- [ ] `firestore-rules-test-suite.js` is available
- [ ] Firebase emulator installed (`firebase setup:emulators:firestore`)
- [ ] Emulator can start without errors

### Documentation
- [ ] `firestore-rules-deployment-plan.md` reviewed
- [ ] `firestore-deployment-verification.sh` is executable
- [ ] Current rules backed up (commit before deploy)
- [ ] Change log updated with deployment date

---

## DEPLOYMENT EXECUTION (8:30 AM - 9:15 AM)

### Final Checks (5 min)
- [ ] Slack team notified of upcoming deployment
- [ ] Current rules snapshot taken:
  ```bash
  firebase firestore:describe-rules > /tmp/rules-backup.txt
  git log --oneline firestore.rules | head -1
  ```
- [ ] Read all critical security rules one final time
- [ ] Verify no test data in production Firestore
- [ ] Database size is acceptable (check Firebase Console)

### Syntax Validation (5 min)
- [ ] Run verification script:
  ```bash
  chmod +x firestore-deployment-verification.sh
  ./firestore-deployment-verification.sh
  ```
- [ ] All checks pass (5/5 green)
- [ ] Collections list matches expected count

### Deploy to Production (5 min)
- [ ] Execute deployment:
  ```bash
  firebase deploy --only firestore:rules --project=fufaji-online-business
  ```
- [ ] Deployment shows success message:
  ```
  ✔  firestore rules deployed successfully
  ```
- [ ] No warnings or errors in output
- [ ] Deployment takes < 2 minutes

### Post-Deploy Verification (5 min)
- [ ] Retrieve deployed rules:
  ```bash
  firebase firestore:describe-rules --project=fufaji-online-business
  ```
- [ ] Deployed rules match local rules
- [ ] No errors in Firebase Console
- [ ] Rules tab in Firebase Console shows new rules

---

## MANUAL TESTING (9:15 AM - 10:15 AM)

### Firebase Console Tests (15 min)

**Test 1: Unauthenticated Access**
- [ ] Logout from Firebase Console
- [ ] Try to query: `collection('audit_logs')`
- [ ] Result: `DENIED` (permission-denied)
- [ ] Try to query: `collection('products')`
- [ ] Result: Can see public data or DENIED (depends on rule)

**Test 2: Customer Access**
- [ ] Login as customer user (use test account)
- [ ] Query: `collection('users').doc(userId)`
- [ ] Result: `SUCCESS` (can see own profile)
- [ ] Query: `collection('users').doc(otherUserId)`
- [ ] Result: `DENIED` (cannot see other users)
- [ ] Query: `collection('products')`
- [ ] Result: `SUCCESS` (can see products)
- [ ] Try write: `collection('wallet').doc(userId).update({balance: 9999})`
- [ ] Result: `DENIED` (cannot modify wallet)
- [ ] Query: `collection('orders').doc(ownOrderId)`
- [ ] Result: `SUCCESS` (can see own orders)
- [ ] Query: `collection('orders').doc(otherOrderId)`
- [ ] Result: `DENIED` (cannot see other orders)

**Test 3: Admin Access**
- [ ] Login as admin user
- [ ] Query: `collection('audit_logs')`
- [ ] Result: `SUCCESS` (admin can see logs)
- [ ] Query: `collection('users')`
- [ ] Result: `SUCCESS` (admin can see all users)
- [ ] Try write: `collection('products').doc(id).update({price: 50})`
- [ ] Result: `SUCCESS` (admin can modify products)
- [ ] Try write: `collection('payments').doc(id).update({status: 'paid'})`
- [ ] Result: `DENIED` (backend-only, cannot write directly)
- [ ] Try write: `collection('analytics').doc(id).set({...})`
- [ ] Result: `DENIED` (backend-only)

**Test 4: Rider Access**
- [ ] Login as rider user
- [ ] Query: `collection('delivery_tasks').doc(assignedTaskId)`
- [ ] Result: `SUCCESS` (can see assigned task)
- [ ] Query: `collection('delivery_tasks').doc(unassignedTaskId)`
- [ ] Result: `DENIED` (cannot see other riders' tasks)

**Test 5: Branch Manager Access**
- [ ] Login as branch manager
- [ ] Query: `collection('inventory').doc(branchInventoryId)`
- [ ] Result: `SUCCESS` (can see own branch inventory)
- [ ] Query: `collection('inventory').doc(otherBranchInventoryId)`
- [ ] Result: `DENIED` (cannot see other branches)
- [ ] Query: `collection('orders')` filtered by branchId
- [ ] Result: `SUCCESS` (can see branch orders)

### Mobile App Testing (30 min)

**Android App - Customer Flow**
- [ ] App starts without errors
- [ ] Login works normally
- [ ] Home screen loads products
- [ ] Customer can view own orders
- [ ] Order details load correctly
- [ ] Add to cart works
- [ ] Create order works
- [ ] Payment flow works
- [ ] Order confirmation displays
- [ ] No "Permission Denied" errors in logs

**Android App - Shop Staff Flow**
- [ ] Login as shop staff
- [ ] Inventory screen loads
- [ ] Can see branch inventory
- [ ] Can update inventory (if allowed by rules)
- [ ] Orders screen shows branch orders
- [ ] Fulfillment screen works
- [ ] No permission errors

**iOS App (if available)**
- [ ] Same tests as Android
- [ ] Login and navigation works
- [ ] No crashes or permission errors

### Backend Service Testing (15 min)

**Cloud Functions - Payment Processing**
- [ ] Payment webhook received and processed
- [ ] Payment document created in Firestore
- [ ] Wallet transaction recorded
- [ ] Order status updated
- [ ] No errors in Cloud Functions logs

**Cloud Functions - Delivery Assignment**
- [ ] Delivery task created for new order
- [ ] Rider assigned successfully
- [ ] Rider can fetch their delivery tasks
- [ ] No permission errors in functions logs

**Cloud Functions - Inventory Operations**
- [ ] Stock deduction works on order
- [ ] Reservation system functions
- [ ] No Firestore rule violations
- [ ] Inventory updates visible to staff

**Cloud Functions - Refund Processing**
- [ ] Refund request created by customer
- [ ] Admin can approve refund
- [ ] Wallet balance updated
- [ ] Stock restored if applicable
- [ ] No errors in Cloud Functions logs

### Firestore Logs Analysis (10 min)

In Firebase Console → Firestore → Logs:
- [ ] Search for `Error` in logs
- [ ] Should see NO permission denied errors from legitimate operations
- [ ] May see expected denials from unauthorized attempts
- [ ] No unusual patterns or spikes
- [ ] Latency is normal (< 100ms)

In Cloud Functions Logs:
- [ ] No errors related to Firestore writes
- [ ] Payment functions executing successfully
- [ ] Delivery assignment functions working
- [ ] No retry loops or timeouts

---

## MONITORING (10:15 AM - 11:15 AM)

### First Hour After Deploy

**At 5 Minutes:**
- [ ] Check Firestore logs for errors
- [ ] Verify no immediate complaints from users
- [ ] Check Cloud Functions execution logs

**At 15 Minutes:**
- [ ] Review app crash logs in Crashlytics
- [ ] Check for increase in permission-denied errors
- [ ] Verify backend services are running normally

**At 30 Minutes:**
- [ ] Check customer app usage metrics
- [ ] Verify no spike in "permission denied" errors
- [ ] Ensure payment processing continues
- [ ] Confirm delivery system is working

**At 45 Minutes:**
- [ ] Run a test order end-to-end
- [ ] Verify all workflow stages work
- [ ] Check Firebase Console for unusual activity

**At 60 Minutes:**
- [ ] Full system health check
- [ ] Verify all databases are responsive
- [ ] Check error rates across all services
- [ ] Confirm no widespread issues

### Error Rate Thresholds

If any of these occur, prepare for rollback:
- [ ] Permission denied errors > 1% of requests
- [ ] Customer app crash rate increase > 0.5%
- [ ] Payment failures spike
- [ ] Delivery system outage

### Rollback Decision Checklist

If issues found:
- [ ] Identify the exact rule causing issue
- [ ] Determine if fixable in rule or code
- [ ] If rule fix needed: make change and re-deploy
- [ ] If code fix needed: rollback and coordinate fix

**Rollback Command:**
```bash
git checkout HEAD~ -- firestore.rules
firebase deploy --only firestore:rules --project=fufaji-online-business
```

---

## DOCUMENTATION (11:15 AM - 11:45 AM)

### Update Files
- [ ] `FIRESTORE_RULES_DEPLOYMENT_CHECKLIST.md` - Mark completed
- [ ] `firestore-rules-deployment-plan.md` - Add actual timeline
- [ ] `DEPLOYMENT_LOG.md` - Add entry with:
  - Deployment start time
  - Completion time
  - Success/failure status
  - Collections count
  - Any issues encountered

### Communication
- [ ] Notify team on Slack
- [ ] Post summary in #deployments channel:
  ```
  Firestore Rules Deployed Successfully
  
  Deployed: [time]
  Rules: firestore.rules (45+ collections)
  Status: All checks passed
  Monitoring: Active
  
  No user action required.
  ```
- [ ] Create ticket for any issues found

### Logging
- [ ] Document current rules version:
  ```bash
  git log --oneline -1 firestore.rules
  ```
- [ ] Save deployment log:
  ```bash
  firebase deploy --only firestore:rules --project=fufaji-online-business 2>&1 | tee firestore-deploy-$(date +%Y%m%d-%H%M%S).log
  ```
- [ ] Archive rules file:
  ```bash
  cp firestore.rules firestore-rules-v1-20260625.backup
  ```

---

## SIGN-OFF (11:45 AM - 12:00 PM)

### Final Verification
- [ ] All test cases passed
- [ ] No critical errors found
- [ ] Monitoring is active
- [ ] Team has been notified
- [ ] Documentation is updated
- [ ] Rollback plan is in place if needed

### Completion Checklist
- [ ] ✅ Deployment successful
- [ ] ✅ All tests passing
- [ ] ✅ Rules verified in Firebase
- [ ] ✅ Mobile app working
- [ ] ✅ Backend services working
- [ ] ✅ Team notified
- [ ] ✅ Documentation updated
- [ ] ✅ Task marked complete

### Next Steps
1. Monitor system for next 24 hours
2. Address any issues that arise
3. After 24 hours with no issues, close task
4. Begin next task: Wallet bug fix + APK resign

---

## EMERGENCY CONTACTS

If critical issues occur during deployment:

- **Backend Lead:** [Contact info]
- **DevOps Lead:** [Contact info]
- **Firebase Support:** https://firebase.google.com/support
- **Incident Channel:** #incidents on Slack

---

## APPENDIX: Rules Summary

### Collections Covered (45+)

**Core Business (15):**
- users, customer_wallet, owners, employees, orders
- products, coupons, inventory, inventory_events
- delivery_tasks, delivery_batches, deliveries
- payments, refunds, returns

**Delivery (10+):**
- delivery_agents, delivery_assignments, delivery_otp
- delivery_locations, delivery_tracking, delivery_routes
- delivery_status, delivery_history, delivery_notifications
- delivery_preferences, delivery_events, delivery_exceptions
- delivery_sla_rules, delivery_slots

**Operations (15+):**
- work_queue, approval_requests, cash_audit
- change_requests, bulk_operations, purchase_requests
- supplier_quotes, purchase_orders, goods_receipts
- cache, analytics, alerts, inventory_alerts
- webhook_events, whatsapp_incoming, report_trigger_queue
- low_stock_alerts, settings, audit_logs, security_events
- wallet_transactions, refund_requests, transactions
- payment_disputes, dead_letter_rds_sync, webhook_logs
- reconciliation_queue, payment_retry_queue, payment_retries
- payment_retry_counters, payment_reconciliation_log
- payment_orphans, owner_notifications, campaign_triggers
- cashback_triggers

### Helper Functions (8 roles)
- isOwner() / isFranchiseOwner()
- isAdmin() / isSuperAdmin()
- isCustomer()
- isEmployee()
- isRider()
- isDispatcher()
- isBranchManager()
- isSupplier()

### Key Patterns
- ✓ Users: Own profile only, or admin
- ✓ Orders: Customer, branch staff, or admin
- ✓ Products: Public read, admin write
- ✓ Wallet: Backend only (no client write)
- ✓ Payments: Backend only (via Cloud Functions)
- ✓ Delivery: Rider, dispatcher, customer, or admin
- ✓ Admin collections: Admin only (audit_logs, analytics, etc.)
- ✓ Backend queues: System only (immutable)

---

**Deployment completed by:** ___________________

**Date:** ___________________

**Time:** ___________________

**Status:** ☐ Success | ☐ Partial Success | ☐ Rollback

**Notes:** _________________________________________________________________
