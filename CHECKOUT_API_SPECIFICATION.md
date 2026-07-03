# Checkout API Specification (Sprint 2B-P0)

**Status:** Critical  
**Priority:** P0 (Highest Risk)  
**Date:** 2026-07-03

---

## Overview

This document specifies the complete checkout transaction flow that moves from **client-side Firestore transactions** (unsafe) to **backend PostgreSQL transactions** (safe).

The checkout path is Fufaji's nuclear core:
- Cart → Inventory → Order → Payment → Fulfillment

One mistake here = overselling, duplicate charges, or ghost orders.

---

## Architecture Decision

### Before (Dangerous ❌)
```
Flutter Client
  → Firestore runTransaction()
  → Decrement product.available_quantity
  → Create order
  → No atomic guarantee across domains
```

**Problems:**
- Firestore transactions don't serialize across clients
- No row-level locks
- Partial state possible (order created but payment failed)
- No rollback on exception

### After (Safe ✅)
```
Flutter Client
  → POST /checkout/create-order
  → Backend PostgreSQL transaction
  → SELECT...FOR UPDATE (row-level lock)
  → Validate → Reserve → Create order → Return payment order
  → Atomic: all-or-nothing
```

**Guarantees:**
- Serializable isolation
- Row-level locks prevent concurrent writes
- Atomic across products, reservations, orders, audit logs
- Deterministic rollback on any failure

---

## Required Database Schema

### Table: `checkout_sessions` (New — Parent Object)

```sql
CREATE TABLE checkout_sessions (
  id SERIAL PRIMARY KEY,
  session_id VARCHAR(255) UNIQUE NOT NULL,
  customer_id VARCHAR(255) NOT NULL,
  status VARCHAR(50) NOT NULL,  -- initiated, inventory_reserved, payment_pending, payment_success, completed, failed, expired
  
  -- Cart snapshot at checkout time
  cart_snapshot JSONB NOT NULL,  -- Full cart state for debugging
  
  -- Payment order reference (from Razorpay)
  payment_order_id VARCHAR(255),  -- Razorpay order ID
  
  -- Totals
  total_amount DECIMAL(10, 2) NOT NULL,
  discount_amount DECIMAL(10, 2) DEFAULT 0,
  
  -- Timestamps
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  initiated_at TIMESTAMP,
  inventory_reserved_at TIMESTAMP,
  payment_created_at TIMESTAMP,
  payment_confirmed_at TIMESTAMP,
  completed_at TIMESTAMP,
  failed_at TIMESTAMP,
  expired_at TIMESTAMP,
  
  -- Audit
  failure_reason TEXT,
  notes TEXT,
  
  INDEX idx_customer_id (customer_id),
  INDEX idx_status (status),
  INDEX idx_created_at (created_at)
);

-- Query child objects by joining on checkout_session_id
-- Example: SELECT * FROM reservations WHERE checkout_session_id = X
-- Example: SELECT * FROM orders WHERE checkout_session_id = X
```

### Table: `reservations` (Corrected)

```sql
CREATE TABLE reservations (
  id SERIAL PRIMARY KEY,
  reservation_id VARCHAR(255) UNIQUE NOT NULL,  -- uuid for idempotency
  checkout_session_id INT NOT NULL REFERENCES checkout_sessions(id),
  customer_id VARCHAR(255) NOT NULL,
  order_id VARCHAR(255) REFERENCES orders(id),  -- NULLABLE: linked after payment success
  status VARCHAR(50) NOT NULL,  -- active, confirmed, released, expired
  
  -- Reservation details
  total_quantity INT NOT NULL,
  total_amount DECIMAL(10, 2) NOT NULL,
  discount_amount DECIMAL(10, 2) DEFAULT 0,
  
  -- Timestamps
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,  -- 10 mins from creation (not 30)
  confirmed_at TIMESTAMP,
  released_at TIMESTAMP,
  expired_at TIMESTAMP,
  
  -- Audit
  created_by VARCHAR(255),
  notes TEXT,
  
  INDEX idx_checkout_session_id (checkout_session_id),
  INDEX idx_order_id (order_id),
  INDEX idx_customer_id (customer_id),
  INDEX idx_status (status),
  INDEX idx_expires_at (expires_at)
);
```

### Table: `reservation_items` (sub-items per reservation)

```sql
CREATE TABLE reservation_items (
  id SERIAL PRIMARY KEY,
  reservation_id INT NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
  product_id VARCHAR(255) NOT NULL REFERENCES products(id),
  quantity INT NOT NULL,
  unit_price DECIMAL(10, 2) NOT NULL,
  total_price DECIMAL(10, 2) NOT NULL,
  
  INDEX idx_reservation_id (reservation_id),
  INDEX idx_product_id (product_id)
);
```

### Modify: `products` table

```sql
ALTER TABLE products ADD COLUMN reserved_quantity INT DEFAULT 0;
-- reserved_quantity: units currently locked by active reservations

ALTER TABLE products ADD COLUMN available_quantity INT;
-- available_quantity: STORED (not derived) for fast reads
-- Relationship: available_quantity = total_quantity - reserved_quantity
-- Updated atomically during reserve/release operations

-- Example atomic update (during reservation):
-- UPDATE products SET
--   reserved_quantity = reserved_quantity + qty,
--   available_quantity = available_quantity - qty
-- WHERE id = productId
-- FOR UPDATE (lock ensures atomicity)
```

### Modify: `orders` table

```sql
ALTER TABLE orders ADD COLUMN reservation_id INT REFERENCES reservations(id);
ALTER TABLE orders ADD COLUMN payment_order_id VARCHAR(255);  -- Razorpay order ID
```

---

## API Endpoints

### 1. POST `/checkout/create-order`

**Purpose:** Create order + reserve inventory in ONE atomic transaction

**Authentication:** Bearer token (customer ID from token)

**Request Body:**
```json
{
  "customerId": "cust_abc123",
  "items": [
    {
      "productId": "prod_123",
      "quantity": 2
    },
    {
      "productId": "prod_456",
      "quantity": 1
    }
  ],
  "paymentMethod": "razorpay",
  "paymentMethodId": null,
  "couponCode": null,
  "discountAmount": 0.00,
  "idempotencyKey": "cust_abc123_1688123456_a1b2c3d4"
}
```

**Idempotency:** `idempotencyKey` must be unique per checkout attempt
- Store in cache for 30 minutes
- Return same response if duplicate request arrives

**Response (200 OK):**
```json
{
  "success": true,
  "orderId": "ord_abc123",
  "paymentOrderId": "rzp_order_abc123",
  "reservationId": 42,
  "expiresAt": "2026-07-03T12:13:00Z",
  "totalAmount": 1500.00,
  "items": [
    {
      "productId": "prod_123",
      "quantity": 2,
      "unitPrice": 500,
      "totalPrice": 1000
    }
  ]
}
```

**Response (400 Bad Request):**
```json
{
  "success": false,
  "error": "Insufficient stock for product prod_123",
  "code": "INSUFFICIENT_STOCK",
  "details": {
    "productId": "prod_123",
    "requested": 2,
    "available": 1
  }
}
```

**Response (409 Conflict - Duplicate):**
```json
{
  "success": true,
  "orderId": "ord_abc123",
  "paymentOrderId": "rzp_order_abc123",
  "reservationId": 42,
  "note": "Idempotent: returning cached response"
}
```

**Backend Implementation:**
```javascript
POST /checkout/create-order
├─ Validate: customer exists
├─ Check: idempotencyKey in cache (if yes, return cached response)
├─ Create checkout_session (status = 'initiated')
├─ CALL Razorpay API: POST /v1/orders (BEFORE DB COMMIT)
│  └─ Create payment order with order amount
│  └─ IF fails: abort, return 400
├─ BEGIN TRANSACTION
│  ├─ FOR each item in cart:
│  │  ├─ SELECT * FROM products WHERE id = productId FOR UPDATE (LOCK)
│  │  ├─ IF available_quantity < quantity:
│  │  │  └─ ROLLBACK → return 400
│  │  └─ Calculate totals
│  ├─ CREATE order (status = 'pending_payment')
│  ├─ INSERT reservation (status = 'active', expires_at = now + 10min)
│  ├─ FOR each item:
│  │  ├─ INSERT reservation_items
│  │  └─ UPDATE products SET reserved_quantity = reserved_quantity + qty
│  ├─ UPDATE checkout_sessions:
│  │  ├─ reservation_id
│  │  ├─ order_id
│  │  ├─ payment_order_id
│  │  ├─ status = 'inventory_reserved'
│  ├─ INSERT audit_log
│  ├─ INSERT sync_event (for Firestore eventual consistency)
│  └─ COMMIT
├─ Cache response with idempotencyKey
└─ Return { orderId, paymentOrderId, reservationId, expiresAt }
```

**Critical:** Razorpay order creation happens BEFORE database transaction. If Razorpay fails, checkout aborts before any reservation is created.

**Error Codes:**
- `INSUFFICIENT_STOCK`: Product doesn't have enough available
- `PRODUCT_NOT_FOUND`: One of cart items doesn't exist
- `CUSTOMER_NOT_FOUND`: Customer ID invalid
- `INVALID_COUPON`: Coupon code expired or doesn't exist
- `CHECKOUT_TIMEOUT`: Took too long (>5 seconds)

---

### 2. POST `/inventory/confirm`

**Purpose:** Mark reservation as confirmed after successful payment

**Authentication:** Bearer token (must be admin or system)

**Request Body:**
```json
{
  "reservationId": "res_abc123",
  "orderId": "ord_abc123",
  "paymentId": "pay_abc123",
  "confirmedAt": "2026-07-03T12:30:00Z"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "reservationId": "res_abc123",
  "status": "confirmed",
  "message": "Reservation locked until order fulfillment"
}
```

**Response (404 Not Found):**
```json
{
  "success": false,
  "error": "Reservation not found",
  "code": "RESERVATION_NOT_FOUND"
}
```

**Backend Implementation:**
```javascript
POST /inventory/confirm
├─ Verify: payment webhook signature (if called from webhook)
├─ BEGIN TRANSACTION
│  ├─ SELECT * FROM reservations WHERE reservation_id FOR UPDATE
│  ├─ IF status != 'active':
│  │  └─ ROLLBACK → return 409
│  ├─ UPDATE reservations SET status = 'confirmed', confirmed_at = now
│  ├─ INSERT audit_log (payment verified, reservation locked)
│  └─ COMMIT
├─ Trigger sync to Firestore (eventual consistency)
└─ Return { success: true, status: 'confirmed' }
```

---

### 3. POST `/inventory/release`

**Purpose:** Release reservation (customer cancelled or payment failed)

**Authentication:** Bearer token

**Request Body:**
```json
{
  "reservationId": "res_abc123",
  "orderId": "ord_abc123",
  "releasedAt": "2026-07-03T12:31:00Z"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "reservationId": "res_abc123",
  "status": "released",
  "unlockedItems": [
    {
      "productId": "prod_123",
      "quantity": 2
    }
  ],
  "message": "Stock returned to available pool"
}
```

**Backend Implementation:**
```javascript
POST /inventory/release
├─ BEGIN TRANSACTION
│  ├─ SELECT * FROM reservations WHERE reservation_id FOR UPDATE
│  ├─ IF status not in ('active', 'expired'):
│  │  └─ ROLLBACK → error (already released/confirmed)
│  ├─ GET all reservation_items for this reservation
│  ├─ FOR each item:
│  │  └─ UPDATE products SET reserved_quantity = reserved_quantity - qty
│  ├─ UPDATE reservations SET status = 'released', released_at = now
│  ├─ INSERT audit_log
│  └─ COMMIT
└─ Return { success: true, status: 'released' }
```

---

## TTL Cleanup Job (Cron)

**Purpose:** Auto-release expired reservations every 5 minutes

**Trigger:** Every 5 minutes (via cron or scheduled task)

**Implementation:**
```javascript
CRON: every 5 minutes
├─ SELECT * FROM reservations
│  WHERE status = 'active'
│  AND expires_at < now()
├─ FOR each expired reservation:
│  ├─ BEGIN TRANSACTION
│  │  ├─ GET reservation_items
│  │  ├─ FOR each item:
│  │  │  └─ UPDATE products SET reserved_quantity = reserved_quantity - qty
│  │  ├─ UPDATE reservations SET status = 'expired', expired_at = now
│  │  ├─ UPDATE orders SET status = 'expired' (if still pending_payment)
│  │  ├─ INSERT audit_log
│  │  └─ COMMIT
│  └─ Trigger Firestore sync event
└─ Log: "Expired N reservations, released X total units"
```

**Important:**
- Don't block other transactions
- Use time-windowed queries to avoid large scans
- Alert if more than 100 expirations in one run (suggests checkout spam)

---

## Checkout Session Lifecycle

Checkout sessions track the complete journey:

```
initiated
  ↓
inventory_reserved (after successful stock lock)
  ↓
payment_pending (waiting for Razorpay)
  ↓
payment_success (payment verified via webhook)
  ↓
completed (order processing started) OR failed/expired
```

Each state is tracked with timestamp, allowing recovery and debugging of stuck checkouts.

---

## Cart Architecture (Unchanged)

Cart remains in Firestore (reads are fast, writes are eventual-consistency).

**Allowed cart operations (client-side):**
- Add item
- Remove item
- Update quantity
- Clear cart

**When checkout happens:**
- Client reads full cart snapshot
- Sends to `/checkout/create-order`
- Backend validates item-by-item (may differ from cached cart!)

**Why cache is stale:**
Another customer may have bought the last unit between when the user added it to cart and when they hit "Place Order".

Backend catches this and returns `INSUFFICIENT_STOCK`. Expected behavior.

---

## Checkout Flow (Complete)

```
Customer taps "PLACE ORDER"
│
├─ [Flutter] Build cart snapshot from local state
├─ [Flutter] POST /checkout/create-order
│  │
│  └─ [Backend] BEGIN TRANSACTION
│     ├─ Validate customer
│     ├─ FOR each item: SELECT...FOR UPDATE (lock product)
│     ├─ Verify stock for ALL items (all-or-nothing)
│     ├─ CREATE order (status='pending_payment')
│     ├─ INSERT reservation (status='active', expires_at=+10m)
│     ├─ FOR each item: UPDATE products.reserved_quantity
│     ├─ INSERT audit_log
│     ├─ COMMIT
│     └─ Return { orderId, paymentOrderId, reservationId }
│
├─ [Flutter] Show payment screen (Razorpay)
├─ Customer enters card details
├─ [Razorpay] Process payment
│
├─ [Razorpay] Webhook → Backend
│  │
│  └─ [Backend] POST /payments/verify (existing endpoint)
│     ├─ Verify signature
│     ├─ Call POST /inventory/confirm
│     │  └─ UPDATE reservations SET status='confirmed'
│     └─ Update order status → 'confirmed'
│
├─ [Flutter] Show "Order Placed" screen
└─ [Customer] Proceed to packing/delivery
```

---

## Failure Scenarios (Handled)

### Scenario 1: Customer cancels before payment
```
1. Order created (pending_payment)
2. Customer cancels checkout screen
3. [Flutter] POST /inventory/release
   → reservations.status = 'released'
   → products.reserved_quantity restored
4. Stock becomes available again immediately
```

### Scenario 2: Payment fails
```
1. Razorpay returns error
2. [Flutter] Optionally calls POST /inventory/release (optional cleanup)
3. Cron job cleans up after 10 mins anyway
4. Order remains in 'pending_payment' status (safe)
```

### Scenario 3: Webhook timeout (payment succeeded but notification lost)
```
1. Payment actually succeeded at Razorpay
2. Webhook didn't reach backend
3. Customer waits 10 minutes
4. Cron job expires reservation after 10 mins
   └─ Releases stock back to available pool
   └─ Order remains in 'pending_payment' (stale)
5. Reconciliation job (every 1 hour) runs:
   ├─ SELECT orders WHERE status='pending_payment' AND created_at < now-1hr
   ├─ Check Razorpay API for real payment status
   ├─ If payment_status='captured', call /inventory/confirm
   │  └─ Re-reserve inventory (now available again)
   └─ If payment failed, mark order as 'failed'
```

### Scenario 4: Oversell race condition (impossible now)
```
Before:
  Product: 1 unit available
  Client A + Client B checkout simultaneously
  Result: Both succeed (OVERSELL)

After:
  Product: 1 unit available
  Client A: SELECT...FOR UPDATE (locks product)
  Client B: SELECT...FOR UPDATE (waits for A's transaction to finish)
  Client A: reserves 1 unit, commits
  Client B: reads 0 available, rollback → returns 400
```

---

## Audit Trail

Every state change is logged:

```sql
INSERT INTO audit_logs (entity_id, entity_type, action, actor_id, timestamp, details) VALUES
('ord_abc123', 'order', 'created', 'system', now(), '{"items": 2, "amount": 1500}'),
(42, 'reservation', 'confirmed', 'system', now(), '{"paymentId": "pay_abc123"}'),
('prod_123', 'product', 'reserved', 'system', now(), '{"quantity": 2, "orderId": "ord_abc123"}'),
...
```

Provides complete history for debugging, fraud detection, reconciliation.

---

## Success Criteria (Acceptance)

✅ `POST /checkout/create-order` atomically reserves inventory
✅ No overselling possible (row-level locks)
✅ Partial checkout state impossible (all-or-nothing)
✅ Idempotency prevents duplicate orders on network retry
✅ `POST /inventory/confirm` locks stock until fulfillment
✅ `POST /inventory/release` immediately frees stock
✅ Cron job expires stale reservations after 10 mins
✅ Audit log captures every state change
✅ Firestore eventually synced (not blocking)
✅ Load test: Checkout Race Condition (500 concurrent, same product) → 0 oversells
✅ Load test: Webhook Retry Storm (100 duplicate confirmations) → exactly once processing
✅ Load test: Reservation Expiry Storm (1000 expired reservations) → cleanup under 1 minute
✅ TTL enforcement: Reservations auto-expire after 10 minutes

---

## Deployment Notes (Updated with 5 Corrections)

1. **Database Schema** (Correction 4 — Checkout Sessions)
   - Create `checkout_sessions` table (parent tracking object)
   - Create `reservations` table with nullable `order_id` (Correction 1)
   - Create `reservation_items` table
   - Modify `products`: add `reserved_quantity` column

2. **API Implementation** (Correction 3 — Razorpay Order Timing)
   - `POST /checkout/create-order`:
     - Create checkout_session first
     - Call Razorpay BEFORE database transaction
     - If Razorpay fails, abort completely
     - Then atomically reserve + create order
   - `POST /inventory/confirm` (idempotent)
   - `POST /inventory/release` (idempotent)

3. **TTL Configuration** (Correction 2 — Shorter TTL)
   - Set reservation TTL to **10 minutes** (not 30)
   - Cron job runs every 5 minutes
   - Better for grocery commerce (less stock blocking)

4. **Cron Jobs**
   - Reservation cleanup: every 5 minutes
   - Reconciliation: every 1 hour (webhook timeout detection)

5. **Load Testing** (Correction 5 — Rigorous Load Tests)
   - **Checkout Race Test:** 500 concurrent checkouts, same product → verify 0 oversells
   - **Webhook Retry Storm:** 100 duplicate payment confirmations → verify exactly-once processing
   - **Reservation Expiry Storm:** 1000 expired reservations → verify cleanup < 1 minute

6. **Flutter** (Already Done)
   - checkout_inventory_service.dart refactored ✅

7. **Monitoring**
   - Alert on oversell attempts (should be 0)
   - Alert on reservation cleanup lag
   - Alert on webhook retry backlog
   - Dashboard: checkout success rate, average reservation time

---

## Timeline (Sprint 2B-P0)

- **Session 1 (Done):** Flutter refactoring ✅
- **Session 2 (Next):** Backend API + database schema implementation
  - Create schema migrations
  - Implement 3 checkout APIs
  - Deploy cron jobs
- **Session 3 (After):** Integration testing + comprehensive load testing
- **Session 4 (Final):** Production deployment + monitoring

---

## Key Architectural Improvements (5 Corrections Applied)

1. ✅ **Checkout Sessions as Parent Object:** Tracks full lifecycle (Correction 4)
2. ✅ **Nullable Order FK:** Reservation independent of order (Correction 1)
3. ✅ **Razorpay First:** Payment order created BEFORE database transaction (Correction 3)
4. ✅ **10-Minute TTL:** Minimize stock locking in grocery commerce (Correction 2)
5. ✅ **Rigorous Load Testing:** 500 concurrent, webhook storms, expiry storms (Correction 5)
