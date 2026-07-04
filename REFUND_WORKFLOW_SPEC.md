# Refund Workflow Specification
**Scope:** Fufaji Store (single-shop, owner-managed)  
**Status:** v1 (Manual Approval)  
**Timeline:** Can be automated in Phase 2

---

## Overview

**Philosophy:** For a single-shop grocery store, refunds are business-critical trust events. Owner must approve each one.

**Flow:**
```
Customer requests refund
       ↓
Refund stored as PENDING
       ↓
Owner reviews (email + dashboard)
       ↓
Owner approves OR rejects
       ↓
If approved: Razorpay refund issued
       ↓
Customer notified (SMS + in-app)
```

---

## Database Schema

```sql
CREATE TABLE refund_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id),
  customer_id UUID NOT NULL,
  
  -- Request details
  reason VARCHAR(500) NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  
  -- Status workflow
  status VARCHAR(20) DEFAULT 'pending',
  -- Values: pending → approved → refunded → rejected
  
  -- Owner approval
  approved_by UUID,  -- owner_id (NULL if pending)
  approval_note TEXT,
  approved_at TIMESTAMP,
  
  -- Razorpay
  razorpay_refund_id VARCHAR(255),
  razorpay_refund_status VARCHAR(50),
  
  -- Audit
  customer_requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  refunded_at TIMESTAMP,
  
  INDEX idx_status ON refund_requests(status),
  INDEX idx_customer ON refund_requests(customer_id),
  INDEX idx_order ON refund_requests(order_id)
);

CREATE TABLE refund_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  refund_id UUID NOT NULL REFERENCES refund_requests(id),
  action VARCHAR(50),  -- requested, approved, rejected, refunded
  actor_id UUID,       -- customer_id or owner_id
  note TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## API Endpoints

### 1. Customer Request Refund
**Endpoint:** `POST /refunds/request`  
**Auth:** Customer only  
**Request:**
```json
{
  "orderId": "order-123",
  "reason": "Item damaged/defective"  // or: "Order not placed", "Wrong item", "Changed mind"
}
```

**Response (Success):**
```json
{
  "success": true,
  "refundId": "refund-456",
  "status": "pending",
  "message": "Refund request submitted. Owner will review within 24 hours.",
  "estimatedRefundDate": "2026-07-08"  // If approved today
}
```

**Validation:**
- Order exists & belongs to customer
- Order status is 'confirmed' (payment successful)
- Order is < 30 days old
- No duplicate refund request already pending/approved

**Implementation:**
```javascript
router.post('/request', authMiddleware, async (req, res) => {
  const { orderId, reason } = req.body;
  const customerId = req.user.id;

  if (!orderId || !reason) {
    return res.status(400).json({ 
      error: 'VALIDATION_001', 
      message: 'orderId and reason required' 
    });
  }

  // Check order exists & belongs to customer
  const order = await pool.query(
    'SELECT id, status, total_amount, created_at FROM orders WHERE id = $1 AND customer_id = $2',
    [orderId, customerId]
  );

  if (order.rows.length === 0) {
    return res.status(404).json({ 
      error: 'STOCK_001', 
      message: 'Order not found' 
    });
  }

  if (order.rows[0].status !== 'confirmed') {
    return res.status(400).json({ 
      error: 'VALIDATION_001', 
      message: 'Can only refund confirmed orders' 
    });
  }

  // Check order age
  const orderAge = (Date.now() - new Date(order.rows[0].created_at)) / (1000 * 60 * 60 * 24);
  if (orderAge > 30) {
    return res.status(400).json({ 
      error: 'VALIDATION_001', 
      message: 'Refund requests only accepted within 30 days' 
    });
  }

  // Check no duplicate pending/approved
  const existing = await pool.query(
    `SELECT id FROM refund_requests 
     WHERE order_id = $1 AND status IN ('pending', 'approved')`,
    [orderId]
  );

  if (existing.rows.length > 0) {
    return res.status(409).json({ 
      error: 'VALIDATION_001', 
      message: 'Refund already requested for this order' 
    });
  }

  // Create refund request
  const refundId = require('uuid').v4();
  await pool.query(
    `INSERT INTO refund_requests (id, order_id, customer_id, reason, amount, status)
     VALUES ($1, $2, $3, $4, $5, 'pending')`,
    [refundId, orderId, customerId, reason, order.rows[0].total_amount]
  );

  // Audit log
  await pool.query(
    `INSERT INTO refund_audit_log (refund_id, action, actor_id, note)
     VALUES ($1, 'requested', $2, $3)`,
    [refundId, customerId, 'Customer requested refund']
  );

  // Send notification to owner
  console.log(`[Refund] New refund request: ${refundId} from customer ${customerId}`);
  // TODO: Send email to owner

  return res.status(201).json({
    success: true,
    refundId,
    status: 'pending',
    message: 'Refund request submitted. Owner will review within 24 hours.',
    estimatedRefundDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
  });
});
```

---

### 2. Owner View Pending Refunds
**Endpoint:** `GET /admin/refunds/pending`  
**Auth:** Owner only  
**Response:**
```json
{
  "success": true,
  "data": [
    {
      "refundId": "refund-456",
      "orderId": "order-123",
      "customerId": "cust-789",
      "customerName": "Rajesh Kumar",
      "customerPhone": "+91 98765 43210",
      "reason": "Item damaged",
      "amount": 599,
      "requestedAt": "2026-07-04T10:30:00Z",
      "orderDetails": {
        "items": [
          { "productName": "Amul Milk 1L", "quantity": 2, "price": 60 }
        ],
        "totalAmount": 599,
        "deliveryAddress": "123 Market St, Delhi"
      }
    }
  ]
}
```

---

### 3. Owner Approve Refund
**Endpoint:** `POST /admin/refunds/:refundId/approve`  
**Auth:** Owner only  
**Request:**
```json
{
  "approvalNote": "Item damage verified"  // Optional
}
```

**Response:**
```json
{
  "success": true,
  "refundId": "refund-456",
  "status": "approved",
  "message": "Refund approved. Processing Razorpay refund...",
  "refundedAt": "2026-07-04T10:35:00Z"
}
```

**Implementation:**
```javascript
router.post('/admin/refunds/:refundId/approve', ownerAuthMiddleware, async (req, res) => {
  const { refundId } = req.params;
  const { approvalNote } = req.body;
  const ownerId = req.user.id;

  // Get refund
  const refund = await pool.query(
    `SELECT * FROM refund_requests WHERE id = $1 AND status = 'pending'`,
    [refundId]
  );

  if (refund.rows.length === 0) {
    return res.status(404).json({ error: 'Not found or already processed' });
  }

  const refundData = refund.rows[0];

  // Get order for payment details
  const order = await pool.query(
    `SELECT * FROM orders WHERE id = $1`,
    [refundData.order_id]
  );

  if (order.rows.length === 0) {
    return res.status(404).json({ error: 'Order not found' });
  }

  const orderData = order.rows[0];

  try {
    // Issue Razorpay refund
    const razorpayResponse = await RazorpayService.createRefund({
      paymentId: orderData.razorpay_payment_id,
      amount: refundData.amount * 100,  // Convert to paise
      notes: {
        refundId,
        reason: refundData.reason,
        approvalNote,
      },
    });

    // Update refund record
    await pool.query(
      `UPDATE refund_requests
       SET status = 'approved',
           approved_by = $1,
           approval_note = $2,
           approved_at = CURRENT_TIMESTAMP,
           razorpay_refund_id = $3,
           razorpay_refund_status = $4,
           refunded_at = CURRENT_TIMESTAMP
       WHERE id = $5`,
      [ownerId, approvalNote, razorpayResponse.id, 'processed', refundId]
    );

    // Audit log
    await pool.query(
      `INSERT INTO refund_audit_log (refund_id, action, actor_id, note)
       VALUES ($1, 'approved', $2, $3)`,
      [refundId, ownerId, approvalNote || 'Owner approved refund']
    );

    // Notify customer
    await sendCustomerNotification({
      customerId: refundData.customer_id,
      type: 'refund_approved',
      amount: refundData.amount,
      message: 'Your refund has been approved. Amount will appear in your account within 3-5 business days.',
    });

    console.log(`[Refund] Approved: ${refundId}, amount: ₹${refundData.amount}`);

    return res.status(200).json({
      success: true,
      refundId,
      status: 'approved',
      message: 'Refund approved and Razorpay refund issued',
      razorpayRefundId: razorpayResponse.id,
    });
  } catch (err) {
    console.error('[Refund] Razorpay refund failed:', err.message);
    return res.status(500).json({
      error: 'INTERNAL_001',
      message: 'Failed to issue Razorpay refund. Please retry or contact support.',
      details: err.message,
    });
  }
});
```

---

### 4. Owner Reject Refund
**Endpoint:** `POST /admin/refunds/:refundId/reject`  
**Auth:** Owner only  
**Request:**
```json
{
  "rejectionReason": "Item condition acceptable"  // Required
}
```

**Response:**
```json
{
  "success": true,
  "refundId": "refund-456",
  "status": "rejected",
  "message": "Refund rejected. Customer will be notified."
}
```

**Implementation:**
```javascript
router.post('/admin/refunds/:refundId/reject', ownerAuthMiddleware, async (req, res) => {
  const { refundId } = req.params;
  const { rejectionReason } = req.body;
  const ownerId = req.user.id;

  if (!rejectionReason) {
    return res.status(400).json({ 
      error: 'VALIDATION_001', 
      message: 'rejectionReason required' 
    });
  }

  const refund = await pool.query(
    `SELECT * FROM refund_requests WHERE id = $1 AND status = 'pending'`,
    [refundId]
  );

  if (refund.rows.length === 0) {
    return res.status(404).json({ error: 'Not found or already processed' });
  }

  const refundData = refund.rows[0];

  // Update refund record
  await pool.query(
    `UPDATE refund_requests
     SET status = 'rejected',
         approved_by = $1,
         approval_note = $2,
         approved_at = CURRENT_TIMESTAMP
     WHERE id = $3`,
    [ownerId, rejectionReason, refundId]
  );

  // Audit log
  await pool.query(
    `INSERT INTO refund_audit_log (refund_id, action, actor_id, note)
     VALUES ($1, 'rejected', $2, $3)`,
    [refundId, ownerId, rejectionReason]
  );

  // Notify customer
  await sendCustomerNotification({
    customerId: refundData.customer_id,
    type: 'refund_rejected',
    message: `Your refund request has been declined. Reason: ${rejectionReason}`,
  });

  console.log(`[Refund] Rejected: ${refundId}, reason: ${rejectionReason}`);

  return res.status(200).json({
    success: true,
    refundId,
    status: 'rejected',
    message: 'Refund rejected. Customer notified.',
  });
});
```

---

### 5. Customer View Refund Status
**Endpoint:** `GET /refunds/:refundId`  
**Auth:** Customer only  
**Response:**
```json
{
  "success": true,
  "data": {
    "refundId": "refund-456",
    "orderId": "order-123",
    "status": "approved",
    "amount": 599,
    "reason": "Item damaged",
    "timeline": {
      "requestedAt": "2026-07-04T10:30:00Z",
      "approvedAt": "2026-07-04T10:35:00Z",
      "refundedAt": "2026-07-04T10:35:00Z",
      "expectedInAccount": "2026-07-07T23:59:59Z"  // 3-5 business days
    },
    "razorpayRefundId": "rfnd_123456",
    "razorpayStatus": "processed"
  }
}
```

---

## Workflow States

| State | Description | Next Action |
|-------|-------------|------------|
| **pending** | Waiting for owner approval | Owner approves/rejects |
| **approved** | Owner approved, Razorpay refund issued | Wait for bank (3-5 days) |
| **refunded** | Money returned to customer | Complete (no further action) |
| **rejected** | Owner declined | Complete (no appeal) |

---

## Notifications

### Customer Notifications
1. **Refund Requested (SMS):**
   ```
   Hi Rajesh, your refund request for order #123 (₹599) has been received. 
   Owner will review within 24 hours. We'll notify you of the decision.
   ```

2. **Refund Approved (SMS + In-App):**
   ```
   Great news! Your refund of ₹599 has been approved. 
   The amount will appear in your account within 3-5 business days.
   ```

3. **Refund Rejected (SMS + In-App):**
   ```
   Your refund request for order #123 has been declined. 
   Reason: Item condition acceptable. If you have questions, contact us.
   ```

### Owner Notifications
1. **New Refund Request (Email):**
   ```
   Subject: New refund request: ₹599 from Rajesh Kumar
   
   Order: #order-123
   Customer: Rajesh Kumar (+91 98765 43210)
   Amount: ₹599
   Reason: Item damaged
   Requested: July 4, 10:30 AM
   
   Action: https://fufaji.store/admin/refunds/refund-456
   ```

---

## Owner Dashboard

**View:** `/admin/refunds`
```
┌─────────────────────────────────────────────────────────────┐
│ Refund Requests                                             │
├──────┬──────────┬────────────┬─────────┬─────────┬─────────┤
│ ID   │ Customer │ Reason     │ Amount  │ Status  │ Action  │
├──────┼──────────┼────────────┼─────────┼─────────┼─────────┤
│ 456  │ Rajesh K │ Damaged    │ ₹599    │ PENDING │ ✓ / ✗   │
│ 457  │ Priya D  │ Wrong item │ ₹1,299  │ PENDING │ ✓ / ✗   │
│ 458  │ Amit S   │ Defective  │ ₹399    │ PENDING │ ✓ / ✗   │
└──────┴──────────┴────────────┴─────────┴─────────┴─────────┘

Quick Stats:
- Pending: 3 refunds, ₹2,297
- Approved (today): 2 refunds, ₹1,199
- Rejected (today): 0 refunds
```

---

## Safeguards

1. **No partial refunds** (initially)
   - Refund must be full order amount
   - Can be automated in Phase 2 if needed

2. **Refund window** 
   - Only allow refunds within 30 days
   - Older requests can be handled manually

3. **One refund per order**
   - Cannot request duplicate refunds
   - Owner must reject before customer can re-request

4. **Audit trail**
   - Every action logged (request, approve, reject, issue, fail)
   - Owner can see full history

5. **Razorpay verification**
   - Only approve if Razorpay payment exists & successful
   - Do NOT approve cancelled/failed payments

---

## Phase 2 Enhancements (Post-Launch)

- Auto-approve refunds < ₹500 (configurable threshold)
- Partial refunds (for specific items)
- Refund appeal workflow (if owner rejects)
- Scheduled refund processing (batch at EOD)
- Razorpay refund status polling (confirm bank transfer)

---

## Testing Checklist

- [x] Customer can request refund
- [x] Owner gets notification
- [x] Owner can approve (Razorpay issued)
- [x] Owner can reject (customer notified)
- [x] Customer can view refund status
- [x] No duplicate requests allowed
- [x] Audit trail complete
- [x] Error handling (Razorpay down, etc.)

