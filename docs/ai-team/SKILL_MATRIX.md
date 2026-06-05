# 🤖 Fufaji Online — AI Software Development Team Skill Matrix
> **Stack:** Flutter · Firebase · Razorpay · Shorebird · GitHub Actions  
> **Market:** India (Hindi/English) · Hyperlocal · Rural + Semi-urban  
> Last updated: June 2026

---

## How to Use This Document
For each skill, paste the prompt into Claude, fill in the `[PLACEHOLDERS]`, and run it.  
Save every output under `docs/ai-team/outputs/skill-N-<name>/`.  
Each skill has a ✅ Verification checklist — don't move to the next skill until it passes.

---

## 🎯 Skill 1 — PRODUCT MANAGEMENT
**Purpose:** Define requirements, user stories, and prioritized feature backlog

```
Act as a senior product manager for a hyperlocal e-commerce Flutter app.
App name: "Fufaji Online" (Fufaji's Online: Aapki Apni Dukaan)
Stack: Flutter + Firebase + Razorpay + Shorebird OTA

Core features to spec:
- 5 user roles: Customer, Shop Owner (Fufaji), Delivery Agent, Employee/Packer, Super Admin
- Product catalog (grocery, pharmacy, seasonal Indian goods)
- Shopping cart & checkout with Razorpay (UPI, Cards, COD, Udhaar credit ledger)
- Firebase backend (Firestore, Auth, Functions, Storage, FCM)
- Voice search in Hindi/English
- Udhaar (monthly credit) system — digital Bahi-Khata
- Dad-joke / hyperlocal micro-interactions
- Festive mode themes (Diwali, Eid, Independence Day)
- Target: Rural + semi-urban India

Output:
1. User stories in Gherkin syntax (Given/When/Then) for top 10 flows
2. Feature prioritization using MoSCoW method
3. Technical requirements document (Flutter constraints, Firebase quotas)
4. Acceptance criteria for each role's portal
5. Definition of Done checklist
```

✅ **Verification:** All user stories must have Given/When/Then. MoSCoW must cover all 5 roles.

---

## 🎨 Skill 2 — UI/UX DESIGN
**Purpose:** Complete design system, tokens, and screen specs

```
Act as a senior UI/UX designer for Fufaji Online — a Flutter hyperlocal e-commerce app.

Design system specs:
- Brand colors: Primary #FF6F00 (Sunset Orange), Secondary #2E7D32 (Basil Green), Neutral #FAECE3
- Dark mode: #1A110B neutral core
- Typography: Noto Sans (Hindi + English), fallback: system-ui
- Target: Indian users aged 25–60, rural to semi-urban
- 3 themes: Classic Fufaji (glassmorphism), Senior Mode (high-contrast, large type), Festive Mode (dynamic holidays)

Design deliverables:
1. Complete design token JSON (colors, spacing, radius, shadows, typography scales)
2. Component library spec: Button variants, Product Cards, Cart badges, UPI QR modal, Udhaar ledger card
3. 7-screen user flow specs: Splash → Home → Search → Product Detail → Cart → Checkout → Order Tracking
4. Accessibility checklist (WCAG 2.1 AA, screen reader labels in Hindi)
5. Micro-interaction specs: Flying cart parabola, Shimmer loaders, Countdown stepper, Haptic feedback map
6. Flutter widget mapping for each component

Output: Design tokens as Dart constants file (lib/theme/app_theme.dart skeleton)
```

✅ **Verification:** Color contrast ratio ≥ 4.5:1 for all text. Senior Mode must pass WCAG AAA.

---

## 📱 Skill 3 — FLUTTER ARCHITECTURE
**Purpose:** Set up the complete project structure and state management

```
Act as a Flutter architect. Create a production-grade project structure for Fufaji Online.

Current stack: Flutter 3.x, Firebase, Riverpod (state management), GoRouter (navigation), Hive (local cache)

Required folder structure:
lib/
  core/         (constants, errors, extensions, utils)
  data/         (repositories, datasources, models)
  domain/       (entities, use_cases, interfaces)
  presentation/ (screens, widgets, providers)
    screens/    (home, product, cart, checkout, tracking, profile, owner_dashboard, delivery_dashboard)
  services/     (firebase, razorpay, voice, notification)
  theme/        (app_theme, colors, typography)
  l10n/         (Hindi + English ARB files)

Output:
1. Complete annotated folder tree
2. pubspec.yaml with all dependencies (pinned versions)
3. main.dart with Firebase init + GoRouter setup
4. Base repository pattern code (abstract + firebase implementation)
5. Riverpod provider structure for cart, auth, products
6. l10n/app_en.arb and l10n/app_hi.arb with 30 key strings

Architecture: Clean Architecture (Data → Domain → Presentation)
```

✅ **Verification:** All dependencies must be compatible with Flutter 3.x and null-safe. No conflicting packages.

---

## 🔥 Skill 4 — FIREBASE SETUP
**Purpose:** Configure all Firebase services with security rules

```
Act as a Firebase backend engineer for Fufaji Online.

Services to configure:
1. Firestore — products, orders, users, udhaar_ledger, inventory, delivery_routes
2. Firebase Auth — Phone OTP (India +91)
3. Storage — product images, invoices, user documents
4. Cloud Functions (Node.js 18) — order confirmation, Razorpay webhook handler, inventory alerts, udhaar auto-reminder
5. FCM — push notifications for order status, delivery, low stock

Output:
1. firestore.rules (role-based: customer read-only catalog, owner full access own store, admin global)
2. storage.rules (authenticated upload, public read for product images)
3. Complete Firestore schema in JSON (all 8 collections with field types)
4. functions/index.js skeleton (5 Cloud Functions with JSDoc)
5. Firestore index configuration (firestore.indexes.json)
6. Step-by-step Firebase Console setup guide (India region: asia-south1)
7. Seed data: 20 sample Indian grocery/lifestyle products JSON

Note: India region = asia-south1. Enable phone auth for +91 numbers.
```

✅ **Verification:** Security rules must block unauthenticated writes. Customer cannot access owner dashboard collections.

---

## 🛒 Skill 5 — ECOMMERCE & UDHAAR LOGIC
**Purpose:** Cart, checkout, Udhaar credit, and order management

```
Act as an e-commerce developer specializing in Indian market apps (Flutter/Dart).

Build complete business logic for:

1. Shopping cart (Riverpod StateNotifier)
   - Add/remove/update quantity
   - Persistent storage (Hive)
   - Total with GST (18% default, 5% for essentials like grains)
   - Item-level discount + coupon system

2. Udhaar (Credit) System
   - Digital Bahi-Khata ledger
   - Monthly statement generation
   - WhatsApp share of statement (share_plus package)
   - Credit limit per customer (set by owner)
   - Overdue reminders via FCM

3. Checkout flow
   - Address with landmark (rural delivery optimization)
   - Razorpay payment intent
   - COD option with max limit
   - Udhaar option (requires credit approval)
   - Order confirmation Firestore write

4. Order management
   - Status lifecycle: placed → packed → picked_up → delivered
   - Real-time Firestore listener for tracking
   - Cancellation within 5 minutes
   - Reorder from order history

Output: Complete Dart files for:
- lib/domain/entities/cart_item.dart
- lib/data/repositories/cart_repository.dart
- lib/presentation/providers/cart_provider.dart
- lib/services/udhaar_service.dart
- lib/core/utils/gst_calculator.dart (with product category tax rates)
```

✅ **Verification:** GST must be category-accurate (FMCG 18%, grains 5%, medicines 12%). Udhaar cannot exceed credit limit.

---

## 💳 Skill 6 — RAZORPAY INTEGRATION
**Purpose:** Complete payment integration for Indian payment methods

```
Act as a payment integration specialist for Flutter apps in India.

Integrate Razorpay (NOT Stripe) for Fufaji Online:

Indian payment methods to support:
1. UPI (Google Pay, PhonePe, Paytm, BHIM)
2. Cards (Debit/Credit, RuPay)
3. Net Banking
4. Cash on Delivery (COD)
5. Udhaar (internal credit — no gateway needed)

Implementation:
1. Razorpay Flutter SDK setup (razorpay_flutter package)
2. Create order on Firebase Cloud Function (Razorpay Order API)
3. Payment success/failure handlers
4. Razorpay webhook (signature verification in Cloud Function)
5. GST invoice generation (PDF) on payment success
6. Refund initiation via owner dashboard

Output:
1. lib/services/razorpay_service.dart
2. functions/razorpay/create_order.js
3. functions/razorpay/webhook_handler.js (signature verification)
4. lib/presentation/screens/checkout_screen.dart (payment selection UI)
5. .env.example with RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET

Test mode: Use Razorpay test UPI ID success@razorpay
```

✅ **Verification:** Webhook must verify Razorpay signature. COD max limit must be configurable from Remote Config.

---

## 🧪 Skill 7 — TESTING STRATEGY
**Purpose:** Complete test suite for reliability

```
Act as a QA engineer for a Flutter e-commerce app (Fufaji Online).

Testing requirements:
1. Unit tests (flutter_test)
   - GST calculator edge cases
   - Udhaar credit limit enforcement
   - Cart total calculations

2. Widget tests (flutter_test + mockito)
   - Product card rendering
   - Cart badge count update
   - Checkout form validation

3. Integration tests (integration_test package)
   - Full purchase flow: login → browse → add to cart → checkout → order placed
   - Udhaar flow: request credit → owner approves → place order

4. Firebase Emulator tests
   - Firestore security rules validation
   - Cloud Function invocation tests

5. Performance tests
   - App startup < 3 seconds on mid-range Android (Snapdragon 400)
   - Product list scroll (60fps on 100+ items)
   - Image lazy loading

Output:
1. test/ folder structure
2. Complete test files for GST calculator and cart
3. integration_test/app_test.dart (purchase flow)
4. GitHub Actions CI YAML (.github/workflows/flutter_ci.yml)
5. Test data fixtures (mock products, mock user)
6. Achieve > 80% code coverage on lib/domain/ and lib/core/
```

✅ **Verification:** CI must pass on every PR. Coverage report must show ≥ 80% for domain layer.

---

## 🔒 Skill 8 — SECURITY
**Purpose:** Harden the app against common threats

```
Act as a mobile security engineer auditing Fufaji Online (Flutter + Firebase).

Security checklist:
1. API key protection
   - flutter_dotenv for runtime injection
   - .gitignore all .env files
   - Firebase App Check (Android SafetyNet / Play Integrity)

2. Firestore rules hardening
   - Owner can only access their own store document
   - Delivery agent can only read assigned orders
   - Rate limiting via Cloud Functions

3. Input sanitization
   - Address field XSS prevention
   - Phone number E.164 format enforcement
   - Product search query sanitization

4. OTP abuse prevention
   - Firebase Auth rate limiting
   - Captcha for repeated OTP requests
   - Block suspicious IP patterns (Cloud Function middleware)

5. Payment security
   - Never log payment credentials
   - Razorpay signature verification (HMAC-SHA256)
   - PCI DSS awareness (no card data stored)

6. Data privacy (India DPDP Act 2023)
   - User consent flow
   - Right to erasure implementation
   - Data localization (asia-south1 region)

Output:
1. SECURITY.md — threat model and mitigations
2. Updated firestore.rules (v2, hardened)
3. lib/core/utils/validators.dart (phone, address, search sanitizers)
4. functions/middleware/rate_limiter.js
5. lib/services/app_check_service.dart
```

✅ **Verification:** No secrets in source code. Firestore rules must pass Firebase Rules Playground tests.

---

## 📦 Skill 9 — DEPLOYMENT & CI/CD
**Purpose:** Automated builds, signing, and Play Store releases

```
Act as a DevOps engineer for a Flutter app targeting Google Play Store (India).

Build complete deployment pipeline for Fufaji Online:

1. Shorebird OTA (hot patches without Play Store review)
   - shorebird.yaml configuration
   - Patch vs release workflow decision tree

2. GitHub Actions workflows
   - PR check: flutter test + flutter analyze
   - Release: flutter build apk --release → sign → upload to Play Store
   - Firebase deploy: rules + functions on main merge

3. Signing
   - keystore generation guide
   - android/key.properties (gitignored)
   - GitHub Secrets for CI signing

4. Play Store listing
   - App title: "Fufaji Online - Aapki Apni Dukaan"
   - Short description (Hindi + English, 80 chars each)
   - Full description (4000 chars, keyword-optimized for Indian search)
   - Content rating: Everyone
   - Icon specs: 512x512 PNG adaptive icon (Sunset Orange #FF6F00)
   - Feature graphic: 1024x500 PNG
   - 8 screenshots: 4 phone + 4 tablet (showing Hinglish UI)

5. Version strategy
   - Semantic versioning: 1.0.0 (major.minor.patch)
   - Build number auto-increment in CI
   - Changelog template

Output:
1. .github/workflows/release.yml (complete)
2. .github/workflows/ci.yml (PR checks)
3. eas.json equivalent → shorebird.yaml
4. android/app/build.gradle (signing config)
5. store_listing/ folder with all text assets
6. APK size budget: < 30MB (use --split-per-abi)
```

✅ **Verification:** APK < 30MB per ABI. CI must run in < 15 minutes. Shorebird patch must not require store update.

---

## 🤖 Skill 10 — AI AGENT ORCHESTRATION
**Purpose:** Chain all 9 skills into an automated build pipeline

```
Act as an AI engineering team lead. Design the orchestration plan to build Fufaji Online
using a team of specialized Claude agents (one per skill).

Workflow design:
1. Dependency graph (which skills block others)
2. Parallel execution opportunities (Skills 2+3 can run simultaneously)
3. Handoff contracts (output of Skill N = input of Skill N+1)
4. Validation gates between skills (automated checks)
5. Error recovery procedures (what to do when a skill output fails verification)

Claude agent roles:
- PM Agent → feeds requirements to all other agents
- Design Agent → feeds design tokens to Frontend + UI agents
- Backend Agent → feeds Firestore schema to all data-layer agents
- QA Agent → runs after each skill to validate output
- Security Agent → audits output of Skills 3-6
- DevOps Agent → assembles final build from all outputs

Output:
1. README_ORCHESTRATION.md — master execution guide
2. Mermaid diagram of full skill dependency graph
3. Handoff template for each skill transition
4. scripts/validate_skill_output.sh — bash validator
5. Troubleshooting guide (top 10 failure modes + fixes)

Format: Step-by-step runbook that a junior developer can follow.
```

✅ **Verification:** Every skill output must have a machine-readable validation step. No circular dependencies.

---

## 📁 Recommended Output Folder Structure

```
docs/
└── ai-team/
    ├── SKILL_MATRIX.md          ← this file
    ├── AI_AGENT_TEAMS.md        ← agent workforce design
    ├── README_ORCHESTRATION.md  ← master build guide
    └── outputs/
        ├── skill-1-product-management/
        ├── skill-2-ux-design/
        ├── skill-3-flutter-arch/
        ├── skill-4-firebase/
        ├── skill-5-ecommerce-logic/
        ├── skill-6-razorpay/
        ├── skill-7-testing/
        ├── skill-8-security/
        ├── skill-9-deployment/
        └── skill-10-orchestration/
```

---

*Built for Fufaji Online — Aapki Apni Dukaan* 🏪
