# Phase 5B: Supplier Backend API Specifications
**Render Backend - Complete Implementation Guide**

---

## Overview

This document specifies all backend API endpoints required for the Supplier App (Phase 5B). All endpoints use **Razorpay Route API** for supplier payments and interact with **Supabase PostgreSQL** as the source of truth.

**Architecture:**
```
Flutter App (Supplier/Owner)
  ↓ HTTPS
Render Backend (API Layer)
  ↓
Supabase PostgreSQL (Source of Truth)
  ↓
Razorpay API (Supplier Payments)
  ↓
Supplier Bank Account
```

---

## Authentication

All endpoints require:

```
Authorization: Bearer <Firebase Auth Token>
Content-Type: application/json
```

Server validates token via Firebase Admin SDK.

---

## 1. Supplier Profile Endpoints

### 1.1 Get Supplier Profile
**Endpoint:** `GET /suppliers/:supplierId`

**Description:** Fetch single supplier profile with full details

**Request:**
```
GET /suppliers/uuid-1234
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-1234",
    "user_id": "firebase-uid",
    "name": "Vegetable Supplier Co",
    "email": "supplier@example.com",
    "phone": "9876543210",
    "address": "123 Market St",
    "city": "Delhi",
    "state": "DL",
    "pincode": "110001",
    "gst_number": "07AAPCU1234A1Z0",
    "status": "approved",
    "is_verified": true,
    "rating": 4.5,
    "total_orders": 45,
    "completed_orders": 43,
    "on_time_delivery_rate": 94.4,
    "quality_score": 92.0,
    "response_rate": 96.0,
    "auto_order_enabled": true,
    "preferred_delivery_day": "monday",
    "min_order_value": 500.0,
    "total_revenue": 125000.0,
    "total_paid": 120000.0,
    "total_pending": 5000.0,
    "created_at": "2026-07-01T10:00:00Z",
    "updated_at": "2026-07-11T15:30:00Z"
  }
}
```

**Error Response (404):**
```json
{
  "success": false,
  "error": "Supplier not found"
}
```

---

### 1.2 Get All Suppliers (Owner Only)
**Endpoint:** `GET /suppliers?status=approved&sort=rating`

**Description:** List all suppliers with filtering and sorting

**Query Parameters:**
- `status` (optional): approved, pending, rejected, suspended
- `active_only` (optional): true/false
- `sort` (optional): rating, on_time_rate, total_orders, created_at
- `order` (optional): asc, desc
- `limit` (optional): default 50
- `offset` (optional): default 0

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    { /* supplier object */ },
    { /* supplier object */ }
  ],
  "total": 120,
  "page": 1,
  "limit": 50
}
```

---

## 2. Auto-Order Management Endpoints

### 2.1 Get Auto-Order Suggestions
**Endpoint:** `GET /suppliers/:supplierId/auto-order-suggestions`

**Description:** AI-powered suggestions for what to order from supplier based on Fufaji inventory levels

**Request:**
```
GET /suppliers/uuid-1234/auto-order-suggestions
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "suggestions": [
    {
      "product_id": "prod-001",
      "product_name": "Tomato",
      "current_stock": 15,
      "reorder_point": 20,
      "suggested_quantity": 50,
      "unit_price": 25.0,
      "estimated_total": 1250.0,
      "lead_time_days": 1,
      "estimated_delivery": "2026-07-12"
    },
    {
      "product_id": "prod-002",
      "product_name": "Onion",
      "current_stock": 8,
      "reorder_point": 30,
      "suggested_quantity": 100,
      "unit_price": 15.0,
      "estimated_total": 1500.0,
      "lead_time_days": 2,
      "estimated_delivery": "2026-07-13"
    }
  ],
  "total_estimated": 2750.0,
  "timestamp": "2026-07-11T15:45:00Z"
}
```

**Logic:**
```
For each product in Fufaji inventory:
  If product has reorder_rule for this supplier:
    current_stock = get_from_supabase('products', 'available_stock')
    if current_stock <= reorder_point:
      suggested_qty = order_quantity from rule
      total = suggested_qty * unit_price
      lead_time = lead_time_days from rule
      suggested_delivery = now + lead_time_days
```

---

### 2.2 Get Reorder Rules
**Endpoint:** `GET /suppliers/:supplierId/reorder-rules`

**Description:** Fetch all active reorder rules for a supplier

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "rule-001",
      "supplier_id": "uuid-1234",
      "product_id": "prod-001",
      "reorder_point": 20,
      "order_quantity": 50,
      "unit_price": 25.0,
      "discount_percentage": 5.0,
      "min_order_qty": 1,
      "max_order_qty": 1000,
      "lead_time_days": 1,
      "active": true,
      "created_at": "2026-07-01T00:00:00Z"
    }
  ]
}
```

---

### 2.3 Create/Update Reorder Rule
**Endpoint:** `POST /suppliers/:supplierId/reorder-rules`

**Description:** Create a new reorder rule for supplier

**Request:**
```json
{
  "product_id": "prod-001",
  "shop_id": "shop-uuid",
  "reorder_point": 20,
  "order_quantity": 50,
  "unit_price": 25.0,
  "discount_percentage": 5.0,
  "min_order_qty": 1,
  "max_order_qty": 1000,
  "lead_time_days": 1
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "rule_id": "rule-001",
  "message": "Reorder rule created successfully"
}
```

---

## 3. Order Management Endpoints

### 3.1 Get Supplier Orders
**Endpoint:** `GET /suppliers/:supplierId/orders`

**Query Parameters:**
- `status`: draft, confirmed, dispatched, received, cancelled
- `limit`: 50
- `offset`: 0

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "order-001",
      "po_number": "PO-2026-0001",
      "supplier_id": "uuid-1234",
      "status": "confirmed",
      "items": [
        {
          "product_id": "prod-001",
          "quantity": 50,
          "unit_price": 25.0,
          "amount": 1250.0
        }
      ],
      "total_amount": 2750.0,
      "tax_amount": 0.0,
      "discount_amount": 137.5,
      "final_amount": 2612.5,
      "expected_delivery_date": "2026-07-12",
      "actual_delivery_date": null,
      "created_at": "2026-07-11T10:00:00Z",
      "confirmed_at": "2026-07-11T11:00:00Z"
    }
  ]
}
```

---

### 3.2 Accept/Reject Supplier Order
**Endpoint:** `POST /suppliers/orders/:orderId/accept`

**Request:**
```json
{
  "action": "accept"  // or "reject"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "order_id": "order-001",
  "status": "confirmed",
  "message": "Order accepted"
}
```

---

### 3.3 Mark Order Dispatched
**Endpoint:** `POST /suppliers/orders/:orderId/dispatch`

**Request:**
```json
{
  "dispatch_date": "2026-07-12",
  "tracking_number": "TRK123456" // optional
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "order_id": "order-001",
  "status": "dispatched",
  "message": "Order marked as dispatched"
}
```

---

## 4. Payment Endpoints (Razorpay Route)

### 4.1 Request Payment from Owner
**Endpoint:** `POST /suppliers/:supplierId/request-payment`

**Description:** Supplier requests payment; creates payment record

**Request:**
```json
{
  "supplier_order_id": "order-001",  // optional, for specific order
  "amount": 2612.5,
  "description": "Payment for PO-2026-0001 - Fresh Vegetables"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "payment_id": "payment-001",
  "status": "pending",
  "amount": 2612.5,
  "currency": "INR",
  "requested_at": "2026-07-11T16:00:00Z",
  "message": "Payment request created"
}
```

---

### 4.2 Initiate Bulk Supplier Payments (Owner)
**Endpoint:** `POST /suppliers/bulk-payment`

**Description:** Owner initiates payments to multiple suppliers via Razorpay Route API

**Request:**
```json
{
  "supplier_ids": [
    "uuid-1234",
    "uuid-5678",
    "uuid-9999"
  ],
  "amounts": [
    2612.5,
    5000.0,
    1500.0
  ],
  "total_amount": 9112.5,
  "idempotency_key": "bulk-payment-2026-07-11-001"
}
```

**Server Logic:**
```
For each supplier in supplier_ids:
  amount = amounts[index]
  
  // Create payment record
  INSERT INTO supplier_payments
  VALUES (supplier_id, amount, 'pending', razorpay_payment_id=NULL)
  
  // Call Razorpay Route API
  razorpay_response = razorpay.route.create({
    account_number: supplier.bank_account_number,
    ifsc_code: supplier.bank_ifsc_code,
    amount: amount * 100,  // paise
    vpa: null,
    mode: "NEFT",
    purpose: "Payment for supplier orders",
    queue_if_low_balance: false,
    idempotency_key: "supplier-{id}-{timestamp}"
  })
  
  // Update payment record
  UPDATE supplier_payments
  SET razorpay_transfer_id = razorpay_response.id,
      status = 'processing'
  WHERE id = payment_id
```

**Response (202 Accepted):**
```json
{
  "success": true,
  "bulk_payment_id": "bulk-payment-001",
  "total_amount": 9112.5,
  "supplier_count": 3,
  "status": "processing",
  "transfers": [
    {
      "supplier_id": "uuid-1234",
      "supplier_name": "Vegetable Supplier Co",
      "amount": 2612.5,
      "razorpay_transfer_id": "trf_AHfqOvkldxEDYQ",
      "status": "processing"
    },
    // ... more transfers
  ],
  "initiated_at": "2026-07-11T16:05:00Z"
}
```

**Error Response (400):**
```json
{
  "success": false,
  "error": "Invalid bank details",
  "details": {
    "supplier_id": "uuid-1234",
    "reason": "Bank account number missing or invalid"
  }
}
```

---

### 4.3 Get Payment Status
**Endpoint:** `GET /suppliers/payments/:paymentId`

**Description:** Check status of individual payment transfer

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "payment-001",
    "supplier_id": "uuid-1234",
    "amount": 2612.5,
    "status": "success",  // pending, processing, success, failed
    "razorpay_transfer_id": "trf_AHfqOvkldxEDYQ",
    "razorpay_settlement_id": "setl_AHfqOvkldxEDYR",
    "failure_reason": null,
    "initiated_at": "2026-07-11T16:05:00Z",
    "completed_at": "2026-07-11T16:15:00Z"
  }
}
```

---

## 5. Metrics & Analytics Endpoints

### 5.1 Get Supplier Metrics
**Endpoint:** `GET /suppliers/:supplierId/metrics?month=2026-07`

**Description:** Monthly performance aggregation

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "supplier_id": "uuid-1234",
    "metric_month": "2026-07-01",
    "total_orders": 10,
    "completed_orders": 9,
    "on_time_orders": 8,
    "late_orders": 1,
    "cancelled_orders": 0,
    "damaged_items": 0,
    "returned_items": 2,
    "quality_issues": 0,
    "on_time_rate": 88.89,
    "quality_score": 85.0,
    "reliability_score": 86.95,
    "total_amount": 25000.0,
    "total_paid": 24000.0,
    "calculated_at": "2026-07-11T00:00:00Z"
  }
}
```

---

### 5.2 Supplier Leaderboard (Owner)
**Endpoint:** `GET /admin/supplier-leaderboard`

**Query Parameters:**
- `sort_by`: rating, on_time_rate, quality_score, reliability_score
- `limit`: 50

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "rank": 1,
      "supplier_id": "uuid-1234",
      "name": "Vegetable Supplier Co",
      "rating": 4.8,
      "on_time_rate": 98.0,
      "quality_score": 96.0,
      "total_orders": 150,
      "completed_orders": 148,
      "status": "approved"
    },
    // ... more suppliers
  ],
  "generated_at": "2026-07-11T15:45:00Z"
}
```

---

## 6. Webhook Handlers

### 6.1 Razorpay Settlement Webhook
**Endpoint:** `POST /webhooks/razorpay/settlement`

**Description:** Razorpay notifies when settlement completes

**Payload:**
```json
{
  "event": "settlement.processed",
  "contains": ["settlement"],
  "payload": {
    "settlement": {
      "entity": {
        "id": "setl_AHfqOvkldxEDYR",
        "status": "processed",
        "amount": 261250,  // paise
        "fees": 750,
        "tax": 0,
        "utr": "1568176960vDiHkUfZdWAO"
      }
    }
  }
}
```

**Server Logic:**
```
settlement_id = payload.settlement.entity.id
amount_paise = payload.settlement.entity.amount

// Find payment with this settlement_id
payment = SELECT * FROM supplier_payments
          WHERE razorpay_settlement_id = settlement_id

// Update payment status
UPDATE supplier_payments
SET status = 'success',
    completed_at = NOW()
WHERE razorpay_settlement_id = settlement_id

// Update supplier balance
UPDATE suppliers
SET total_paid = total_paid + (amount_paise / 100),
    total_pending = total_pending - (amount_paise / 100)
WHERE id = payment.supplier_id

// Log audit trail
INSERT INTO supplier_audit_log
VALUES (supplier_id, 'payment', details, performed_by)
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Settlement processed"
}
```

---

### 6.2 Payment Failure Webhook
**Endpoint:** `POST /webhooks/razorpay/transfer_failed`

**Payload:**
```json
{
  "event": "transfer.failed",
  "payload": {
    "transfer": {
      "entity": {
        "id": "trf_AHfqOvkldxEDYQ",
        "source": "route",
        "amount": 261250,
        "reason_code": "INVALID_ACCOUNT",
        "on_hold": true
      }
    }
  }
}
```

**Server Logic:**
```
transfer_id = payload.transfer.entity.id
failure_reason = payload.transfer.entity.reason_code

UPDATE supplier_payments
SET status = 'failed',
    failure_reason = failure_reason
WHERE razorpay_transfer_id = transfer_id

// Alert owner
send_notification(owner_id, "Payment failed for supplier", details)
```

---

## 7. Error Handling

All endpoints follow this error format:

```json
{
  "success": false,
  "error": "Error message",
  "error_code": "INVALID_SUPPLIER",
  "details": {}
}
```

**Common Error Codes:**
- `INVALID_SUPPLIER`: Supplier not found
- `UNAUTHORIZED`: User not authorized for this action
- `INVALID_AMOUNT`: Amount is negative or zero
- `BANK_DETAILS_MISSING`: Supplier missing bank account info
- `RAZORPAY_ERROR`: Razorpay API error
- `DUPLICATE_PAYMENT`: Payment already initiated
- `INSUFFICIENT_BALANCE`: Owner account low on balance

---

## 8. Database Transactions

All payment operations are atomic:

```sql
BEGIN TRANSACTION;

INSERT INTO supplier_payments (...) VALUES (...);
UPDATE suppliers SET total_pending = ... WHERE id = ...;

-- Call Razorpay Route API
-- If API fails, ROLLBACK entire transaction

COMMIT;
```

---

## 9. Implementation Checklist

**Endpoints to Implement:**
- [ ] GET /suppliers/:supplierId
- [ ] GET /suppliers
- [ ] GET /suppliers/:supplierId/auto-order-suggestions
- [ ] GET /suppliers/:supplierId/reorder-rules
- [ ] POST /suppliers/:supplierId/reorder-rules
- [ ] GET /suppliers/:supplierId/orders
- [ ] POST /suppliers/orders/:orderId/accept
- [ ] POST /suppliers/orders/:orderId/dispatch
- [ ] POST /suppliers/:supplierId/request-payment
- [ ] POST /suppliers/bulk-payment
- [ ] GET /suppliers/payments/:paymentId
- [ ] GET /suppliers/:supplierId/metrics
- [ ] GET /admin/supplier-leaderboard
- [ ] POST /webhooks/razorpay/settlement
- [ ] POST /webhooks/razorpay/transfer_failed

**Razorpay Integration:**
- [ ] Use Razorpay Route API for transfers
- [ ] Store transfer IDs for reconciliation
- [ ] Handle webhook callbacks for settlements
- [ ] Implement retry logic for failed transfers
- [ ] Add balance validation before payment

**Security:**
- [ ] Validate Firebase tokens on all endpoints
- [ ] Implement rate limiting (10 req/sec per user)
- [ ] Use HTTPS for all communications
- [ ] Log all payment operations
- [ ] Verify idempotency keys for bulk payments

---

**Status: Ready for Render Backend Implementation**

All specifications are finalized. Frontend (Flutter) is ready to call these endpoints once backend is deployed.
