# 🔨 IMPLEMENTATION EXECUTION PLAN
**Date:** June 23, 2026 - 8:00 AM Start  
**Deadline:** June 23, 2026 - 6:30 PM Production Deploy  
**Total Duration:** 10.5 hours available → 8 hours needed

---

## PHASE 1: CRITICAL P0 FIXES (1 hour) — PARALLEL EXECUTION

### Fix 1.1: Secrets Rotation (CRITICAL)
**Owner:** DevOps Engineer  
**Time:** 30 min  
**Action Items:**
- [ ] Rotate Razorpay API key + webhook_secret
- [ ] Rotate Stripe API key + webhook_secret
- [ ] Rotate Firebase service account key
- [ ] Rotate Twilio Account SID + Auth Token
- [ ] Rotate SendGrid API key
- [ ] Rotate WhatsApp access token
- [ ] Update .env files in backend
- [ ] Update environment variables in production
- [ ] Verify no old secrets in git history (git-secrets scan)
- [ ] Verify APK build doesn't contain secrets

**Deliverable:** Updated .env file with new secrets, verification log

---

### Fix 1.2: Firestore Rules Verification (QUICK CHECK)
**Owner:** Firebase Engineer  
**Time:** 15 min  
**Status:** ✅ All rules added June 20, just verify they're deployed
**Action Items:**
- [ ] Verify pin_lockouts rules are live in production
- [ ] Verify delivery_* rules are live (10 collections)
- [ ] Run security rules test suite
- [ ] Check for any deployments still pending

**Deliverable:** Rules deployment verification log

---

### Fix 1.3: Payment Webhook Signature Validation (VERIFY)
**Owner:** Payments Engineer  
**Time:** 15 min  
**Status:** ✅ Code present, verify correct secrets set
**Action Items:**
- [ ] Verify `RAZORPAY_WEBHOOK_SECRET` env var matches production value
- [ ] Test webhook with actual Razorpay test event
- [ ] Verify Stripe webhook signature validation working (constructEvent call)
- [ ] Add logging to webhook signature validation for debugging

**Deliverable:** Webhook validation test results

---

## PHASE 2: HIGH-PRIORITY P1 FIXES (3 hours)

### Fix 2.1: Order Status Normalization
**Owner:** Backend Engineer + E-Commerce Specialist  
**Time:** 1 hour  
**Current Issue:** Status values inconsistent across Firestore/Postgres/Queries

**Action Items:**
1. **Define Single Source of Truth:**
   ```
   Enum OrderStatus {
     pending        // Initial state when order created
     confirmed      // Shop owner confirmed order
     processing     // Kitchen processing items
     packed         // Items packed for delivery
     out_for_delivery // With delivery rider
     delivered      // Delivered to customer
     completed      // Customer confirmed receipt
     cancelled      // Order cancelled
     refund_requested // Customer requested refund
     refund_approved // Refund approved
     refund_completed // Refund processed to wallet
   }
   ```

2. **Update Database Schema:**
   - [ ] Postgres: Update orders table CHECK constraint for status values
   - [ ] Add migration: Convert old status values to new enum
   - [ ] Update Firestore document schema definition

3. **Update All Queries:**
   - [ ] `/backend/src/routes/orders.js` - use enum in queries
   - [ ] `/backend/src/routes/delivery.js` - use `OrderStatus.packed` not bare string
   - [ ] `/lib/services/order_service.dart` - use enum throughout
   - [ ] All status comparison checks - use enum

4. **Update Notifications:**
   - [ ] `/backend/src/routes/orders.js` (line 25-50) - update status -> message mapping to use enum

**Test:**
   - [ ] Create order → verify status is `pending`
   - [ ] Confirm order → verify status is `confirmed`
   - [ ] Delivery pickup → status is `packed` and riders can query it
   - [ ] Out for delivery → status is `out_for_delivery`
   - [ ] Delivery complete → status is `delivered`

**Deliverable:** Updated code with enum, migration script, test results

---

### Fix 2.2: Inventory Deduction Timing
**Owner:** Inventory Specialist  
**Time:** 45 min  
**Current Issue:** Stock may deduct on order creation instead of payment confirmation

**Action Items:**
1. **Understand Current Flow:**
   - [ ] Trace code path: Order creation → inventory reservation → payment → deduction
   - [ ] Identify where stock is actually deducted (which service?)
   - [ ] Check if deduction is idempotent (safe if called twice?)

2. **Fix Deduction Timing:**
   - [ ] Ensure deduction happens ONLY in payment success webhook
   - [ ] Add idempotency check: if stock already deducted, skip
   - [ ] Add transaction ID to prevent double-deduction

3. **Update Inventory Service:**
   - [ ] `/backend/src/services/InventoryTransactionService.js` - add deduction idempotency
   - [ ] Create transaction log: timestamp, order_id, sku, quantity_deducted, webhook_event_id

4. **Test Scenarios:**
   - [ ] Payment fails → stock NOT deducted
   - [ ] Payment success → stock deducted once
   - [ ] Webhook received twice (Razorpay retry) → stock deducted only once

**Deliverable:** Updated inventory service, test results showing idempotency working

---

### Fix 2.3: Delivery Status Queries
**Owner:** Backend Engineer  
**Time:** 30 min  
**Current Issue:** Rider queries use bare strings (`"packed"`) that don't match Firestore enum (`"OrderStatus.packed"`)

**Action Items:**
1. **Find All Queries:**
   - [ ] Search codebase for `status: "packed"` (bare string queries)
   - [ ] Search for `status: "out_for_delivery"` patterns
   - [ ] Find delivery.js route that queries rider orders

2. **Fix Query Logic:**
   - [ ] Update query to use: `status == OrderStatus.packed` (enum)
   - [ ] Add test: Create packed order, verify rider app can query it
   - [ ] Verify rider sees correct orders to deliver

3. **Code Changes:**
   - [ ] `/backend/src/routes/delivery.js` - fix rider order query
   - [ ] Any status comparison logic - use enum

**Test:**
   - [ ] Create order, confirm, pack it (set status to `packed`)
   - [ ] Query as rider: Get list of orders with status=packed
   - [ ] Verify order appears in results (currently it won't)

**Deliverable:** Fixed queries, test showing orders appear for riders

---

### Fix 2.4: Refund Calculation - GST Documentation & Tests
**Owner:** Backend Engineer + E-Commerce Specialist  
**Time:** 30 min  
**Current Issue:** GST handling in refunds unclear, needs test cases

**Action Items:**
1. **Document GST Refund Rules:**
   ```
   Refund Formula:
   - Refund Amount = Order Total - Cancellation Fee
   - GST Treatment: Included in Order Total
   - Example:
     * Item: ₹100 (incl. ₹18 GST)
     * Cancellation fee: ₹10
     * Refund: ₹100 - ₹10 = ₹90
     * (GST not separately added/removed; it's already in the total)
   ```

2. **Add Test Cases:**
   ```javascript
   // Test 1: Basic refund
   Order: ₹100 (incl. ₹18 GST)
   Fee: ₹0
   Expected refund: ₹100

   // Test 2: With cancellation fee
   Order: ₹100 (incl. ₹18 GST)
   Fee: ₹10
   Expected refund: ₹90

   // Test 3: Partial refund (wrong item removed)
   Order: ₹100 (2 items, ₹50 each)
   Fee: ₹0
   Item removed: ₹50
   Expected refund: ₹50

   // Test 4: Rounding edge case
   Order: ₹999.99
   Fee: ₹5.50
   Expected refund: ₹994.49
   ```

3. **Update Refund Service:**
   - [ ] Add calculation function: `calculateRefundAmount(orderTotal, cancellationFee, itemsRemoved)`
   - [ ] Add unit test file: `/backend/src/__tests__/refund.test.js`
   - [ ] Add JSDoc comments explaining GST treatment

4. **Verify In Code:**
   - [ ] Search for refund calculation logic
   - [ ] Add tests to Jest suite

**Deliverable:** Test file with 5+ test cases, all passing

---

## PHASE 3: MOBILE APP & ERROR HANDLING (1.5 hours)

### Fix 3.1: Mobile Error Handling
**Owner:** Mobile Engineer  
**Time:** 1 hour  
**Current Issue:** Backend error JSON shown to user instead of friendly messages

**Action Items:**
1. **Create Error Message Mapper:**
   ```dart
   // lib/utils/error_handler.dart
   
   String getUserFriendlyError(String errorCode, String? message) {
     switch (errorCode) {
       case 'rate_limited':
         return 'Too many requests. Please try again in a few minutes.';
       case 'invalid_otp':
         return 'Invalid OTP. Please check and try again.';
       case 'otp_expired':
         return 'OTP expired. Please request a new one.';
       case 'pin_locked':
         return 'Too many failed attempts. Try again in 30 minutes.';
       case 'payment_failed':
         return 'Payment failed. Please try another payment method.';
       case 'out_of_stock':
         return 'Item is out of stock. Please choose another.';
       // ... more cases
       default:
         return message ?? 'Something went wrong. Please try again.';
     }
   }
   ```

2. **Update API Call Handlers:**
   - [ ] `/lib/services/api_service.dart` - catch errors, map using handler
   - [ ] Show mapped error to user in UI
   - [ ] Log original error for debugging

3. **Update All Screens:**
   - [ ] Auth screens - show user-friendly errors
   - [ ] Cart/checkout screens - show payment errors
   - [ ] Order tracking - show refund status errors

4. **Test:**
   - [ ] Intentionally trigger rate limit → see friendly message
   - [ ] Wrong OTP → see "Invalid OTP" message
   - [ ] Payment failure → see "Payment failed" message

**Deliverable:** Error handler utility, updated screens, test results

---

### Fix 3.2: Concurrent Order Protection
**Owner:** Backend Engineer  
**Time:** 30 min  
**Current Issue:** Two simultaneous orders from same user could oversell inventory

**Action Items:**
1. **Add Transaction-Level Locking:**
   - [ ] When order created, lock inventory for that SKU
   - [ ] Prevent simultaneous stock reservations
   - [ ] Release lock on payment failure or order cancellation

2. **Implementation Approach:**
   - [ ] Use Firestore `runTransaction()` for order creation + stock reservation
   - [ ] Or use Redis lock with expiry (if Redis available)
   - [ ] Or update order creation endpoint with conflict detection

3. **Code Changes:**
   - [ ] `/backend/src/routes/orders.js` - wrap in transaction
   - [ ] Test: Create 2 orders rapidly, verify only 1 succeeds if inventory insufficient

4. **Test Scenario:**
   ```
   - Inventory: 1 unit of SKU-123
   - User creates order 1: 1x SKU-123 (succeeds)
   - User creates order 2: 1x SKU-123 (simultaneously, should fail with "out_of_stock")
   - Verify: Only order 1 is created, order 2 rejected
   ```

**Deliverable:** Transaction-locked order creation, test results showing collision protection

---

## PHASE 4: TESTING & VERIFICATION (2 hours)

### Fix 4.1: Unit Test Suite
**Owner:** Test Writer  
**Time:** 1 hour  
**Action Items:**
1. **Add Tests for:**
   - [ ] Auth: OTP validation, token refresh, rate limiting
   - [ ] Payments: Webhook signature validation, idempotency
   - [ ] Orders: Status transitions, concurrent creation, refund calculation
   - [ ] Inventory: Stock deduction, reservation, collision detection
   - [ ] Coupons: One-time use, discount calculation
   - [ ] Wallets: Balance accuracy, refund credit

2. **Test Framework:**
   - Backend: Jest (Node.js)
   - Mobile: Flutter test framework

3. **Coverage Target:** >70% of critical business logic

**Deliverable:** Jest test suite with 30+ tests, all passing

---

### Fix 4.2: End-to-End Flow Testing
**Owner:** E2E Test Engineer  
**Time:** 1 hour  
**Happy Path:** Login → Browse → Cart → Checkout → Payment → Packing → Delivery → Confirm

**Failure Paths:**
- Payment fails → Retry succeeds
- Order cancelled → Refund processed
- Delivery OTP validation

**Tools:**
- Mobile: Detox
- Web: Cypress (if applicable)

**Test Scenarios:**
- [ ] Happy path: Full order completion
- [ ] Refund path: Cancel order, receive refund to wallet
- [ ] Failure recovery: Payment fails, retry succeeds
- [ ] Concurrent orders: Multiple users, no inventory collision
- [ ] Mobile + Web parity: Same flows work on both

**Deliverable:** E2E test suite, execution report with screenshots/videos

---

## PHASE 5: DEPLOYMENT (1 hour)

### Deploy 5.1: Backend Deploy
**Owner:** DevOps Engineer  
**Time:** 20 min
- [ ] Deploy backend code changes
- [ ] Deploy Firestore rules updates
- [ ] Verify webhook endpoints responding
- [ ] Smoke test: Call /health endpoint

### Deploy 5.2: APK Build & Sign
**Owner:** Android Engineer  
**Time:** 30 min
- [ ] Build APK with latest code
- [ ] Sign with production key
- [ ] Verify no secrets in binary
- [ ] Prepare for WhatsApp distribution

### Deploy 5.3: Live Verification
**Owner:** QA Lead  
**Time:** 10 min
- [ ] Run smoke test on live backend
- [ ] Test full order flow in production
- [ ] Verify WhatsApp APK distribution works

**Deliverable:** Deployment log, smoke test results, live system verification

---

## SUCCESS CRITERIA

✅ All P0 issues resolved  
✅ All P1 issues fixed and tested  
✅ Unit test coverage > 70%  
✅ E2E flows verify working end-to-end  
✅ Secrets rotated and secured  
✅ Backend deployed successfully  
✅ APK built, signed, ready for distribution  
✅ Zero security vulnerabilities in automated scan  
✅ Launch readiness score: 85-90/100

---

## TIMELINE SUMMARY

| Phase | Duration | Owner | Status |
|-------|----------|-------|--------|
| 1. P0 Fixes | 1 hour | DevOps, Firebase, Payments | 🟡 In Progress |
| 2. P1 Fixes | 3 hours | Backend, E-Commerce, Mobile | 🟡 In Progress |
| 3. Mobile + Error Handling | 1.5 hours | Mobile, Backend | 🟡 In Progress |
| 4. Testing | 2 hours | QA | 🔴 Pending |
| 5. Deployment | 1 hour | DevOps | 🔴 Pending |
| **Total** | **~8.5 hours** | | |

**Launch Deadline:** 6:30 PM (10.5 hours available)  
**Buffer:** 2 hours for unexpected issues  

---

**Status:** 🔄 EXECUTION IN PROGRESS  
**Last Updated:** 2026-06-23 08:00  
**Owner:** Full AI Company Team

