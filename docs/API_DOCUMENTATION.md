# Fufaji Online - API Documentation

**API Version:** 1.0  
**Base URL:** `https://api.fufaji.com/v1`  
**Updated:** June 22, 2026

## Table of Contents

1. [Authentication](#authentication)
2. [API Endpoints](#api-endpoints)
   - [Auth](#auth)
   - [Users](#users)
   - [Products](#products)
   - [Cart](#cart)
   - [Orders](#orders)
   - [Payments](#payments)
   - [Inventory](#inventory)
   - [Packing](#packing)
   - [Delivery](#delivery)
   - [Loyalty](#loyalty)
   - [Support](#support)
3. [Error Handling](#error-handling)
4. [Rate Limiting](#rate-limiting)
5. [Webhooks](#webhooks)
6. [Code Examples](#code-examples)

---

## Authentication

### Overview

Fufaji uses **Firebase Authentication** with custom JWT tokens for API access.

### Token Types

1. **ID Token** (Firebase)
   - Obtained from Firebase Auth SDK
   - Valid for 3600 seconds (1 hour)
   - Renewed automatically by SDK

2. **Custom JWT Token** (Server)
   - Issued after ID token verification
   - Contains user role and permissions
   - Valid for 7 days

### Authentication Headers

All requests require authorization header:

```
Authorization: Bearer {id_token}
```

Or with custom token:

```
Authorization: Bearer {custom_jwt_token}
```

### Example: Firebase Sign-In

```dart
import 'package:firebase_auth/firebase_auth.dart';

final auth = FirebaseAuth.instance;

// Sign up with email and password
final userCredential = await auth.createUserWithEmailAndPassword(
  email: 'user@example.com',
  password: 'SecurePassword123!',
);

// Get ID token
final idToken = await userCredential.user?.getIdToken();

// Use in API requests
final response = await http.get(
  Uri.parse('https://api.fufaji.com/v1/users/profile'),
  headers: {'Authorization': 'Bearer $idToken'},
);
```

### Token Refresh

```dart
// Tokens refresh automatically in SDKs
// Manual refresh if needed:
final newToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);
```

---

## API Endpoints

### Auth

#### POST /auth/signup

Create new user account

**Request:**
```json
{
  "phone": "9876543210",
  "email": "user@example.com",
  "name": "John Doe",
  "role": "customer"
}
```

**Response (201 Created):**
```json
{
  "user_id": "usr_2026_12345",
  "phone": "9876543210",
  "email": "user@example.com",
  "name": "John Doe",
  "role": "customer",
  "created_at": "2026-06-22T10:30:00Z",
  "auth_token": "eyJhbGc..."
}
```

**cURL Example:**
```bash
curl -X POST https://api.fufaji.com/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "9876543210",
    "email": "user@example.com",
    "name": "John Doe",
    "role": "customer"
  }'
```

---

#### POST /auth/verify-otp

Verify phone number with OTP

**Request:**
```json
{
  "phone": "9876543210",
  "otp": "123456"
}
```

**Response (200 OK):**
```json
{
  "verified": true,
  "user_id": "usr_2026_12345",
  "auth_token": "eyJhbGc..."
}
```

---

#### POST /auth/logout

Logout current user

**Request:**
```json
{
  "user_id": "usr_2026_12345"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

#### POST /auth/refresh-token

Refresh authentication token

**Response (200 OK):**
```json
{
  "auth_token": "eyJhbGc...",
  "expires_in": 604800
}
```

---

### Users

#### GET /users/profile

Get current user profile

**Headers:**
```
Authorization: Bearer {id_token}
```

**Response (200 OK):**
```json
{
  "user_id": "usr_2026_12345",
  "phone": "9876543210",
  "email": "user@example.com",
  "name": "John Doe",
  "role": "customer",
  "profile_image": "https://...",
  "wallet_balance": 500.00,
  "loyalty_points": 2350,
  "loyalty_tier": "silver",
  "created_at": "2026-06-22T10:30:00Z",
  "updated_at": "2026-06-22T14:45:00Z"
}
```

**Python Example:**
```python
import requests

headers = {'Authorization': f'Bearer {id_token}'}
response = requests.get(
  'https://api.fufaji.com/v1/users/profile',
  headers=headers
)
user = response.json()
print(f"Welcome {user['name']}!")
```

---

#### PUT /users/profile

Update user profile

**Request:**
```json
{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "profile_image": "https://..."
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "user": {
    "user_id": "usr_2026_12345",
    "name": "Jane Doe",
    "email": "jane@example.com",
    "profile_image": "https://..."
  }
}
```

---

#### GET /users/saved-addresses

Get all saved addresses

**Response (200 OK):**
```json
{
  "addresses": [
    {
      "address_id": "addr_001",
      "label": "Home",
      "address": "123 Main St, Bangalore",
      "lat": 12.9716,
      "lng": 77.6412,
      "is_default": true,
      "delivery_instructions": "Ring bell twice"
    },
    {
      "address_id": "addr_002",
      "label": "Work",
      "address": "456 Business Park, Bangalore",
      "lat": 12.9370,
      "lng": 77.6245,
      "is_default": false
    }
  ]
}
```

---

#### POST /users/saved-addresses

Add new saved address

**Request:**
```json
{
  "label": "Home",
  "address": "123 Main St, Bangalore",
  "lat": 12.9716,
  "lng": 77.6412,
  "is_default": true,
  "delivery_instructions": "Ring bell twice"
}
```

**Response (201 Created):**
```json
{
  "address_id": "addr_001",
  "label": "Home",
  "address": "123 Main St, Bangalore",
  "lat": 12.9716,
  "lng": 77.6412,
  "is_default": true,
  "delivery_instructions": "Ring bell twice"
}
```

---

### Products

#### GET /products

List all products with filters

**Query Parameters:**
```
?category=groceries&sort=price&limit=20&offset=0
?search=milk&price_min=50&price_max=500
?shop_id=shop_001&rating_min=4
```

**Response (200 OK):**
```json
{
  "products": [
    {
      "product_id": "prod_001",
      "name": "Fresh Milk - 1L",
      "category": "dairy",
      "price": 45.00,
      "rating": 4.8,
      "review_count": 245,
      "image": "https://...",
      "shop_id": "shop_001",
      "shop_name": "Fresh Foods",
      "stock": 150,
      "description": "Pure fresh milk",
      "expiry_date": "2026-06-25",
      "tags": ["bestseller", "daily-needs"]
    }
  ],
  "total_count": 1250,
  "limit": 20,
  "offset": 0
}
```

**Node.js Example:**
```javascript
const fetch = require('node-fetch');

async function getProducts(category) {
  const response = await fetch(
    `https://api.fufaji.com/v1/products?category=${category}`,
    {
      headers: { 'Authorization': `Bearer ${idToken}` }
    }
  );
  const data = await response.json();
  return data.products;
}

const products = await getProducts('dairy');
```

---

#### GET /products/{product_id}

Get single product details

**Response (200 OK):**
```json
{
  "product_id": "prod_001",
  "name": "Fresh Milk - 1L",
  "category": "dairy",
  "price": 45.00,
  "rating": 4.8,
  "review_count": 245,
  "images": ["https://...", "https://..."],
  "description": "Pure fresh milk from dairy farm",
  "shop_id": "shop_001",
  "shop_name": "Fresh Foods",
  "shop_rating": 4.7,
  "stock": 150,
  "unit": "1L Packet",
  "manufacturer": "Amul",
  "expiry_date": "2026-06-25",
  "nutritional_info": {
    "calories": 150,
    "protein": "8g",
    "fat": "9g"
  },
  "reviews": [
    {
      "review_id": "rev_001",
      "user_name": "Rajesh K",
      "rating": 5,
      "comment": "Very fresh and tasty",
      "image": "https://..."
    }
  ],
  "tags": ["bestseller", "daily-needs", "fresh"],
  "offers": [
    {
      "type": "percentage",
      "value": 5,
      "description": "5% off on purchase of 2 packets"
    }
  ]
}
```

---

### Cart

#### GET /cart

Get current user's cart

**Response (200 OK):**
```json
{
  "cart_id": "cart_2026_12345",
  "items": [
    {
      "cart_item_id": "ci_001",
      "product_id": "prod_001",
      "product_name": "Fresh Milk - 1L",
      "shop_id": "shop_001",
      "shop_name": "Fresh Foods",
      "price": 45.00,
      "quantity": 2,
      "total": 90.00,
      "image": "https://..."
    }
  ],
  "subtotal": 90.00,
  "delivery_fee": 20.00,
  "discount": 0.00,
  "taxes": 14.40,
  "total": 124.40,
  "created_at": "2026-06-22T14:30:00Z"
}
```

---

#### POST /cart/add

Add item to cart

**Request:**
```json
{
  "product_id": "prod_001",
  "quantity": 2,
  "shop_id": "shop_001"
}
```

**Response (200 OK):**
```json
{
  "cart_id": "cart_2026_12345",
  "item_added": {
    "cart_item_id": "ci_001",
    "product_id": "prod_001",
    "quantity": 2,
    "total": 90.00
  },
  "cart_total": 124.40
}
```

---

#### PUT /cart/update/{cart_item_id}

Update item quantity

**Request:**
```json
{
  "quantity": 3
}
```

**Response (200 OK):**
```json
{
  "cart_item_id": "ci_001",
  "quantity": 3,
  "total": 135.00,
  "cart_total": 174.40
}
```

---

#### DELETE /cart/remove/{cart_item_id}

Remove item from cart

**Response (200 OK):**
```json
{
  "success": true,
  "cart_total": 89.40
}
```

---

#### POST /cart/apply-coupon

Apply coupon code

**Request:**
```json
{
  "coupon_code": "WELCOME50"
}
```

**Response (200 OK):**
```json
{
  "coupon_id": "coup_001",
  "code": "WELCOME50",
  "discount_amount": 50.00,
  "discount_type": "fixed",
  "valid": true,
  "cart_total": 124.40
}
```

---

### Orders

#### POST /orders/create

Create new order

**Request:**
```json
{
  "cart_id": "cart_2026_12345",
  "delivery_address_id": "addr_001",
  "payment_method": "razorpay",
  "coupon_code": "WELCOME50",
  "use_loyalty_points": 0,
  "special_instructions": "Please ring bell twice"
}
```

**Response (201 Created):**
```json
{
  "order_id": "ord_2026_12345",
  "status": "confirmed",
  "total": 124.40,
  "payment_status": "pending",
  "created_at": "2026-06-22T15:30:00Z",
  "items": [
    {
      "product_id": "prod_001",
      "quantity": 2,
      "price": 90.00
    }
  ],
  "estimated_delivery": "2026-06-22T16:00:00Z"
}
```

**cURL Example:**
```bash
curl -X POST https://api.fufaji.com/v1/orders/create \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "cart_id": "cart_2026_12345",
    "delivery_address_id": "addr_001",
    "payment_method": "razorpay",
    "coupon_code": "WELCOME50"
  }'
```

---

#### GET /orders

Get user's order history

**Query Parameters:**
```
?status=all&limit=10&offset=0
?status=pending,delivered&sort=created_at&order=desc
```

**Response (200 OK):**
```json
{
  "orders": [
    {
      "order_id": "ord_2026_12345",
      "status": "delivered",
      "total": 124.40,
      "items_count": 2,
      "shop_name": "Fresh Foods",
      "created_at": "2026-06-22T15:30:00Z",
      "delivered_at": "2026-06-22T15:55:00Z",
      "rating": 4.5
    }
  ],
  "total_count": 45,
  "limit": 10,
  "offset": 0
}
```

---

#### GET /orders/{order_id}

Get order details

**Response (200 OK):**
```json
{
  "order_id": "ord_2026_12345",
  "status": "delivered",
  "total": 124.40,
  "payment_status": "completed",
  "items": [
    {
      "product_id": "prod_001",
      "name": "Fresh Milk - 1L",
      "quantity": 2,
      "price": 45.00,
      "subtotal": 90.00,
      "rating": 4,
      "review": "Good quality"
    }
  ],
  "delivery": {
    "rider_id": "rider_001",
    "rider_name": "Raj Kumar",
    "rider_phone": "+91-9876543210",
    "rider_rating": 4.8,
    "vehicle": "Bike",
    "status": "delivered",
    "picked_at": "2026-06-22T15:35:00Z",
    "delivered_at": "2026-06-22T15:55:00Z"
  },
  "shop": {
    "shop_id": "shop_001",
    "shop_name": "Fresh Foods",
    "shop_address": "123 Market St, Bangalore"
  },
  "address": "123 Main St, Bangalore"
}
```

---

#### POST /orders/{order_id}/cancel

Cancel order

**Request:**
```json
{
  "reason": "Changed my mind"
}
```

**Response (200 OK):**
```json
{
  "order_id": "ord_2026_12345",
  "status": "cancelled",
  "refund_amount": 124.40,
  "refund_status": "initiated",
  "message": "Order cancelled. Refund will be processed within 2-5 business days"
}
```

---

### Payments

#### POST /payments/create-order

Create Razorpay payment order

**Request:**
```json
{
  "order_id": "ord_2026_12345",
  "amount": 12440,
  "currency": "INR"
}
```

**Response (201 Created):**
```json
{
  "razorpay_order_id": "order_1234567890",
  "amount": 12440,
  "currency": "INR",
  "status": "created",
  "receipt": "ord_2026_12345"
}
```

---

#### POST /payments/verify

Verify payment after Razorpay callback

**Request:**
```json
{
  "razorpay_order_id": "order_1234567890",
  "razorpay_payment_id": "pay_29QQoUBi66xm2f",
  "razorpay_signature": "9ef4dffbfd84f1318f6739a3ce19f9d85851857ae648f114332d8401e0949a3d"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "payment_id": "pay_001",
  "order_id": "ord_2026_12345",
  "status": "completed",
  "amount": 12440,
  "verified_at": "2026-06-22T15:30:30Z"
}
```

---

#### GET /payments/{payment_id}

Get payment details

**Response (200 OK):**
```json
{
  "payment_id": "pay_001",
  "order_id": "ord_2026_12345",
  "razorpay_payment_id": "pay_29QQoUBi66xm2f",
  "amount": 12440,
  "status": "completed",
  "method": "card",
  "card": {
    "brand": "visa",
    "last4": "4111",
    "expiry": "12/25"
  },
  "created_at": "2026-06-22T15:30:00Z",
  "verified_at": "2026-06-22T15:30:30Z"
}
```

---

### Inventory

#### GET /inventory/check-stock

Check product stock

**Query Parameters:**
```
?product_id=prod_001&shop_id=shop_001
```

**Response (200 OK):**
```json
{
  "product_id": "prod_001",
  "shop_id": "shop_001",
  "stock": 150,
  "available": true,
  "reserved": 10,
  "reservable": 140
}
```

---

#### POST /inventory/reserve

Reserve stock for order

**Request:**
```json
{
  "order_id": "ord_2026_12345",
  "items": [
    {
      "product_id": "prod_001",
      "quantity": 2
    }
  ]
}
```

**Response (201 Created):**
```json
{
  "reservation_id": "res_001",
  "order_id": "ord_2026_12345",
  "status": "reserved",
  "reserved_until": "2026-06-22T18:30:00Z",
  "items": [
    {
      "product_id": "prod_001",
      "quantity": 2,
      "reserved": true
    }
  ]
}
```

---

### Packing

#### GET /packing/tasks

Get shop's packing tasks

**Headers:**
```
Authorization: Bearer {shop_owner_token}
```

**Response (200 OK):**
```json
{
  "tasks": [
    {
      "task_id": "pack_001",
      "order_id": "ord_2026_12345",
      "status": "pending",
      "items": [
        {
          "product_id": "prod_001",
          "quantity": 2,
          "packed": false
        }
      ],
      "created_at": "2026-06-22T15:30:00Z"
    }
  ],
  "pending_count": 3,
  "in_progress_count": 2,
  "ready_count": 5
}
```

---

#### PUT /packing/tasks/{task_id}

Update packing task status

**Request:**
```json
{
  "status": "ready",
  "items_packed": [
    {
      "product_id": "prod_001",
      "quantity": 2,
      "packed": true
    }
  ]
}
```

**Response (200 OK):**
```json
{
  "task_id": "pack_001",
  "order_id": "ord_2026_12345",
  "status": "ready",
  "packed_at": "2026-06-22T15:45:00Z"
}
```

---

### Delivery

#### GET /delivery/assign

Get delivery assignments for rider

**Headers:**
```
Authorization: Bearer {rider_token}
```

**Response (200 OK):**
```json
{
  "assignments": [
    {
      "delivery_id": "del_001",
      "order_id": "ord_2026_12345",
      "status": "assigned",
      "shop": {
        "shop_id": "shop_001",
        "name": "Fresh Foods",
        "address": "123 Market St",
        "lat": 12.9370,
        "lng": 77.6245
      },
      "delivery_address": "123 Main St, Bangalore",
      "customer": {
        "name": "John Doe",
        "phone": "+91-9876543210"
      },
      "items_count": 2,
      "total": 124.40,
      "assigned_at": "2026-06-22T15:30:00Z"
    }
  ]
}
```

---

#### PUT /delivery/{delivery_id}

Update delivery status

**Request:**
```json
{
  "status": "picked_up",
  "location": {
    "lat": 12.9500,
    "lng": 77.6300,
    "timestamp": "2026-06-22T15:35:00Z"
  }
}
```

**Response (200 OK):**
```json
{
  "delivery_id": "del_001",
  "status": "picked_up",
  "updated_at": "2026-06-22T15:35:00Z"
}
```

---

### Loyalty

#### GET /loyalty/points

Get user's loyalty points

**Response (200 OK):**
```json
{
  "user_id": "usr_2026_12345",
  "total_points": 2350,
  "tier": "silver",
  "points_breakdown": {
    "purchase_points": 2000,
    "review_points": 250,
    "referral_points": 100
  },
  "expiry_date": "2027-06-22",
  "transaction_history": [
    {
      "transaction_id": "tx_001",
      "type": "earned",
      "points": 50,
      "reason": "Order #ord_2026_12345",
      "timestamp": "2026-06-22T15:30:00Z"
    }
  ]
}
```

---

#### POST /loyalty/redeem

Redeem loyalty points

**Request:**
```json
{
  "order_id": "ord_2026_12346",
  "points": 100
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "points_redeemed": 100,
  "credit_amount": 100.00,
  "remaining_points": 2250
}
```

---

### Support

#### POST /support/tickets

Create support ticket

**Request:**
```json
{
  "subject": "Received wrong item",
  "category": "order_issue",
  "order_id": "ord_2026_12345",
  "description": "Received tomato instead of potato",
  "attachments": ["https://..."]
}
```

**Response (201 Created):**
```json
{
  "ticket_id": "tkt_001",
  "status": "open",
  "created_at": "2026-06-22T15:30:00Z",
  "assigned_to": null
}
```

---

#### GET /support/tickets/{ticket_id}

Get support ticket

**Response (200 OK):**
```json
{
  "ticket_id": "tkt_001",
  "subject": "Received wrong item",
  "status": "open",
  "priority": "high",
  "messages": [
    {
      "message_id": "msg_001",
      "from": "usr_2026_12345",
      "message": "Received tomato instead of potato",
      "timestamp": "2026-06-22T15:30:00Z"
    }
  ],
  "created_at": "2026-06-22T15:30:00Z"
}
```

---

## Error Handling

### Error Response Format

All errors follow this structure:

```json
{
  "error": {
    "code": "INVALID_REQUEST",
    "message": "Validation failed",
    "details": {
      "field": "email",
      "issue": "Invalid email format"
    }
  },
  "timestamp": "2026-06-22T15:30:00Z",
  "request_id": "req_12345"
}
```

### HTTP Status Codes

| Code | Meaning | Example |
|------|---------|---------|
| 200 | OK | Successful request |
| 201 | Created | Resource created |
| 400 | Bad Request | Invalid parameters |
| 401 | Unauthorized | Missing/invalid token |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Duplicate email/phone |
| 429 | Rate Limited | Too many requests |
| 500 | Server Error | Internal server error |
| 503 | Service Unavailable | Server maintenance |

### Common Error Codes

```
INVALID_REQUEST - Missing or invalid parameters
UNAUTHORIZED - Authentication failed
FORBIDDEN - Permission denied
NOT_FOUND - Resource doesn't exist
DUPLICATE - Resource already exists
INVALID_STATE - Operation not allowed in current state
RATE_LIMIT_EXCEEDED - Too many requests
PAYMENT_FAILED - Payment processing error
STOCK_UNAVAILABLE - Product out of stock
INVALID_COUPON - Coupon code invalid/expired
```

---

## Rate Limiting

### Limits

- **Public endpoints:** 100 requests/minute per IP
- **Authenticated endpoints:** 500 requests/minute per user
- **Payment endpoints:** 10 requests/minute per user

### Rate Limit Headers

```
X-RateLimit-Limit: 500
X-RateLimit-Remaining: 450
X-RateLimit-Reset: 1687180800
```

### Handling Rate Limits

When rate limited (HTTP 429), retry after `X-RateLimit-Reset` timestamp.

```python
import time
import requests

def request_with_retry(url, headers, max_retries=3):
  for attempt in range(max_retries):
    response = requests.get(url, headers=headers)
    
    if response.status_code == 429:
      retry_after = int(response.headers.get('X-RateLimit-Reset', 60))
      wait_time = retry_after - time.time()
      if wait_time > 0:
        time.sleep(wait_time + 1)
        continue
    
    return response
```

---

## Webhooks

### Webhook Events

Fufaji sends POST requests to your webhook URL for these events:

| Event | Trigger |
|-------|---------|
| `order.created` | New order placed |
| `order.confirmed` | Order confirmed by shop |
| `order.packed` | Order packed and ready |
| `order.picked_up` | Rider picked up order |
| `order.in_delivery` | Order in transit |
| `order.delivered` | Order delivered |
| `order.cancelled` | Order cancelled |
| `payment.completed` | Payment successful |
| `payment.failed` | Payment failed |
| `refund.initiated` | Refund started |
| `refund.completed` | Refund completed |

### Webhook Payload

```json
{
  "event": "order.delivered",
  "timestamp": "2026-06-22T15:55:00Z",
  "data": {
    "order_id": "ord_2026_12345",
    "status": "delivered",
    "total": 124.40,
    "customer": {
      "user_id": "usr_2026_12345",
      "name": "John Doe",
      "phone": "+91-9876543210"
    }
  },
  "signature": "sha256=..."
}
```

### Verifying Webhooks

```python
import hmac
import hashlib

def verify_webhook(payload, signature, secret):
  expected_signature = hmac.new(
    secret.encode(),
    payload.encode(),
    hashlib.sha256
  ).hexdigest()
  
  return hmac.compare_digest(signature, expected_signature)
```

---

## Code Examples

### JavaScript/Node.js

```javascript
const axios = require('axios');

const apiClient = axios.create({
  baseURL: 'https://api.fufaji.com/v1',
  headers: {
    'Authorization': `Bearer ${idToken}`
  }
});

// Get products
async function getProducts(category) {
  try {
    const response = await apiClient.get('/products', {
      params: { category }
    });
    return response.data.products;
  } catch (error) {
    console.error('Error:', error.response.data.error);
  }
}

// Create order
async function createOrder(cartId, addressId) {
  try {
    const response = await apiClient.post('/orders/create', {
      cart_id: cartId,
      delivery_address_id: addressId,
      payment_method: 'razorpay'
    });
    return response.data;
  } catch (error) {
    console.error('Error:', error.response.data.error);
  }
}
```

### Python

```python
import requests
from datetime import datetime

class FufajiAPI:
  def __init__(self, id_token):
    self.base_url = 'https://api.fufaji.com/v1'
    self.headers = {'Authorization': f'Bearer {id_token}'}
  
  def get_user_profile(self):
    response = requests.get(
      f'{self.base_url}/users/profile',
      headers=self.headers
    )
    return response.json()
  
  def create_order(self, cart_id, address_id):
    payload = {
      'cart_id': cart_id,
      'delivery_address_id': address_id,
      'payment_method': 'razorpay'
    }
    response = requests.post(
      f'{self.base_url}/orders/create',
      headers=self.headers,
      json=payload
    )
    return response.json()

# Usage
api = FufajiAPI(id_token)
profile = api.get_user_profile()
print(f"Welcome {profile['name']}!")
```

### Dart/Flutter

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class FufajiAPI {
  final String baseUrl = 'https://api.fufaji.com/v1';
  final String idToken;

  FufajiAPI(this.idToken);

  Future<Map<String, dynamic>> getProducts(String category) async {
    final response = await http.get(
      Uri.parse('$baseUrl/products?category=$category'),
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load products');
    }
  }

  Future<Map<String, dynamic>> createOrder(
    String cartId,
    String addressId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/create'),
      headers: {'Authorization': 'Bearer $idToken'},
      body: jsonEncode({
        'cart_id': cartId,
        'delivery_address_id': addressId,
        'payment_method': 'razorpay',
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create order');
    }
  }
}
```

---

## Support & Resources

- **API Status:** https://status.fufaji.com
- **Support Email:** api-support@fufaji.com
- **Slack Community:** [Join here](https://fufaji-dev.slack.com)
- **GitHub Repository:** https://github.com/fufaji/api-sdk

---

**Last Updated:** June 22, 2026  
**API Version:** 1.0  
**Status:** Production Ready
