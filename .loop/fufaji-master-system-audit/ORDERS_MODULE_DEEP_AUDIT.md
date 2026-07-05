# ORDERS MODULE — DEEP AUDIT & IMPLEMENTATION PLAN

**Date:** 2026-07-05
**Module:** Orders (core business logic)
**Scope:** Complete order lifecycle — creation → payment → fulfillment → delivery → completion

---

## CURRENT IMPLEMENTATION STATE

### Files Analyzed
- `/backend/src/routes/orders.js` — Order management endpoints
- `/backend/src/routes/orders_v2.js` — DEAD (to be deleted)
- `/backend/src/routes/checkout-routes.js` — Checkout & payment flow
- `/backend/src/services/SupabaseOrderService.js` — Order CRUD
- `/backend/src/services/OrderStatusService.js` — Status management
- `/backend/src/services/checkout-service.js` — Atomic checkout (NOT YET READ - CRITICAL)
- `/backend/src/services/PaymentService.js` — Payment processing
- `/backend/src/services/InventoryTransactionService.js` — Stock management

### Implemented
✅ Order creation with inventory reservation
✅ Payment webhook (Razorpay) integration
✅ Order status state machine (pending → confirmed → processing → packed → delivered)
✅ Refund with stock restoration
✅ Customer notifications (FCM + WhatsApp + in-app)
✅ Low stock alerts (WhatsApp to owner)
✅ Idempotency key checking
✅ Delivery address capture
✅ Coupon & shipping calculations

---

## CRITICAL GAPS FOUND

### GAP 1: **MISSING ORDER CONFIRMATION LOGIC** 🔴 P0

**Issue:** 
- Checkout creates order + reserves stock
- Payment webhook arrives (payment.authorized or payment.captured)
- BUT: No clear logic to move order from `pending` → `confirmed` state

**Current flow reads:**
1. POST /checkout/create-order → creates order in Supabase, returns paymentOrderId
2. Frontend initiates payment with Razorpay
3. Razorpay webhook POST /webhooks/razorpay → payment.authorized/captured
4. Webhook should update order status to `confirmed`
5. **ISSUE:** Webhook in `/routes/webhooks.js` writes to PostgreSQL + outbox_events, BUT does NOT check if order exists or update its status

**Location:** `/backend/src/routes/webhooks.js` lines 190-302

**Fix Needed:**
```javascript
// After signature validation + idempotency check:
// 1. Find order by razorpay_order_id
// 2. Update order status: pending → confirmed
// 3. Emit outbox_event for Firestore sync
// 4. Log audit event
```

**Impact:** Orders stuck in `pending` state in production = business doesn't know they're confirmed

---

### GAP 2: **MISSING ORDER STATUS TRANSITIONS** 🔴 P0

**Issue:**
OrderStatusService.normalizeStatus() has 8 statuses:
- `pending`, `payment_verified`, `ready_to_pack`, `packed`, `assigned_to_delivery`, `out_for_delivery`, `delivered`, `cancelled`, `refunded`, `returned`

But SupabaseOrderService.updateOrderStatus() only recognizes 7:
- `pending`, `confirmed`, `preparing`, `ready_for_pickup`, `out_for_delivery`, `delivered`, `cancelled`

**Mismatch:**
- OrderStatusService expects `PAYMENT_VERIFIED` but SupabaseOrderService uses `confirmed`
- OrderStatusService expects `ASSIGNED_TO_DELIVERY` but SupabaseOrderService doesn't have it
- OrderStatusService has `refunded` & `returned` but SupabaseOrderService doesn't handle transitions to these

**Location:**
- OrderStatusService.js lines 9-20 (status enum)
- SupabaseOrderService.js lines 113-121 (valid statuses)

**Fix Needed:**
Unified status enum. Define canonical order state machine:
```
pending → payment_verified → ready_to_pack → packed → assigned_to_delivery → out_for_delivery → delivered
                                                    ↓
                                               cancelled (any state)
                                                    ↓
                                               refunded (payment_verified+)
                                                    ↓
                                               returned (delivered only)
```

**Impact:** Status queries break, rider app shows wrong orders, payment verification stuck

---

### GAP 3: **MISSING INVENTORY CONFIRMATION AFTER PAYMENT** 🔴 P0

**Issue:**
POST /checkout/create-order reserves stock (3-layer: available → reserved)
But POST /inventory/confirm endpoint isn't wired to webhook flow

**Current code:**
```javascript
// checkout-routes.js line 104-120
router.post('/confirm', authMiddleware, async (req, res) => {
  const { reservationId, orderId, paymentId } = req.body;
  // ... validates, then calls InventoryService.confirmReservation()
```

**Problem:**
- This endpoint expects manual call from frontend
- Frontend doesn't know when to call it (should be called by payment webhook)
- If call fails, reserved stock never moves to `sold` state
- Result: Inventory stays in `reserved` forever, blocks future orders

**Flow should be:**
1. Razorpay webhook → payment.authorized
2. Webhook calls POST /inventory/confirm (internally, not frontend)
3. Reserved stock → sold
4. Order status → confirmed

**Location:** `/backend/src/routes/checkout-routes.js` lines 104-120

**Fix Needed:**
In webhook handler (webhooks.js), after order status update:
```javascript
await axios.post('http://localhost:3001/checkout/confirm', {
  reservationId: order.reservationId,
  orderId: order.id,
  paymentId: payment.id
}, { headers: { 'Authorization': `Bearer ${serviceToken}` } });
```

**Impact:** Stock never confirmed, inventory audit fails, duplicate orders possible

---

### GAP 4: **MISSING CANCELLATION & REFUND WORKFLOW** 🔴 P0

**Issue:**
- OrderStatusService.processRefund() exists (lines 73-100)
- But NO endpoint to trigger it
- No API to cancel an order
- No handling of partial cancellations

**Current:**
- No POST /orders/:orderId/cancel endpoint
- No POST /orders/:orderId/refund endpoint
- processRefund() called internally but never from routes

**Flow should be:**
1. Customer clicks "Cancel Order"
2. POST /orders/:orderId/cancel
3. Check order status (can only cancel if pending/confirmed/processing)
4. Release reserved stock
5. If payment confirmed: refund via Razorpay API
6. Update order status → cancelled
7. Notify customer

**Location:** Missing from `/backend/src/routes/orders.js`

**Fix Needed:**
```javascript
// In orders.js
router.post('/:orderId/cancel', authMiddleware, async (req, res) => {
  const orderId = req.params.orderId;
  const reason = req.body.reason || 'customer_request';
  
  // 1. Get order
  // 2. Check status can be cancelled
  // 3. Release stock
  // 4. Process refund if needed
  // 5. Update status → cancelled
  // 6. Emit outbox_event
  // 7. Notify customer
});
```

**Impact:** Customers can't cancel orders, no refunds, stuck payments

---

### GAP 5: **NO DELIVERY OTP VERIFICATION** 🔴 P0

**Issue:**
- Order has OTP field (orders.js line 39-41 sets it for `outForDelivery` status)
- But no endpoint to verify OTP at delivery
- Rider can mark order delivered without OTP check

**Current:**
```javascript
// orders.js line 39-41
case 'outForDelivery':
  const otp = orderData.otp || 'N/A';
  const rider = orderData.deliveryEmployeeName || 'a rider';
  body = `Our rider (${rider}) is on the way! 🚴 Your Delivery OTP is: ${otp}`;
```

**Missing:**
- No POST /orders/:orderId/verify-delivery-otp endpoint
- No validation before marking delivered
- No audit trail of who verified

**Flow should be:**
1. Rider at customer location
2. Rider enters OTP from app
3. POST /orders/:orderId/verify-delivery-otp with { otp, riderId }
4. If OTP matches: mark order → delivered
5. Log verification in audit_logs
6. Send confirmation notification

**Location:** Missing from `/backend/src/routes/orders.js`

**Fix Needed:**
```javascript
router.post('/:orderId/verify-delivery-otp', authMiddleware, async (req, res) => {
  const { otp, riderId } = req.body;
  // Verify OTP
  // Update order status
  // Audit log
  // Notify
});
```

**Impact:** Fraud risk (delivery without verification), no proof of delivery

---

### GAP 6: **MISSING ORDER RETURN WORKFLOW** 🔴 P0

**Issue:**
- OrderStatusService has `RETURNED` status
- But no endpoint to initiate returns
- No return reason tracking
- No return refund automation

**Current:** Status exists but no workflow

**Missing:**
- POST /orders/:orderId/initiate-return
- No return reason capture
- No refund approval flow
- No reverse logistics

**Flow should be:**
1. Customer clicks "Return"
2. POST /orders/:orderId/initiate-return with { reason, photos }
3. Order status → pending_return
4. Owner reviews & approves/rejects
5. If approved: refund issued
6. Status → returned

**Location:** Missing entirely from `/backend/src/routes/orders.js`

**Impact:** Can't handle returns, customer dissatisfaction, no policy enforcement

---

### GAP 7: **MISSING PARTIAL FULFILLMENT** 🟡 P1

**Issue:**
- Inventory supports partial orders (3-layer model)
- But orders.js assumes all-or-nothing fulfillment
- No `partial_fulfillment` status

**Current:**
- If 1 item out of 5 is out of stock: entire order fails
- No option to ship 4 items, backorder 1

**Missing:**
- Ability to split order into shipments
- Backorder logic
- Notification for partial shipments

**Fix Needed:**
Add `partial_fulfillment` status and logic to split orders

**Impact:** Customer can't get partial delivery, lost sales

---

### GAP 8: **MISSING DELIVERY FAILURE HANDLING** 🟡 P1

**Issue:**
- No "delivery_failed" status
- No auto-retry logic
- No customer notifi cation for failed deliveries

**Current:**
- Rider can only mark delivered or (implicitly) fail to mark
- No formal failure process

**Missing:**
- POST /orders/:orderId/delivery-failed with { reason }
- Auto-reassign to another rider
- Retry scheduling
- Customer notification

**Flow should be:**
1. Rider tries delivery
2. Delivery fails (customer not home, refused, etc.)
3. POST /orders/:orderId/delivery-failed { reason }
4. Order status → delivery_failed
5. Auto-assign to rider with 2+ retries
6. Or offer self-pickup option

**Impact:** Stuck deliveries, customer confusion, no escalation

---

### GAP 9: **NO ORDER TRACKING PAGE** 🟡 P1

**Issue:**
- Order status exists but customers can't track
- No GET /orders/:orderId/track endpoint
- No timeline of status changes

**Current:**
- Orders have status but no historical trail
- No last_updated timestamp
- No "order arrived at hub" milestones

**Missing:**
- GET /orders/:orderId/track returns: current status + timeline
- Historical status changes with timestamps
- Rider location (if out_for_delivery)
- Estimated delivery time

**Fix Needed:**
```javascript
GET /orders/:orderId/track returns:
{
  current_status: "out_for_delivery",
  timeline: [
    { status: "confirmed", timestamp: "2026-07-05T10:00Z", message: "Order confirmed" },
    { status: "processing", timestamp: "2026-07-05T10:30Z", message: "Packing order" },
    { status: "packed", timestamp: "2026-07-05T11:00Z", message: "Ready for pickup" },
    { status: "out_for_delivery", timestamp: "2026-07-05T14:00Z", message: "With rider" }
  ],
  rider: { name, phone, location },
  estimated_delivery: "2026-07-05T15:00Z"
}
```

**Impact:** Customer anxiety, support calls, bad UX

---

### GAP 10: **MISSING ORDER ANALYTICS & METRICS** 🟡 P1

**Issue:**
- No KPI tracking
- No order funnel analysis
- No abandoned cart metrics

**Missing:**
- Orders created vs confirmed ratio (conversion)
- Average order value trend
- Cancellation rate by status
- Refund analysis
- Delivery success rate

**Impact:** No visibility into business health, can't optimize

---

## WIRING ISSUES FOUND

### Issue A: **Checkout Service Not Implemented**

**Location:** `/backend/src/services/checkout-service.js`

**Status:** File exists but content unknown (not read yet)

**Problem:** This is the CRITICAL piece that orchestrates:
1. Inventory reservation
2. Razorpay order creation
3. Order creation in DB
4. Idempotency check

If broken here, entire checkout fails.

**REQUIRED:** Read and audit this file completely

---

### Issue B: **Payment Service Webhook Callback Missing**

**Location:** `/backend/src/routes/webhooks.js` (P0-1 from audit)

**Problem:** Webhook receives payment confirmation but doesn't call downstream services:
- Doesn't confirm inventory
- Doesn't update order status
- Doesn't trigger notifications

Should call:
1. SupabaseOrderService.updateOrderStatus()
2. InventoryService.confirmReservation()
3. notifyCustomer()

---

### Issue C: **Cross-Service Dependencies Unclear**

**Example:**
- notifyCustomer() in orders.js (line 9-107) is copy-pasted, not shared
- Notification logic duplicated in multiple places
- If you change notification format in one place, others break

**Should be:** Centralized NotificationService

---

## MISSING FEATURES CHECKLIST

### Core Order Lifecycle
- [ ] Order creation ✅
- [ ] Payment verification ⚠️ (webhook wiring broken)
- [ ] Order confirmation ❌ (no status update from webhook)
- [ ] Stock confirmation ❌ (no automation after payment)
- [ ] Packing ⚠️ (manual, no automation)
- [ ] Dispatch to rider ✅
- [ ] Out for delivery ✅
- [ ] **Delivery OTP verification ❌**
- [ ] Delivery confirmation ⚠️ (no OTP check)
- [ ] Order completion ✅
- [ ] **Order cancellation ❌**
- [ ] **Refund processing ⚠️** (service exists, no endpoint)
- [ ] **Return handling ❌**
- [ ] **Partial fulfillment ❌**
- [ ] **Delivery retry ❌**

### Customer Experience
- [ ] Order tracking ❌
- [ ] Status notifications ✅
- [ ] Delivery OTP ✅ (sent but not verified)
- [ ] Cancellation option ❌
- [ ] Return option ❌

### Operations & Analytics
- [ ] Order analytics ❌
- [ ] Funnel metrics ❌
- [ ] Cancellation tracking ⚠️
- [ ] Delivery performance ❌

---

## IMPLEMENTATION PRIORITY

### P0 (BLOCKING PRODUCTION)
1. **Fix payment webhook → order status update** (orders.js + webhooks.js)
2. **Implement inventory confirmation after payment** (checkout flow)
3. **Fix status enum mismatch** (unified state machine)
4. **Add order cancellation endpoint** (orders.js)
5. **Add delivery OTP verification** (orders.js + delivery.js)

### P1 (CORE FEATURES)
6. **Add return initiation & approval** (orders.js)
7. **Add delivery failure handling** (orders.js + delivery.js)
8. **Add order tracking page** (GET /orders/:id/track)
9. **Implement partial fulfillment** (inventory + orders)
10. **Add order analytics** (reports.js + dashboard)

### P2 (OPTIMIZATION)
11. Refactor duplicate notification logic → NotificationService
12. Automate packing workflow
13. Add delivery timeout & auto-retry

---

## FILES TO MODIFY

| File | Changes | P-Level |
|------|---------|---------|
| `/backend/src/routes/webhooks.js` | Add order status update after payment verification | P0 |
| `/backend/src/routes/orders.js` | Add cancel, refund, return, verify-delivery-otp endpoints | P0 |
| `/backend/src/routes/checkout-routes.js` | Automate inventory confirmation after payment | P0 |
| `/backend/src/services/OrderStatusService.js` | Unify status enum, add state machine validation | P0 |
| `/backend/src/services/SupabaseOrderService.js` | Add tracking endpoint, update status transitions | P0 |
| `/backend/src/services/NotificationService.js` | **NEW** — centralize notification logic | P1 |
| `/backend/src/services/DeliveryService.js` | Add OTP verification, failure handling, retry | P0 |
| `/backend/src/routes/delivery.js` | Integrate delivery service endpoints | P0 |

---

## NEXT IMMEDIATE ACTIONS

1. **Read checkout-service.js completely** — it's the orchestrator
2. **Read PaymentService.js** — payment flow
3. **Read DeliveryService.js** — delivery logic
4. **Create unified Order State Machine diagram** (state transitions + validation)
5. **Implement P0 fixes** (in order of business impact)

---

**END ORDERS MODULE AUDIT**

Next: Read remaining files, then move to Payment Module audit.
