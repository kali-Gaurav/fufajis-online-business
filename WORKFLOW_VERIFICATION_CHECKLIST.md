# Workflow Verification Checklist

**Purpose**: QA/Developer verification before production deployment  
**Timeline**: Should complete in 4-6 hours with test data  
**Owner**: QA Lead + Backend Lead

---

## Pre-Verification Setup (30 minutes)

### Firestore Collections Created
```
❏ orders/
❏ fulfillment_tasks/
❏ delivery_tasks/
❏ returns/
❏ loyalty/
❏ loyalty_transactions/
❏ referrals/
❏ audit_logs/
```

### Test Data Seeded
```
❏ 3 test shops created
❏ 5 test employees per shop
❏ 3 test riders
❏ 10 test customers with wallet balances
❏ 20 test products with stock > 0
```

### Environment Setup
```
❏ APK built with all new services
❏ Deployed to 5 test devices
❏ Crashlytics enabled and monitoring
❏ Firestore rules updated
❏ Firebase console accessible
```

---

## 1. Order Workflow Verification (60 minutes)

### 1.1 Order Creation (10 min)
```
Test: Create order
Preconditions:
  - Customer logged in
  - Shop selected
  - 2+ items in cart (5+ quantity each)
  - Total ≥ ₹100

Steps:
  1. Click "Place Order"
  2. Enter delivery address
  3. Click "Continue to Payment"

Verification:
  ❏ Order created in firestore/orders with status='pending'
  ❏ Order ID generated (ORD-timestamp-hash)
  ❏ Order number shown to user
  ❏ Inventory NOT deducted (status=pending)
  ❏ No wallet charged
  ❏ Audit log created (order_created)
  ❏ Customer can see order in "My Orders" → "Pending"

Failure Case:
  - Try placing 2 identical orders in 30 seconds
  ❏ Second order blocked: "Your order is already being placed"
  ❏ No duplicate in Firestore
```

### 1.2 Order Confirmation (10 min)
```
Test: Confirm order after payment
Preconditions:
  - Order in pending status
  - Payment processed (mock Razorpay payment)

Steps:
  1. Payment gateway returns success
  2. App triggers OrderWorkflowService.confirmOrder()
  3. Wait 2 seconds

Verification:
  ❏ Order status changed to 'confirmed'
  ❏ Payment status = 'verified'
  ❏ Payment ID stored
  ❏ Inventory RESERVED for each item
    - Check inventory_ledger_service logs
    - Product stock still shows available
    - But 'reserved' counter incremented
  ❏ Fulfillment task CREATED (new status)
  ❏ Shop receives notification
    - In Firestore: notification_logs entry
    - In app: Shop sees new order dashboard
  ❏ Audit log: order_confirmed event
  ❏ Customer sees order in "Confirmed" status

Failure Case:
  - Try confirming order twice
  ❏ Second attempt fails: "Order already confirmed"
  ❏ No duplicate inventory reservation
```

### 1.3 Order Packing (10 min)
```
Test: Mark order as packed
Preconditions:
  - Order in 'confirmed' status
  - Fulfillment task exists (status='new')

Steps:
  1. Employee assigned to task
  2. All items marked picked
  3. QC verified items
  4. Click "Mark Packed"

Verification:
  ❏ Order status changed to 'packed'
  ❏ Inventory DEDUCTED (reserved → actual)
    - Check product stock decreased
    - Inventory ledger shows deduction
  ❏ Delivery task CREATED (status='assigned')
  ❏ Customer notified: "Order packed, delivery coming"
  ❏ Audit log: order_packed event

Edge Case:
  - Cancel before packing marked
  ❏ Inventory released (deduction undone)
  ❏ Refund processed
```

### 1.4 Order Shipped (10 min)
```
Test: Mark order as shipped (rider pickup)
Preconditions:
  - Order in 'packed' status
  - Rider assigned to delivery task

Steps:
  1. Rider clicks "Picked Up"
  2. Select order from delivery list

Verification:
  ❏ Order status changed to 'shipped'
  ❏ Delivery task status = 'picked_up'
  ❏ Rider ID, name, phone stored
  ❏ Customer notified with rider details
    - Notification shows: "Rider [name] is on the way"
    - Shows rider phone number
  ❏ Audit log: order_shipped event

Tracking:
  ❏ GPS location updates start
  ❏ Delivery task status auto-transitions to 'in_transit'
  ❏ Customer sees real-time map
```

### 1.5 Order Delivered (10 min)
```
Test: Mark order as delivered
Preconditions:
  - Order in 'shipped' status
  - Rider at delivery location

Steps:
  1. Rider clicks "Delivered"
  2. Captures customer signature/photo
  3. Confirms delivery

Verification:
  ❏ Order status changed to 'delivered'
  ❏ Delivery task status = 'delivered'
  ❏ Loyalty points AWARDED
    - For ₹500 order: 50 points (bronze tier)
    - For ₹500 order with silver: 62.5 points
    - Check loyalty account balance increased
    - Check loyalty_transactions has entry
  ❏ Customer notified: "Order delivered! Rate your experience"
  ❏ Rating prompt shown in app
  ❏ Audit log: order_delivered event

Verify No Double-Award:
  ❏ Refresh order, check points same
  ❏ Check loyalty_transactions has only 1 entry
```

### 1.6 Order Cancellation (10 min)
```
Test Case 1: Cancel at pending (before payment)
  ❏ No inventory reserved yet
  ❏ No refund (no payment)
  ❏ Status = cancelled
  ❏ Customer notified

Test Case 2: Cancel at confirmed (after payment)
  ❏ Inventory RELEASED
  ❏ Wallet CREDITED with full amount
  ❏ Status = cancelled → refunded
  ❏ Customer sees refund in wallet
  ❏ Audit log: order_cancelled event

Test Case 3: Cannot cancel at delivered
  ❏ Cancel button disabled
  ❏ Error: "Cannot cancel delivered orders"
```

---

## 2. Packing Workflow Verification (45 minutes)

### 2.1 Task Assignment (10 min)
```
Test: Assign fulfillment task to employee
Preconditions:
  - Task in 'new' status
  - Employee logged in

Steps:
  1. Manager clicks "Assign Task"
  2. Selects employee from list
  3. Clicks "Assign"

Verification:
  ❏ Task status changed to 'assigned'
  ❏ Employee ID, name stored
  ❏ Employee receives notification
    - In app: "New packing task assigned"
    - Shows item count
    - "Start Packing" button shown
  ❏ In employee's "Assigned Tasks" list
  ❏ Audit log: fulfillment_assigned event
```

### 2.2 Item Picking (10 min)
```
Test: Employee picks items
Preconditions:
  - Task in 'assigned' status
  - Employee has items list

Steps:
  1. Employee scans/marks first item "picked"
  2. Repeat for remaining items
  3. System detects all items picked

Verification:
  After first item:
  ❏ Task status auto-transitions to 'picking'
  ❏ Item marked as picked in task
  ❏ pickedItems array updated
  
  After all items:
  ❏ Task status auto-transitions to 'quality_check'
  ❏ All items marked picked
  ❏ Employee notified: "Please request QC"
  ❏ Audit log tracks each item pick
```

### 2.3 Quality Check (10 min)
```
Test: QC inspector verifies packing
Preconditions:
  - Task in 'quality_check' status
  - QC team has tasks list

Steps:
  1. QC inspector reviews task
  2. Verifies all items and packing
  3. Clicks "Verify" button

Verification:
  ❏ Task status changed to 'verified'
  ❏ All items marked verified
  ❏ verifiedItems array populated
  ❏ Employee notified: "Packing passed QC, hand off for delivery"
  ❏ Audit log: packing_verified event

Failure Case: Reject packing
  ❏ QC inspector clicks "Reject"
  ❏ Task status = 'rejected'
  ❏ All picked items reset to unpicked
  ❏ Employee notified: "Rejected: [reason]. Please redo."
  ❏ Task can be reassigned
  ❏ Rejection reason logged
```

### 2.4 Task Completion (10 min)
```
Test: Complete packing (hand off to delivery)
Preconditions:
  - Task in 'verified' status
  - Employee ready to hand off

Steps:
  1. Employee clicks "Hand Off to Delivery"
  2. Confirms handoff

Verification:
  ❏ Task status changed to 'completed'
  ❏ Order status auto-updated to 'packed'
  ❏ Delivery task created (if not already)
  ❏ Audit log: fulfillment_completed event
```

---

## 3. Delivery Workflow Verification (45 minutes)

### 3.1 Task Assignment (10 min)
```
Test: Assign delivery task to rider
Preconditions:
  - Delivery task in 'assigned' status
  - Rider app open

Steps:
  1. Dispatcher clicks "Assign Rider"
  2. Selects rider from list
  3. Clicks "Assign"

Verification:
  ❏ Delivery task updated with rider info
  ❏ Rider receives notification:
    - "New delivery order assigned"
    - Shows delivery address
    - Shows customer phone
    - Shows delivery fee
  ❏ In rider's "Assigned Orders" list
  ❏ "Accept" button shown
  ❏ Audit log: rider_assigned event

P0 Bug Verification:
  ❏ Rider query uses correct status values
  ❏ Rider sees the assigned order (NOT empty list)
```

### 3.2 Pickup from Shop (10 min)
```
Test: Rider picks up from shop
Preconditions:
  - Delivery task assigned to rider
  - Rider at shop location

Steps:
  1. Rider clicks "Picked Up"
  2. GPS location captured
  3. Confirms pickup

Verification:
  ❏ Delivery task status changed to 'picked_up'
  ❏ Order status auto-updated to 'shipped'
  ❏ GPS coordinates stored
  ❏ Customer notified: "Rider has picked up your order"
  ❏ Tracking begins
  ❏ Audit log: delivery_picked_up event
```

### 3.3 Real-Time Tracking (15 min)
```
Test: GPS location updates and tracking
Preconditions:
  - Delivery in 'picked_up' status
  - Rider app running with GPS enabled

Steps:
  1. Rider moves location
  2. GPS updates sent every 5 seconds
  3. Customer watches map

Verification - Rider App:
  ❏ Current location shown
  ❏ "Arriving in X minutes" displayed
  ❏ Route to delivery address shown
  
Verification - Customer App:
  ❏ Delivery status auto-transitions to 'in_transit'
  ❏ Map shows real-time rider location
  ❏ Location updates every 5-10 seconds (smooth)
  ❏ Estimated arrival updates
  
Verification - Firestore:
  ❏ trackingUpdates array populated
  ❏ currentLocation field updated
  ❏ lastLocationUpdate field recent
  ❏ Location history complete

Stress Test:
  ❏ 100 location updates in 10 minutes
  ❏ No dropped updates
  ❏ No Firestore quota exceeded
```

### 3.4 Delivery Confirmation (10 min)
```
Test: Rider confirms delivery at customer
Preconditions:
  - Delivery in 'in_transit' status
  - Rider at customer location

Steps:
  1. Rider clicks "Delivered"
  2. Captures signature/photo
  3. Enters delivery notes (optional)
  4. Clicks "Confirm"

Verification:
  ❏ Delivery task status = 'delivered'
  ❏ Order status auto-updated to 'delivered'
  ❏ GPS coordinates stored
  ❏ Customer signature/photo stored
  ❏ Customer notified: "Order delivered! Rate your experience"
  ❏ Loyalty points awarded
  ❏ Delivery fee paid to rider
  ❏ Audit log: delivery_completed event

Verify No State Corruption:
  ❏ Cannot deliver order twice (disabled button)
  ❏ Loyalty points awarded only once
  ❏ Delivery fee paid only once
```

### 3.5 Delivery Failure (10 min)
```
Test: Rider marks delivery failed
Preconditions:
  - Delivery in progress
  - Rider unable to deliver

Steps:
  1. Rider clicks "Mark Failed"
  2. Selects failure reason
  3. Clicks "Submit"

Verification:
  ❏ Delivery task status = 'failed'
  ❏ Failure reason stored
  ❏ Attempt counter = 1
  ❏ Dispatcher notified: "Delivery failed, reassign?"
  ❏ Order status remains 'shipped'
  ❏ Audit log: delivery_failed event

Max Attempts:
  ❏ Allow up to 3 attempts
  ❏ After 3rd failure: notify customer, offer refund
  ❏ Audit log failure attempt count
```

---

## 4. Loyalty Workflow Verification (30 minutes)

### 4.1 Auto-Award Points (10 min)
```
Test: Points awarded after delivery
Preconditions:
  - Order delivered (₹500 order)
  - Customer is bronze tier

Steps:
  1. Check order delivered
  2. Wait 5 seconds
  3. Open customer's loyalty page

Verification:
  ❏ Loyalty account created (if first order)
  ❏ Balance increased by points
    - Bronze: 50 points (500/10)
    - Silver: 62.5 points (500/10 * 1.25)
    - Gold: 75 points (500/10 * 1.5)
  ❏ Lifetime increased by same amount
  ❏ loyalty_transactions entry created
  ❏ Type = 'purchase'
  ❏ Points not double-awarded (refresh page)
  ❏ Tier multiplier correctly applied

Edge Case: Multiple orders
  ❏ Place 10 orders of ₹100 each
  ❏ Total points: 100 (10 * 10)
  ❏ All awarded to account
```

### 4.2 Tier Upgrades (10 min)
```
Test Case 1: Bronze → Silver (2000+ lifetime points)
  Preconditions:
    - Customer has 1999 lifetime points
  
  Steps:
    1. Place order: ₹200 (gets 20 points)
    2. Deliver order
  
  Verification:
    ❏ Lifetime points now = 2019
    ❏ Tier auto-upgraded to silver
    ❏ Customer notified: "Silver tier! 25% bonus points!"
    ❏ Tier upgrade entry in history
    ❏ Audit log: loyalty_tier_upgraded event

Test Case 2: Silver → Gold (5000+ lifetime points)
  Same process but starting at 4980 points
  ❏ Upgrade to gold after sufficient points
  ❏ 50% bonus multiplier activated
  ❏ Customer notified
```

### 4.3 Referral Bonus (10 min)
```
Test: Process referral bonus
Preconditions:
  - Customer A has referral code
  - Customer B uses referral code to signup
  - Customer B places first order

Steps:
  1. System detects referral relationship
  2. Triggers processReferralBonus()
  3. Both customers receive notifications

Verification:
  Referrer (Customer A):
  ❏ Wallet: +₹25
  ❏ Loyalty: +250 points
  ❏ Notification received
  
  Referred (Customer B):
  ❏ Wallet: +₹25
  ❏ Loyalty: +250 points
  ❏ Notification received
  
  Database:
  ❏ referrals entry created
  ❏ Both loyalty accounts updated
  ❏ Audit log: referral_bonus_processed
  
  Verify No Double-Award:
  ❏ Referral can't be reprocessed
  ❏ Each party gets bonus once
```

---

## 5. Returns Workflow Verification (45 minutes)

### 5.1 Request Return (10 min)
```
Test: Customer requests return
Preconditions:
  - Order delivered (3 days ago)
  - Product defective

Steps:
  1. Customer opens order
  2. Clicks "Request Return"
  3. Selects reason "Defective"
  4. Adds description "Bottle leaked"
  5. Uploads 2 photos
  6. Clicks "Submit"

Verification:
  ❏ Return request created
  ❏ Status = 'requested'
  ❏ Reason and photos stored
  ❏ Shop receives notification
  ❏ Return appears in shop's pending returns
  ❏ Audit log: return_requested event

Edge Cases:
  - Request 8 days after delivery
  ❏ Error: "Return window expired (7 days)"
  
  - Order not delivered
  ❏ Error: "Can only return delivered orders"
  
  - Duplicate return request
  ❏ Error: "Return already requested for this order"
```

### 5.2 Shop Approval (10 min)
```
Test: Shop owner approves return
Preconditions:
  - Return in 'requested' status
  - Shop owner reviewing

Steps:
  1. Shop owner opens pending returns
  2. Reviews reason and photos
  3. Clicks "Approve"
  4. Enters refund amount (e.g., 500)
  5. Adds notes "Replacement sent"
  6. Clicks "Approve"

Verification:
  ❏ Return status = 'refund_initiated' → 'refund_completed'
  ❏ Refund amount stored
  ❏ Wallet CREDITED with ₹500
    - Check customer's wallet balance increased
  ❏ Inventory RESTORED
    - Check product stock increased back
  ❏ Order status updated to 'refunded'
  ❏ Customer notified: "Return approved! ₹500 refunded"
  ❏ Audit log: return_approved event

Verify Atomicity:
  ❏ Refund + inventory both processed
  ❏ Or both rolled back (no partial state)
```

### 5.3 Shop Rejection (10 min)
```
Test: Shop owner rejects return
Preconditions:
  - Return in 'requested' status

Steps:
  1. Shop owner clicks "Reject"
  2. Enters rejection reason "Product used"
  3. Clicks "Reject"

Verification:
  ❏ Return status = 'rejected'
  ❏ Rejection reason stored
  ❏ NO REFUND processed (wallet unchanged)
  ❏ NO INVENTORY restored
  ❏ Customer notified: "Return rejected: [reason]"
  ❏ Audit log: return_rejected event
  ❏ Cannot approve rejected return
```

### 5.4 Return Completion (10 min)
```
Test: Goods received and return completed
Preconditions:
  - Return in 'refund_completed' status
  - Goods received by shop

Steps:
  1. Warehouse employee receives goods
  2. Checks condition
  3. Marks return as "Completed"

Verification:
  ❏ Return status = 'completed'
  ❏ Received by field populated
  ❏ Completion timestamp recorded
  ❏ Audit log: return_completed event
```

### 5.5 Return Statistics (5 min)
```
Test: Shop dashboard shows return metrics
Preconditions:
  - 10 returns processed in last 30 days
  - 7 approved, 3 rejected

Steps:
  1. Shop owner opens Analytics
  2. Views Return Statistics

Verification:
  ❏ Total returns: 10
  ❏ Approved: 7
  ❏ Rejected: 3
  ❏ Pending: 0
  ❏ Total refunded: ₹3,500 (sum of 7 approvals)
  ❏ Return rate: 10/100 orders (if 100 orders placed)
```

---

## 6. Integration & Edge Cases (45 minutes)

### 6.1 Complete Happy Path (20 min)
```
Full User Journey:
1. Create order (₹500 order, 2 items)
   ❏ Order created, pending
   
2. Pay for order
   ❏ Order confirmed, stock reserved
   
3. Employee packs
   ❏ Items picked → QC verified → task completed
   ❏ Order packed, stock deducted
   
4. Rider delivers
   ❏ Assigned → picked up → in transit → delivered
   ❏ GPS tracking works
   ❏ Order marked delivered
   
5. Post-delivery
   ❏ Loyalty points awarded (50 for bronze)
   ❏ Customer sees rating prompt
   ❏ Loyalty balance increased

Verification Points:
  ❏ Each state transition logged in audit
  ❏ No data inconsistency
  ❏ All notifications sent
  ❏ Inventory accurate
```

### 6.2 Concurrent Orders (15 min)
```
Test: Multiple orders being processed simultaneously
Preconditions:
  - 5 customers, 3 employees, 2 riders

Steps:
  1. 5 customers place orders simultaneously
  2. 3 employees pick different orders
  3. 2 riders deliver different orders
  4. All operations concurrent

Verification:
  ❏ No inventory oversell
  ❏ No stock corruption
  ❏ No duplicate points awards
  ❏ All orders progress independently
  ❏ Firestore quotas not exceeded
  ❏ No race conditions detected
```

### 6.3 Payment Failure Recovery (10 min)
```
Test: Order with failed payment
Preconditions:
  - Order created, pending

Steps:
  1. User attempts payment
  2. Payment fails
  3. User retries payment after 30 seconds

Verification:
  ❏ Order status still 'pending'
  ❏ No inventory reserved (confirm via ledger)
  ❏ Retry payment succeeds
  ❏ Order confirms normally
  ❏ Stock reserved correctly (not double-reserved)
```

---

## 7. Database Integrity (30 minutes)

### 7.1 Stock Level Verification
```
Test: Stock changes throughout order lifecycle

Product: Milk (initial stock: 100)

Order 1:
  - Confirm: stock reserved (shown as 95 available)
  - Verify: stock deducted (shown as 90 available)
  - Cancel: stock released (shown as 95 available)

Order 2:
  - Confirm: stock reserved (shown as 90 available)
  - Deliver: stock finalized (shown as 89 available)

Order 3:
  - Confirm: stock reserved (shown as 84 available)
  - Request return: still deducted (shown as 84)
  - Approve return: stock restored (shown as 85 available)

Final verification:
  ❏ Stock = 85 (100 - 1 delivered - 1 delivered + 1 returned)
  ❏ No stock < 0
  ❏ Stock ledger matches firestore product inventory
```

### 7.2 Wallet Balance Verification
```
Test: Wallet changes throughout customer lifecycle

Customer initial balance: ₹500

Transaction 1:
  - Place order ₹300
  - Status: pending (wallet unchanged)
  
Transaction 2:
  - Payment confirmed
  - Status: confirmed (wallet unchanged)
  
Transaction 3:
  - Order delivered
  - Loyalty points awarded (50 points = ₹5 value)
  - Status: delivered (wallet unchanged)
  
Transaction 4:
  - Redeem 100 loyalty points
  - Status: 100 points redeemed (wallet = ₹605: ₹500 + ₹100 redemption + ₹5 value)
  
Transaction 5:
  - Referral bonus
  - Status: wallet = ₹630 (₹605 + ₹25 bonus)
  
Transaction 6:
  - Order cancelled with refund ₹300
  - Status: wallet = ₹930 (₹630 + ₹300 refund)

Final verification:
  ❏ Wallet balance = ₹930
  ❏ Audit log shows all transactions
  ❏ Ledger matches Firestore wallet document
  ❏ No funds lost or duplicated
```

### 7.3 Audit Log Completeness
```
Verify all events are logged:

For complete order journey, should have logs:
  ❏ order_created
  ❏ order_confirmed
  ❏ fulfillment_task_created
  ❏ fulfillment_assigned
  ❏ item_picked (2x for 2 items)
  ❏ packing_verified
  ❏ fulfillment_completed
  ❏ delivery_task_created
  ❏ rider_assigned
  ❏ delivery_picked_up
  ❏ delivery_locations (20+ updates)
  ❏ delivery_completed
  ❏ loyalty_points_awarded
  ❏ order_delivered

Total: 30+ audit log entries per order

Verify each entry has:
  ❏ Timestamp
  ❏ User/System ID
  ❏ Event type
  ❏ Relevant IDs (orderId, customerId, etc.)
  ❏ Amounts/counts
```

---

## 8. Performance Testing (30 minutes)

### 8.1 State Transition Speed
```
Test: Measure state transition latency
Preconditions:
  - 100 test orders created

Measurements:
  1. Order creation: < 100ms
     ❏ Average: ____ms
     ❏ P95: ____ms
     ❏ P99: ____ms
  
  2. Order confirmation: < 200ms (multiple writes)
     ❏ Average: ____ms
     ❏ P95: ____ms
  
  3. Mark delivered: < 150ms
     ❏ Average: ____ms
     ❏ P95: ____ms
  
  4. Update location: < 50ms (light operation)
     ❏ Average: ____ms
     ❏ P95: ____ms

Acceptance Criteria:
  ❏ All operations < 500ms
  ❏ P99 latency < 1000ms
  ❏ No timeouts
```

### 8.2 Query Performance
```
Test: Measure query speeds
Preconditions:
  - 1000 orders in firestore
  - 500 delivery tasks
  - 1000 loyalty accounts

Queries:
  1. Get customer orders (limit 20):
     ❏ Latency: ____ms (target: < 100ms)
  
  2. Get shop orders (limit 50):
     ❏ Latency: ____ms (target: < 150ms)
  
  3. Get rider deliveries (limit 10):
     ❏ Latency: ____ms (target: < 50ms)
  
  4. Get return statistics:
     ❏ Latency: ____ms (target: < 200ms)
  
  5. Get leaderboard (limit 20):
     ❏ Latency: ____ms (target: < 100ms)

Acceptance Criteria:
  ❏ All queries < 300ms
  ❏ No reads quota exceeded
```

### 8.3 Concurrent Load Test
```
Test: Handle concurrent operations
Preconditions:
  - Simulate 50 concurrent users
  - Each places order, pays, completes

Measurements:
  ❏ Firestore read quota: ____/100,000
  ❏ Firestore write quota: ____/60,000
  ❏ No quota exceeded
  ❏ No operations failed
  ❏ No data corruption
  ❏ Average completion time: ____s
```

---

## 9. Security & Data Validation

### 9.1 Firestore Rules
```
Verify security rules deployed:
  ❏ Users can only read own orders
  ❏ Users can only read own loyalty data
  ❏ Employees can only access shop's tasks
  ❏ Riders can only access own deliveries
  ❏ Admins can override
  ❏ Test unauthorized access: blocked
```

### 9.2 Input Validation
```
Test invalid inputs:
  ❏ Order amount: 0 or negative → error
  ❏ Quantity: 0 or > stock → error
  ❏ Delivery distance: negative → error
  ❏ Phone: invalid format → error
  ❏ Return days: after 7 days → error
  ❏ Points redemption: > balance → error
```

---

## 10. Final Sign-Off

### QA Sign-Off
```
❏ All order workflow tests passed
❏ All packing workflow tests passed
❏ All delivery workflow tests passed
❏ All loyalty workflow tests passed
❏ All returns workflow tests passed
❏ All integration tests passed
❏ All edge cases handled
❏ Performance within limits
❏ Security rules verified
❏ Database integrity verified
❏ No critical bugs found

QA Lead Name: ___________________
QA Lead Signature: ___________________
Date: ___________________
```

### Backend Lead Sign-Off
```
❏ Code review completed
❏ All services integrated
❏ No memory leaks
❏ Error handling complete
❏ Audit logging complete
❏ Real-time streaming works
❏ State machines validated
❏ Recovery paths tested
❏ Documentation complete
❏ Ready for production

Backend Lead Name: ___________________
Backend Lead Signature: ___________________
Date: ___________________
```

### Product Manager Sign-Off
```
❏ All workflows functioning as designed
❏ User experience smooth
❏ Notifications delivered
❏ Performance acceptable
❏ No critical issues
❏ Ready to ship

PM Name: ___________________
PM Signature: ___________________
Date: ___________________
```

---

## Post-Deployment Monitoring

### Daily Checks (First Week)
```
❏ Order completion rate > 95%
❏ Delivery success rate > 95%
❏ Return approval rate normal
❏ Loyalty points awarded correctly
❏ No Crashlytics critical errors
❏ Firestore quotas < 80%
❏ API response times < 500ms
```

### Weekly Checks
```
❏ Order funnel metrics
❏ Return reason analysis
❏ Delivery SLA tracking
❏ Loyalty tier distribution
❏ Referral success rate
```

---

**Total estimated time: 5-6 hours**  
**Recommended: Spread over 2 days with QA team**

Once all checkboxes complete: ✅ READY FOR PRODUCTION
