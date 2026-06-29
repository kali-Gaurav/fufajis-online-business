# Backend Setup Summary - What's Done & What's Next

**Created**: 2026-06-22  
**Status**: Architecture & Deployment Ready ✅  
**Backend Stack**: Dart + Supabase + Firebase + Razorpay  
**Deployment**: Docker on Self-Hosted VPS (git push automatic)

---

## ✅ What Has Been Created

### 1. **Architecture Documentation** (`BACKEND_ARCHITECTURE.md`)
- Complete system design with 10+ subsystems
- Data models for Supabase (Postgres) + Firestore
- Unified Order Service (consolidates 4 broken engines)
- Service layer for all business logic
- Security fixes (especially Razorpay webhook secret fix)
- Deployment architecture

### 2. **Database Schema** (`db_migrations_001_initial_schema.sql`)
- Ready-to-run SQL for Supabase
- 13 tables: users, shops, products, orders, payments, refunds, inventory_stock, packing_tasks, delivery_assignments, coupons, and more
- Row-Level Security (RLS) policies
- Triggers for automatic timestamp updates
- Sample test data included

### 3. **API Documentation** (`API_ENDPOINTS_REFERENCE.md`)
- 27 REST endpoints documented
- Request/response examples for each
- Error handling reference
- Rate limiting & pagination info
- cURL and Postman testing examples

### 4. **Deployment Guide** (`DEPLOYMENT_GUIDE.md`)
- One-time VPS setup instructions
- GitHub Actions CI/CD configuration
- How git push → auto deploys to VPS
- Manual VPS commands
- Production checklist
- Cost estimates (~$30-50/month)

### 5. **18 Implementation Tasks** (Created in task list)
- Task #1: Design unified architecture ✅ Done
- Task #2: CRITICAL - Rotate secrets 🔴 **DO THIS FIRST**
- Task #3: Create Supabase schema
- Task #4: Set up Firestore rules
- Task #5: Fix SQL injection
- Tasks #6-18: Build backend services, API, Docker, CI/CD

---

## 🚀 Next Steps (In Order)

### Phase 1: Security (This Week) 🔴 CRITICAL

**Task #2: Rotate All Leaked Secrets**
```bash
# DO THIS IMMEDIATELY!
# Current status: Secrets PUBLIC on GitHub + in APK

1. List all leaked secrets:
   ❌ razorpay_key_secret
   ❌ razorpay_webhook_secret (SAME VALUE - BUG!)
   ❌ firebase_config.json
   ❌ signing_key.jks
   ❌ Postgres password

2. Actions:
   ✅ Remove from GitHub (git filter-branch or clean history)
   ✅ Rotate Razorpay credentials (generate new key pair)
   ✅ Create separate webhook_secret (DIFFERENT from key_secret)
   ✅ Move all secrets to GitHub Actions secrets
   ✅ Create .env.example template (NO actual secrets)
   ✅ Update APK signing in CI/CD (use GitHub Actions injected keys)
   ✅ Force users to update app (revoke old signing key)

3. After rotation:
   - Update RAZORPAY_KEY_SECRET in PaymentService
   - Update RAZORPAY_WEBHOOK_SECRET in webhook handler
   - Test payment webhook verification
```

### Phase 2: Database & Infrastructure (Week 2)

**Task #3: Create Supabase Project**
```bash
1. Go to https://supabase.com
2. Create new project
3. Copy connection string
4. In Supabase SQL Editor, run: db_migrations_001_initial_schema.sql
5. Verify tables created:
   ✅ users
   ✅ shops
   ✅ products
   ✅ orders (unified)
   ✅ payments
   ✅ refunds
   ✅ inventory_stock
   ✅ packing_tasks
   ✅ delivery_assignments

6. Get credentials:
   - SUPABASE_URL
   - SUPABASE_ANON_KEY
   - SUPABASE_SERVICE_KEY (for migrations)
```

**Task #4: Set up Firestore**
```bash
1. Create Firestore database in Firebase Console
2. Create collections (manual or via backend init):
   - user_profiles/{uid}
   - products/{product_id}
   - live_locations/{rider_id}
   - inventory_reservations/{reservation_id}
   - coupons/{coupon_id}
   - (orders & delivery_assignments sync from Postgres via triggers)

3. Import Firestore security rules from BACKEND_ARCHITECTURE.md
   Section 4: "Firestore Security Rules"
   
   Copy the rules block and paste into Firestore Rules Editor
```

### Phase 3: Backend Development (Weeks 3-4)

**Task #6: Scaffold Dart Backend Project**
```bash
# Create new Dart project
dart create -t package fufaji-backend
cd fufaji-backend

# Add dependencies to pubspec.yaml
dart pub add shelf
dart pub add shelf_router
dart pub add postgres
dart pub add firebase_admin
dart pub add razorpay_flutter

# Create folder structure
mkdir -p lib/{handlers,middleware,services,repositories,models,utils}
mkdir -p bin db tests
```

**Tasks #7-12: Implement Core Services**
```
Priority order:
1. PaymentService (fix Razorpay webhook_secret bug)
2. OrderService (unify 4 engines)
3. InventoryService (reservation + stock deduction)
4. PackingService (unified fulfillment)
5. DeliveryService (fix rider queries)
6. RefundService (wallet + stock recovery)
```

### Phase 4: API & Deployment (Week 5)

**Task #13: Firebase Auth Middleware**
- Verify Firebase ID tokens
- Extract user claims (role, shop_id)
- Create route guards

**Task #14: Create API Endpoints**
- Use endpoints from `API_ENDPOINTS_REFERENCE.md`
- Implement all 27 endpoints with handlers
- Add error handling & validation

**Task #15: Docker Setup**
```bash
# Create Dockerfile
# Create docker-compose.yml with Supabase + Redis

# Test locally:
docker-compose up --build
curl http://localhost:8080/health  # Should return 200
```

**Task #16: GitHub Actions CI/CD**
```bash
# Create .github/workflows/deploy.yml
# Add SSH key for deployment:
#   1. Generate: ssh-keygen -t ed25519 -f deploy_key
#   2. Add to VPS: /home/deployer/.ssh/authorized_keys
#   3. Add to GitHub: Settings → Secrets → DEPLOY_SSH_KEY

# Now: git push main → Auto-deploys to VPS
```

---

## 📋 Quick Reference: What Each File Does

| File | Purpose | Status |
|------|---------|--------|
| `BACKEND_ARCHITECTURE.md` | System design & data models | ✅ Complete |
| `API_ENDPOINTS_REFERENCE.md` | All 27 API endpoints | ✅ Complete |
| `DEPLOYMENT_GUIDE.md` | How to deploy (git push) | ✅ Complete |
| `db_migrations_001_initial_schema.sql` | Supabase schema (copy-paste ready) | ✅ Ready |
| `BACKEND_SETUP_SUMMARY.md` | This file - your roadmap | ✅ You're reading it |

---

## 🎯 Key Improvements Over Current System

### Current (Broken)
```
❌ 4 order engines (OrderService, WalletOrderService, GroupBuyService, ReorderService)
❌ 3 packing workflows (orphaned, different status formats)
❌ 3 delivery services (can't match rider queries to packing status)
❌ Razorpay key_secret == webhook_secret (breaks verification)
❌ Wallet orders skip stock deduction (LIVE BUG)
❌ Inventory reservations not created (checkout fails silently)
❌ Zero Firestore rules (open data)
❌ Secrets PUBLIC on GitHub + in APK
❌ No unified API
❌ Manual deployment
```

### New (Unified)
```
✅ 1 unified OrderService (handles normal, wallet, group_buy, reorder)
✅ 1 PackingService (consistent Firestore paths, status formats)
✅ 1 DeliveryService (queries match packing status)
✅ Razorpay: separate key_secret & webhook_secret (secure)
✅ All payment methods deduct stock (wallet orders fixed)
✅ Inventory reservations auto-created & cleaned up
✅ Complete Firestore RLS policies
✅ All secrets in GitHub Actions (not in repo)
✅ 27 REST endpoints (fully documented)
✅ Auto-deploy on git push (via GitHub Actions → VPS)
```

---

## 📊 Consolidation Summary

### Orders (4 → 1)
```
Before:
  - OrderService (live)
  - WalletOrderService (duplicate)
  - GroupBuyService (orphaned)
  - ReorderService (partial)

After:
  - OrderService (single)
    - order_type: 'normal', 'wallet', 'group_buy', 'reorder'
    - All 4 types share same database table & service logic
```

### Packing (3 → 1)
```
Before:
  - workflow_1 (Firestore: orders/{orderId}/packing)
  - workflow_2 (Firestore: packing/{packingId})
  - workflow_3 (orphaned, different status)

After:
  - PackingService (single)
    - Consistent status: ready_to_pick → picked → packed → handed_off
    - Unified Firestore path: packing_tasks/{taskId}
```

### Delivery (3 → 1)
```
Before:
  - DeliveryService1
  - DeliveryService2
  - DeliveryService3
  - Rider queries use bare strings (can't match packed status)

After:
  - DeliveryService (single)
    - Queries match: status IN ('packed', 'assigned_to_delivery')
    - Unified status: assigned → picked_up → in_transit → delivered
```

---

## 💰 Cost Breakdown

| Service | Tier | Cost/Month | Notes |
|---------|------|-----------|-------|
| VPS (DigitalOcean) | Basic 2GB | $12 | Hosting backend |
| Supabase | Free | $0 | First 500MB free, $25/month after |
| Firebase | Free | $0 | First 1GB storage free, then $0.18/GB |
| Razorpay | Transaction-based | 0% | No monthly fee |
| Domain | - | $5-15 | Optional (fufaji.com) |
| **Total** | - | **~$30-50** | Very affordable |

---

## ⚠️ Critical Warnings

### 🔴 DO NOT proceed to Phase 2 without completing Task #2 (secrets rotation)

The current setup has:
- Secrets visible to anyone on GitHub
- Same key used for payments & verification (Razorpay bug)
- APK signed with key available publicly
- Database password in code

**This is a security incident waiting to happen.**

### 🟡 Coordinate secrets rotation carefully

1. Pre-announce to customers: "Security update coming, you may see new payment window"
2. Rotate secrets BEFORE going live
3. Keep old keys for ~1 week (for webhook retries)
4. Monitor payment failures during transition

---

## 🔗 File Locations

```
C:\Projects\fufaji-online-business\
├── BACKEND_ARCHITECTURE.md (THIS EXPLAINS THE ENTIRE SYSTEM)
├── API_ENDPOINTS_REFERENCE.md (27 endpoints documented)
├── DEPLOYMENT_GUIDE.md (git push → VPS)
├── db_migrations_001_initial_schema.sql (Copy-paste to Supabase)
├── BACKEND_SETUP_SUMMARY.md (You are here)
├── lib\
│   └── (Flutter mobile app code - stays as is)
└── backend\ (Create this - new Dart backend)
    ├── bin\
    │   └── server.dart
    ├── lib\
    │   ├── handlers\
    │   ├── services\
    │   ├── repositories\
    │   └── models\
    ├── db\
    │   └── migrations\
    ├── .github\
    │   └── workflows\
    │       └── deploy.yml
    ├── pubspec.yaml
    ├── .env.example (NO SECRETS)
    └── Dockerfile
```

---

## ✅ Success Criteria

By end of Phase 1 (this week):
- [ ] All secrets rotated (Razorpay has separate webhook_secret)
- [ ] GitHub Actions secrets set up
- [ ] .env.example created (no actual values)
- [ ] VPS provisioned and Docker installed
- [ ] Deploy SSH key working

By end of Phase 2:
- [ ] Supabase tables created from SQL migration
- [ ] Firestore collections with RLS policies
- [ ] Firebase Auth integrated with Firestore

By end of Phase 3:
- [ ] All 6 core services implemented & tested
- [ ] PaymentService webhook verification working
- [ ] Stock deduction working for all payment methods

By end of Phase 4:
- [ ] All 27 API endpoints working
- [ ] GitHub Actions deploying on git push
- [ ] Production running on VPS

---

## 📞 When You're Stuck

1. **Architecture questions** → Read `BACKEND_ARCHITECTURE.md` (Section 3: Service Layer)
2. **API format questions** → Check `API_ENDPOINTS_REFERENCE.md`
3. **Deployment questions** → Follow `DEPLOYMENT_GUIDE.md` step-by-step
4. **Database schema** → Copy from `db_migrations_001_initial_schema.sql`
5. **Task status** → Check the task list (18 tasks created)

---

## 🎉 What You'll Have at the End

A production-ready backend with:
- ✅ Single source of truth (no duplicate systems)
- ✅ Secure payment processing (Razorpay + webhook verification)
- ✅ Unified order → payment → packing → delivery pipeline
- ✅ Real-time location tracking (Firestore)
- ✅ Automatic stock management
- ✅ Complete refund & wallet handling
- ✅ Role-based API access
- ✅ Auto-deploying CI/CD (git push → live)
- ✅ Comprehensive API documentation
- ✅ Production monitoring & health checks

**Total time to production: ~4-5 weeks**

---

**Ready to start?** Begin with Task #2 (secrets rotation). Everything else builds on that foundation. 🚀
