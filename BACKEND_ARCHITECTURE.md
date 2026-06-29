# Fufaji Store - Complete Backend Architecture

**Status**: Design Phase  
**Tech Stack**: Dart (Shelf framework) + Supabase + Firebase Auth + Firestore  
**Deployment**: Docker on Self-Hosted VPS with GitHub Actions CI/CD  
**Last Updated**: 2026-06-21

---

## 1. System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter Mobile App                            │
│                    (Firebase Auth)                               │
└────────────────────────┬────────────────────────────────────────┘
                         │ HTTPS REST API
┌────────────────────────▼────────────────────────────────────────┐
│              Dart Backend (Shelf Framework)                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ API Handlers: /orders, /payments, /inventory, /delivery  │   │
│  │ Middleware: Auth, Logging, Error Handling, Rate Limiting │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Services Layer (Business Logic)                           │   │
│  │  • OrderService (unified)                                │   │
│  │  • PaymentService (Razorpay + Stripe + Wallet)          │   │
│  │  • InventoryService (reservations + stock deduction)    │   │
│  │  • PackingService (unified fulfillment)                 │   │
│  │  • DeliveryService (unified rider assignment)           │   │
│  │  • RefundService (wallet + stock recovery)              │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Data Layer (Repositories)                                │   │
│  │  • SupabaseRepository (Postgres queries)                 │   │
│  │  • FirestoreRepository (document reads/writes)           │   │
│  │  • CacheRepository (Redis)                               │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
         │                      │                      │
         │                      │                      │
┌────────▼──────────┐  ┌────────▼──────────┐  ┌──────▼───────────┐
│   Supabase        │  │  Firestore        │  │  Firebase Auth    │
│   (Postgres)      │  │  (Real-time docs) │  │  (ID Tokens)      │
│                   │  │                   │  │                   │
│ Tables:           │  │ Collections:      │  │ Users with:       │
│ • users           │  │ • user_profiles   │  │ • email           │
│ • shops           │  │ • delivery_       │  │ • role (custom)   │
│ • products        │  │   assignments     │  │ • shop_id         │
│ • orders          │  │ • live_locations  │  │ • phone           │
│ • payments        │  │ • coupons         │  │                   │
│ • refunds         │  │ • inventory_      │  │ Webhook Secrets   │
│ • inventory_      │  │   reservations    │  │ (Razorpay)        │
│   reservations    │  │                   │  │                   │
│ • packing_tasks   │  │                   │  │                   │
│ • delivery_       │  │                   │  │                   │
│   assignments     │  │                   │  │                   │
└───────────────────┘  └───────────────────┘  └───────────────────┘
```

---

## 2. Data Models & Database Schema

### 2.1 Supabase (PostgreSQL) - Relational Data

**users table** (user master data)
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid VARCHAR(255) UNIQUE NOT NULL,
  phone VARCHAR(20) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  role VARCHAR(50) NOT NULL CHECK (role IN ('customer', 'owner', 'rider', 'admin')),
  shop_id UUID REFERENCES shops(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE
);
```

**shops table**
```sql
CREATE TABLE shops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES users(id),
  name VARCHAR(255) NOT NULL,
  location_lat DECIMAL(10, 8),
  location_long DECIMAL(11, 8),
  image_url VARCHAR(255),
  rating DECIMAL(3, 2),
  created_at TIMESTAMP DEFAULT NOW()
);
```

**products table**
```sql
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID NOT NULL REFERENCES shops(id),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price DECIMAL(10, 2) NOT NULL,
  cost_price DECIMAL(10, 2),
  sku VARCHAR(100) UNIQUE,
  category VARCHAR(100),
  image_url VARCHAR(255),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**orders table** (SINGLE ORDER ENGINE - consolidates all 4 engines)
```sql
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number VARCHAR(50) UNIQUE NOT NULL, -- Generated by backend
  customer_id UUID NOT NULL REFERENCES users(id),
  shop_id UUID NOT NULL REFERENCES shops(id),
  
  -- Order content
  items JSONB NOT NULL, -- [{product_id, quantity, price}, ...]
  total_amount DECIMAL(10, 2) NOT NULL,
  discount_amount DECIMAL(10, 2) DEFAULT 0,
  tax_amount DECIMAL(10, 2) DEFAULT 0,
  delivery_charge DECIMAL(10, 2) DEFAULT 0,
  final_amount DECIMAL(10, 2) NOT NULL,
  
  -- Order state (single source of truth)
  status VARCHAR(50) NOT NULL CHECK (status IN (
    'pending_payment', 'payment_verified', 'ready_to_pack', 
    'picked', 'packed', 'assigned_to_delivery', 
    'picked_up', 'in_transit', 'delivered', 'cancelled', 'refunded'
  )),
  
  -- Order type
  order_type VARCHAR(50) DEFAULT 'normal' CHECK (order_type IN (
    'normal', 'wallet', 'group_buy', 'reorder'
  )),
  
  -- Delivery info
  delivery_address JSONB NOT NULL, -- {street, city, pincode, lat, lng}
  delivery_instructions TEXT,
  assigned_rider_id UUID REFERENCES users(id),
  estimated_delivery_time TIMESTAMP,
  
  -- Payment info
  payment_method VARCHAR(50), -- 'razorpay', 'stripe', 'wallet', 'cash'
  razorpay_order_id VARCHAR(255),
  razorpay_payment_id VARCHAR(255),
  payment_verified_at TIMESTAMP,
  
  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  -- Foreign keys & indexes
  CONSTRAINT valid_amounts CHECK (final_amount = total_amount - discount_amount + tax_amount + delivery_charge)
);

CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_shop_id ON orders(shop_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
```

**payments table** (Complete payment history)
```sql
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  razorpay_payment_id VARCHAR(255),
  razorpay_order_id VARCHAR(255),
  
  amount DECIMAL(10, 2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'INR',
  payment_method VARCHAR(50),
  
  -- Payment state machine
  status VARCHAR(50) NOT NULL CHECK (status IN (
    'created', 'authorized', 'captured', 'failed', 'refunded'
  )),
  
  -- Webhook verification
  razorpay_signature VARCHAR(255),
  signature_verified BOOLEAN DEFAULT FALSE,
  webhook_received_at TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_payments_razorpay_payment_id ON payments(razorpay_payment_id);
```

**refunds table** (Track all refunds)
```sql
CREATE TABLE refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id),
  payment_id UUID NOT NULL REFERENCES payments(id),
  
  amount DECIMAL(10, 2) NOT NULL,
  reason VARCHAR(255), -- 'customer_cancel', 'delivery_failed', 'item_unavailable'
  status VARCHAR(50) CHECK (status IN ('pending', 'processed', 'failed')),
  
  -- Restoration
  refund_to_wallet BOOLEAN DEFAULT TRUE,
  stock_restored BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMP DEFAULT NOW()
);
```

**inventory_stock table** (Current stock levels)
```sql
CREATE TABLE inventory_stock (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id),
  shop_id UUID NOT NULL REFERENCES shops(id),
  
  available_qty INT NOT NULL DEFAULT 0, -- actual - reserved
  reserved_qty INT NOT NULL DEFAULT 0, -- locked for pending orders
  sold_qty INT NOT NULL DEFAULT 0,
  
  last_updated TIMESTAMP DEFAULT NOW()
);
```

**packing_tasks table** (Unified fulfillment workflow)
```sql
CREATE TABLE packing_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id),
  shop_id UUID NOT NULL REFERENCES shops(id),
  
  status VARCHAR(50) NOT NULL CHECK (status IN (
    'ready_to_pick', 'picked', 'packed', 'handed_off'
  )),
  
  items JSONB NOT NULL, -- [{product_id, qty, picked_qty}, ...]
  packed_by_employee_id UUID REFERENCES users(id),
  
  created_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP,
  
  CONSTRAINT picked_qty_consistency CHECK (
    (status = 'picked' OR status = 'packed') OR picked_qty IS NULL
  )
);

CREATE INDEX idx_packing_tasks_shop_id ON packing_tasks(shop_id);
CREATE INDEX idx_packing_tasks_status ON packing_tasks(status);
```

**delivery_assignments table** (Unified delivery service)
```sql
CREATE TABLE delivery_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  rider_id UUID NOT NULL REFERENCES users(id),
  
  status VARCHAR(50) NOT NULL CHECK (status IN (
    'assigned', 'picked_up', 'in_transit', 'delivered', 'failed'
  )),
  
  pickup_location JSONB NOT NULL, -- shop location
  delivery_location JSONB NOT NULL, -- customer location
  
  picked_up_at TIMESTAMP,
  delivered_at TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_delivery_assignments_rider_id ON delivery_assignments(rider_id);
CREATE INDEX idx_delivery_assignments_order_id ON delivery_assignments(order_id);
CREATE INDEX idx_delivery_assignments_status ON delivery_assignments(status);
```

---

### 2.2 Firestore - Real-time & Semi-structured Data

**Collections to create** (all with RLS policies):

```
firestore/
├── user_profiles/{uid}
│   ├── phone
│   ├── email
│   ├── role
│   ├── shop_id
│   ├── profile_image
│   └── verified: boolean
│
├── shops/{shop_id}
│   ├── name
│   ├── location
│   ├── owner_id
│   ├── active: boolean
│   └── metadata
│
├── products/{product_id}
│   ├── name, price, category
│   ├── in_stock: boolean
│   └── rating: number
│
├── live_locations/{rider_id}
│   ├── latitude
│   ├── longitude
│   ├── timestamp
│   └── accuracy
│
├── orders/{order_id}
│   └── Real-time mirror of Postgres orders table
│       (synced via trigger: order updates → Firestore)
│
├── inventory_reservations/{reservation_id}
│   ├── order_id
│   ├── product_id
│   ├── quantity
│   ├── expires_at (5 min timeout)
│   └── status: ('reserved' | 'confirmed' | 'released')
│
├── coupons/{coupon_id}
│   ├── code
│   ├── discount
│   ├── validity
│   └── usage_count
│
└── delivery_assignments/{assignment_id}
    └── Real-time mirror (synced via trigger)
```

---

## 3. Service Layer (Business Logic)

### 3.1 Order Service (Unified - Consolidates 4 engines)

**Current broken state:**
- OrderService (live)
- WalletOrderService (duplicate)
- GroupBuyService (orphaned)
- ReorderService (partial)

**New unified approach:**
```dart
class OrderService {
  Future<Order> createOrder({
    required String customerId,
    required String shopId,
    required List<CartItem> items,
    required OrderType type, // normal, wallet, group_buy, reorder
    required DeliveryAddress delivery,
    required String paymentMethod,
  }) async {
    // 1. Validate inventory
    // 2. Create Supabase order record
    // 3. Create Firestore inventory_reservations (5 min expiry)
    // 4. Trigger payment flow
    // 5. Return order with status: 'pending_payment'
  }
  
  Future<void> verifyPayment({
    required String orderId,
    required String razorpayPaymentId,
  }) async {
    // 1. Verify signature against Razorpay webhook_secret
    // 2. Lock order.status = 'payment_verified'
    // 3. Deduct stock from inventory_stock
    // 4. Clear inventory_reservations
    // 5. Notify shop (packing task created)
  }
  
  Future<void> cancelOrder(String orderId) async {
    // 1. Check if paid or pending
    // 2. If paid: trigger RefundService
    // 3. Release inventory_reservations
    // 4. Update order.status = 'cancelled'
  }
}
```

### 3.2 Payment Service (Razorpay + Stripe + Wallet)

**Critical fix:** Separate key_secret from webhook_secret
```dart
class PaymentService {
  final RazorpayConfig _config = RazorpayConfig(
    key_id: 'rzp_live_xxx', // Public
    key_secret: 'rz_key_secret_xxx', // For server-side API calls
    webhook_secret: 'rz_webhook_secret_xxx', // DIFFERENT - for webhook verification
  );
  
  Future<RazorpayOrder> initiate({
    required String orderId,
    required double amount,
  }) async {
    // 1. Create Razorpay order via API (use key_secret)
    // 2. Store razorpay_order_id in Postgres payments table
    // 3. Return to client
  }
  
  Future<void> verifyWebhook({
    required String razorpaySignature,
    required String payload,
  }) async {
    // Verify using webhook_secret (NOT key_secret!)
    // payload = Razorpay webhook JSON
    // signature = SHA256(payload + webhook_secret)
    
    final isValid = verifyHmacSha256(
      payload: payload,
      secret: _config.webhook_secret, // CORRECT
      signature: razorpaySignature,
    );
    
    if (!isValid) throw SecurityException('Invalid webhook signature');
    
    // Process payment
    final decoded = jsonDecode(payload);
    await _processPayment(decoded);
  }
  
  Future<void> refund({
    required String paymentId,
    required double amount,
  }) async {
    // Call Razorpay refund API
    // Update payments table
    // Trigger RefundService for wallet/stock
  }
}
```

### 3.3 Inventory Service (Reservations + Stock Deduction)

**Problem:** Checkout reservations need Firestore docs that nothing creates.

```dart
class InventoryService {
  /// Called during checkout (before payment)
  Future<String> reserveInventory({
    required String orderId,
    required List<CartItem> items,
  }) async {
    // 1. Create Firestore inventory_reservations/{reservation_id}
    // 2. Set TTL = 5 minutes (auto-cleanup)
    // 3. Create backup cleanup timer
    // 4. Return reservation_id
  }
  
  /// Called when payment verified
  Future<void> deductStockOnPayment(String orderId) async {
    // 1. Get order items from Supabase
    // 2. For each item:
    //    UPDATE inventory_stock
    //    SET available_qty -= quantity,
    //        sold_qty += quantity
    // 3. Delete Firestore reservation
  }
  
  /// Called on refund or order cancel
  Future<void> restoreStock(String orderId) async {
    // 1. Get original order items
    // 2. Increment available_qty
    // 3. Decrement sold_qty
  }
  
  /// CRITICAL: Wallet orders currently skip this
  Future<void> handleWalletOrder(String orderId) async {
    // Same as normal order - NO SKIPPING
    await deductStockOnPayment(orderId);
  }
}
```

### 3.4 Packing Service (Unified Fulfillment)

**Current state:** 3 orphaned workflows with different Firestore paths/status formats.

```dart
class PackingService {
  /// Create packing task (called after payment verified)
  Future<String> createPackingTask(String orderId) async {
    // 1. Get order from Supabase
    // 2. Create packing_tasks record
    // 3. Sync to Firestore packing_tasks/{task_id}
    // 4. Notify shop employees
  }
  
  /// Employee picks items
  Future<void> markItemPicked({
    required String taskId,
    required String productId,
    required int quantity,
  }) async {
    // 1. Update packing_tasks.items[].picked_qty
    // 2. Sync to Firestore
    // 3. If all items picked: transition to 'picked'
  }
  
  /// Mark entire task as packed
  Future<void> markPacked({
    required String taskId,
    required String employeeId,
  }) async {
    // 1. packing_tasks.status = 'packed'
    // 2. orders.status = 'packed'
    // 3. Notify delivery system
  }
}
```

### 3.5 Delivery Service (Unified - Fix Rider Queries)

**Problem:** Rider queries use bare strings that can't match qualified status from packing.

```dart
class DeliveryService {
  /// Assign order to rider
  Future<String> assignToRider({
    required String orderId,
    required String riderId,
  }) async {
    // 1. Create delivery_assignments record
    // 2. Update orders.assigned_rider_id
    // 3. Sync to Firestore
  }
  
  /// Get rider's assigned orders (FIX: use qualified status)
  Future<List<Order>> getRiderOrders(String riderId) async {
    // BEFORE (broken):
    // SELECT * FROM orders WHERE assigned_rider_id = ? AND status = 'assigned'
    // (status is 'packed', not 'assigned' - mismatch!)
    
    // AFTER (fixed):
    // SELECT * FROM orders WHERE assigned_rider_id = ? 
    //        AND status IN ('packed', 'assigned_to_delivery')
    // (match the actual status from packing service)
    
    return await _db.orders
        .where('assigned_rider_id', isEqualTo: riderId)
        .where('status', whereIn: ['packed', 'assigned_to_delivery'])
        .orderBy('created_at', descending: true)
        .get();
  }
  
  /// Rider picks up order
  Future<void> markPickedUp(String assignmentId) async {
    // 1. delivery_assignments.status = 'picked_up'
    // 2. orders.status = 'picked_up'
    // 3. Start location tracking
  }
  
  /// Update location (real-time)
  Future<void> updateLocation({
    required String riderId,
    required double lat,
    required double lng,
  }) async {
    // 1. Firestore live_locations/{rider_id}
    //    {latitude, longitude, timestamp}
    // 2. Customers see real-time location
  }
  
  /// Mark as delivered
  Future<void> markDelivered(String assignmentId) async {
    // 1. delivery_assignments.status = 'delivered'
    // 2. orders.status = 'delivered'
    // 3. Trigger wallet top-up if group_buy order
  }
}
```

### 3.6 Refund Service (Wallet + Stock Recovery)

**Problems:**
- Zero-fee cancellations not refunding
- Wallet orders not restoring stock
- Orphaned refund screen still open

```dart
class RefundService {
  /// Handle order cancellation or refund
  Future<void> refundOrder({
    required String orderId,
    required String reason,
  }) async {
    final order = await _db.getOrder(orderId);
    
    // 1. Check if payment was made
    if (order.status == 'pending_payment') {
      // Not paid - just cancel
      await _db.updateOrder(orderId, {'status': 'cancelled'});
      await _inventoryService.restoreStock(orderId);
      return;
    }
    
    // 2. Refund logic
    if (order.paymentMethod == 'razorpay') {
      await _paymentService.refund(
        paymentId: order.razorpayPaymentId,
        amount: order.finalAmount,
      );
    } else if (order.paymentMethod == 'wallet') {
      // CRITICAL FIX: wallet orders need stock restoration too
      await _walletService.addBalance(
        userId: order.customerId,
        amount: order.finalAmount,
      );
    }
    
    // 3. Restore stock (works for all payment methods)
    await _inventoryService.restoreStock(orderId);
    
    // 4. Update order
    await _db.updateOrder(orderId, {'status': 'refunded'});
  }
}
```

---

## 4. Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // User profiles - users can only read/modify their own
    match /user_profiles/{uid} {
      allow read: if request.auth.uid == uid;
      allow write: if request.auth.uid == uid
        && !request.resource.data.role // Prevent self-write of role
        && !request.resource.data.shop_id; // Prevent self-write of shop
    }
    
    // Products - public read, shop owner write
    match /products/{productId} {
      allow read: if true;
      allow write: if request.auth.token.shop_id == resource.data.shop_id
        && request.auth.token.role == 'owner';
    }
    
    // Orders - customer/owner can read own, backend can write
    match /orders/{orderId} {
      allow read: if request.auth.uid == resource.data.customer_id
        || request.auth.token.shop_id == resource.data.shop_id;
      allow write: if request.auth.token.is_backend == true;
    }
    
    // Coupons - read-only, backend maintains
    match /coupons/{couponId} {
      allow read: if true;
      allow write: if request.auth.token.is_backend == true;
    }
    
    // Inventory reservations - backend only
    match /inventory_reservations/{reservationId} {
      allow read, write: if request.auth.token.is_backend == true;
    }
    
    // Live locations - rider can update own, customer/admin can read
    match /live_locations/{riderId} {
      allow write: if request.auth.uid == riderId;
      allow read: if request.auth.token.role in ['admin', 'owner']
        || request.auth.uid == riderId;
    }
    
    // Delivery assignments - backend maintains
    match /delivery_assignments/{assignmentId} {
      allow read: if request.auth.uid == resource.data.rider_id
        || request.auth.token.role == 'owner';
      allow write: if request.auth.token.is_backend == true;
    }
  }
}
```

---

## 5. API Endpoints (Dart/Shelf)

### Authentication
- `POST /auth/login` - Firebase sign-up/login with phone OTP
- `POST /auth/verify-otp` - Verify OTP, get Firebase ID token
- `POST /auth/refresh` - Refresh ID token

### Orders
- `POST /orders` - Create order (creates reservation + pending order)
- `GET /orders/{orderId}` - Get order details
- `GET /orders?customerId={id}` - List customer orders
- `GET /orders?shopId={id}&status=ready_to_pack` - List shop's packing tasks
- `POST /orders/{orderId}/cancel` - Cancel order
- `POST /orders/{orderId}/refund` - Initiate refund

### Payments
- `POST /payments/{orderId}/razorpay-webhook` - Razorpay webhook handler
- `GET /payments/{orderId}` - Get payment status

### Inventory
- `GET /inventory/products/{productId}` - Check availability
- `POST /inventory/reserve` - Create reservation (used internally)
- `GET /inventory/stock?shopId={id}` - Get shop's stock levels

### Packing
- `GET /packing/tasks?shopId={id}` - List packing tasks
- `POST /packing/tasks/{taskId}/mark-item-picked` - Mark item picked
- `POST /packing/tasks/{taskId}/mark-packed` - Mark task complete
- `GET /packing/tasks/{taskId}` - Get task details

### Delivery
- `GET /delivery/orders?riderId={id}` - Get rider's assigned orders
- `POST /delivery/{assignmentId}/pickup` - Mark picked up
- `POST /delivery/{assignmentId}/location` - Update location
- `POST /delivery/{assignmentId}/deliver` - Mark delivered
- `GET /delivery/active-orders` - Active orders with live locations

### Admin
- `GET /admin/dashboard` - System status
- `GET /admin/analytics` - Revenue, order stats
- `POST /admin/config` - Update shop config

---

## 6. Critical Security Fixes

### 6.1 Secrets Rotation (IMMEDIATE)

**Current state:** PUBLIC on GitHub + in APK
```
❌ razorpay_key_secret
❌ razorpay_webhook_secret (SAME VALUE - breaks verification)
❌ firebase_config.json
❌ signing_key.jks
```

**Action plan:**
1. Remove all secrets from GitHub (`.gitignore` them)
2. Move to Supabase secrets vault or GitHub Actions secrets
3. Rotate Razorpay credentials (generate new key pair)
4. Create separate webhook_secret
5. Update APK signing to use CI/CD-provided credentials
6. Force users to update app (revoke old signing key)

### 6.2 SQL Injection Fix
- Replace all string concatenation with parameterized queries
- Audit approval_workflow_service.dart specifically

### 6.3 Firestore Rules
- Enable security rules for all 10+ collections
- Block all self-writes except email/profile
- Implement role-based access

### 6.4 Payment Verification
- Fix webhook_secret != key_secret
- Implement webhook signature verification
- Add replay attack prevention (idempotency keys)

---

## 7. Deployment Architecture

```
GitHub Repository
    │
    └─→ git push
        │
        └─→ GitHub Actions CI
            ├─ Run tests (dart test)
            ├─ Lint (dart analyze)
            ├─ Build Docker image
            ├─ Push to registry
            └─ Trigger deploy.sh on VPS
                │
                └─→ VPS (Self-Hosted)
                    ├─ docker-compose pull
                    ├─ docker-compose up -d
                    ├─ Health check: GET /health
                    └─ Notify Slack on success/failure
```

**Dockerfile:**
```dockerfile
FROM google/dart:latest

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o bin/server

EXPOSE 8080
CMD ["./bin/server"]
```

**docker-compose.yml:**
```yaml
version: '3.8'
services:
  backend:
    build: .
    ports:
      - "8080:8080"
    environment:
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
      - FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}
      - RAZORPAY_KEY_ID=${RAZORPAY_KEY_ID}
      - RAZORPAY_KEY_SECRET=${RAZORPAY_KEY_SECRET}
      - RAZORPAY_WEBHOOK_SECRET=${RAZORPAY_WEBHOOK_SECRET}
    depends_on:
      - supabase
      - redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 3
  
  supabase:
    image: supabase/postgres:latest
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
  
  redis:
    image: redis:latest
```

**GitHub Actions deploy trigger:**
```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run tests
        run: dart test
      - name: Build Docker
        run: docker build -t fufaji-backend:${{ github.sha }} .
      - name: Deploy to VPS
        run: |
          scp -r . ${{ secrets.VPS_USER }}@${{ secrets.VPS_HOST }}:/app
          ssh ${{ secrets.VPS_USER }}@${{ secrets.VPS_HOST }} 'cd /app && ./deploy.sh'
```

---

## 8. Implementation Order

1. **Security first (this week):**
   - Rotate secrets
   - Push new GitHub Actions with secret injection
   - Remove secrets from repo

2. **Database (next week):**
   - Create Supabase migrations
   - Set up Firestore collections
   - Create security rules

3. **Services (Week 3-4):**
   - OrderService (unified)
   - PaymentService (Razorpay fixed)
   - InventoryService
   - PackingService
   - DeliveryService

4. **API & Deployment (Week 5):**
   - Shelf endpoints
   - Docker setup
   - GitHub Actions
   - Health monitoring

---

## 9. Key Files to Create

```
fufaji-backend/
├── bin/
│   └── server.dart                 # Entry point
├── lib/
│   ├── handlers/                   # API route handlers
│   │   ├── auth_handler.dart
│   │   ├── order_handler.dart
│   │   ├── payment_handler.dart
│   │   ├── inventory_handler.dart
│   │   ├── packing_handler.dart
│   │   └── delivery_handler.dart
│   ├── middleware/                 # Auth, logging, error handling
│   │   ├── auth_middleware.dart
│   │   ├── logging_middleware.dart
│   │   └── error_handler.dart
│   ├── services/                   # Business logic
│   │   ├── order_service.dart
│   │   ├── payment_service.dart
│   │   ├── inventory_service.dart
│   │   ├── packing_service.dart
│   │   ├── delivery_service.dart
│   │   └── refund_service.dart
│   ├── repositories/               # Data access
│   │   ├── supabase_repository.dart
│   │   ├── firestore_repository.dart
│   │   └── cache_repository.dart
│   ├── models/                     # Data classes
│   │   ├── order.dart
│   │   ├── payment.dart
│   │   ├── user.dart
│   │   └── ...
│   └── utils/
│       ├── config.dart             # Load .env
│       ├── logger.dart
│       └── validators.dart
├── db/
│   ├── migrations/
│   │   ├── 001_initial_schema.sql
│   │   ├── 002_add_indexes.sql
│   │   └── ...
│   └── firestore_rules.json
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── .github/workflows/
│   └── deploy.yml
├── pubspec.yaml
├── .env.example                    # Template (NO SECRETS)
├── BACKEND_ARCHITECTURE.md         # This file
├── API_DOCUMENTATION.md
└── README.md
```

---

## 10. Success Criteria

- [ ] All secrets removed from GitHub + rotated
- [ ] Single order engine handling all 4 types
- [ ] Zero SQL injection vulnerabilities
- [ ] All Firestore collections have security rules
- [ ] Razorpay webhook verification working
- [ ] Stock deduction working for all payment methods (wallet orders fixed)
- [ ] Rider queries matching packing status
- [ ] Inventory reservations created/cleaned up properly
- [ ] Docker deployment working
- [ ] CI/CD pushing code to VPS on git push
- [ ] 100% API test coverage

---

**Next Steps:**
1. Read this document with your team
2. Start with security fixes (Task #2)
3. Create Supabase project + initialize schema (Task #3)
4. Scaffold Dart backend project (Task #6)
5. Work through services in order (Tasks #7-12)

Good luck! 🚀
