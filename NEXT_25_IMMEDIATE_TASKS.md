# NEXT 25 IMMEDIATE TASKS — Priority Order

**Timeline:** Execute in this order (Days 1-5)  
**Goal:** Get system live with core features  
**Scope:** No email, focus on architecture & features

---

## 🔴 PHASE 1: FOUNDATION (Days 1-2) — Tasks 1-8

### Task 1: Get Supabase Credentials
**Action:** 
- Go to Supabase Dashboard (app.supabase.com)
- Select project: `mxjtgpunctckovtuyfmz`
- Settings → API
- Copy: SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, SUPABASE_SECRET_KEY
- Save to `.env`

**Time:** 5 minutes  
**Blocker for:** Tasks 2, 3, 4, 5

---

### Task 2: Create `.env` File
**Action:**
```env
SUPABASE_URL=https://mxjtgpunctckovtuyfmz.supabase.co
SUPABASE_PUBLISHABLE_KEY=<from dashboard>
SUPABASE_SECRET_KEY=<from dashboard>
RAZORPAY_KEY_ID=rzp_live_...
RAZORPAY_KEY_SECRET=<from Razorpay>
RAZORPAY_WEBHOOK_SECRET=<from Razorpay>
OPENAI_API_KEY=sk-...
NODE_ENV=production
```

**Time:** 10 minutes  
**Depends on:** Task 1

---

### Task 3: Install Supabase CLI
**Action:**
```bash
npm install -g supabase
supabase --version  # verify
```

**Time:** 5 minutes  
**No dependencies**

---

### Task 4: Link Supabase Project
**Action:**
```bash
cd C:\Projects\fufaji-online-business\supabase
supabase link --project-ref mxjtgpunctckovtuyfmz
# Enter database password when prompted
```

**Time:** 2 minutes  
**Depends on:** Tasks 1, 3

---

### Task 5: Push Database Schema
**Action:**
```bash
cd supabase
supabase db push
# Confirms: Creating tables, indexes, RLS policies
```

**Time:** 3 minutes  
**Depends on:** Task 4  
**Blocker for:** Tasks 6-10 (all feature functions)

---

### Task 6: Verify Database Tables
**Action:**
```bash
# In Supabase Studio (UI), verify these tables exist:
- customers
- shops
- products
- orders
- deliveries
- wallets
- payment_transactions
- user_interactions
- product_embeddings
- inventory
- coupons
- reviews
```

**Time:** 2 minutes  
**Depends on:** Task 5

---

### Task 7: Test Local Supabase
**Action:**
```bash
supabase start
# Wait for: Local database running on port 54322
# Studio running on port 54323
```

**Time:** 1 minute  
**Depends on:** Task 3

---

### Task 8: Verify RLS Policies
**Action:**
```sql
-- In Supabase SQL Editor
SELECT * FROM information_schema.table_privileges 
WHERE table_name = 'customers';

-- Verify: Row level security is enabled
-- SELECT count(*) FROM pg_policies;  -- Should be 30+
```

**Time:** 3 minutes  
**Depends on:** Task 5

---

## 🟠 PHASE 2: CORE FEATURES (Days 2-3) — Tasks 9-16

### Task 9: Create Order Service Edge Function
**Action:** Create `supabase/functions/create-order/index.ts`

Features:
```typescript
- Accept: customerId, shopId, items[], totalAmount
- Validate: inventory sufficient
- Create order in DB
- Return: orderId, status
- Call payment service next
```

**Time:** 30 minutes  
**Depends on:** Task 5  
**Enables:** Task 10

---

### Task 10: Create Checkout Edge Function
**Action:** Create `supabase/functions/checkout/index.ts`

Features:
```typescript
- Accept: orderId, paymentMethod
- If 'razorpay': Create Razorpay order
- If 'wallet': Process from wallet
- Return: paymentUrl or success
```

**Time:** 30 minutes  
**Depends on:** Task 9  
**Revenue-critical**

---

### Task 11: Test Payment Webhook (Razorpay)
**Action:**
```bash
# Deploy webhook function
supabase functions deploy razorpay-webhook

# Configure Razorpay:
# Dashboard → Settings → Webhooks
# URL: https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/razorpay-webhook
# Secret: RAZORPAY_WEBHOOK_SECRET

# Test: Create test payment in Razorpay dashboard
# Verify: Order status changes to 'confirmed' in DB
```

**Time:** 20 minutes  
**Depends on:** Task 5

---

### Task 12: Deploy Recommendations Function
**Action:**
```bash
supabase functions deploy get-recommendations

# Test:
curl -X POST https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/get-recommendations \
  -H "Content-Type: application/json" \
  -d '{"customerId": "test-user", "limit": 20}'
```

**Time:** 15 minutes  
**Depends on:** Task 5

---

### Task 13: Backfill Product Embeddings
**Action:** Create `supabase/functions/generate-embeddings/index.ts`

Features:
```typescript
- Query all products
- Call OpenAI API for each
- Store in product_embeddings table
- Rate limit: 10 products/second (OpenAI API limit)
```

**Time:** 45 minutes  
**Depends on:** Task 12

---

### Task 14: Create Search Function
**Action:** Create `supabase/functions/search-products/index.ts`

Features:
```typescript
- Accept: query (string)
- Search: tsvector (full-text) + keyword matching
- Return: products array with relevance score
- Latency target: <100ms
```

**Time:** 30 minutes  
**Depends on:** Task 5

---

### Task 15: Create Product Detail Function
**Action:** Create `supabase/functions/get-product/index.ts`

Features:
```typescript
- Accept: productId
- Return: product details + shop info + reviews + similar products
- No authentication required (public data)
```

**Time:** 20 minutes  
**Depends on:** Task 5

---

### Task 16: Create Cart Service
**Action:** Create `supabase/functions/cart-service/index.ts` (in-memory or Supabase)

Features:
```typescript
- Add to cart
- Remove from cart
- Update quantity
- Validate inventory (can't exceed stock)
- Calculate total with taxes
```

**Time:** 30 minutes  
**Depends on:** Task 5

---

## 🟡 PHASE 3: REAL-TIME & NOTIFICATIONS (Days 3-4) — Tasks 17-22

### Task 17: Enable Realtime Subscriptions
**Action:**
```sql
-- In Supabase SQL Editor
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE deliveries;
ALTER PUBLICATION supabase_realtime ADD TABLE products;

-- Verify:
SELECT * FROM pg_publication_tables;
```

**Time:** 5 minutes  
**Depends on:** Task 5

---

### Task 18: Create Order Tracking Function
**Action:** Create `supabase/functions/track-order/index.ts`

Features:
```typescript
- Accept: orderId
- Return: order status, delivery info, timeline
- Real-time updates via Realtime subscription
```

**Time:** 20 minutes  
**Depends on:** Task 17

---

### Task 19: Configure Push Notifications (FCM)
**Action:**
```bash
1. Firebase Console → Cloud Messaging
2. Get Server Key
3. Add to .env: FCM_SERVER_KEY

# Test sending notification:
supabase functions deploy send-notification
```

**Time:** 30 minutes  
**Depends on:** Task 5

---

### Task 20: Create Device Token Management
**Action:** Create `supabase/functions/register-device/index.ts`

Features:
```typescript
- Accept: userId, fcmToken, platform (iOS/Android)
- Store in customers.device_tokens array
- Return: success
```

**Time:** 15 minutes  
**Depends on:** Task 19

---

### Task 21: Create Delivery Assignment Logic
**Action:** Create `supabase/functions/assign-delivery/index.ts`

Features:
```typescript
- Accept: orderId
- Find available riders near pickup location
- Assign to closest rider (geospatial query)
- Send push notification to rider
```

**Time:** 40 minutes  
**Depends on:** Task 19, Task 17

---

### Task 22: Create Rider Location Tracking
**Action:** Create `supabase/functions/update-rider-location/index.ts`

Features:
```typescript
- Accept: riderId, latitude, longitude
- Update delivery_location_history
- Broadcast via Realtime to customers
- Latency target: <50ms
```

**Time:** 20 minutes  
**Depends on:** Task 17

---

## 🟢 PHASE 4: INTEGRATIONS & ADMIN (Days 4-5) — Tasks 23-25

### Task 23: Create Admin Dashboard Order Feed
**Action:** Create `supabase/functions/admin-orders/index.ts`

Features:
```typescript
- Accept: shopId (admin's shop)
- Return: all orders for that shop (real-time)
- Filter by status (pending, confirmed, ready, picked_up, delivered)
- Show: order number, customer, items, total, time
```

**Time:** 30 minutes  
**Depends on:** Task 5, Task 17

---

### Task 24: Create Wallet System
**Action:** Create `supabase/functions/wallet-operations/index.ts`

Features:
```typescript
- Credit wallet (refunds, bonuses)
- Debit wallet (payments)
- Get balance
- Show transaction history
- Atomic: no race conditions
```

**Time:** 30 minutes  
**Depends on:** Task 5

---

### Task 25: Create Analytics Dashboard
**Action:** Create `supabase/functions/analytics/index.ts`

Features:
```typescript
- Total orders today
- Total revenue today
- Average order value
- Top products
- Top shops
- Customer count
- Real-time metrics
```

**Time:** 30 minutes  
**Depends on:** Task 5

---

## 📋 EXECUTION CHECKLIST

### By End of Day 1 (Tasks 1-8)
- [ ] Supabase credentials obtained
- [ ] `.env` file created
- [ ] Database schema pushed (all tables created)
- [ ] Local Supabase running
- [ ] RLS policies verified

**Checkpoint:** Database foundation ready. **Duration: ~40 minutes**

---

### By End of Day 2 (Tasks 9-16)
- [ ] Create Order function working
- [ ] Checkout flow tested
- [ ] Payment webhook receiving events
- [ ] Recommendations deploying
- [ ] Product embeddings backfilling
- [ ] Search function working
- [ ] Cart service ready

**Checkpoint:** Core e-commerce flow working (order → payment → confirmation). **Duration: ~5 hours**

---

### By End of Day 3 (Tasks 17-22)
- [ ] Realtime enabled on orders/deliveries
- [ ] Order tracking live
- [ ] Push notifications configured
- [ ] Device tokens storing
- [ ] Delivery assignment algorithm
- [ ] Rider location tracking

**Checkpoint:** Real-time order tracking live. **Duration: ~3 hours**

---

### By End of Day 4 (Tasks 23-25)
- [ ] Admin order dashboard ready
- [ ] Wallet system operational
- [ ] Analytics dashboard live

**Checkpoint:** Complete system operational. **Duration: ~2 hours**

---

## 🚀 TESTING SEQUENCE (As You Build)

After each task, test immediately:

```
Task 9 → Test order creation (API call)
Task 10 → Test checkout flow (end-to-end)
Task 11 → Test payment webhook (create test payment)
Task 12 → Test recommendations (call API)
Task 13 → Verify embeddings in DB (SELECT * FROM product_embeddings)
Task 14 → Test search (call API)
Task 15 → Test product detail (API call)
Task 16 → Test cart (add/remove items)
Task 17 → Verify Realtime tables
Task 18 → Test order tracking (subscribe in real-time)
Task 19-20 → Test push notification (create test notification)
Task 21 → Test delivery assignment (trigger manually)
Task 22 → Test rider location update (emit location)
Task 23 → Test admin dashboard (load orders)
Task 24 → Test wallet (credit/debit)
Task 25 → Test analytics (get metrics)
```

---

## ⏱️ TOTAL TIME ESTIMATE

| Phase | Tasks | Duration |
|-------|-------|----------|
| Phase 1 (Foundation) | 1-8 | 40 minutes |
| Phase 2 (Features) | 9-16 | 5 hours |
| Phase 3 (Real-time) | 17-22 | 3 hours |
| Phase 4 (Admin/Wallet) | 23-25 | 2 hours |
| **TOTAL** | **25** | **~10.5 hours** |

**Realistic Timeline:** 1-2 days with testing & fixes

---

## 🎯 SUCCESS CRITERIA (After All 25 Tasks)

✅ Core e-commerce flow complete (order → payment → confirmation)
✅ Product search & recommendations working
✅ Real-time order tracking live
✅ Admin dashboard showing orders
✅ Rider delivery assignment working
✅ Wallet system operational
✅ Analytics metrics available
✅ All functions tested & working
✅ Performance targets met (<100ms API latency)
✅ Ready for mobile app integration

---

## 📱 THEN: Mobile App Integration (Tasks 26+)

After these 25 tasks, your next phase:

1. Update Android app to use new API endpoints
2. Integrate Realtime subscriptions (order tracking)
3. Set up push notification handlers
4. Test end-to-end user flow
5. Deploy APK to Play Store

---

## 🔥 START NOW

**Begin with Task 1:** Get Supabase credentials (5 minutes)

Then execute Tasks 1-8 in order (should take ~40 minutes total).

This will get your database foundation solid, then Tasks 9-16 unlock the entire e-commerce feature set.

**Go!** ⚡
