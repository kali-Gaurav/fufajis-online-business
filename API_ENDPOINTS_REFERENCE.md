# Fufaji Backend - API Endpoints Reference

**Base URL:** `http://localhost:8080` (dev) or `https://api.fufaji.com` (prod)  
**Authentication:** Firebase ID Token in `Authorization: Bearer {token}`

---

## Authentication Endpoints

### 1. Login with Phone (Send OTP)
```
POST /auth/login
Content-Type: application/json

{
  "phone": "+919999999990"
}

Response (200):
{
  "success": true,
  "message": "OTP sent to your phone"
}
```

### 2. Verify OTP
```
POST /auth/verify-otp
Content-Type: application/json

{
  "phone": "+919999999990",
  "otp": "123456"
}

Response (200):
{
  "success": true,
  "firebase_id_token": "eyJhbGc...",
  "user": {
    "id": "uuid",
    "phone": "+919999999990",
    "email": "user@test.com",
    "role": "customer",
    "shop_id": null
  }
}
```

### 3. Refresh Token
```
POST /auth/refresh
Authorization: Bearer {firebase_id_token}

Response (200):
{
  "firebase_id_token": "eyJhbGc...",
  "expires_in": 3600
}
```

---

## Order Endpoints

### 4. Create Order
```
POST /orders
Authorization: Bearer {token}
Content-Type: application/json

{
  "shop_id": "uuid",
  "items": [
    {
      "product_id": "uuid",
      "quantity": 2,
      "price_at_purchase": 50.00
    }
  ],
  "delivery_address": {
    "street": "123 Main St",
    "city": "Delhi",
    "pincode": "110001",
    "latitude": 28.6139,
    "longitude": 77.2090
  },
  "delivery_instructions": "Ring bell twice",
  "payment_method": "razorpay",
  "order_type": "normal"
}

Response (201):
{
  "id": "uuid",
  "order_number": "FJ-20260622-001",
  "status": "pending_payment",
  "total_amount": 100.00,
  "final_amount": 105.00,
  "razorpay_order_id": "order_IlR5C1sK1gGmKZ",
  "created_at": "2026-06-22T10:30:00Z"
}
```

### 5. Get Order Details
```
GET /orders/{order_id}
Authorization: Bearer {token}

Response (200):
{
  "id": "uuid",
  "order_number": "FJ-20260622-001",
  "customer_id": "uuid",
  "shop_id": "uuid",
  "status": "payment_verified",
  "order_type": "normal",
  "items": [...],
  "final_amount": 105.00,
  "assigned_rider_id": "uuid",
  "payment_method": "razorpay",
  "payment_verified_at": "2026-06-22T10:32:00Z",
  "created_at": "2026-06-22T10:30:00Z"
}
```

### 6. List Customer Orders
```
GET /orders?customer_id={customer_id}&status={status}&limit=20&offset=0
Authorization: Bearer {token}

Response (200):
{
  "total": 42,
  "orders": [
    { order object },
    { order object }
  ]
}
```

### 7. List Shop Orders (for packing)
```
GET /orders?shop_id={shop_id}&status=ready_to_pack,picked,packed
Authorization: Bearer {token}

Response (200):
{
  "total": 8,
  "orders": [
    { order object with packing info }
  ]
}
```

### 8. Cancel Order
```
POST /orders/{order_id}/cancel
Authorization: Bearer {token}
Content-Type: application/json

{
  "reason": "Changed my mind"
}

Response (200):
{
  "success": true,
  "message": "Order cancelled",
  "refund_initiated": true,
  "refund_id": "uuid"
}
```

### 9. Refund Order
```
POST /orders/{order_id}/refund
Authorization: Bearer {token}
Content-Type: application/json

{
  "reason": "delivery_failed"
}

Response (200):
{
  "success": true,
  "refund": {
    "id": "uuid",
    "amount": 105.00,
    "status": "processed",
    "refunded_to": "wallet"
  }
}
```

---

## Payment Endpoints

### 10. Get Payment Status
```
GET /payments/{order_id}
Authorization: Bearer {token}

Response (200):
{
  "id": "uuid",
  "razorpay_payment_id": "pay_IlR5C1sK1gGmKZ",
  "razorpay_order_id": "order_IlR5C1sK1gGmKZ",
  "amount": 105.00,
  "status": "captured",
  "signature_verified": true,
  "created_at": "2026-06-22T10:30:00Z"
}
```

### 11. Razorpay Webhook (Backend receives this)
```
POST /payments/{order_id}/razorpay-webhook
Content-Type: application/json
X-Razorpay-Signature: {signature}

{
  "event": "payment.authorized",
  "payload": {
    "payment": {
      "entity": {
        "id": "pay_IlR5C1sK1gGmKZ",
        "order_id": "order_IlR5C1sK1gGmKZ",
        "amount": 10500,
        "currency": "INR",
        "status": "captured"
      }
    }
  }
}

Response (200):
{
  "success": true,
  "message": "Payment verified and processed"
}
```

---

## Inventory Endpoints

### 12. Check Product Availability
```
GET /inventory/products/{product_id}?shop_id={shop_id}
Authorization: Bearer {token}

Response (200):
{
  "product_id": "uuid",
  "name": "Test Milk",
  "available_qty": 45,
  "reserved_qty": 5,
  "sold_qty": 50,
  "in_stock": true
}
```

### 13. Get Shop Stock Levels
```
GET /inventory/stock?shop_id={shop_id}
Authorization: Bearer {token}

Response (200):
{
  "shop_id": "uuid",
  "products": [
    {
      "product_id": "uuid",
      "name": "Test Milk",
      "available_qty": 45,
      "reserved_qty": 5,
      "sold_qty": 50
    }
  ]
}
```

---

## Packing Endpoints

### 14. Get Packing Tasks (for shop employees)
```
GET /packing/tasks?shop_id={shop_id}&status=ready_to_pick,picked
Authorization: Bearer {token}

Response (200):
{
  "total": 5,
  "tasks": [
    {
      "id": "uuid",
      "order_id": "uuid",
      "order_number": "FJ-20260622-001",
      "status": "ready_to_pick",
      "items": [
        {
          "product_id": "uuid",
          "product_name": "Test Milk",
          "quantity": 2,
          "picked_qty": 0
        }
      ],
      "created_at": "2026-06-22T10:32:00Z"
    }
  ]
}
```

### 15. Mark Item Picked
```
POST /packing/tasks/{task_id}/mark-item-picked
Authorization: Bearer {token}
Content-Type: application/json

{
  "product_id": "uuid",
  "quantity": 2
}

Response (200):
{
  "success": true,
  "task": {
    "id": "uuid",
    "status": "picked",
    "items": [...]
  }
}
```

### 16. Mark Task Complete (Packed)
```
POST /packing/tasks/{task_id}/mark-packed
Authorization: Bearer {token}
Content-Type: application/json

{
  "employee_id": "uuid"
}

Response (200):
{
  "success": true,
  "task": {
    "id": "uuid",
    "status": "packed",
    "packed_at": "2026-06-22T10:45:00Z"
  }
}
```

### 17. Get Task Details
```
GET /packing/tasks/{task_id}
Authorization: Bearer {token}

Response (200):
{
  "id": "uuid",
  "order_id": "uuid",
  "shop_id": "uuid",
  "status": "packed",
  "items": [...],
  "packed_by_employee_id": "uuid",
  "created_at": "2026-06-22T10:32:00Z",
  "packed_at": "2026-06-22T10:45:00Z"
}
```

---

## Delivery Endpoints

### 18. Get Rider's Assigned Orders
```
GET /delivery/orders?rider_id={rider_id}&status=packed,in_transit
Authorization: Bearer {token}

Response (200):
{
  "total": 3,
  "orders": [
    {
      "id": "uuid",
      "order_number": "FJ-20260622-001",
      "status": "packed",
      "customer_id": "uuid",
      "customer_phone": "+919999999991",
      "customer_name": "John Doe",
      "delivery_location": {
        "street": "456 Oak Ave",
        "city": "Delhi",
        "latitude": 28.6200,
        "longitude": 77.2150
      },
      "delivery_assignment_id": "uuid"
    }
  ]
}
```

### 19. Mark Order Picked Up
```
POST /delivery/{assignment_id}/pickup
Authorization: Bearer {token}

Response (200):
{
  "success": true,
  "message": "Marked as picked up",
  "assignment": {
    "id": "uuid",
    "status": "picked_up",
    "picked_up_at": "2026-06-22T10:50:00Z"
  }
}
```

### 20. Update Rider Location (Real-time)
```
POST /delivery/{assignment_id}/location
Authorization: Bearer {token}
Content-Type: application/json

{
  "latitude": 28.6175,
  "longitude": 77.2135,
  "accuracy": 5
}

Response (200):
{
  "success": true,
  "message": "Location updated",
  "last_update": "2026-06-22T10:52:15Z"
}
```

### 21. Mark Order Delivered
```
POST /delivery/{assignment_id}/deliver
Authorization: Bearer {token}
Content-Type: application/json

{
  "signature_image_url": "https://...",
  "notes": "Delivered to customer"
}

Response (200):
{
  "success": true,
  "message": "Order marked as delivered",
  "assignment": {
    "id": "uuid",
    "status": "delivered",
    "delivered_at": "2026-06-22T11:05:00Z"
  }
}
```

### 22. Get Active Orders with Live Locations
```
GET /delivery/active-orders
Authorization: Bearer {token}

Response (200):
{
  "orders": [
    {
      "order_id": "uuid",
      "order_number": "FJ-20260622-001",
      "rider_id": "uuid",
      "rider_name": "Raj",
      "current_location": {
        "latitude": 28.6175,
        "longitude": 77.2135,
        "updated_at": "2026-06-22T11:02:00Z"
      },
      "delivery_location": {...},
      "estimated_arrival": "2026-06-22T11:15:00Z"
    }
  ]
}
```

---

## Admin Endpoints

### 23. Get Dashboard Stats
```
GET /admin/dashboard
Authorization: Bearer {admin_token}

Response (200):
{
  "system_status": "healthy",
  "today": {
    "total_orders": 127,
    "delivered_orders": 112,
    "cancelled_orders": 3,
    "total_revenue": 6350.50
  },
  "active_deliveries": 12,
  "pending_refunds": 2,
  "failed_payments": 1
}
```

### 24. Get Analytics
```
GET /admin/analytics?period=week&metric=orders,revenue,ratings
Authorization: Bearer {admin_token}

Response (200):
{
  "period": "week",
  "data": {
    "orders": {
      "2026-06-16": 45,
      "2026-06-17": 52,
      ...
    },
    "revenue": {
      "2026-06-16": 2250.00,
      ...
    }
  }
}
```

### 25. Update Shop Config
```
POST /admin/config
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "shop_id": "uuid",
  "min_order_amount": 100.00,
  "delivery_charge": 50.00,
  "tax_percentage": 5.0
}

Response (200):
{
  "success": true,
  "config": {...}
}
```

---

## Health & Status Endpoints

### 26. Health Check
```
GET /health

Response (200):
{
  "status": "healthy",
  "timestamp": "2026-06-22T11:10:00Z",
  "database": "connected",
  "firebase": "connected",
  "uptime_seconds": 3600
}
```

### 27. Database Connection Check
```
GET /admin/db-check
Authorization: Bearer {admin_token}

Response (200):
{
  "supabase": "connected",
  "firestore": "connected",
  "redis": "connected"
}
```

---

## Error Responses

All errors return a consistent format:

```json
{
  "success": false,
  "error": "ORDER_NOT_FOUND",
  "message": "Order with ID 'xyz' not found",
  "status_code": 404,
  "timestamp": "2026-06-22T11:10:00Z"
}
```

### Common Error Codes

| Code | Status | Meaning |
|------|--------|---------|
| `UNAUTHORIZED` | 401 | Missing or invalid Firebase token |
| `FORBIDDEN` | 403 | User doesn't have permission |
| `ORDER_NOT_FOUND` | 404 | Order doesn't exist |
| `PAYMENT_FAILED` | 402 | Payment verification failed |
| `INVALID_PAYMENT_METHOD` | 400 | Unknown payment method |
| `INVENTORY_UNAVAILABLE` | 409 | Product out of stock |
| `INVALID_REQUEST` | 400 | Request validation failed |
| `INTERNAL_ERROR` | 500 | Server error |

---

## Rate Limiting

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1624325400
```

- **Limit**: 1000 requests per hour per user
- **Burst**: 10 requests per second
- Returns `429 Too Many Requests` when exceeded

---

## Pagination

Endpoints that return lists support pagination:

```
GET /orders?limit=20&offset=40

{
  "total": 200,
  "limit": 20,
  "offset": 40,
  "orders": [...]
}
```

---

## Timestamps

All timestamps are in UTC ISO 8601 format:
```
2026-06-22T11:10:00Z
```

---

## Testing with cURL

```bash
# Login
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone": "+919999999990"}'

# Verify OTP
TOKEN=$(curl -X POST http://localhost:8080/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"phone": "+919999999990", "otp": "123456"}' \
  | jq -r '.firebase_id_token')

# Get orders
curl -X GET http://localhost:8080/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

---

## Testing with Postman

Import this Postman collection:

```
https://www.postman.com/collections/YOUR_COLLECTION_ID
```

Or create a new collection in Postman:
1. Create `Dev` environment with `BASE_URL=http://localhost:8080`
2. Add `Authorization: Bearer {{token}}` to collection headers
3. After login, save the token to environment variable

---

**Questions?** Check `BACKEND_ARCHITECTURE.md` for service details or `DEPLOYMENT_GUIDE.md` for setup.
