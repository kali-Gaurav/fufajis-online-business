# BACKEND IMPLEMENTATION SPECIFICATION
## Checkout & Payment System - Production-Grade Fixes

**Based on**: Architecture Audit by Architecture Agent  
**For**: Backend Development Team  
**Timeline**: 3-4 sprints (estimated 40 hours)  
**Status**: READY FOR IMPLEMENTATION  

---

## CRITICAL ISSUES TO FIX (In Priority Order)

### ISSUE #1: COUPON DISCOUNT SILENTLY IGNORED [CRITICAL]

**File**: `backend/src/services/checkout-service.js` (lines 22-109)  
**Current Problem**:
- Coupon discount calculated client-side
- CouponService.validateAndApply() never called on backend
- Order created with original total (discount lost)
- Razorpay charged wrong amount

**Impact**: Revenue loss (customer gets free discount, company loses margin)

**Fix Required**:

```javascript
// checkout-service.js - BEFORE (broken):
async createOrderWithReservation(checkoutData) {
  const {items, couponCode, deliveryAddressId} = checkoutData;
  const subtotal = calculateSubtotal(items);
  const finalAmount = subtotal;  // ❌ COUPON IGNORED
  
  // Create Razorpay order
  const razorpayOrder = await razorpay.orders.create({
    amount: Math.round(finalAmount * 100),  // ❌ WRONG AMOUNT
    currency: 'INR'
  });
  
  // Create order in DB
  await supabaseService.query('orders', 'insert', {
    payload: {
      total_amount: finalAmount,  // ❌ COUPON NOT DEDUCTED
      razorpay_order_id: razorpayOrder.id
    }
  });
}

// ✅ AFTER (fixed):
async createOrderWithReservation(checkoutData) {
  const {items, couponCode, deliveryAddressId, deliveryType} = checkoutData;
  const subtotal = calculateSubtotal(items);
  
  // ✅ STEP 1: Validate and apply coupon
  let discountAmount = 0;
  let couponId = null;
  if (couponCode) {
    const couponResult = await CouponService.validateAndApply({
      couponCode,
      orderTotal: subtotal,
      userId: checkoutData.userId,
      items: items
    });
    
    if (!couponResult.valid) {
      throw new CheckoutError(CHECKOUT_ERRORS.COUPON_INVALID, {
        couponCode,
        reason: couponResult.error
      });
    }
    
    discountAmount = couponResult.discount;
    couponId = couponResult.couponId;
  }
  
  // ✅ STEP 2: Calculate shipping server-side
  const shippingResult = await ShippingService.calculateFee({
    deliveryType,
    deliveryAddressId,
    subtotal,
    items
  });
  const shippingFee = shippingResult.fee;
  
  // ✅ STEP 3: Calculate final amount (subtotal - discount + shipping)
  const finalAmount = subtotal - discountAmount + shippingFee;
  
  // ✅ STEP 4: Create Razorpay order with CORRECT amount
  const razorpayOrder = await razorpay.orders.create({
    amount: Math.round(finalAmount * 100),  // ✅ CORRECT
    currency: 'INR',
    receipt: `order_${Date.now()}`,
    notes: {
      orderId: uuid(),
      couponCode: couponCode || 'NONE',
      discountAmount: discountAmount,
      shippingFee: shippingFee
    }
  });
  
  // ✅ STEP 5: Create order in DB with all tracking
  const result = await supabaseService.query('orders', 'insert', {
    payload: {
      customer_id: checkoutData.userId,
      subtotal_amount: subtotal,
      discount_amount: discountAmount,
      coupon_id: couponId,
      delivery_fee: shippingFee,
      total_amount: finalAmount,  // ✅ INCLUDES DISCOUNT + SHIPPING
      razorpay_order_id: razorpayOrder.id,
      delivery_type: deliveryType,
      delivery_address_id: deliveryAddressId,
      status: 'pending',
      created_at: new Date()
    }
  });
  
  return {
    orderId: result.rows[0].id,
    paymentOrderId: razorpayOrder.id,
    finalAmount,  // ✅ RETURN TO CLIENT
    breakdown: {
      subtotal,
      discount: discountAmount,
      shipping: shippingFee,
      total: finalAmount
    }
  };
}
```

**Checklist**:
- [ ] Import CouponService at top of checkout-service.js
- [ ] Import ShippingService at top of checkout-service.js
- [ ] Call CouponService.validateAndApply() before Razorpay order creation
- [ ] Add coupon_id + discount_amount columns to orders INSERT
- [ ] Pass correct finalAmount to Razorpay (subtotal - discount + shipping)
- [ ] Return breakdown to client
- [ ] Test with coupon SAVE50 on ₹1000 order (should be ₹950 in Razorpay, not ₹1000)

---

### ISSUE #2: SHIPPING CALCULATION MISSING [CRITICAL]

**File**: `backend/src/services/checkout-service.js` (referenced from ISSUE #1)  
**Current Problem**:
- DeliveryChargeCalculator exists in Flutter only
- No server-side shipping calculation
- CheckoutScreen cannot show final total before payment
- Razorpay amount may not match UI total

**Impact**: Customer confusion, cart abandonment, signature verification failures

**Fix Required** (already shown in ISSUE #1 fix):
- Create ShippingService
- Call ShippingService.calculateFee() in createOrderWithReservation()
- Return shipping fee in response
- Add to orders table

**Create New File**: `backend/src/services/ShippingService.js`

```javascript
const pool = require('../db/pool');

class ShippingService {
  /**
   * Calculate delivery fee based on type and distance
   */
  static async calculateFee({deliveryType, deliveryAddressId, subtotal, items}) {
    try {
      // Fetch delivery address
      const address = await pool.query(
        'SELECT latitude, longitude FROM users_addresses WHERE id = $1',
        [deliveryAddressId]
      );
      
      if (address.rows.length === 0) {
        throw new Error('Delivery address not found');
      }
      
      const {latitude, longitude} = address.rows[0];
      
      // Calculate distance from shop (hardcoded for now, can be config)
      const shopLat = 28.6139;
      const shopLon = 77.2090;
      const distanceKm = this.haversineDistance(shopLat, shopLon, latitude, longitude);
      
      // Calculate weight from items
      const totalWeight = items.reduce((sum, item) => {
        // Assume item.weight_kg exists, or default to 0.5kg per item
        return sum + (item.weight_kg || 0.5);
      }, 0);
      
      // Rate calculation
      let baseFee = 50;
      let distanceFee = 0;
      let weightFee = 0;
      
      // Free shipping for orders > 500
      if (subtotal > 500) {
        baseFee = 0;
      }
      
      // Distance fees
      if (distanceKm <= 2) distanceFee = 0;
      else if (distanceKm <= 5) distanceFee = 20;
      else if (distanceKm <= 10) distanceFee = 40;
      else distanceFee = 60;
      
      // Weight fees
      if (totalWeight <= 1) weightFee = 0;
      else if (totalWeight <= 5) weightFee = 20;
      else if (totalWeight <= 10) weightFee = 50;
      else weightFee = 100;
      
      // Delivery type multiplier
      let multiplier = 1.0;
      if (deliveryType === 'express') multiplier = 1.5;
      else if (deliveryType === 'scheduled') multiplier = 0.8;
      
      const totalFee = Math.round((baseFee + distanceFee + weightFee) * multiplier);
      
      return {
        fee: totalFee,
        breakdown: {base: baseFee, distance: distanceFee, weight: weightFee},
        distance: distanceKm,
        multiplier,
        estimatedDeliveryDate: this.estimateDeliveryDate(distanceKm, deliveryType)
      };
    } catch (error) {
      console.error('[Shipping] Calculate failed:', error.message);
      throw error;
    }
  }
  
  /**
   * Haversine formula for distance calculation
   */
  static haversineDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth radius in km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = 
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }
  
  /**
   * Estimate delivery date based on distance
   */
  static estimateDeliveryDate(distanceKm, deliveryType) {
    const now = new Date();
    let days = 1;
    
    if (distanceKm < 5) {
      days = 0; // Same-day for < 5km
    } else if (distanceKm < 15) {
      days = 1;
    } else {
      days = 2;
    }
    
    if (deliveryType === 'scheduled') days += 1;
    
    const deliveryDate = new Date(now);
    deliveryDate.setDate(deliveryDate.getDate() + days);
    deliveryDate.setHours(18, 0, 0, 0); // 6 PM delivery window
    
    return deliveryDate.toISOString();
  }
}

module.exports = ShippingService;
```

**Create New Endpoint**: `backend/src/routes/shipping.js`

```javascript
const express = require('express');
const router = express.Router();
const ShippingService = require('../services/ShippingService');
const { authMiddleware } = require('../middleware/validation');

/**
 * GET /api/checkout/shipping
 * Calculate shipping fee for selected delivery type and address
 */
router.get('/shipping', authMiddleware, async (req, res) => {
  try {
    const {deliveryType, deliveryAddressId, subtotal, items} = req.query;
    
    if (!deliveryType || !deliveryAddressId) {
      return res.status(400).json({
        success: false,
        error: 'deliveryType and deliveryAddressId required'
      });
    }
    
    // Parse items (JSON string)
    const itemsArray = JSON.parse(items);
    
    const result = await ShippingService.calculateFee({
      deliveryType,
      deliveryAddressId,
      subtotal: parseFloat(subtotal),
      items: itemsArray
    });
    
    res.json({success: true, data: result});
  } catch (err) {
    res.status(500).json({success: false, error: err.message});
  }
});

module.exports = router;
```

**Wire into Express app** (`backend/src/index.js`):
```javascript
app.use('/api/checkout', require('./routes/shipping'));
```

**Checklist**:
- [ ] Create ShippingService.js with calculateFee() method
- [ ] Create shipping.js route with GET /checkout/shipping endpoint
- [ ] Wire route into Express app
- [ ] Test: GET /checkout/shipping?deliveryType=standard&deliveryAddressId=abc123&subtotal=1000&items=[...]
- [ ] Verify response includes: fee, breakdown, estimatedDeliveryDate
- [ ] Call from CheckoutScreen before showing final total

---

### ISSUE #3: PAYMENT WEBHOOK SIGNATURE VERIFICATION BROKEN [CRITICAL]

**File**: `backend/src/routes/payment-webhook-routes.js` (lines 20-48)  
**Current Problem**:
- No idempotency check for duplicate webhooks
- If webhook retried, reservation confirmed twice
- Double notifications, double packing lists
- Payment webhook signature may use wrong secret

**Impact**: Duplicate orders, customer confusion, support burden

**Fix Required**:

```javascript
// BEFORE (broken):
router.post('/razorpay', async (req, res) => {
  const webhookEvent = req.body;
  const razorpay_signature = req.headers['x-razorpay-signature'];
  
  // Verify signature
  const hmac = crypto.createHmac('sha256', process.env.RAZORPAY_WEBHOOK_SECRET);
  hmac.update(JSON.stringify(webhookEvent));
  const digest = hmac.digest('hex');
  
  if (digest !== razorpay_signature) {
    return res.status(400).json({success: false, error: 'Invalid signature'});
  }
  
  // Process event (❌ NO IDEMPOTENCY CHECK)
  const paymentEntity = webhookEvent.payload.payment.entity;
  const razorpay_payment_id = paymentEntity.id;
  const razorpay_order_id = paymentEntity.order_id;
  
  // Update order status directly
  await supabaseService.query('payments', 'insert', {  // ❌ CAN FAIL IF DUPLICATE
    payload: {
      razorpay_payment_id,
      razorpay_order_id,
      status: 'completed'
    }
  });
  
  res.json({success: true});  // ❌ NO 200 OK IMMEDIATELY
});

// ✅ AFTER (fixed):
router.post('/razorpay', async (req, res) => {
  try {
    const webhookEvent = req.body;
    const razorpay_signature = req.headers['x-razorpay-signature'];
    
    // ✅ STEP 1: Verify signature
    const hmac = crypto.createHmac('sha256', process.env.RAZORPAY_WEBHOOK_SECRET);
    hmac.update(JSON.stringify(webhookEvent));
    const digest = hmac.digest('hex');
    
    if (digest !== razorpay_signature) {
      console.error('[Webhook] Invalid signature:', {digest, expected: razorpay_signature});
      return res.status(400).json({success: false, error: 'Invalid signature'});
    }
    
    const paymentEntity = webhookEvent.payload.payment.entity;
    const razorpay_payment_id = paymentEntity.id;
    const razorpay_order_id = paymentEntity.order_id;
    
    // ✅ STEP 2: Return 200 OK immediately (async processing)
    res.json({success: true, message: 'Webhook received'});
    
    // ✅ STEP 3: Process async (fire-and-forget with error handling)
    processWebhookAsync(razorpay_payment_id, razorpay_order_id, webhookEvent).catch(err => {
      console.error('[Webhook] Async processing failed:', err);
      // Log to DLQ for manual review
      logToDeadLetterQueue({
        webhookId: razorpay_payment_id,
        error: err.message,
        webhookData: webhookEvent
      });
    });
    
  } catch (err) {
    console.error('[Webhook] Handler failed:', err);
    res.status(500).json({success: false, error: 'Internal error'});
  }
});

/**
 * Async webhook processing with idempotency
 */
async function processWebhookAsync(razorpay_payment_id, razorpay_order_id, webhookEvent) {
  try {
    // ✅ STEP 1: Check if payment already processed (IDEMPOTENCY KEY)
    const existing = await supabaseService.query('payments', 'select', {
      filters: {razorpay_payment_id}
    });
    
    if (existing.rows.length > 0) {
      console.log('[Webhook] Payment already processed (idempotent):', razorpay_payment_id);
      return; // No-op, already processed
    }
    
    // ✅ STEP 2: Look up order
    const order = await supabaseService.query('orders', 'select', {
      filters: {razorpay_order_id}
    });
    
    if (order.rows.length === 0) {
      console.error('[Webhook] Order not found:', razorpay_order_id);
      throw new Error('Order not found');
    }
    
    const orderId = order.rows[0].id;
    
    // ✅ STEP 3: Fetch reservation status
    const reservation = await supabaseService.query('reservations', 'select', {
      filters: {order_id: orderId}
    });
    
    if (reservation.rows.length === 0) {
      throw new Error('Reservation not found');
    }
    
    const reservationStatus = reservation.rows[0].status;
    
    // ✅ STEP 4: State machine based on reservation status
    if (reservationStatus === 'active') {
      // Normal path: confirm reservation
      await supabaseService.query('reservations', 'update', {
        payload: {status: 'confirmed', confirmed_at: new Date()},
        filters: {id: reservation.rows[0].id}
      });
      
      // Create payment record
      await supabaseService.query('payments', 'insert', {
        payload: {
          razorpay_payment_id,
          razorpay_order_id,
          order_id: orderId,
          amount: webhookEvent.payload.payment.entity.amount / 100,
          status: 'completed',
          created_at: new Date()
        }
      });
      
      // Publish event for async processing
      await EventBus.publishEvent({
        event_type: 'PAYMENT_SUCCESS',
        aggregate_id: orderId,
        payload: {razorpay_payment_id, orderId}
      });
      
    } else if (reservationStatus === 'expired') {
      // Recovery: attempt to re-reserve
      console.log('[Webhook] Reservation expired, attempting recovery:', orderId);
      const recovered = await InventoryService.retryReservation(orderId);
      
      if (recovered) {
        // Successfully re-reserved, continue normal path
        await supabaseService.query('payments', 'insert', {
          payload: {
            razorpay_payment_id,
            razorpay_order_id,
            order_id: orderId,
            amount: webhookEvent.payload.payment.entity.amount / 100,
            status: 'completed'
          }
        });
        
        await EventBus.publishEvent({
          event_type: 'PAYMENT_SUCCESS',
          aggregate_id: orderId,
          payload: {razorpay_payment_id, orderId, recovered: true}
        });
      } else {
        // Recovery failed, initiate refund
        await EventBus.publishEvent({
          event_type: 'PAYMENT_REFUND_NEEDED',
          aggregate_id: orderId,
          payload: {razorpay_payment_id, reason: 'inventory_unavailable_on_recovery'}
        });
      }
      
    } else if (reservationStatus === 'confirmed') {
      // Duplicate webhook (already confirmed)
      console.log('[Webhook] Reservation already confirmed (duplicate webhook):', orderId);
      return; // Idempotent, no-op
    } else {
      throw new Error(`Unknown reservation status: ${reservationStatus}`);
    }
    
  } catch (err) {
    throw err; // Will be caught by caller and logged to DLQ
  }
}
```

**Checklist**:
- [ ] Add async processing wrapper: processWebhookAsync()
- [ ] Check idempotency: SELECT * FROM payments WHERE razorpay_payment_id = $1
- [ ] If exists, return 200 OK silently (no-op)
- [ ] Implement state machine for reservation status (active/expired/confirmed)
- [ ] Add error logging to DLQ for recovery
- [ ] Return 200 OK to Razorpay IMMEDIATELY (before async processing)
- [ ] Verify RAZORPAY_WEBHOOK_SECRET is set correctly in .env
- [ ] Test: Send webhook twice with same payment ID (second should be no-op)

---

### ISSUE #4: STALE RESERVATIONS NEVER EXPIRE [CRITICAL]

**File**: `backend/src/services/inventory-service.js` (lines 140-166)  
**Current Problem**:
- expireStaleReservations() function exists but NEVER CALLED
- No cron job scheduled
- Abandoned checkouts stay reserved forever
- Stock appears sold out to new customers

**Impact**: Inventory blocked, underselling, revenue loss

**Fix Required**:

Create and schedule cron job: `backend/jobs/reservation-expiry-cron.js`

```javascript
const pool = require('../db/pool');
const logger = require('../utils/logger');

/**
 * Cron job: Expire stale reservations every 2 minutes
 * Runs: */2 * * * * (every 2 minutes)
 */
async function expireStaleReservations() {
  const startTime = Date.now();
  
  try {
    // Find reservations that are:
    // 1. status='active'
    // 2. created_at older than 10 minutes
    const result = await pool.query(`
      UPDATE reservations
      SET status = 'expired', expired_at = NOW()
      WHERE status = 'active'
        AND created_at <= NOW() - INTERVAL '10 minutes'
      RETURNING id, order_id;
    `);
    
    const expiredCount = result.rowCount || 0;
    
    if (expiredCount > 0) {
      logger.info('[Expiry Cron] Expired reservations', {count: expiredCount});
      
      // Release stock for each expired reservation
      for (const row of result.rows) {
        await releaseInventoryForReservation(row.id);
      }
      
      logger.info('[Expiry Cron] Released inventory', {count: expiredCount});
    }
    
    const duration = Date.now() - startTime;
    logger.debug('[Expiry Cron] Completed', {durationMs: duration, expiredCount});
    
  } catch (err) {
    logger.error('[Expiry Cron] Failed', {error: err.message});
    // Alert ops: cron job failed
    await alertOps('Reservation expiry cron failed');
  }
}

/**
 * Release inventory for expired reservation
 */
async function releaseInventoryForReservation(reservationId) {
  try {
    const items = await pool.query(
      'SELECT product_id, shop_id, quantity FROM reservation_items WHERE reservation_id = $1',
      [reservationId]
    );
    
    for (const item of items.rows) {
      await pool.query(`
        UPDATE inventory
        SET reserved_quantity = reserved_quantity - $1,
            updated_at = NOW()
        WHERE product_id = $2 AND shop_id = $3
      `, [item.quantity, item.product_id, item.shop_id]);
    }
    
  } catch (err) {
    logger.error('[Expiry] Release failed', {reservationId, error: err.message});
  }
}

module.exports = {expireStaleReservations};
```

Schedule in `backend/server.js` or `backend/jobs/index.js`:

```javascript
const cron = require('node-cron');
const {expireStaleReservations} = require('./reservation-expiry-cron');

// Schedule: every 2 minutes
cron.schedule('*/2 * * * *', async () => {
  await expireStaleReservations();
});

logger.info('[Cron] Reservation expiry job scheduled (every 2 minutes)');
```

**Checklist**:
- [ ] Create reservation-expiry-cron.js
- [ ] Implement UPDATE reservations SET status='expired' WHERE created_at <= NOW() - 10min
- [ ] Implement releaseInventoryForReservation() to UPDATE inventory.reserved_quantity
- [ ] Schedule cron job in server.js using node-cron
- [ ] Test: Create reservation, wait 10min, verify status='expired' and inventory released
- [ ] Verify logging works (should see "Expired X reservations" every 2 minutes)

---

### ISSUE #5: ORPHANED RAZORPAY ORDERS NOT CLEANED [HIGH]

**File**: Need to create `backend/jobs/payment-reconciliation-cron.js`  
**Current Problem**:
- If DB transaction fails after Razorpay order created, order is orphaned
- No automated cleanup
- Manual reconciliation needed (support burden)

**Impact**: Orphaned orders accumulate, manual support work, cash leakage risk

**Fix Required**:

Create: `backend/jobs/payment-reconciliation-cron.js`

```javascript
const razorpay = require('../lib/razorpay');
const pool = require('../db/pool');
const logger = require('../utils/logger');

/**
 * Cron job: Reconcile orphaned Razorpay orders every 30 minutes
 * Runs: 0 */30 * * * * (every 30 minutes)
 */
async function reconcileOrphanedOrders() {
  const startTime = Date.now();
  
  try {
    // Fetch all Razorpay orders from last 1 hour
    const razorpayOrders = await razorpay.orders.fetchMultiple({
      count: 100,
      skip: 0
    });
    
    for (const rzpOrder of razorpayOrders.items) {
      // Check if this Razorpay order ID exists in our DB
      const exists = await pool.query(
        'SELECT id FROM orders WHERE razorpay_order_id = $1',
        [rzpOrder.id]
      );
      
      if (exists.rows.length === 0) {
        // Orphaned: exists in Razorpay but not in our DB
        logger.warn('[Reconciliation] Orphaned Razorpay order found', {
          razorpayOrderId: rzpOrder.id,
          amount: rzpOrder.amount / 100,
          status: rzpOrder.status,
          createdAt: new Date(rzpOrder.created_at * 1000)
        });
        
        // If order is still pending (no payments), close it
        if (rzpOrder.status === 'created' && rzpOrder.payments.total === 0) {
          await razorpay.orders.close(rzpOrder.id);
          logger.info('[Reconciliation] Closed unpaid orphaned order', {
            razorpayOrderId: rzpOrder.id
          });
        }
        // If order has partial payment, initiate refund
        else if (rzpOrder.payments.total > 0 && rzpOrder.status !== 'paid') {
          logger.error('[Reconciliation] Orphaned order with partial payment!', {
            razorpayOrderId: rzpOrder.id,
            paymentAmount: rzpOrder.payments.total / 100
          });
          // Alert ops immediately
          await alertOps(`Orphaned Razorpay order with partial payment: ${rzpOrder.id}`);
          // Create refund manually
          await createManualRefund(rzpOrder);
        }
      }
    }
    
    const duration = Date.now() - startTime;
    logger.debug('[Reconciliation] Completed', {durationMs: duration});
    
  } catch (err) {
    logger.error('[Reconciliation] Failed', {error: err.message});
    await alertOps('Payment reconciliation cron failed');
  }
}

/**
 * Create manual refund for orphaned order
 */
async function createManualRefund(razorpayOrder) {
  try {
    const refund = await razorpay.refunds.create({
      amount: razorpayOrder.payments.total,
      notes: {
        reason: 'Orphaned order reconciliation'
      }
    });
    
    logger.info('[Reconciliation] Refund created', {
      razorpayOrderId: razorpayOrder.id,
      refundId: refund.id,
      amount: refund.amount / 100
    });
  } catch (err) {
    logger.error('[Reconciliation] Refund creation failed', {
      razorpayOrderId: razorpayOrder.id,
      error: err.message
    });
  }
}

module.exports = {reconcileOrphanedOrders};
```

Schedule in `backend/server.js`:

```javascript
const {reconcileOrphanedOrders} = require('./jobs/payment-reconciliation-cron');

// Schedule: every 30 minutes
cron.schedule('0 */30 * * * *', async () => {
  await reconcileOrphanedOrders();
});

logger.info('[Cron] Payment reconciliation job scheduled (every 30 minutes)');
```

**Checklist**:
- [ ] Create payment-reconciliation-cron.js
- [ ] Fetch all Razorpay orders from last hour
- [ ] Check if each Razorpay order exists in our DB
- [ ] If orphaned + unpaid: close via Razorpay API
- [ ] If orphaned + partial payment: alert ops + create refund
- [ ] Schedule in server.js using node-cron
- [ ] Test: Create Razorpay order without matching DB record, verify it's closed/refunded

---

## IMPLEMENTATION TIMELINE

| Issue | Priority | Hours | Sprint |
|-------|----------|-------|--------|
| #1: Coupon Integration | CRITICAL | 3 | 1 |
| #2: Shipping Calculation | CRITICAL | 5 | 1 |
| #3: Webhook Idempotency | CRITICAL | 4 | 1 |
| #4: Reservation Expiry Cron | CRITICAL | 2 | 1 |
| #5: Payment Reconciliation | HIGH | 3 | 1 |

**Sprint 1 Total**: 17 hours

---

## GO-NO-GO CRITERIA

✅ **READY TO DEPLOY IF:**
- All 5 issues fixed and tested
- No overselling in concurrent load test
- Coupon discount applied correctly
- Shipping fee calculated server-side
- Webhook idempotency verified
- Cron jobs logging correctly
- E2E test: checkout → payment → order confirmed (success + failure paths)

❌ **BLOCKER IF:**
- Coupon discount still not applied
- Shipping still missing from order total
- Orphaned Razorpay orders not cleaned
- Cron jobs not running

---

## NEXT STEP

**Backend Agent**: Implement all 5 fixes in order. Start with Issue #1 (coupon integration).

