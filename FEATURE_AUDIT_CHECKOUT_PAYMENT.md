# FUFAJI STORE — FEATURE AUDIT & QUALITY REPORT
## CHECKOUT & PAYMENT SYSTEM

**Audit Date**: 2026-07-04  
**Feature Status**: ⚠️ PARTIAL (10/12 endpoints)  
**Current Quality Score**: 62/100  
**Target Quality Score**: 95+/100  
**Estimated Effort to 95+**: 40-50 hours

---

## Executive Summary

**Checkout & Payment** is the revenue-critical flow. Currently 83% complete but missing 2 endpoints and has several integration gaps:

- ✅ Cart management working (Firestore-backed)
- ✅ Basic order creation working (atomic transaction)
- ✅ Razorpay payment initiated (test mode)
- ✅ Webhook signature verification fixed
- ⚠️ Missing: Shipping calculation endpoint
- ⚠️ Missing: Advanced payment methods endpoint
- ⚠️ No comprehensive error handling
- ⚠️ No coupon integration in checkout flow
- ⚠️ No inventory locking during checkout

**Risk Level**: HIGH — Payment failures directly impact revenue

---

## Current Architecture State

### Endpoints Implemented (10/12)
```
✅ POST /checkout/add-item              → Add to Firestore cart
✅ GET /checkout/cart                   → Fetch from Firestore
✅ PUT /checkout/update-item            → Modify quantity
✅ DELETE /checkout/remove-item         → Remove from cart
✅ POST /checkout/clear                 → Clear cart
✅ POST /checkout/create-order          → Atomic: reserve → create → sync
✅ GET /checkout/validate               → Check stock availability
✅ POST /checkout/apply-coupon          → Apply discount (PARTIAL)
✅ GET /checkout/saved-addresses        → Fetch saved addresses
✅ POST /checkout/save-address          → Save new address

❌ GET /checkout/shipping               → MISSING (calculate rates)
❌ POST /checkout/payment-methods       → MISSING (advanced methods)
```

### Technology Stack
```
Frontend (Flutter):
  └── Firestore cart (real-time)
  └── AsyncStorage persistence
  
Backend (Node.js + Express):
  └── SupabaseService (query wrapper)
  └── SupabaseInventoryService (stock check)
  └── SupabaseOrderService (order creation)
  └── PaymentService (Razorpay integration)
  
Database:
  └── Firestore: carts collection
  └── Supabase: orders, order_items, inventory, payments
  
Payment Gateway:
  └── Razorpay (test mode)
  └── Webhook handler at /webhook/razorpay
```

### Key Issues Found

**Critical (Must Fix)**:
1. No inventory locking during checkout → risk of overselling
2. Coupon application not wired into order creation → discounts lost
3. No shipping calculation → can't show final total
4. Weak error handling → customer confusion on failure

**Major (Should Fix)**:
1. No retry logic for failed payment → customer thinks payment failed but got charged
2. No delivery address validation → orders ship to wrong place
3. Cart not synced between devices → data loss
4. No payment method selection → only UPI/card default

**Minor (Nice to Have)**:
1. No order confirmation screen
2. No invoice generation
3. No payment receipt email
4. No estimated delivery time shown

---

## Quality Scoring Framework

### Scoring Matrix (0-100)

```
Architecture (20 points)
  └─ Schema design: 4 pts
  └─ Service separation: 4 pts
  └─ Error handling: 4 pts
  └─ Async/transaction handling: 4 pts
  └─ Database indexing: 2 pts
  Current: 12/20 (60%) — Missing transactions, weak error handling

API Design (15 points)
  └─ Endpoint completeness: 3 pts → 2.5/3 (10/12 endpoints)
  └─ Request/response format: 3 pts → 3/3 ✅
  └─ Error responses: 3 pts → 1.5/3 (generic errors)
  └─ Validation: 3 pts → 2/3 (missing shipping validation)
  └─ Documentation: 3 pts → 0.5/3 (minimal docs)
  Current: 10/15 (67%)

Implementation (20 points)
  └─ Code quality: 4 pts → 2.5/4 (needs refactor)
  └─ Test coverage: 4 pts → 1/4 (no unit tests)
  └─ Error recovery: 4 pts → 1/4 (no retry logic)
  └─ Performance: 4 pts → 3/4 (<500ms except order creation)
  └─ Logging: 4 pts → 2/4 (partial logging)
  Current: 10/20 (50%)

Integration (15 points)
  └─ Firebase ↔ Supabase sync: 3 pts → 2/3 (delays)
  └─ Inventory ↔ Order coupling: 3 pts → 1/3 (no locking)
  └─ Coupon ↔ Order integration: 3 pts → 0/3 (not integrated)
  └─ Payment ↔ Order workflow: 3 pts → 2/3 (works, but weak error handling)
  └─ Notification triggers: 3 pts → 1/3 (minimal notifications)
  Current: 6/15 (40%)

Security (15 points)
  └─ Input validation: 3 pts → 2/3 (address, email not fully validated)
  └─ Authorization: 3 pts → 3/3 ✅
  └─ Payment security: 3 pts → 3/3 ✅ (HMAC verified)
  └─ PCI compliance: 3 pts → 3/3 ✅ (no raw cards stored)
  └─ Rate limiting: 3 pts → 0/3 (not implemented)
  Current: 14/15 (93%) ✅

User Experience (15 points)
  └─ Checkout flow: 3 pts → 2.5/3 (no confirmation screen)
  └─ Error messages: 3 pts → 1.5/3 (generic)
  └─ Loading states: 3 pts → 2/3 (partial spinners)
  └─ Mobile responsiveness: 3 pts → 2/3 (works, not optimized)
  └─ Accessibility: 3 pts → 1/3 (not WCAG compliant)
  Current: 9/15 (60%)

TOTAL SCORE: 12+10+10+6+14+9 = 61/100 (61%)
```

Current breakdown:
- Architecture: 60%
- API Design: 67%
- Implementation: 50%
- Integration: 40% ⚠️ LOWEST
- Security: 93% ✅ HIGHEST
- UX: 60%

**Biggest gaps**: Integration (40%) and Implementation (50%)

---

## 25 Major Tasks with 10 Subtasks Each

### PHASE 1: FOUNDATIONS (Tasks 1-5)

---

### **TASK 1: Inventory Locking & Reservation System**
**Priority**: CRITICAL | **Effort**: 6 hours | **Current Status**: 30% (reserve exists, no lock)

Implement dual-layer inventory locking to prevent overselling during checkout.

#### Subtask 1.1: Implement Redis Distributed Lock
**Goal**: Use Redis to lock inventory row during checkout  
**Files**: backend/src/services/RedisLockService.js (NEW)  
**Acceptance**: Lock acquired within 50ms, timeout after 30s

```javascript
class RedisLockService {
  async acquireLock(productId, shopId, durationMs = 30000) {
    // SET key WITH NX (only if not exists) + EX (expiry)
    // Return lock token for release
  }
  
  async releaseLock(productId, shopId, token) {
    // Verify token matches before releasing
  }
  
  async isLocked(productId, shopId) {
    // Check if currently locked
  }
}
```

#### Subtask 1.2: Integrate Lock into Inventory Reserve
**File**: backend/src/services/SupabaseInventoryService.js (MODIFY)  
**Current code**:
```javascript
async reserveStock(productId, shopId, quantity) {
  const inventory = await this.getInventory(productId, shopId);
  if (available < quantity) throw new Error('Insufficient stock');
  await supabaseService.rawQuery('reserve_inventory', {...});
}
```

**New code**:
```javascript
async reserveStock(productId, shopId, quantity) {
  const lockToken = await redisLock.acquireLock(productId, shopId);
  try {
    const inventory = await this.getInventory(productId, shopId);
    if (available < quantity) throw new Error('Insufficient stock');
    await supabaseService.rawQuery('reserve_inventory', {...});
  } finally {
    await redisLock.releaseLock(productId, shopId, lockToken);
  }
}
```

**Acceptance**: Lock prevents concurrent reservations, <100ms latency

#### Subtask 1.3: Add PostgreSQL Row-Level Lock (SELECT...FOR UPDATE)
**File**: backend/src/db/queries.js (NEW)  
**Goal**: Add FOR UPDATE clause to inventory select during transactions

```sql
SELECT * FROM inventory 
WHERE product_id = $1 AND shop_id = $2 
FOR UPDATE;  -- Lock row until transaction commits
```

**Acceptance**: Concurrent transactions wait instead of conflict

#### Subtask 1.4: Implement Lock Timeout & Release Logic
**File**: backend/src/services/SupabaseOrderService.js  
**Goal**: Release inventory lock if order creation fails or times out

**Acceptance**: Lock auto-released after 30s even if server crashes

#### Subtask 1.5: Add Lock Status Endpoint (Admin)
**Endpoint**: GET /admin/inventory-locks  
**Returns**: List of currently locked products, lock age, holder

**Acceptance**: Admin can see lock state for debugging

#### Subtask 1.6: Handle Lock Timeout Gracefully
**File**: backend/src/routes/checkout.js  
**Goal**: If lock acquired for >10s, return error to user: "Item busy, try again"

**Acceptance**: User sees clear message, can retry

#### Subtask 1.7: Test Lock Under Concurrent Load
**Test File**: backend/tests/checkout-concurrent.test.js (NEW)  
**Scenario**: 10 simultaneous checkout requests for same product with 5 available

**Expected**: Exactly 5 succeed, 5 fail with "insufficient stock"

#### Subtask 1.8: Add Metrics Tracking
**File**: backend/src/monitoring/metrics.js  
**Track**:
- Lock acquisition time (p50, p95, p99)
- Lock failures (timeout/conflict)
- Oversell incidents (should be 0)

**Acceptance**: Dashboard shows 0 oversells, <100ms p99 lock time

#### Subtask 1.9: Document Lock Timeout Strategy
**File**: backend/docs/INVENTORY_LOCKING.md (NEW)  
**Cover**:
- How locks work
- Timeout behavior
- Failure scenarios
- Recovery procedures

#### Subtask 1.10: Implement Lock Monitoring & Alerts
**Goal**: Alert if lock held for >20s (possible deadlock)

**Acceptance**: Alert triggers for stuck locks, operator can force-release

**Status**: ⏳ NOT STARTED  
**Estimated Time**: 6 hours  
**Blocker**: Needs Redis setup (if not already present)

---

### **TASK 2: Coupon Integration into Checkout Flow**
**Priority**: CRITICAL | **Effort**: 4 hours | **Current Status**: 10% (endpoint exists, not integrated)

Wire CouponService into order creation to actually apply discounts.

#### Subtask 2.1: Add Coupon Validation in Checkout Controller
**File**: backend/src/routes/checkout.js (MODIFY)  
**Location**: POST /checkout/create-order handler

**Current flow**:
```javascript
POST /checkout/create-order {orderId, items, addressId}
→ Create order with total_price = sum of item prices * (1 + GST)
```

**New flow**:
```javascript
POST /checkout/create-order {orderId, items, addressId, couponCode}
→ Validate coupon (CouponService.validateAndApply)
→ Calculate discount
→ Create order with coupon_id + discount_amount
→ Update total_price = (sum - discount)
```

**Acceptance**: Discount appears in order_items.discount_amount

#### Subtask 2.2: Modify Order Schema to Store Coupon
**File**: backend/migrations/XX_add_coupon_to_orders.sql (NEW)

```sql
ALTER TABLE orders ADD COLUMN coupon_id UUID REFERENCES coupons(id);
ALTER TABLE orders ADD COLUMN discount_amount DECIMAL(10,2) DEFAULT 0;
ALTER TABLE orders ADD COLUMN original_total DECIMAL(10,2);
```

**Acceptance**: Migration runs without error

#### Subtask 2.3: Update Order Creation Service
**File**: backend/src/services/SupabaseOrderService.js (MODIFY)

**Change**:
```javascript
async createOrder({items, addressId, couponId, userId}) {
  const subtotal = calculateSubtotal(items); // sum without GST
  const gst = subtotal * 0.18;
  const subtotalWithGst = subtotal + gst;
  
  let discount = 0;
  if (couponId) {
    const coupon = await supabaseService.query('coupons', 'select', {
      filters: {id: couponId}
    });
    discount = calculateDiscount(coupon[0], subtotalWithGst);
  }
  
  const finalTotal = subtotalWithGst - discount;
  
  // Create order with coupon tracking
  return await supabaseService.query('orders', 'insert', {
    payload: {
      user_id: userId,
      coupon_id: couponId,
      original_total: subtotalWithGst,
      discount_amount: discount,
      total_price: finalTotal,
      status: 'pending'
    }
  });
}
```

**Acceptance**: Order created with correct discount applied

#### Subtask 2.4: Prevent Coupon Reuse in Same Session
**File**: backend/src/services/CouponService.js (MODIFY)

**Logic**: After order created, mark coupon as used

```javascript
async markAsUsed(couponId) {
  await supabaseService.query('coupons', 'update', {
    payload: {used_count: raw('used_count + 1')},
    filters: {id: couponId}
  });
}
```

**Call this** after order confirmed (in payment webhook handler)

**Acceptance**: Coupon used_count increments, no double-usage

#### Subtask 2.5: Display Discount in Order Summary
**File**: Flutter app's CheckoutScreen.dart (MODIFY)

**Show**:
```
Subtotal:        ₹1000
GST (18%):        ₹180
Subtotal + GST:  ₹1180
Discount:         -₹118  (using WELCOME10)
Final Total:     ₹1062
```

**Acceptance**: UX shows discount breakdown clearly

#### Subtask 2.6: Add Coupon Validation Error Handling
**File**: backend/src/routes/checkout.js

**Scenarios**:
- Invalid coupon code → 400: "Coupon not found"
- Expired coupon → 400: "Coupon expired"
- Usage limit reached → 400: "Coupon limit exceeded"
- Min order value not met → 400: "Min order ₹X required"
- Not applicable to items → 400: "Coupon not valid for these items"

**Acceptance**: Each error returns specific message

#### Subtask 2.7: Test Coupon Application with Various Cases
**Test File**: backend/tests/checkout-coupon.test.js (NEW)

**Cases**:
1. Valid coupon (percentage) → discount calculated correctly
2. Valid coupon (fixed amount) → discount applied correctly
3. Expired coupon → error
4. Max discount capped → discount not exceeding cap
5. Min order value not met → error
6. Category restrictions → error if items not applicable

**Acceptance**: All 6 cases pass

#### Subtask 2.8: Sync Coupon Usage to Firestore
**File**: backend/src/services/SyncQueue.js (MODIFY)

**Event**: Order created with coupon → sync coupon.used_count to Firestore

**Acceptance**: Firestore coupons collection has updated used_count

#### Subtask 2.9: Add Coupon Analytics Tracking
**File**: backend/src/monitoring/analytics.js

**Track**:
- Coupon usage rate (% of orders with coupon)
- Most used coupons
- Avg discount per order
- Revenue impact of coupons

**Acceptance**: Dashboard shows coupon metrics

#### Subtask 2.10: Document Coupon Workflow
**File**: backend/docs/CHECKOUT_COUPON_WORKFLOW.md (NEW)

**Cover**:
- How coupon validation works
- Discount calculation formula
- Error scenarios
- Testing procedures

**Status**: ⏳ NOT STARTED  
**Estimated Time**: 4 hours  
**Dependencies**: CouponService ready (Task 4 in IMPLEMENTATION_ROADMAP)

---

### **TASK 3: Shipping Calculation Endpoint**
**Priority**: CRITICAL | **Effort**: 5 hours | **Current Status**: 0% (MISSING)

Implement GET /checkout/shipping to calculate delivery charges.

#### Subtask 3.1: Design Shipping Rate Model
**File**: backend/docs/SHIPPING_RATE_MODEL.md (NEW)

**Rate structure**:
```
Base rate: ₹50 (free if order > ₹500)
Distance-based:
  0-2 km: +₹0
  2-5 km: +₹20
  5-10 km: +₹40
  10+ km: +₹60
Weight-based:
  0-1 kg: +₹0
  1-5 kg: +₹20
  5-10 kg: +₹50
```

**Acceptance**: Rate model documented and approved

#### Subtask 3.2: Create ShippingService Class
**File**: backend/src/services/ShippingService.js (NEW)

```javascript
class ShippingService {
  async calculateShipping(orderId, cartItems, deliveryAddress) {
    const totalWeight = calculateWeight(cartItems);
    const distance = calculateDistance(deliveryAddress);
    const baseRate = 50;
    const distanceFee = getDistanceFee(distance);
    const weightFee = getWeightFee(totalWeight);
    const subtotal = calculateSubtotal(cartItems);
    
    let shippingCost = baseRate + distanceFee + weightFee;
    if (subtotal > 500) shippingCost = 0; // free shipping
    
    return {
      baseRate,
      distanceFee,
      weightFee,
      shippingCost,
      breakdown: {base: baseRate, distance: distanceFee, weight: weightFee}
    };
  }
}
```

**Acceptance**: Service returns shipping cost breakdown

#### Subtask 3.3: Implement Distance Calculation
**File**: backend/src/utils/distance.js (NEW)

**Use**: Google Maps Distance API or Haversine formula

```javascript
function haversineDistance(lat1, lon1, lat2, lon2) {
  // Calculate km between two lat/lon points
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}
```

**Acceptance**: Distance calculated within 5% accuracy

#### Subtask 3.4: Create Shipping Calculator Endpoint
**Endpoint**: GET /checkout/shipping  
**Input**: {cartItems, deliveryAddressId}  
**Output**: {shippingCost, breakdown, estimatedDeliveryDate}

```javascript
router.get('/shipping', authMiddleware, async (req, res) => {
  try {
    const {cartItems, deliveryAddressId} = req.query;
    const address = await getAddress(deliveryAddressId);
    const shipping = await ShippingService.calculateShipping(
      cartItems, address
    );
    res.json({success: true, data: shipping});
  } catch (err) {
    res.status(400).json({success: false, error: err.message});
  }
});
```

**Acceptance**: Endpoint returns shipping in <200ms

#### Subtask 3.5: Integrate Shipping into Order Total
**File**: backend/src/services/SupabaseOrderService.js (MODIFY)

**Change**:
```javascript
async createOrder({items, addressId, couponId}) {
  const subtotal = calculateSubtotal(items);
  const gst = subtotal * 0.18;
  const shipping = await ShippingService.calculateShipping(items, addressId);
  const discount = couponId ? getCouponDiscount(...) : 0;
  
  const finalTotal = subtotal + gst + shipping.cost - discount;
  
  // Create order with shipping tracked
  return await supabaseService.query('orders', 'insert', {
    payload: {
      ...order,
      shipping_cost: shipping.cost,
      total_price: finalTotal
    }
  });
}
```

**Acceptance**: Shipping cost included in order.total_price

#### Subtask 3.6: Add Shipping Cost to Database Schema
**File**: backend/migrations/XX_add_shipping_to_orders.sql (NEW)

```sql
ALTER TABLE orders ADD COLUMN shipping_cost DECIMAL(10,2) DEFAULT 0;
ALTER TABLE orders ADD COLUMN estimated_delivery_date DATE;
```

**Acceptance**: Migration runs, orders table has shipping columns

#### Subtask 3.7: Calculate Estimated Delivery Date
**File**: backend/src/utils/delivery.js (NEW)

**Logic**:
- Same city: next day delivery (18:00)
- <10 km: 1-2 days delivery
- >10 km: 2-3 days delivery
- Holidays: add buffer days

```javascript
function estimateDeliveryDate(distance, orderTime = new Date()) {
  let deliveryDays = 1;
  if (distance < 10) deliveryDays = 2;
  else if (distance > 25) deliveryDays = 3;
  
  const deliveryDate = new Date(orderTime);
  deliveryDate.setDate(deliveryDate.getDate() + deliveryDays);
  
  return deliveryDate;
}
```

**Acceptance**: Delivery date calculated, shown in checkout

#### Subtask 3.8: Test Shipping Calculation
**Test File**: backend/tests/shipping.test.js (NEW)

**Cases**:
1. Order < ₹500, 2 km away → ₹50 base
2. Order > ₹500, any distance → ₹0 shipping (free)
3. Heavy order (10 kg), 15 km away → base + distance + weight
4. Free shipping applies for qualifying orders

**Acceptance**: All cases pass

#### Subtask 3.9: Display Shipping in Checkout UI
**File**: Flutter CheckoutScreen.dart (MODIFY)

**Show**:
```
Items Subtotal:    ₹1000
GST (18%):          ₹180
Shipping:           ₹50
Discount:          -₹118
TOTAL:            ₹1112

Estimated Delivery: Tomorrow by 6 PM
```

**Acceptance**: UI shows shipping breakdown, delivery estimate

#### Subtask 3.10: Add Shipping Fallback for Address without Coords
**File**: backend/src/services/ShippingService.js

**If address.latitude/longitude missing**:
- Use geocoding API to convert address → lat/lon
- OR use default distance (e.g., 5 km) with warning

**Acceptance**: Shipping calculated even for addresses without GPS

**Status**: ⏳ NOT STARTED  
**Estimated Time**: 5 hours  
**Dependencies**: None (can work in parallel)

---

### **TASK 4: Error Handling & Recovery**
**Priority**: CRITICAL | **Effort**: 6 hours | **Current Status**: 20%

Implement comprehensive error handling + retry logic throughout checkout.

#### Subtask 4.1: Define Error Categories & Codes
**File**: backend/src/constants/errors.js (NEW)

```javascript
const CHECKOUT_ERRORS = {
  // Inventory errors (5000-5099)
  INSUFFICIENT_STOCK: {code: 5001, message: 'Item out of stock', statusCode: 400},
  INVENTORY_LOCK_TIMEOUT: {code: 5002, message: 'Item busy, please try again', statusCode: 503},
  
  // Address errors (5100-5199)
  INVALID_ADDRESS: {code: 5101, message: 'Invalid delivery address', statusCode: 400},
  ADDRESS_NOT_FOUND: {code: 5102, message: 'Address not found', statusCode: 404},
  
  // Coupon errors (5200-5299)
  COUPON_INVALID: {code: 5201, message: 'Coupon code not found', statusCode: 400},
  COUPON_EXPIRED: {code: 5202, message: 'Coupon has expired', statusCode: 400},
  
  // Payment errors (5300-5399)
  PAYMENT_FAILED: {code: 5301, message: 'Payment processing failed', statusCode: 402},
  RAZORPAY_TIMEOUT: {code: 5302, message: 'Payment gateway timeout', statusCode: 504},
  
  // Database errors (5400-5499)
  DB_TRANSACTION_FAILED: {code: 5401, message: 'Order creation failed', statusCode: 500},
  DB_SYNC_FAILED: {code: 5402, message: 'Data sync failed', statusCode: 500},
};
```

**Acceptance**: All error codes documented and unique

#### Subtask 4.2: Implement Custom Error Class
**File**: backend/src/utils/errors.js (NEW)

```javascript
class CheckoutError extends Error {
  constructor(errorDef, details = {}) {
    super(errorDef.message);
    this.code = errorDef.code;
    this.statusCode = errorDef.statusCode;
    this.details = details;
    this.timestamp = new Date().toISOString();
  }
}

// Usage:
throw new CheckoutError(CHECKOUT_ERRORS.INSUFFICIENT_STOCK, {productId: '123'});
```

**Acceptance**: Custom error class can be thrown/caught cleanly

#### Subtask 4.3: Add Global Error Handler Middleware
**File**: backend/src/middleware/errorHandler.js (NEW)

```javascript
function errorHandler(err, req, res, next) {
  if (err instanceof CheckoutError) {
    return res.status(err.statusCode).json({
      success: false,
      error: {
        code: err.code,
        message: err.message,
        details: err.details,
        timestamp: err.timestamp,
        requestId: req.id
      }
    });
  }
  
  // Generic error
  res.status(500).json({
    success: false,
    error: {
      code: 5900,
      message: 'Internal server error',
      requestId: req.id
    }
  });
}
```

**Apply** to express app: `app.use(errorHandler)`

**Acceptance**: Errors return structured JSON with error code

#### Subtask 4.4: Implement Retry Logic for Transient Failures
**File**: backend/src/utils/retry.js (NEW)

```javascript
async function retryAsync(fn, options = {}) {
  const {maxRetries = 3, backoff = exponentialBackoff, timeout = 5000} = options;
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await Promise.race([
        fn(),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Timeout')), timeout)
        )
      ]);
    } catch (err) {
      if (attempt === maxRetries) throw err;
      
      const delayMs = backoff(attempt);
      console.log(`Retry ${attempt}/${maxRetries} after ${delayMs}ms`, err.message);
      await new Promise(resolve => setTimeout(resolve, delayMs));
    }
  }
}

function exponentialBackoff(attempt) {
  return Math.min(1000 * Math.pow(2, attempt - 1), 10000); // 1s, 2s, 4s, max 10s
}
```

**Acceptance**: Transient errors retried automatically

#### Subtask 4.5: Wrap Database Operations with Retry
**File**: backend/src/services/SupabaseOrderService.js (MODIFY)

```javascript
async createOrder(orderData) {
  return await retryAsync(
    () => supabaseService.query('orders', 'insert', {payload: orderData}),
    {maxRetries: 3, timeout: 5000}
  );
}
```

**Acceptance**: DB operations retry on transient failures

#### Subtask 4.6: Handle Payment Webhook Retries
**File**: backend/src/routes/payment-webhook-routes.js (MODIFY)

**Current**: Webhook received once → process

**New**: 
- Webhook may arrive multiple times (Razorpay retry)
- Store processed webhook IDs to prevent double-processing
- Return 200 immediately, process async

```javascript
router.post('/razorpay', async (req, res) => {
  const webhookId = req.body.id;
  
  // Check if already processed
  const processed = await redis.get(`webhook:${webhookId}`);
  if (processed) {
    return res.json({success: true, alreadyProcessed: true});
  }
  
  // Process async (fire-and-forget)
  processWebhookAsync(req.body).catch(err => {
    logger.error('Webhook processing failed', err);
  });
  
  // Mark as received
  await redis.set(`webhook:${webhookId}`, '1', 'EX', 86400); // 24h expiry
  
  res.json({success: true});
});
```

**Acceptance**: Duplicate webhooks don't cause double-charges

#### Subtask 4.7: Implement Dead-Letter Queue (DLQ) for Failed Orders
**File**: backend/src/services/DLQService.js (NEW)

**Logic**: If order creation fails after 3 retries → push to DLQ

```javascript
class DLQService {
  async pushFailed(orderData, error, retryCount) {
    await supabaseService.query('dlq_orders', 'insert', {
      payload: {
        order_data: orderData,
        error_message: error.message,
        retry_count: retryCount,
        created_at: new Date(),
        status: 'pending_manual_review'
      }
    });
    
    // Alert ops
    await notifyOps(`Order creation failed after 3 retries: ${orderData.id}`);
  }
  
  async getFailedOrders() {
    return await supabaseService.query('dlq_orders', 'select', {
      filters: {status: 'pending_manual_review'}
    });
  }
}
```

**Acceptance**: Failed orders visible in admin panel for manual review

#### Subtask 4.8: Test Error Scenarios End-to-End
**Test File**: backend/tests/checkout-errors.test.js (NEW)

**Scenarios**:
1. Insufficient stock → 400 error with code 5001
2. Invalid address → 400 error with code 5101
3. Payment timeout → 504 error, retry happens automatically
4. Webhook duplicate → second webhook ignored
5. DB transaction fails → order in DLQ for review

**Acceptance**: All scenarios handled gracefully

#### Subtask 4.9: Add Error Logging & Monitoring
**File**: backend/src/monitoring/errorTracking.js (NEW)

**Track**:
- Error frequency by code
- Error → resolution time
- User impact (orders lost, refunds needed)
- Patterns (which errors repeat)

**Acceptance**: Error dashboard shows all failures + trends

#### Subtask 4.10: Create Runbook for Error Recovery
**File**: backend/docs/ERROR_RECOVERY_RUNBOOK.md (NEW)

**Cover**:
- Common errors and fixes
- How to access DLQ
- How to manually retry failed orders
- Escalation procedures
- Prevention (how to avoid errors)

**Acceptance**: Ops team can self-serve 80% of issues

**Status**: ⏳ NOT STARTED  
**Estimated Time**: 6 hours  
**Dependencies**: Basic error handling exists, needs enhancement

---

### **TASK 5: Comprehensive Testing Suite**
**Priority**: HIGH | **Effort**: 8 hours | **Current Status**: 5%

Implement unit, integration, and E2E tests for checkout.

#### Subtask 5.1: Setup Jest + Supertest
**File**: backend/jest.config.js (NEW)

```javascript
module.exports = {
  testEnvironment: 'node',
  testTimeout: 10000,
  collectCoverageFrom: ['src/**/*.js'],
  coveragePathIgnorePatterns: ['/node_modules/'],
};
```

Install: `npm install --save-dev jest supertest`

**Acceptance**: `npm test` runs successfully with 0 errors

#### Subtask 5.2: Write Unit Tests for ShippingService
**File**: backend/tests/services/shipping.test.js (NEW)

```javascript
describe('ShippingService', () => {
  test('free shipping for order > 500', async () => {
    const shipping = await ShippingService.calculateShipping(
      [item1, item2], // subtotal ₹600
      address
    );
    expect(shipping.cost).toBe(0);
  });
  
  test('base rate ₹50 for order < 500', async () => {
    const shipping = await ShippingService.calculateShipping(
      [item1], // subtotal ₹300
      address
    );
    expect(shipping.cost).toBe(50);
  });
  
  test('distance fee calculated correctly', async () => {
    const shipping = await ShippingService.calculateShipping(
      items,
      address // 15 km away
    );
    expect(shipping.breakdown.distance).toBe(40);
  });
});
```

**Acceptance**: 5+ tests pass, 100% ShippingService coverage

#### Subtask 5.3: Write Unit Tests for CouponService
**File**: backend/tests/services/coupon.test.js (NEW)

```javascript
describe('CouponService', () => {
  test('percentage discount calculated correctly', async () => {
    const result = await CouponService.validateAndApply({
      couponCode: 'SAVE10',
      orderTotal: 1000,
      userId: 'user1',
      items: []
    });
    expect(result.discount).toBe(100); // 10% of 1000
    expect(result.finalTotal).toBe(900);
  });
  
  test('coupon expired → error', async () => {
    await expect(CouponService.validateAndApply({
      couponCode: 'EXPIRED',
      orderTotal: 1000
    })).rejects.toThrow('Coupon expired');
  });
  
  test('coupon usage limit exceeded → error', async () => {
    // Create coupon with maxUsage: 1, used_count: 1
    await expect(CouponService.validateAndApply({
      couponCode: 'LIMITED'
    })).rejects.toThrow('Coupon usage limit exceeded');
  });
});
```

**Acceptance**: 5+ tests pass, edge cases covered

#### Subtask 5.4: Write Integration Tests for Checkout Flow
**File**: backend/tests/checkout-flow.test.js (NEW)

```javascript
describe('Checkout Flow', () => {
  test('complete checkout: cart → validate → order → payment', async () => {
    // 1. Add item to cart
    const cartRes = await request(app)
      .post('/api/checkout/add-item')
      .set('Authorization', `Bearer ${jwtToken}`)
      .send({productId: 'prod1', quantity: 2});
    
    expect(cartRes.status).toBe(200);
    expect(cartRes.body.data.itemCount).toBe(2);
    
    // 2. Validate order
    const validateRes = await request(app)
      .post('/api/checkout/validate')
      .set('Authorization', `Bearer ${jwtToken}`)
      .send({items: [{productId: 'prod1', quantity: 2}]});
    
    expect(validateRes.status).toBe(200);
    expect(validateRes.body.data.valid).toBe(true);
    
    // 3. Create order
    const orderRes = await request(app)
      .post('/api/checkout/create-order')
      .set('Authorization', `Bearer ${jwtToken}`)
      .send({
        items: [{productId: 'prod1', quantity: 2}],
        addressId: 'addr1',
        couponCode: 'WELCOME10'
      });
    
    expect(orderRes.status).toBe(200);
    const orderId = orderRes.body.data.id;
    expect(orderRes.body.data.discount_amount).toBeGreaterThan(0);
    
    // 4. Verify order in database
    const orderInDb = await supabaseService.query('orders', 'select', {
      filters: {id: orderId}
    });
    expect(orderInDb[0].status).toBe('pending');
  });
});
```

**Acceptance**: End-to-end flow test passes

#### Subtask 5.5: Write Concurrent Load Test
**File**: backend/tests/checkout-concurrent.test.js (NEW)

```javascript
test('10 concurrent checkouts for 5 available items → 5 succeed, 5 fail', async () => {
  const promises = [];
  
  for (let i = 0; i < 10; i++) {
    promises.push(
      request(app)
        .post('/api/checkout/create-order')
        .set('Authorization', `Bearer ${jwtToken_${i}}`)
        .send({
          items: [{productId: 'limited-stock', quantity: 1}],
          addressId: 'addr1'
        })
    );
  }
  
  const results = await Promise.allSettled(promises);
  
  const succeeded = results.filter(r => r.status === 'fulfilled').length;
  const failed = results.filter(r => r.status === 'rejected').length;
  
  expect(succeeded).toBe(5);
  expect(failed).toBe(5);
});
```

**Acceptance**: Concurrent test passes, no overselling

#### Subtask 5.6: Write Payment Webhook Test
**File**: backend/tests/payment-webhook.test.js (NEW)

```javascript
test('webhook received → payment status updated → order confirmed', async () => {
  // 1. Create order in pending state
  const order = await createTestOrder({status: 'pending'});
  
  // 2. Send webhook from Razorpay
  const webhookRes = await request(app)
    .post('/api/webhook/razorpay')
    .send({
      payload: {
        payment: {
          entity: {
            id: 'pay_123',
            order_id: order.razorpay_order_id,
            amount: 100000,
            status: 'captured'
          }
        }
      },
      'X-Razorpay-Signature': computeHMAC(webhookData)
    });
  
  expect(webhookRes.status).toBe(200);
  
  // 3. Verify payment created
  const payment = await supabaseService.query('payments', 'select', {
    filters: {razorpay_payment_id: 'pay_123'}
  });
  expect(payment[0].status).toBe('completed');
  
  // 4. Verify order status updated
  const updatedOrder = await supabaseService.query('orders', 'select', {
    filters: {id: order.id}
  });
  expect(updatedOrder[0].status).toBe('confirmed');
});
```

**Acceptance**: Webhook flow test passes

#### Subtask 5.7: Write Error Scenario Tests
**File**: backend/tests/checkout-errors.test.js (NEW)

```javascript
describe('Error Scenarios', () => {
  test('insufficient stock → 400 error', async () => {
    const res = await request(app)
      .post('/api/checkout/create-order')
      .send({items: [{productId: 'out-of-stock', quantity: 100}]});
    
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe(5001);
  });
  
  test('invalid address → 400 error', async () => {
    const res = await request(app)
      .post('/api/checkout/create-order')
      .send({addressId: 'invalid-addr-id'});
    
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe(5102);
  });
  
  test('expired coupon → 400 error', async () => {
    const res = await request(app)
      .post('/api/checkout/apply-coupon')
      .send({couponCode: 'EXPIRED_2020'});
    
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe(5202);
  });
});
```

**Acceptance**: Error scenario tests pass

#### Subtask 5.8: Setup Code Coverage Reporting
**File**: backend/package.json (MODIFY)

```json
{
  "scripts": {
    "test": "jest --coverage",
    "test:watch": "jest --watch"
  }
}
```

Run: `npm test`

**Acceptance**: Coverage report generated, >80% coverage target

#### Subtask 5.9: Write Performance Tests
**File**: backend/tests/checkout-performance.test.js (NEW)

```javascript
test('order creation completes in <500ms', async () => {
  const start = Date.now();
  
  await request(app)
    .post('/api/checkout/create-order')
    .send(orderData);
  
  const duration = Date.now() - start;
  expect(duration).toBeLessThan(500);
});

test('shipping calculation completes in <200ms', async () => {
  const start = Date.now();
  
  await request(app)
    .get('/api/checkout/shipping')
    .query({cartItems: cartData});
  
  const duration = Date.now() - start;
  expect(duration).toBeLessThan(200);
});
```

**Acceptance**: Performance targets met

#### Subtask 5.10: Document Test Suite
**File**: backend/docs/TESTING_GUIDE.md (NEW)

**Cover**:
- How to run tests
- How to write new tests
- Test naming conventions
- Coverage targets
- CI/CD integration

**Acceptance**: New devs can write tests following guide

**Status**: ⏳ NOT STARTED  
**Estimated Time**: 8 hours  
**Dependencies**: None

---

## Summary of Phase 1 (Tasks 1-5)

| Task | Priority | Hours | Current | Target | Gap |
|------|----------|-------|---------|--------|-----|
| 1. Inventory Locking | CRITICAL | 6 | 30% | 100% | 70% |
| 2. Coupon Integration | CRITICAL | 4 | 10% | 100% | 90% |
| 3. Shipping Endpoint | CRITICAL | 5 | 0% | 100% | 100% |
| 4. Error Handling | CRITICAL | 6 | 20% | 100% | 80% |
| 5. Testing Suite | HIGH | 8 | 5% | 100% | 95% |

**Phase 1 Totals**: 29 hours, 50 subtasks  
**Phase 1 Score Improvement**: 62/100 → ~78/100 (16 points)

---

## PHASE 2: ADVANCED FEATURES (Tasks 6-10) [ABBREVIATED]

### **TASK 6: Order Confirmation & Receipt**
- Subtask 6.1-6.10: Confirmation screen, invoice PDF, email receipt, SMS confirmation
- **Current**: 0% | **Target**: 100% | **Hours**: 4

### **TASK 7: Cart Sync Between Devices**
- Subtask 7.1-7.10: Multi-device cart sync, conflict resolution, offline support
- **Current**: 20% | **Target**: 100% | **Hours**: 5

### **TASK 8: Advanced Payment Methods**
- Subtask 8.1-8.10: Saved payment methods, wallet integration, installments
- **Current**: 0% | **Target**: 100% | **Hours**: 6

### **TASK 9: Delivery Address Validation**
- Subtask 9.1-7.10: Address geocoding, service area check, pincode validation
- **Current**: 40% | **Target**: 100% | **Hours**: 4

### **TASK 10: Performance Optimization**
- Subtask 10.1-10.10: Database query optimization, caching strategy, CDN integration
- **Current**: 50% | **Target**: 100% | **Hours**: 6

**Phase 2 Totals**: 25 hours, 50 subtasks  
**Phase 2 Score**: 78 + 12 = 90/100

---

## PHASE 3: POLISH & LAUNCH (Tasks 11-15) [ABBREVIATED]

### **TASK 11: Accessibility (WCAG 2.1 AA)**
- Subtask 11.1-11.10: Color contrast, keyboard nav, screen reader support
- **Current**: 30% | **Target**: 100% | **Hours**: 5

### **TASK 12: Mobile Responsiveness**
- Subtask 12.1-12.10: Responsive design, touch optimization, orientation handling
- **Current**: 60% | **Target**: 100% | **Hours**: 4

### **TASK 13: Analytics & Monitoring**
- Subtask 13.1-13.10: Conversion tracking, error monitoring, performance metrics
- **Current**: 20% | **Target**: 100% | **Hours**: 5

### **TASK 14: Security Hardening**
- Subtask 14.1-14.10: Rate limiting, input validation, SQL injection prevention
- **Current**: 70% | **Target**: 100% | **Hours**: 4

### **TASK 15: Launch Readiness**
- Subtask 15.1-15.10: Production checklist, backup strategy, rollback plan
- **Current**: 40% | **Target**: 100% | **Hours**: 4

**Phase 3 Totals**: 22 hours, 50 subtasks  
**Phase 3 Score**: 90 + 5 = 95+/100 ✅

---

## Expected Quality Score Progression

```
Current:         62/100 ⚠️
After Phase 1:   78/100 (Good)
After Phase 2:   90/100 (Excellent)
After Phase 3:   95+/100 (Production Ready) ✅
```

---

## Estimated Timeline

| Phase | Tasks | Hours | Days (8h/day) | End Date |
|-------|-------|-------|---------------|----------|
| 1 | 1-5 | 29 | 4 days | Jul 8 |
| 2 | 6-10 | 25 | 3 days | Jul 11 |
| 3 | 11-15 | 22 | 3 days | Jul 14 |

**Total**: 76 hours, 15 tasks, 22 days effort (but can be parallelized)

---

## How to Use This Audit

1. **Pick ONE task** from Phase 1
2. **Execute all 10 subtasks** in order
3. **Test thoroughly** (include subtask 5 tests)
4. **Score that task** using the rubric
5. **Repeat** for remaining tasks

**This week's priority**: Tasks 1-3 (inventory, coupon, shipping) = **Revenue-critical**

---

