# FUFAJI STORE — COMPLETE ARCHITECTURE DESIGN

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FUFAJI STORE ARCHITECTURE                        │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    CLIENT LAYER (Flutter)                        │   │
│  │  ├─ Android App (Expo)                                           │   │
│  │  ├─ Firebase Auth (OTP + Google Sign-In)                        │   │
│  │  ├─ Firestore (Real-time Products, Orders, Inventory)          │   │
│  │  ├─ Voice Commerce (Speech-to-Text → Parser → Order)          │   │
│  │  └─ Offline Sync (Local cache + CloudSync)                     │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                    │                                      │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │               API GATEWAY LAYER (Backend)                        │   │
│  │  ├─ Render Node.js (Port 3001)                                  │   │
│  │  ├─ Express Routes (119 endpoints)                              │   │
│  │  ├─ Request validation + Auth middleware                        │   │
│  │  ├─ Error handling + Sentry logging                             │   │
│  │  └─ Rate limiting + CORS                                        │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                 │                          │                 │            │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │              DATA LAYER (Multi-DB Architecture)                  │   │
│  │                                                                   │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │  PostgreSQL (Supabase) — Source of Truth              │   │   │
│  │  │  ├─ Products & Variants (89 seeded)                   │   │   │
│  │  │  ├─ Orders & Payments (Transactional)                 │   │   │
│  │  │  ├─ Inventory + Reservations (Stock locking)          │   │   │
│  │  │  ├─ Users & Delivery (Fulfillment)                    │   │   │
│  │  │  └─ Sync Queue + Events (Async processing)            │   │   │
│  │  └─────────────────────────────────────────────────────────┘   │   │
│  │                                                                   │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │  Firestore (Real-time Cache)                           │   │   │
│  │  │  ├─ Products (Cached from Supabase)                    │   │   │
│  │  │  ├─ Orders (User-specific + realtime)                  │   │   │
│  │  │  ├─ Cart (Ephemeral)                                   │   │   │
│  │  │  └─ Notifications (Push + in-app)                      │   │   │
│  │  └─────────────────────────────────────────────────────────┘   │   │
│  │                                                                   │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │  Redis (Upstash) — Performance Layer                   │   │   │
│  │  │  ├─ Distributed Locks (Inventory)                      │   │   │
│  │  │  ├─ Search Cache (Products)                            │   │   │
│  │  │  ├─ Rate Limiting (API)                                │   │   │
│  │  │  └─ Session Store (Optional)                           │   │   │
│  │  └─────────────────────────────────────────────────────────┘   │   │
│  │                                                                   │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │  External Services                                      │   │   │
│  │  │  ├─ Razorpay (Payments + Webhooks)                     │   │   │
│  │  │  ├─ Google Cloud (Speech-to-Text)                      │   │   │
│  │  │  ├─ Twilio (SMS + WhatsApp)                            │   │   │
│  │  │  ├─ SendGrid (Email)                                   │   │   │
│  │  │  └─ Firebase Admin (Push notifications)                │   │   │
│  │  └─────────────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    ASYNC LAYER (Background)                      │   │
│  │  ├─ Event Bus (PostgreSQL events table)                          │   │
│  │  ├─ Event Worker (Poll every 5 seconds)                          │   │
│  │  ├─ Sync Queue (Retry with exponential backoff)                 │   │
│  │  ├─ Cron Jobs (Cleanup, reconciliation)                          │   │
│  │  └─ DLQ (Dead letter queue for failed jobs)                      │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                  MONITORING & OBSERVABILITY                      │   │
│  │  ├─ Sentry (Error tracking)                                      │   │
│  │  ├─ Firebase Analytics                                           │   │
│  │  ├─ Database Logs (Supabase)                                     │   │
│  │  └─ Performance Monitoring (Frontend + Backend)                  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Core Data Flow

### 1. Authentication Flow
```
Mobile App
  ↓
[OTP or Google Sign-In]
  ↓
Firebase Auth → JWT Token
  ↓
Backend validates JWT
  ↓
User session created in Firestore
  ↓
Firestore listener updates UI
```

### 2. Product Discovery Flow
```
App Startup
  ↓
Fetch from Firestore (cached)
  ↓
If cache empty → Fetch from Backend API
  ↓
Backend queries Supabase (source of truth)
  ↓
Results → Redis cache (5 min TTL)
  ↓
Response to app → Cache in Firestore
  ↓
App displays products
```

### 3. Voice Order Flow
```
User speaks: "2 kg aloo, 1 liter milk"
  ↓
Speech-to-Text (Google Cloud STT)
  ↓
VoiceOrderParserV2 (97%+ accuracy)
  ├─ High confidence → Auto-add to cart
  ├─ Medium confidence → Show confirmation
  └─ Low confidence → Show alternatives
  ↓
Add to Cart (Firestore + local)
  ↓
Checkout (Inventory lock + Razorpay)
```

### 4. Checkout & Payment Flow
```
User initiates checkout
  ↓
CheckoutService.createOrderWithReservation()
  ├─ Validate cart items
  ├─ Create Razorpay order
  ├─ Lock inventory (SELECT...FOR UPDATE in PostgreSQL)
  ├─ Create order record (PostgreSQL transaction)
  └─ Return paymentOrderId to app
  ↓
App opens Razorpay payment UI
  ↓
User pays (UPI/Card/Netbanking)
  ↓
Razorpay sends webhook → Backend
  ↓
PaymentService.processPaymentWebhook()
  ├─ Verify signature (HMAC-SHA256)
  ├─ State machine (active/expired/confirmed/released)
  ├─ Confirm reservation
  └─ Emit PAYMENT_SUCCESS event
  ↓
Event worker processes event
  ├─ Create order in Firestore
  ├─ Send notification
  ├─ Trigger packing list
  └─ Update inventory sync
  ↓
Frontend listens to order changes → Display confirmation
```

### 5. Inventory Management Flow
```
Product stock updates
  ↓
Supabase triggers (if available) or API updates
  ↓
Emit INVENTORY_UPDATED event to EventBus
  ↓
Sync queue enqueues job
  ↓
Event worker processes
  ├─ Update Firestore products collection
  ├─ Invalidate Redis cache
  └─ Emit low-stock alerts if needed
  ↓
App Firestore listener fires
  ↓
Product card UI refreshes
```

### 6. Delivery Flow
```
Order packing → Status: PACKED
  ↓
Emit ORDER_STATUS_CHANGED event
  ↓
DeliveryService assigns rider
  ↓
GpsTrackingService updates location
  ↓
App subscribes to order.delivery_tracking
  ↓
UI shows live rider location
  ↓
Rider marks delivered
  ↓
Emit ORDER_DELIVERED event
  ↓
Trigger rating request + loyalty points
```

---

## API Endpoint Inventory (119 total)

### Auth (8 endpoints)
- POST /auth/register — OTP signup
- POST /auth/verify-otp — Verify OTP
- POST /auth/google-signin — Google Sign-In
- POST /auth/refresh-token — Refresh JWT
- POST /auth/logout — Logout
- GET /auth/profile — Get user profile
- PUT /auth/profile — Update profile
- DELETE /auth/account — Delete account

### Products (15 endpoints)
- GET /products — List all products
- GET /products/:id — Get product details
- GET /products/category/:category — Filter by category
- GET /products/search — Search products
- GET /products/trending — Trending products
- GET /products/deals — Special deals
- GET /products/featured — Featured products
- POST /products (admin) — Create product
- PUT /products/:id (admin) — Update product
- DELETE /products/:id (admin) — Delete product
- POST /products/bulk-import — Bulk import
- GET /products/voice-metadata — Voice search index
- GET /products/inventory/:id — Stock level
- GET /products/related/:id — Related products
- GET /products/reviews/:id — Product reviews

### Cart & Checkout (12 endpoints)
- GET /checkout/cart — Get cart
- POST /checkout/add-item — Add to cart
- PUT /checkout/update-item — Update quantity
- DELETE /checkout/remove-item — Remove from cart
- POST /checkout/clear — Clear cart
- POST /checkout/create-order — Create order with reservation
- GET /checkout/validate — Validate cart before checkout
- POST /checkout/apply-coupon — Apply coupon
- GET /checkout/shipping — Calculate shipping
- POST /checkout/payment-methods — Save payment method
- GET /checkout/saved-addresses — Saved delivery addresses
- POST /checkout/save-address — Save new address

### Payments (10 endpoints)
- POST /payments/create-razorpay-order — Create order
- POST /payments/verify-payment — Verify payment signature
- GET /payments/order/:orderId — Get payment status
- GET /payments/transaction-history — User transactions
- POST /payments/refund — Initiate refund
- GET /payments/refund-status/:refundId — Check refund status
- POST /payments/wallet/add-money — Add to wallet
- GET /payments/wallet/balance — Wallet balance
- POST /payments/saved-methods — Manage payment methods
- GET /payments/settlement-status — Settlement tracking

### Orders (16 endpoints)
- GET /orders — List orders
- GET /orders/:id — Get order details
- POST /orders/:id/cancel — Cancel order
- PUT /orders/:id/address — Update delivery address
- GET /orders/:id/status — Track status
- GET /orders/:id/tracking — Real-time tracking
- POST /orders/:id/rate — Rate order
- GET /orders/:id/invoice — Download invoice
- POST /orders/bulk-create (admin) — Bulk create
- GET /orders/analytics (admin) — Order analytics
- POST /orders/:id/reassign-rider — Reassign delivery
- PUT /orders/:id/notes — Add internal notes
- GET /orders/customer/:customerId — Customer orders
- POST /orders/:id/retry-payment — Retry failed payment
- GET /orders/fulfillment (admin) — Fulfillment queue
- PUT /orders/:id/status (admin) — Update status

### Delivery (12 endpoints)
- GET /delivery/orders — Active deliveries
- POST /delivery/:orderId/assign — Assign rider
- GET /delivery/:orderId/tracking — Live GPS tracking
- PUT /delivery/:orderId/update-location — Update rider location
- POST /delivery/:orderId/mark-delivered — Mark as delivered
- GET /delivery/:orderId/route-optimized — Optimized route
- GET /delivery/rider/stats — Rider performance
- POST /delivery/rider/availability — Set availability
- GET /delivery/rider/earnings — Daily earnings
- PUT /delivery/:orderId/reassign — Reassign order
- GET /delivery/areas — Service area coverage
- POST /delivery/batch-assign — Batch assign orders

### Inventory (14 endpoints)
- GET /inventory/stock/:productId — Stock level
- PUT /inventory/stock/:productId — Update stock
- POST /inventory/reserve — Reserve for order
- POST /inventory/release — Release reservation
- GET /inventory/low-stock — Low stock alerts
- POST /inventory/reorder — Auto-reorder
- GET /inventory/history/:productId — Stock history
- POST /inventory/audit — Stock audit
- GET /inventory/locations — Multi-location stock
- POST /inventory/transfer — Transfer between locations
- GET /inventory/expiry-alerts — Expiry tracking
- POST /inventory/set-expiry — Set expiry date
- GET /inventory/movement-report — Movement analytics
- POST /inventory/sync (admin) — Force sync

### Admin (18 endpoints)
- GET /admin/dashboard — Overview metrics
- GET /admin/users — User management
- PUT /admin/users/:id/role — Change user role
- DELETE /admin/users/:id — Deactivate user
- GET /admin/reports/sales — Sales reports
- GET /admin/reports/inventory — Inventory reports
- GET /admin/reports/delivery — Delivery reports
- GET /admin/settings — System settings
- PUT /admin/settings — Update settings
- GET /admin/moderators — Moderator list
- POST /admin/moderators/:id/promote — Promote to mod
- GET /admin/support/tickets — Support tickets
- PUT /admin/support/tickets/:id — Respond to ticket
- POST /admin/notifications/broadcast — Broadcast message
- GET /admin/analytics/funnel — Funnel analytics
- POST /admin/compliance/audit — Compliance audit
- GET /admin/integrations — Third-party integrations
- POST /admin/backup — Database backup

### Notifications (8 endpoints)
- GET /notifications — User notifications
- POST /notifications/mark-read — Mark as read
- DELETE /notifications/:id — Delete notification
- GET /notifications/preferences — Notification settings
- PUT /notifications/preferences — Update preferences
- POST /notifications/test — Test notification
- GET /notifications/history — Notification history
- POST /notifications/subscribe-push — Subscribe to push

### Reviews & Ratings (8 endpoints)
- GET /reviews/product/:productId — Product reviews
- POST /reviews/product/:productId — Post review
- PUT /reviews/:id — Edit review
- DELETE /reviews/:id — Delete review
- GET /reviews/helpful/:id — Mark helpful
- GET /ratings/product/:productId — Rating summary
- POST /ratings/order/:orderId — Rate order
- GET /ratings/seller/:sellerId — Seller ratings

### Sync & Cache (6 endpoints)
- POST /sync/reserve — Reserve inventory
- POST /sync/release — Release reservation
- GET /sync/status — Sync health status
- POST /sync/trigger-full-sync — Force full sync
- GET /sync/failed-jobs — View failed jobs
- POST /sync/retry-failed — Retry failures

---

## Database Schema (Supabase PostgreSQL)

### Core Tables
1. **users** — User accounts with roles
2. **addresses** — Delivery addresses (multi per user)
3. **products** — Product catalog
4. **variants** — Product SKUs (sizes, quantities)
5. **categories** — Product categories
6. **brands** — Brand information
7. **inventory** — Stock levels per shop
8. **reservations** — Inventory reservations for orders
9. **orders** — Order records
10. **order_items** — Items in order
11. **payments** — Payment transactions
12. **refunds** — Refund tracking
13. **coupons** — Discount codes
14. **cart** — Cart items (optional if using Firestore)

### Async Processing Tables
15. **events** — Event bus (ORDER_CREATED, PAYMENT_SUCCESS, etc.)
16. **sync_queue** — Firestore sync jobs with retry
17. **idempotency_keys** — Deduplication for webhooks

### Analytics Tables
18. **order_events** — Order status history
19. **delivery_tracking** — GPS coordinates log
20. **product_views** — Product view tracking
21. **search_queries** — Search analytics

---

## Implementation Roadmap

### PHASE 1: Core Checkout (DONE ✅)
- ✅ User authentication (OTP + Google)
- ✅ Product catalog (89 products seeded)
- ✅ Shopping cart
- ✅ Inventory reservation & locking
- ✅ Razorpay integration
- ✅ Order creation

### PHASE 2: Real-time Sync (IN PROGRESS)
- ⏳ Firestore ↔ Supabase sync
- ⏳ Event bus & worker
- ⏳ Sync queue with retry
- ⏳ Real-time product updates

### PHASE 3: Delivery (PENDING)
- ⏳ Rider assignment
- ⏳ GPS tracking
- ⏳ Route optimization
- ⏳ Delivery status updates

### PHASE 4: Analytics & Admin (PENDING)
- ⏳ Dashboard metrics
- ⏳ Reports (sales, inventory, delivery)
- ⏳ Admin controls
- ⏳ Moderator tools

### PHASE 5: Advanced Features (BACKLOG)
- ⏳ Multi-location inventory
- ⏳ Loyalty program
- ⏳ Referral rewards
- ⏳ Subscription orders
- ⏳ Marketplace (multi-seller)

---

## Security Checklist

- ✅ JWT token validation on all protected routes
- ✅ Razorpay webhook signature verification
- ✅ Firestore RLS rules (public read, user-only orders)
- ✅ No hardcoded secrets (use .env)
- ✅ Rate limiting on auth endpoints
- ✅ Input validation (XSS/SQL injection prevention)
- ✅ HTTPS enforced
- ✅ Idempotency keys for critical operations

---

## Performance Targets

- Search latency: <150ms (Redis cache)
- Order creation: <500ms (transaction)
- Voice response: <2s (STT + parsing)
- Product load: <1s (Firestore cache)
- Sync latency: <5s (event bus → Firestore)

---

## Deployment Checklist

- Render backend (Node.js)
- Supabase database + migrations
- Firebase Firestore + Auth
- Upstash Redis
- Razorpay merchant account
- Google Cloud STT API
- Sentry DSN
- SendGrid API key (email)
- Twilio account (SMS/WhatsApp)

