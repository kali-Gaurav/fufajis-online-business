# FUFAJI STORE — INTEGRATION & DEPLOYMENT CHECKLIST

**Status**: Ready for Phase 0 (Pre-Launch) execution
**Date**: 2026-07-04
**Target**: All wiring complete + core features tested by 2026-07-11

---

## Phase 0 Execution Tasks

### ✅ COMPLETED (High Priority - Already Done)

#### Supabase Integration
- [x] Create SupabaseService wrapper class with .query() method
- [x] Add .rawQuery() for RPC calls (inventory increment)
- [x] Add .batch() for batch operations
- [x] Test connection to Supabase PostgreSQL
- [x] Verify service role key loaded from environment
- [x] All services now use new wrapper (SupabaseInventoryService, SupabaseOrderService, etc.)

#### Firebase Integration
- [x] Initialize Firebase Admin SDK
- [x] Set up Firestore client (read/write)
- [x] Configure real-time listeners for carts
- [x] Test Firebase Auth with OTP + Google Sign-In
- [x] Verify sync queue can write to Firestore

#### Payment Webhook
- [x] Fix signature verification (extract from correct payload location)
- [x] Extract razorpay_payment_id from paymentEntity.id
- [x] Extract razorpay_signature from X-Razorpay-Signature header
- [x] Implement HMAC-SHA256 verification
- [x] Update payment status on webhook confirmation
- [x] Test with Razorpay test mode

#### Sync Queue
- [x] Fix import of firebaseAdmin
- [x] Replace undefined db.query() with pool.query()
- [x] Add exponential backoff: 1s, 2s, 4s, 8s, 16s
- [x] Implement DLQ (dead-letter queue) after 5 retries
- [x] Test sync flow: PostgreSQL → Event Bus → Firestore

#### Database Pool
- [x] Configure connection pooling (min: 2, max: 10)
- [x] Add retry logic for failed queries
- [x] Implement health checks
- [x] Test query execution under load

---

### ⏳ IN PROGRESS (Medium Priority - This Week)

#### Database Schema Migration
- [ ] Apply Migration 08: add delivery_riders, delivery_assignments, delivery_tracking tables
- [ ] Create reviews, ratings_summary, coupons, order_events tables
- [ ] Add search_queries table
- [ ] Run indexes for performance
- [ ] Add order_status_changed trigger
- [ ] Verify all foreign keys and constraints

**Time**: 1 hour

#### ReviewService Implementation
- [ ] Create backend/src/services/ReviewService.js
- [ ] Implement postReview() with transaction
- [ ] Implement updateRatingSummary()
- [ ] Create backend/src/routes/reviews.js
- [ ] Test POST /reviews/product/:productId
- [ ] Test GET /reviews/product/:productId

**Time**: 3 hours

#### DeliveryService Implementation
- [ ] Create backend/src/services/DeliveryService.js
- [ ] Implement assignRider(orderId, riderId)
- [ ] Implement updateRiderLocation(riderId, latitude, longitude)
- [ ] Implement markDelivered(assignmentId)
- [ ] Broadcast location updates to Firestore in real-time
- [ ] Create backend/src/routes/delivery.js
- [ ] Test assignment flow end-to-end

**Time**: 5 hours

#### CouponService Implementation
- [ ] Create backend/src/services/CouponService.js
- [ ] Implement validateAndApply() with all constraints
- [ ] Implement createCoupon() (admin)
- [ ] Implement getActiveCoupons()
- [ ] Implement markAsUsed()
- [ ] Create backend/src/routes/coupons.js
- [ ] Test validation: min order, validity, usage limit, categories

**Time**: 2 hours

#### AdminService Implementation
- [ ] Create backend/src/services/AdminService.js
- [ ] Implement getDashboardMetrics()
- [ ] Implement getOrderAnalytics()
- [ ] Implement getInventoryStatus()
- [ ] Implement getDeliveryAnalytics()
- [ ] Implement getUserAnalytics()
- [ ] Implement getPaymentAnalytics()
- [ ] Create backend/src/routes/admin.js
- [ ] Test all analytics endpoints

**Time**: 4 hours

#### Checkout Flow Integration
- [ ] Wire CheckoutScreen → SupabaseOrderService
- [ ] Test atomic transaction: inventory reserve → order create → payment
- [ ] Implement coupon application in checkout
- [ ] Test complete flow: add item → checkout → payment → order created

**Time**: 2 hours

#### End-to-End Testing
- [ ] Full customer journey: signup → browse → add to cart → checkout → payment → order
- [ ] Verify order appears in Firestore within 2s
- [ ] Test payment webhook: Razorpay → webhook → order status updated
- [ ] Test delivery assignment: admin assigns → rider gets notification
- [ ] Test real-time delivery tracking: GPS updates → customer sees location
- [ ] Test reviews: post review → ratings summary updates

**Time**: 3 hours

---

### ⏹️ NOT STARTED (Lower Priority - Phase 1)

#### Optional Firebase Triggers
- [ ] Firestore trigger: order created → send notification
- [ ] Firestore trigger: delivery assigned → send SMS to rider
- [ ] Note: sync queue can handle these events instead

**Time**: 2 hours (optional)

#### Deployment & Launch Preparation
- [ ] Set up GitHub Actions CI/CD
- [ ] Configure Docker for backend
- [ ] Deploy backend to Render
- [ ] Deploy Flutter APK (EAS Build)
- [ ] Configure Razorpay production credentials
- [ ] Run load tests: 100+ concurrent checkouts
- [ ] Set up monitoring & alerts (APM, error tracking)

**Time**: 6 hours

---

## Testing Scenarios

### Scenario 1: Complete Checkout Flow
```
1. User browses products (GET /products)
2. Adds item to cart (POST /checkout/add-item)
3. Views cart (GET /checkout/cart)
4. Applies coupon (POST /checkout/apply-coupon)
5. Validates order (POST /checkout/validate)
6. Creates order (POST /checkout/create-order)
   → Triggers: inventory reserve + order create
7. Creates Razorpay order (POST /payments/create-razorpay-order)
8. Completes payment in mobile app
9. Razorpay webhook fires (POST /webhook/razorpay)
   → Triggers: update payment status + order confirmation
10. Admin assigns rider (POST /delivery/:orderId/assign)
11. Rider updates location (PUT /delivery/update-location)
    → Real-time updates in Firestore
12. Rider marks delivered (POST /delivery/:assignmentId/mark-delivered)
13. Customer rates order (POST /orders/:orderId/rate)
```

**Pass Criteria**:
- All endpoints respond in <500ms
- Firestore reflects changes within 2s
- Cart persists in AsyncStorage
- Payment verification works
- Delivery tracking real-time

---

### Scenario 2: Payment Webhook Verification
```
1. Create order total: ₹1000
2. Initiate Razorpay payment
3. Razorpay sends webhook:
   POST /webhook/razorpay
   {
     "payload": {
       "payment": {
         "entity": {
           "id": "pay_12345",
           "order_id": "order_67890",
           "amount": 100000,
           "status": "captured"
         }
       }
     },
     "X-Razorpay-Signature": "computed_hmac"
   }
4. Backend verifies signature using HMAC-SHA256
5. Updates payment status in database
6. Increments inventory deduction
7. Sends order confirmation to customer
```

**Pass Criteria**:
- Signature verification succeeds
- Payment status updated within 1s
- Order marked as confirmed
- No duplicate orders on retry

---

### Scenario 3: Delivery Assignment & Tracking
```
1. Order delivered to hub
2. Admin assigns rider: POST /delivery/:orderId/assign {riderId}
   → Rider notified via push notification
3. Rider accepts delivery
4. Rider starts delivery: mobile app sends GPS
   PUT /delivery/update-location {latitude, longitude}
   → Firestore updated in real-time
   → Customer app listens to Firestore: sees rider location on map
5. Rider reaches customer
6. Delivery complete: POST /delivery/:assignmentId/mark-delivered
   → Order status → "delivered"
   → Event logged to order_events
   → Customer notified
7. Customer rates delivery & writes review
   → Rider rating updated
   → Product rating updated
```

**Pass Criteria**:
- Assignment confirms within 1s
- GPS updates appear in Firestore within 2s
- Customer sees live tracking
- Ratings persist

---

### Scenario 4: Low Inventory Alert
```
1. Product has 8 units
2. Order for 5 units placed
3. Inventory updated: 8 - 5 = 3 remaining
4. Alert triggered: product below threshold (5)
5. Admin sees: GET /admin/analytics/inventory
   → lowStockProducts array includes this product
6. Admin can manually reorder or notify supplier
```

**Pass Criteria**:
- Inventory deducted correctly
- Alert generated
- Admin sees low-stock list

---

## Integration Points to Verify

### Supabase ↔ Firestore Sync
- [ ] Order created in Supabase → synced to Firestore within 2s
- [ ] Inventory updated in Supabase → synced to Firestore
- [ ] Delivery assignment → synced to Firestore
- [ ] Reverse: If Firestore update fails → retry queue active
- [ ] No data loss on network failures

### Firebase Auth ↔ Supabase
- [ ] User signs in with OTP → Firebase creates JWT
- [ ] JWT validated on backend → user_id extracted
- [ ] User record exists in Supabase users table
- [ ] Profile sync between Firebase and Supabase

### Firestore Rules ↔ Backend Authorization
- [ ] Products: public read, admin-only write
- [ ] Orders: user can only read/write own orders
- [ ] Cart: user can only read/write own cart
- [ ] Delivery assignments: admin can write, riders can read assigned orders

### Payment Webhook ↔ Order Update
- [ ] Webhook received → signature verified
- [ ] Payment status updated in Supabase
- [ ] Inventory deduction triggered
- [ ] Order status → "confirmed"
- [ ] Firestore order collection synced
- [ ] Customer notification sent

### Delivery GPS ↔ Real-time Map
- [ ] Rider sends GPS every 30s
- [ ] Backend receives update
- [ ] Firestore updated immediately
- [ ] Customer app listens to Firestore
- [ ] Map updates in real-time (no delay >2s)

---

## Pre-Launch Verification Checklist

**Run these before going live**:

### Backend Checks
- [ ] All endpoints return proper error messages (no 500s)
- [ ] Database connection pooling working (min: 2, max: 10)
- [ ] Sync queue active (check pending jobs)
- [ ] Payment webhook endpoint accessible from internet
- [ ] CORS configured for mobile app
- [ ] Rate limiting active: max 100 requests/min per IP
- [ ] Logging active (check application logs)

### Database Checks
- [ ] All tables created (20 tables total)
- [ ] Indexes created on high-query columns
- [ ] Foreign keys in place
- [ ] Sample data: 89 products seeded
- [ ] Coupons table: has test coupons
- [ ] Delivery riders table: has test riders

### Firebase Checks
- [ ] Auth enabled (OTP + Google)
- [ ] Firestore rules deployed
- [ ] Storage rules configured
- [ ] Cloud Messaging set up for notifications
- [ ] Test users created

### Razorpay Checks
- [ ] Test mode active
- [ ] Key ID & Key Secret configured
- [ ] Webhook endpoint registered
- [ ] Test payment flow works
- [ ] Signature verification passes

### Mobile App Checks
- [ ] All screens rendering correctly
- [ ] Navigation working
- [ ] Cart persists in AsyncStorage
- [ ] Push notifications working
- [ ] Real-time Firestore listeners active
- [ ] GPS permissions requested (for riders)

---

## Performance Targets

| Operation | Target | Current |
|-----------|--------|---------|
| Product Search | <150ms | TBD |
| Order Creation | <500ms | TBD |
| Payment Verification | <1s | TBD |
| Delivery Assignment | <1s | TBD |
| GPS Sync | <2s | TBD |
| Firestore Sync | <2s | TBD |
| Page Load | <2s | TBD |
| Checkout Complete | <3s | TBD |

---

## Go/No-Go Decision Matrix

| Component | Status | Blocker? |
|-----------|--------|----------|
| Auth ✅ | Complete | NO |
| Products ✅ | 89 seeded | NO |
| Cart ✅ | Firestore | NO |
| Checkout ✅ | Atomic txn | NO |
| Payments ✅ | Razorpay OK | NO |
| Orders ✅ | PostgreSQL | NO |
| Delivery ⏳ | IN PROGRESS | YES (need by Friday) |
| Reviews ⏳ | IN PROGRESS | NO (can launch without) |
| Admin ⏳ | IN PROGRESS | NO (can launch without) |
| Notifications ⏳ | Partial | NO (have basics) |

**RECOMMENDATION**: Launch when delivery system complete. Can deploy reviews + admin in Phase 1.

---

## Rollback Plan

If critical issues found after deployment:

1. **Database Rollback**: Keep backup of Supabase snapshot before migration
2. **Code Rollback**: Tag each backend release in git, revert to previous tag
3. **App Rollback**: Keep previous APK version in Play Store, user can downgrade
4. **Payment Rollback**: Razorpay refund for failed transactions within 24h

**Rollback SLA**: 30 minutes to restore previous version

---

## Post-Launch Monitoring

**First Week Metrics**:
- Checkout success rate (target: >95%)
- Payment success rate (target: >98%)
- Average response time (target: <300ms)
- Error rate (target: <0.5%)
- Uptime (target: >99.5%)

**Monitor these dashboards**:
- Supabase Dashboard: Database performance, query times
- Firebase Console: Firestore usage, Auth activity
- Render: Backend logs, memory usage
- Razorpay Dashboard: Payment health, webhook status
- APM (if set up): Slow endpoints, error traces

