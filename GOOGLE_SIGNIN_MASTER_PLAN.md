# FUFAJI GOOGLE SIGN-IN MASTER IMPLEMENTATION PLAN
**Objective:** Build complete Google Sign-In authentication + multi-user system  
**Timeline:** 10-14 weeks (Jun 11 - Aug 29, 2026)  
**Scope:** All 5 user types, payments, data management, localization, compliance

---

## EXECUTIVE SUMMARY

### What's Being Built
A **production-grade, multi-user e-commerce app** powered by **Google Sign-In** with:
- 5 distinct user types (Customer, Employee, Owner, Delivery Agent, Admin)
- Role-based dashboards and navigation
- Google Sign-In for all (no OTP)
- Razorpay payment integration
- Complete user data management (profile, addresses, location, payment history)
- Language support (English/Hindi)
- Offline-first architecture
- GDPR compliance
- Enterprise-grade security

### Why This Approach
- **No OTP complexity** — Google Sign-In handles authentication
- **Scalable** — Custom claims + Firestore for role management
- **Secure** — Device fingerprinting, PIN/biometric, audit logging
- **Compliant** — GDPR-ready, PII protection, data export/deletion
- **Offline-capable** — Works without internet, syncs when online
- **User-friendly** — One-tap login, role-aware navigation

---

## COMPLETE FEATURE SET

### Authentication (All Users)
- ✅ Google Sign-In (OAuth2 flow)
- ✅ Pre-authorization checking (employees, admins)
- ✅ Session management (Firestore-based)
- ✅ Device fingerprinting & multi-device support
- ✅ PIN setup for sensitive operations
- ✅ Biometric authentication (fingerprint, face)
- ✅ Sign-out (local + remote session revocation)
- ✅ Session timeout (role-specific: 7 days customer, 4 hours owner/admin)

### User Profiles (All Roles)
- ✅ Display name, email, phone number
- ✅ Profile picture (Google-provided, cached)
- ✅ Addresses (home, work, delivery, billing)
- ✅ Location services (Google Maps integration)
- ✅ Preferences (language English/Hindi, notifications, theme)
- ✅ Device management (owner/employee can approve/revoke)

### Customer-Specific
- ✅ Shopping cart (persistent, synced to Firestore)
- ✅ Order history with filters
- ✅ Saved addresses (multiple)
- ✅ Favorite products
- ✅ Recently viewed products
- ✅ Wallet & cashback balance
- ✅ Referral code & earnings

### Employee-Specific
- ✅ Order queue (assigned to them)
- ✅ Packing status (new, in-progress, ready)
- ✅ Inventory count
- ✅ Performance metrics

### Delivery Agent-Specific
- ✅ Assigned deliveries (map view)
- ✅ Delivery proof (photo, signature)
- ✅ Earnings tracker
- ✅ Route optimization

### Owner-Specific
- ✅ Dashboard (KPIs, sales, orders)
- ✅ Product management
- ✅ Inventory management
- ✅ Employee roster
- ✅ Analytics & reports
- ✅ Settings (shop hours, location, contact)

### Admin-Specific
- ✅ User management (create, disable, roles)
- ✅ Shop management (create, deactivate)
- ✅ Compliance dashboard
- ✅ Audit logs
- ✅ System settings

### Payments
- ✅ Razorpay integration (card, UPI, wallet, netbanking)
- ✅ Saved payment methods
- ✅ Wallet system (balance, transactions, cashback)
- ✅ Order payment status tracking
- ✅ Refund processing
- ✅ Invoice generation
- ✅ Payment history (all transactions)

### Data Management
- ✅ Profile data storage (SharedPreferences for simple, Firestore for sync)
- ✅ Cart persistence (Hive for offline, Firestore for sync)
- ✅ Address management (CRUD)
- ✅ Payment method management
- ✅ Order history (SQLite for offline, Firestore for cloud)
- ✅ Sync strategy (offline-first, delta sync, conflict resolution)
- ✅ Data export (JSON + PDFs)
- ✅ Account deletion (GDPR)

### Localization
- ✅ English (en)
- ✅ Hindi (hi)
- ✅ Language toggle in settings
- ✅ Persistent language preference
- ✅ Dynamic locale switching

### Security
- ✅ Firebase Authentication
- ✅ Firebase App Check (PlayIntegrity on Android)
- ✅ Custom claims (role, shop_id, permissions)
- ✅ Firestore security rules (document-level, user isolation)
- ✅ Encrypted storage (PBKDF2 for PINs)
- ✅ Session revocation (admin logout from backend)
- ✅ Audit logging (all sensitive actions)
- ✅ Rate limiting (login attempts, API calls)

---

## IMPLEMENTATION PHASES

### PHASE 1: Authentication Foundation (Week 1-2)
**Goal:** Google Sign-In + role-based routing working

1. Setup Firebase Authentication
2. Configure Google Sign-In (Android + iOS)
3. Build AuthProvider & AuthService
4. Implement role detection via custom claims
5. Create role-based routing guards
6. Build login screen + role detection UI
7. Implement sign-out
8. Testing: Auth flows for all 5 roles

**Deliverables:**
- LoginScreen working with Google Sign-In
- Role-based routing (customer → customer_home, owner → owner_dashboard, etc.)
- Sign-out functionality
- Unit tests for auth service

---

### PHASE 2: User Profiles & Data Storage (Week 3-4)
**Goal:** User data fully managed, offline-capable

1. Design Firestore schema (users, addresses, profiles)
2. Setup local storage (SharedPreferences, Hive, flutter_secure_storage)
3. Build UserService (CRUD for profile)
4. Build AddressService (manage addresses)
5. Implement sync manager (Firestore ↔ local)
6. Build ProfileScreen per role
7. Implement language selection + persistence
8. Testing: Data sync, offline mode, conflict resolution

**Deliverables:**
- ProfileScreen for each role
- Settings screen with language toggle
- Address management UI
- Data sync working offline & online

---

### PHASE 3: Navigation & UI Shells (Week 5)
**Goal:** Role-specific navigation working

1. Create CustomerShell (bottom nav: home, search, cart, orders, profile)
2. Create EmployeeShell (bottom nav: tasks, inventory, delivery, profile)
3. Create DeliveryShell (bottom nav: map, orders, earnings, profile)
4. Create OwnerShell (drawer: dashboard, orders, inventory, analytics)
5. Create AdminShell (sidebar: users, shops, compliance)
6. Implement nav guards (prevent unauthorized access)
7. Testing: Navigation flows for each role

**Deliverables:**
- All 5 role-specific shells rendering
- GoRouter guards blocking unauthorized access
- Smooth transitions between screens

---

### PHASE 4: Payment Integration (Week 6-7)
**Goal:** Razorpay fully integrated, payments working

1. Setup Razorpay account & API keys
2. Create RazorpayService (init, create order, verify signature)
3. Create PaymentService (higher-level API)
4. Create WalletService (balance, transactions, cashback)
5. Build PaymentScreen & PaymentHistoryScreen
6. Implement saved payment methods
7. Create Firestore schema for payments/transactions
8. Setup Cloud Functions for webhook verification
9. Testing: Full payment flow, refunds, wallet operations

**Deliverables:**
- Complete payment flow (init → payment → success → invoice)
- Payment history showing all transactions
- Wallet management UI
- Cloud Functions for secure webhook handling

---

### PHASE 5: Location & Maps Integration (Week 8)
**Goal:** Google Maps integrated, location services working

1. Setup Google Maps API & credentials
2. Integrate google_maps_flutter package
3. Build location picker widget
4. Implement address auto-complete
5. Build delivery map (for delivery agents)
6. Implement geofencing (if needed for pickup zones)
7. Testing: Map rendering, location selection, permissions

**Deliverables:**
- Address picker using Google Maps
- Delivery agent map view
- Location permission handling

---

### PHASE 6: Cart & Order Management (Week 9)
**Goal:** Cart synced, orders trackable

1. Enhance CartProvider for multi-device sync
2. Build OrderService (create, fetch, update status)
3. Implement cart persistence (Hive + Firestore)
4. Build CartScreen (edit quantities, remove items)
5. Build OrderScreen (view, track, cancel)
6. Implement order status tracking
7. Testing: Cart sync, order creation, status updates

**Deliverables:**
- Cart fully synced across devices
- Order management UI for customers
- Order tracking with real-time updates

---

### PHASE 7: Role-Specific Features (Week 10)
**Goal:** Each role has full feature set

**Employee:**
- Task queue (orders to pack)
- Inventory counting
- Status updates

**Delivery Agent:**
- Assigned deliveries
- Delivery proof (photo)
- Earnings tracking

**Owner:**
- Dashboard with KPIs
- Analytics & reports
- Inventory management

**Admin:**
- User management
- Audit logs
- Compliance tools

**Deliverables:**
- All role-specific screens functional
- Real-time data (using Firestore listeners)

---

### PHASE 8: Security & Compliance (Week 11)
**Goal:** Enterprise-grade security in place

1. Implement Firebase App Check
2. Setup Firestore security rules (document-level access)
3. Implement PIN setup + storage (PBKDF2)
4. Implement biometric auth
5. Setup audit logging (Firestore audit_logs collection)
6. Implement device fingerprinting
7. Setup rate limiting (Cloud Functions)
8. GDPR compliance (data export, deletion)
9. Testing: Security flows, GDPR features, rate limiting

**Deliverables:**
- App Check enabled on production
- Firestore rules enforcing user isolation
- PIN/biometric working
- Audit logs being recorded
- GDPR features (export, deletion)

---

### PHASE 9: Offline-First & Sync (Week 12)
**Goal:** App works without internet, syncs when online

1. Implement offline queue (SQLite)
2. Build sync manager (delta sync)
3. Implement conflict resolution (server wins)
4. Add network status indicator
5. Build retry UI
6. Testing: Offline mode, sync edge cases, performance

**Deliverables:**
- App fully usable offline
- Automatic sync when online
- No data loss on network transitions

---

### PHASE 10: Localization & Accessibility (Week 13)
**Goal:** Hindi support, accessible to all

1. Extract all strings to localization keys
2. Create en.json & hi.json translation files
3. Implement dynamic locale switching
4. Add accessibility labels (semantic)
5. Test with screen readers
6. Testing: Localization, accessibility, elderly mode

**Deliverables:**
- Complete Hindi localization
- All screens accessible
- Language toggle working everywhere

---

### PHASE 11: Testing & QA (Week 14)
**Goal:** Production-ready, all features tested

1. Unit tests (services, models)
2. Widget tests (screens, components)
3. Integration tests (auth → payment → order flow)
4. Security testing (auth bypass, data leaks)
5. Performance testing (load, memory, battery)
6. User acceptance testing (UAT with 5 roles)
7. Bug fixes & refinement

**Deliverables:**
- >80% code coverage
- All critical features tested
- Zero known P1 bugs
- Performance benchmarks met

---

### PHASE 12: Documentation & Deployment (Week 15)
**Goal:** Ready for production launch

1. API documentation
2. Deployment guide
3. Runbook for operations
4. Release notes
5. Play Store submission
6. Firebase production setup
7. Monitoring & alerting setup

**Deliverables:**
- Complete documentation
- App published to Play Store
- Production monitoring active

---

## TECHNOLOGY STACK

### Frontend (Flutter)
- **google_sign_in** — Google Sign-In
- **firebase_core, firebase_auth, cloud_firestore** — Firebase
- **go_router** — Navigation
- **provider** — State management
- **razorpay_flutter** — Payments
- **google_maps_flutter** — Maps
- **shared_preferences** — Simple storage
- **hive, hive_flutter** — Complex data storage
- **flutter_secure_storage** — Sensitive data
- **sqflite** — Local database
- **intl** — Localization
- **http** — Network requests
- **freezed, json_serializable** — Code generation
- **sentry_flutter** — Error reporting

### Backend (Firebase)
- **Firebase Authentication** (Google Sign-In provider)
- **Cloud Firestore** (database)
- **Cloud Functions** (Razorpay webhooks, custom logic)
- **Firestore Security Rules** (access control)
- **Cloud Storage** (image URLs, documents)
- **Firebase App Check** (security)
- **Cloud Logging** (audit trail)

### Third-Party Services
- **Google Sign-In** (OAuth2)
- **Google Cloud Platform** (Maps API, Cloud Functions)
- **Razorpay** (Payments)

---

## FIRESTORE COLLECTIONS

```
users/
├── {uid}/
│   ├── profile (name, email, phone, avatar)
│   ├── addresses/ (home, work, delivery)
│   ├── role (customer, employee, owner, delivery, admin)
│   ├── preferences (language, notifications, theme)
│   └── devices/ (for multi-device management)

payments/
├── {uid}/
│   ├── methods/ (saved cards, wallets)
│   ├── transactions/
│   └── invoices/

orders/
├── {uid}/
│   └── {orderId} (items, status, total, payment)

products/
├── {id} (name, price, image_url, category, stock)

employees/
├── {uid} (shop_id, role, devices, approval_status)

deliveries/
├── {orderId} (assigned_to, location, status, proof)

wallets/
├── {uid} (balance, transactions, cashback)

audit_logs/
├── {timestamp} (action, user, details, ip, device)

active_sessions/
├── {uid}/{sessionId} (device, ip, login_time, expiry)
```

---

## SUCCESS METRICS

| Metric | Target |
|--------|--------|
| Authentication success rate | >99% |
| Payment success rate | >99.5% |
| Data sync latency | <5 seconds |
| Failed sync recovery | 100% |
| Offline mode uptime | 100% (no crashes) |
| Code coverage | >80% |
| Load time (home screen) | <2 seconds |
| Memory usage | <200MB |
| Battery drain | <10% per hour |
| Crash-free users | >99.9% |

---

## RISK MITIGATION

| Risk | Mitigation |
|------|-----------|
| Google Sign-In API changes | Monitor Google Cloud console, update SDKs quarterly |
| Firestore quota exceeded | Implement rate limiting, pagination, caching |
| Payment fraud | Razorpay's fraud tools, custom validation, audit logging |
| Data loss (offline) | Dual write (local + cloud), delta sync, backup |
| App crash | Sentry monitoring, beta testing, staged rollout |
| Role escalation | Custom claims + Firestore rules, audit logging |

---

## BUDGET & RESOURCES

### Personnel
- 2 Backend Engineers (Firebase, Cloud Functions)
- 2 Flutter Engineers (UI, features)
- 1 QA Engineer (testing, UAT)
- 1 DevOps (infrastructure, CI/CD)

### External Services
- Firebase (Blaze plan: ~$100-500/month depending on usage)
- Razorpay (2-3% of transaction value)
- Google Cloud (Maps API: ~$0.50 per 1000 requests)

### Timeline
- Total: 14 weeks (10-14 development weeks + 1 week testing + 1 week deployment)
- Start: Jun 11, 2026
- Target Launch: Aug 29, 2026

---

## NEXT STEPS

1. **Approve this plan** — Confirm scope, timeline, resources
2. **Review research documents** — Understand architecture details
3. **Setup Firebase project** — Create Firestore, authentication, Cloud Functions
4. **Setup Google Cloud** — OAuth consent, Maps API, Cloud Functions
5. **Begin Phase 1** — Start authentication implementation
6. **Daily standups** — Track progress, identify blockers

---

**Status: READY FOR EXECUTION** ✅
