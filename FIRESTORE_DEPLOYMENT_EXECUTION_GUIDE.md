# Firestore Rules Deployment - Execution Guide

**Date:** June 25, 2026  
**Project:** Fufaji Store  
**Objective:** Deploy comprehensive Firestore security rules covering 45+ collections  
**Timeline:** 8:00 AM - 12:00 PM (4 hours)  
**Status:** Ready for execution

---

## Quick Start (TL;DR)

```bash
# 1. Verify setup
./firestore-deployment-verification.sh

# 2. Deploy
firebase deploy --only firestore:rules --project=fufaji-online-business

# 3. Verify deployment
firebase firestore:describe-rules --project=fufaji-online-business

# 4. Test manually in Firebase Console
# (See testing section below)
```

---

## Step 1: Pre-Deployment Setup (8:00 AM - 8:30 AM)

### 1.1 Environment Verification

```bash
# Check Firebase CLI version
firebase --version
# Expected: firebase-tools 12.0.0+ (or latest)

# Check Node.js version
node --version
# Expected: v18+ (LTS)

# Verify project access
firebase projects:list
# Expected: List includes "fufaji-online-business"
```

### 1.2 Project Configuration

```bash
# Set current project
firebase use fufaji-online-business

# Verify .firebaserc
cat .firebaserc
# Should show: "fufaji-online-business" as default project

# Check firebase.json
cat firebase.json
# Should show:
# "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" }
```

### 1.3 Rules File Validation

```bash
# Check file exists
ls -lh firestore.rules
# Expected: File exists, size ~10-15 KB

# View file summary
wc -l firestore.rules
# Expected: ~600+ lines

# Count collections
grep -c "match /" firestore.rules
# Expected: 45+ collections

# Check for syntax errors
firebase rules:test --rules=firestore.rules
# Expected: All rules valid, no errors
```

### 1.4 Backup Current Rules (Safety First)

```bash
# Download current rules
firebase firestore:describe-rules --project=fufaji-online-business > /tmp/rules-backup-before-$(date +%Y%m%d-%H%M%S).txt

# Backup local rules to versioned file
cp firestore.rules firestore-rules-backup-v1-$(date +%Y%m%d).txt

# Commit to git (optional but recommended)
git add firestore-rules-backup-v1-*.txt
git commit -m "Backup: Firestore rules before deployment (2026-06-25)"
```

### 1.5 Final Security Check

```bash
# Verify no sensitive data in rules
grep -i "password\|token\|secret\|key" firestore.rules
# Expected: No matches (rules don't contain secrets)

# Verify all "backend only" collections have "allow write: if false;"
grep -B 2 "allow write: if false" firestore.rules | head -20
# Expected: Multiple backend-only collections listed

# Verify DENY-BY-DEFAULT pattern
tail -20 firestore.rules
# Expected: Ends with:
# match /{document=**} {
#   allow read, write: if false;
# }
```

---

## Step 2: Pre-Deployment Verification (8:30 AM - 9:00 AM)

### 2.1 Run Verification Script

```bash
# Make executable
chmod +x firestore-deployment-verification.sh

# Run verification
./firestore-deployment-verification.sh

# Expected output:
# [1/5] Checking Firebase CLI installation... ✓
# [2/5] Checking Firebase authentication... ✓
# [3/5] Checking local Firestore rules file... ✓
# [4/5] Checking deployed rules in Firebase... ✓
# [5/5] Verifying critical collections are covered... ✓
# All Verification Checks Passed!
```

### 2.2 Manual Collection Verification

Critical collections that MUST be covered:

```bash
# Core collections
for col in users orders products payments coupons inventory \
           delivery_tasks deliveries wallet_transactions refunds \
           audit_logs analytics security_events cache settings; do
  echo "Checking: $col"
  grep -q "match /$col/" firestore.rules && echo "  ✓ Found" || echo "  ✗ MISSING"
done

# If any shows ✗ MISSING - DO NOT DEPLOY
# Fix rules first before continuing
```

### 2.3 Role Verification

Verify all 8 roles are defined in helper functions:

```bash
# Check helper functions
grep "function is" firestore.rules | head -20

# Expected functions:
# - isSignedIn()
# - isAdmin() / isSuperAdmin()
# - isCustomer()
# - isEmployee()
# - isRider()
# - isDispatcher()
# - isBranchManager()
# - isOwner() / isFranchiseOwner()
# - isSupplier()
# - isGlobalAdmin()
```

### 2.4 Notify Team

```bash
# Slack notification
echo "@team Deploying Firestore rules in ~5 minutes. Brief 2-3 min window."

# Start deployment only after acknowledgment from:
# - Backend Lead
# - DevOps
# - One other team member
```

---

## Step 3: Deploy to Production (9:00 AM - 9:15 AM)

### 3.1 Pre-Deploy Checklist

Before running deploy command:

- [ ] All verification checks passed (green lights)
- [ ] All critical collections verified
- [ ] Rules file has no syntax errors
- [ ] Team notified and acknowledged
- [ ] Current rules backed up
- [ ] Git branch is clean
- [ ] Time is during business hours (don't deploy at night!)

### 3.2 Execute Deployment

```bash
# DEPLOY COMMAND
firebase deploy --only firestore:rules --project=fufaji-online-business

# Expected output:
# i  deploying firestore
# ✔  firestore rules deployed successfully
#
# Deploy complete!
# Time: X.XXXs
```

**IMPORTANT NOTES:**
- This command is IDEMPOTENT (safe to run multiple times)
- Typical deployment time: 20-60 seconds
- No data is deleted during deployment
- Rules take effect immediately

### 3.3 Capture Deployment Confirmation

```bash
# Save deployment timestamp
DEPLOY_TIME=$(date "+%Y-%m-%d %H:%M:%S")
DEPLOY_HASH=$(git rev-parse HEAD)

# Document deployment
echo "Deployment: $DEPLOY_TIME" > DEPLOYMENT.log
echo "Git Hash: $DEPLOY_HASH" >> DEPLOYMENT.log
firebase firestore:describe-rules --project=fufaji-online-business >> DEPLOYMENT.log

# Show result
cat DEPLOYMENT.log
```

### 3.4 If Deployment Fails

If you see error messages:

**Error: "Permission denied"**
```bash
# Ensure you're logged in
firebase login
firebase use fufaji-online-business
# Then retry deploy
```

**Error: "Project not found"**
```bash
# List available projects
firebase projects:list
# Use correct project ID
firebase use [PROJECT_ID]
```

**Error: "Syntax error in rules"**
```bash
# Fix the error in firestore.rules
# Test locally:
firebase rules:test --rules=firestore.rules
# Then retry deploy
```

**ROLLBACK if needed:**
```bash
# Revert to previous version
git checkout HEAD~ -- firestore.rules

# Redeploy
firebase deploy --only firestore:rules --project=fufaji-online-business

# Notify team immediately
```

---

## Step 4: Post-Deployment Verification (9:15 AM - 10:15 AM)

### 4.1 Verify Rules Deployed

```bash
# Fetch deployed rules
firebase firestore:describe-rules --project=fufaji-online-business > /tmp/deployed-rules.txt

# Compare with local (should be identical)
diff firestore.rules /tmp/deployed-rules.txt
# Expected: No differences (or minor formatting)

# Check for key patterns
grep "match /users/" /tmp/deployed-rules.txt || echo "ERROR: users collection missing!"
grep "isAdmin" /tmp/deployed-rules.txt || echo "ERROR: isAdmin function missing!"
```

### 4.2 Check Firebase Console

Navigate to: https://console.firebase.google.com/project/fufaji-online-business/firestore/rules

- [ ] Rules tab shows new rules
- [ ] Last modified timestamp is recent (within last 5 minutes)
- [ ] No errors or warnings displayed

### 4.3 Test in Firebase Emulator (Optional but Recommended)

```bash
# Start emulator
firebase emulators:start --only firestore

# In another terminal, run tests
npm test firestore-rules-test-suite.js

# Expected: All tests passing
# ✓ Authentication tests (5 passed)
# ✓ Users collection tests (5 passed)
# ✓ Orders collection tests (5 passed)
# ✓ Wallet collection tests (5 passed)
# ✓ Products collection tests (3 passed)
# ✓ Coupons collection tests (3 passed)
# ✓ Delivery collection tests (4 passed)
# ✓ Admin collections tests (6 passed)
# ✓ Inventory collection tests (3 passed)
# ✓ Backend-only collections tests (5 passed)

# Stop emulator with Ctrl+C
```

---

## Step 5: Manual Testing in Firebase Console (10:15 AM - 11:00 AM)

### 5.1 Test Unauthenticated Access

1. In Firebase Console, open Firestore
2. Clear browser cache and logout
3. Try to query: `db.collection('audit_logs').get()`
4. Expected: `PERMISSION_DENIED` error

### 5.2 Test Customer Access

1. Login as customer user (use test account created earlier)
2. Run queries:

```javascript
// Can read own profile
db.collection('users').doc(userId).get()
// Result: ✓ Success

// Cannot read other profiles
db.collection('users').doc(otherId).get()
// Result: ✗ PERMISSION_DENIED

// Can read own orders
db.collection('orders').where('customerId', '==', userId).get()
// Result: ✓ Success

// Cannot read other orders
db.collection('orders').doc(otherOrderId).get()
// Result: ✗ PERMISSION_DENIED

// Cannot modify wallet
db.collection('customer_wallet').doc(userId).update({balance: 9999})
// Result: ✗ PERMISSION_DENIED

// Can browse products
db.collection('products').get()
// Result: ✓ Success
```

### 5.3 Test Admin Access

1. Login as admin user
2. Run queries:

```javascript
// Can read all users
db.collection('users').get()
// Result: ✓ Success

// Can read all orders
db.collection('orders').get()
// Result: ✓ Success

// Can modify products
db.collection('products').doc(id).update({price: 50})
// Result: ✓ Success

// Cannot directly modify payments (backend-only)
db.collection('payments').doc(id).update({status: 'paid'})
// Result: ✗ PERMISSION_DENIED

// Can read audit logs
db.collection('audit_logs').get()
// Result: ✓ Success
```

### 5.4 Test Delivery Access

1. Login as rider user with assigned deliveries
2. Run queries:

```javascript
// Can read assigned delivery
db.collection('delivery_tasks').doc(assignedTaskId).get()
// Result: ✓ Success

// Cannot read unassigned delivery
db.collection('delivery_tasks').doc(unassignedTaskId).get()
// Result: ✗ PERMISSION_DENIED

// Cannot modify delivery (rider can only update specific fields)
// This depends on rule implementation
```

---

## Step 6: Mobile App Testing (11:00 AM - 11:30 AM)

### 6.1 Customer App Test

1. On Android device, open customer app
2. Test these flows:

```
✓ Login page → Login with test account
✓ Home screen → Products load and display
✓ Product detail → Open any product
✓ Add to cart → Add item to cart
✓ Cart → View cart items
✓ Create order → Complete checkout
✓ Order confirmation → Show order ID
✓ My orders → View created order
✓ Order detail → View order status and items
✓ Wallet → View wallet balance (read-only)
```

**Expected:** No "Permission Denied" errors

### 6.2 Staff App Test (if exists)

1. Login as shop staff
2. Test:

```
✓ Inventory screen → Can view branch inventory
✓ Orders screen → Can view branch orders
✓ Update inventory → Can update stock (if allowed)
✓ Fulfillment → Can process orders
```

### 6.3 Check Logs

```
Android Logcat:
grep -i "permission\|denied" logcat.log
# Should see 0 results (no permission errors)

Firebase Crashlytics:
Visit: https://console.firebase.google.com/project/fufaji-online-business/crashlytics
# Should show no new crashes related to Firestore
```

---

## Step 7: Backend Service Testing (11:30 AM - 12:00 PM)

### 7.1 Payment Processing

Test that backend payment processing still works:

```bash
# Trigger a test order payment
# In your backend service, create a test order:
curl -X POST http://localhost:8080/orders/create \
  -H "Authorization: Bearer [TEST_TOKEN]" \
  -d '{customerId: "test-customer", items: [...]}'

# Monitor Cloud Functions logs:
firebase functions:log

# Should see:
# - Order document created
# - Payment verification initiated
# - Wallet transaction recorded
# - No Firestore permission errors
```

### 7.2 Delivery Assignment

Test that delivery tasks are created and assigned:

```bash
# Check Cloud Functions logs
firebase functions:log --project=fufaji-online-business

# Should show:
# - New delivery_tasks document created
# - Rider assignment successful
# - No permission errors
```

### 7.3 Inventory Operations

Test that stock management works:

```bash
# Check if inventory can be updated by staff
# (This is a backend-orchestrated operation)

# Verify in Firestore:
# Collection: inventory
# Recent documents should show updated quantities
# No permission denied errors in logs
```

### 7.4 Check Cloud Functions Logs

```bash
# View last 50 log entries
firebase functions:log --limit=50 --project=fufaji-online-business

# Watch for patterns:
grep -i "permission" functions.log  # Should be minimal
grep -i "error" functions.log       # Should be minimal
grep "WARN" functions.log           # Check for warnings
```

---

## Step 8: Monitoring & Sign-Off (Ongoing)

### 8.1 First Hour Monitoring

**At T+5 minutes:**
- Check Firestore Logs: No unexpected denials
- Check Cloud Functions: All executing normally
- Check app metrics: Normal usage patterns

**At T+15 minutes:**
- Review Crashlytics: No new crashes
- Check error rates: Should be baseline or lower
- Verify payment processing: Success rate normal

**At T+30 minutes:**
- Full system health check
- Test end-to-end order flow again
- Verify all workflow stages work

**At T+60 minutes:**
- All systems nominal
- No ongoing issues
- Ready to close task

### 8.2 Document Deployment

```bash
# Create deployment record
cat > FIRESTORE_DEPLOYMENT_RECORD.md << EOF
# Firestore Rules Deployment - June 25, 2026

**Status:** SUCCESSFUL ✓

**Timeline:**
- Pre-deployment: 8:00 AM - 8:30 AM (30 min)
- Verification: 8:30 AM - 9:00 AM (30 min)
- Deployment: 9:00 AM - 9:15 AM (15 min)
- Testing: 9:15 AM - 11:30 AM (135 min)
- Monitoring: 11:30 AM - 12:00 PM (30 min)

**Deployment Command:**
\`firebase deploy --only firestore:rules --project=fufaji-online-business\`

**Rules Deployed:**
- 45+ collections covered
- 8 role-based access patterns
- 100+ rules defined
- DENY-BY-DEFAULT pattern enforced

**Tests Passed:**
- ✓ Verification script (5/5 checks)
- ✓ Firebase emulator tests (40+ test cases)
- ✓ Firebase Console manual tests
- ✓ Mobile app testing (customer flow)
- ✓ Backend service testing
- ✓ Firestore logs (no unexpected denials)

**Monitoring Results:**
- No critical errors in first hour
- No increase in permission denied errors
- App usage metrics normal
- Payment processing working
- Delivery system operational

**Rollback Plan:**
In case of critical issues, run:
\`git checkout HEAD~ -- firestore.rules\`
\`firebase deploy --only firestore:rules --project=fufaji-online-business\`

**Sign-Off:**
- Deployed by: _______________
- Verified by: _______________
- Date: June 25, 2026
- Time: __________
EOF

# Add to git
git add FIRESTORE_DEPLOYMENT_RECORD.md
git commit -m "Record: Firestore rules deployed successfully (2026-06-25)"
```

### 8.3 Team Notification

```bash
# Slack update
Send message to team:

"✅ Firestore Rules Deployment Complete

Deployed: June 25, 2026 at [TIME]
Status: SUCCESS - All tests passing
Rules: firestore.rules (45+ collections)

Testing Results:
- ✓ Verification script: 5/5 passed
- ✓ Manual testing: All flows work
- ✓ Mobile app: No permission errors
- ✓ Backend services: Operational
- ✓ Monitoring: No issues detected

Next steps:
1. Monitor for 24 hours (normal)
2. Proceed with Wallet bug fix (P0)
3. Begin APK re-signing

Questions? Contact: @[BACKEND_LEAD]"
```

---

## Troubleshooting Guide

### Issue: "Permission Denied" from legitimate users

**Diagnosis:**
1. Check which user role is affected
2. Identify which collection is denied
3. Review the rule for that collection

**Fix:**
```bash
# 1. Find the rule
grep -A 5 "match /[collection]/" firestore.rules

# 2. Identify the issue (common patterns):
# - Missing role check
# - Wrong property name (e.g., customerId vs userId)
# - Missing branch ID check

# 3. Update rule
# 4. Test with emulator
# 5. Deploy again

firebase deploy --only firestore:rules
```

### Issue: Backend services can't write to collections

**Diagnosis:**
```bash
# Check Cloud Functions logs
firebase functions:log

# Look for "permission-denied" errors
grep "permission-denied" functions.log
```

**Solution:**
- Backend MUST use Admin SDK (not client SDK)
- Check that Cloud Functions have correct implementation
- Verify service account has required permissions

### Issue: Mobile app crashes with "Permission Denied"

**Diagnosis:**
```bash
# Check app logs
adb logcat | grep "permission\|denied"

# Check Crashlytics
# Visit: Firebase Console > Crashlytics > Recent Issues
```

**Solution:**
1. Identify which operation is failing
2. Check if that operation is allowed in rules
3. If allowed, check if user is authenticated properly
4. If not allowed, either:
   - Update rules (if it should be allowed)
   - Update app code (if it shouldn't be allowed)

### Issue: Deployment fails with syntax error

**Diagnosis:**
```bash
firebase rules:test --rules=firestore.rules
```

**Solution:**
1. Read the error message carefully
2. Find line number mentioned in error
3. Check that line and surrounding lines
4. Common issues:
   - Missing semicolon
   - Wrong bracket/parenthesis
   - Invalid function call
   - Wrong operator

---

## Success Criteria

Deployment is successful if ALL of these are true:

- ✅ Deployment command completed without errors
- ✅ Rules are visible in Firebase Console
- ✅ Verification script shows 5/5 checks passed
- ✅ Emulator tests pass (if run)
- ✅ Firebase Console manual tests succeed
- ✅ Mobile app works without permission errors
- ✅ Backend services process data normally
- ✅ No increase in error rates
- ✅ Team notified and acknowledged
- ✅ Deployment documented

If ANY of these fail, investigate and fix before moving forward.

---

## Next Task

After successful Firestore rules deployment:

1. **Wallet Bug Fix** - Fix the stock deduction gap (P0 bug)
   - Implement missing stock deduction for wallet orders
   - Test all order types (cash, card, wallet)
   - Verify stock counts after order

2. **APK Re-signing** - Create new APK with updated keystore
   - Generate new signing key
   - Build new APK
   - Deploy to Play Store

3. **Production Deployment** - Full system go-live
   - Deploy all services
   - Run final smoke tests
   - Monitor 24/7

---

## Contact & Support

- **Firebase Documentation:** https://firebase.google.com/docs/firestore/security/start
- **Error Messages:** Check Firebase Console → Logs
- **Incidents:** Post in #incidents Slack channel
- **Questions:** Ask @backend-lead

---

**Remember:** Rules can always be updated, but it's better to get them right the first time. Take your time testing before deploying to production.
