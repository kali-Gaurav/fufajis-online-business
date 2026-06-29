# Fufaji's Online — Master Workflow & Gap Audit

**App:** Fufaji's Online / फुफाजी स्टोर — single-shop hyperlocal e-commerce for rural/district India
**Package:** `com.fufajis.online` · **Stack:** Flutter (Dart) · Provider · GoRouter · Firebase (Firestore/Auth/Storage/Functions/App Check) · Razorpay · Sentry · Shorebird
**Workspace:** `C:\Projects\fufaji-online-business`
**Audit date:** 2026-06-10 · Produced by 4 parallel research agents (customer / owner+admin / delivery+employee / cross-cutting infra)

> **Purpose of this doc:** the single source of truth for (a) what each of the 5 user roles does end-to-end, (b) what's actually built vs. broken, and (c) the prioritized backlog we will design and fix against. Read this before touching any screen.

---

## 0. How to read & work this repo (READ FIRST)

These constraints are non-negotiable and have already cost full rebuild sessions:

1. **Never use Edit/Write on existing `.dart` files in this repo.** The mount is Windows-backed with CRLF; the file tools silently **truncate** files at the edit point and *report success*. 72 files were destroyed this way in one prior session. Safe edit path = read via `git show HEAD:<file>`, apply replacements in a Python heredoc, write with `open(f,'w',newline='\n')` **inside the bash shell**. New files (like this `.md`) are safe.
2. **The bash shell is currently DOWN** (workspace disk full). Until it's restored, no existing-code edits are safe. Free up disk on the workspace to re-enable it. Everything in the backlog below is therefore *staged* — designed and ready, executed once the shell is back.
3. **No `flutter analyze` in-sandbox** (bundled SDK is Windows). Verify edits with a Dart-aware brace lexer + API grep + on-disk `wc -c` size check.
4. **Git index may be corrupt** from a prior session (`.git/index` bad signature + stale `index.lock`). The object DB and working tree are intact. Repair on Windows before committing: `del .git\index.lock` → `git read-tree HEAD` → `git status`.

---

## 1. Executive summary

Fufaji's is a **large, feature-rich app that is roughly 80% built but only ~55–60% wired and visually consistent.** The engine is strong — comprehensive Firestore RBAC, centralized `AppTheme` (light/dark, role accents, Hindi/elderly accessibility), 110+ services, 19 registered providers (all registered, no orphans). The problems are at the seams:

- **~30+ screens exist on disk but are unreachable** (no route, or buried behind tab-index dashboards) — this is the bulk of "missing features": they're built, not connected.
- **Owner & Admin dashboards use tab-index navigation, not routes** → no deep linking, broken back button, many sub-screens only reachable via the tab shell.
- **Theme is centralized but inconsistently applied** — well-maintained routed screens respect `AppTheme` (~90%); orphaned/older screens hardcode `Color(0xFF…)`, font sizes, padding (~20%). This is the root of "UI not designed properly for Android."
- **Several flows are stubbed with mock data** (pending price changes, settlement approval, reviews moderation, admin analytics) — look done, do nothing.
- **Two real security issues:** a hardcoded Razorpay **live** key in `payment_provider.dart`, and Firestore `analytics`/`audit_logs`/`cache` collections writable by any signed-in user.
- **i18n gap:** Hindi (`app_hi.arb`) covers ~25 strings; delivery/employee/owner screens are English-hardcoded.

The good news: almost nothing needs to be invented. The work is **connect, unify, and finish** — not build from zero.

### Health scorecard by role

| Role | Screens | Routed | Workflow completeness | Top risk |
|---|---|---|---|---|
| Customer | ~43 (5 dead/backup) | ~26 | High — full shop→cart→pay→track→post-order loop works | Orphaned barcode scanner, dead profile-edit button, 3 duplicate checkout files |
| Owner | ~47 | ~27 + tab-index | Medium — ops exist but mock-data stubs in pricing/settlements | Tab-index routing; mock approval flows |
| Admin | 7 | 1 (`/admin` only) | Medium — moderation UIs exist, actions thin | All 6 sub-screens behind tab index; pagination warned-but-absent |
| Delivery | 9 (4 orphaned) | 5 | High — clock-in→route→POD→earnings works | COD cash not linked to POD; dead cluster/chat screens |
| Employee | 19 | 19 ✅ | High — full scan/pack/dispatch/inventory suite, all routed | Hindi missing; no offline badge; double-scroll jank |

---

## 2. Role workflows (the "what each user does")

### 2.1 Customer journey (end-to-end)

**Auth/onboarding:** `splash_screen` → guest browse (`GuestProvider`) OR `/profile-creation` (new) → verified home. Guest can see home/search/product only; checkout triggers a verification wall (`verification_wall_screen`) that migrates the guest cart.

**The loop:**
1. **Discover** — `home_screen.dart` (~1990 lines, Swiggy-benchmarked single-shop storefront): pinned search w/ rotating hints + voice, store hero card (rating/delivery/COD), offer carousel (driven by `ShopConfigProvider`), quick-action tiles (Buy Again, Voice Order, Snap to Shop, Smart Kitchen, Wallet), category grid, festival banner, lightning deals w/ countdown, product rails (Bestsellers/Trending/Local/Fufaji's Pick/Recently Viewed), trust strip, store-info footer. Elderly mode supported.
2. **Search** — `search_screen.dart`: `ProductProvider.searchProducts()`, phonetic + Hindi-alias matching, voice search, recent/popular queries.
3. **Product** — `product_detail_screen.dart`: images, variants, reviews stream, Q&A, farm-map transparency, group-buy widget, wishlist/share, add-to-cart.
4. **Cart** — `cart_screen.dart`: swipe-to-delete, qty steppers, upsell rail, coupon input, "Village Rider" progress, summary sheet → checkout.
5. **Checkout** — `checkout_screen.dart` unified 5-step: phone/OTP verify → cart review + promo → address & delivery type (standard/express/scheduled w/ slot picker) → payment (COD default, UPI via `UpiPaymentService`, Fufaji Credit, wallet) → in-place confirmation (Lottie + confetti, cart cleared) → `/customer/order-confirmation`.
6. **Track** — `delivery_tracking_screen.dart` (custom animated path) and/or `track_order_screen.dart` (Google Maps live rider) — *duplication, see backlog*. ETA, call-rider.
7. **Post-order** — `orders_screen.dart` (tabs + scratch rewards), `order_detail_screen.dart` (timeline, packing proof, invoice), `add_review_screen.dart` (stars/text/3 photos/profanity filter), `dispute_screen.dart` (return w/ photo proof, 24h SLA).
8. **Engage/retain** — wallet (`wallet_history_screen`), loyalty (`loyalty_screen`, tiers), refer & earn (`refer_earn_screen`, ₹50/friend), membership (`membership_dashboard_screen`, streaks + slot booking), profile (`profile_screen`, Buy-Again rail), support chat (`support_chat_screen`).
9. **Power features** — voice order (`voice_order_screen`, Hinglish), snap-to-shop, smart kitchen, group buying, subscriptions, family management, fast checkout.

**Providers:** Auth, Guest, Cart, Product, Order, Payment, Wallet, Review, Subscription, Notification, ShopConfig, Accessibility, Location.

### 2.2 Owner journey

Entry: `owner_home_page_simplified.dart` (KPI snapshot, alerts, quick actions) inside `owner_dashboard.dart` (tab-index shell, ~18 pages).

**Operational journeys:**
- **Catalog** — `products_management` (categories, bulk-upload dialog *[handler empty]*, seed), `add_product_screen` (barcode/HSN/multi-image), `voice_product_add_screen` *[orphaned]*.
- **Pricing** — `pricing_rules_screen` (Match/Premium/Cost+%), `dynamic_pricing_console` *[tab-only]*, `mandi_pricing_dashboard` *[orphaned]*, `pending_price_changes_screen` *[MOCK DATA]*.
- **Orders/fulfillment** — `orders_management` (status tabs), `packing_dashboard_screen` (6-col kanban, horizontal scroll), `order_packing_screen`, `packing_terminal_screen`.
- **Inventory** — `inventory_screen` (low/out/expiring filters, auto-reorder toggle), `bill_scanner_screen`/`supplier_bill_scanner_screen` (OCR receive), `inventory_receiving`, `inventory_audit`, `expiry_tracking` (markdown trigger), `barcode_inventory_screen` *[orphaned]*.
- **People** — `employee_management_screen` (email-keyed authorize), `rider_management_screen` (OTP), `attendance_management` *[tab-only]*, `rider_support_console`, `fleet_tracking_dashboard` *[tab-only]*, `smart_dispatch_screen` *[orphaned]*.
- **Shop config** — `delivery_zones_screen`, `operating_hours_screen`, `shop_settings_screen`, `shop_location_picker_screen`, `branch_management_screen`.
- **Money** — `cash_register_screen` (POS, cash-only — *no UPI*), `settlements_management` (COD/refunds/payouts — *approval buttons missing*), `bahi_khata_screen` (credit ledger).
- **Insight & comms** — `analytics_screen` (KPIs + postcode heatmaps, *hardcoded Jaipur data*), `broadcast_notification_screen` *[orphaned + FCM simulated]*, `reviews_moderation_screen` *[tab-only + mock]*, `whatsapp_sync_setup_screen`.

**Providers:** Auth, Product, Order, ShopConfig, Delivery, Notification, Admin, Cart (POS), Employee.

### 2.3 Admin journey

Entry: `admin_dashboard.dart` — single `/admin` route, all sub-screens via **tab index**: `user_management` (no pagination despite warning), `shop_management` (approve/suspend), `product_moderation` (approve/reject queue), `order_management` (global, disputes/refunds), `coupon_management` (grid + add dialog), `analytics` (global KPIs, *mock data*). No deep links to any of them.

### 2.4 Delivery agent journey

`delivery_dashboard.dart` (5-tab: dashboard/orders/earnings/trip-sheet/scanner, shift clock-in w/ geofence) → `delivery_orders_screen` (New/In-Progress/Completed, 30s location ping, tap-to-call) → route via `smart_route_screen` (clustering, ₹30/trip est.) or `trip_route_sheet` (nearest-neighbor + Google Maps multi-stop, offline cache) → `live_tracking_screen` (Maps + OTP complete) → POD via `delivery_pod_scanner_screen` (scan PARCEL-{orderId}, GPS, photo, auto-confirm within 150m) → COD cash *[disconnected — manual nav]* → `delivery_earnings_screen` (base + long-distance bonus + fuel + tips + COD). **Orphaned/dead:** `delivery_detail_screen`, `delivery_cluster_view`, `rider_chat`.

**Services:** DeliveryProvider, FleetService, DeliveryTrackingService, OfflineRoutingService, OrderService, OfflineSyncService.

### 2.5 Employee (in-store ops) journey — fully routed ✅

`employee_home_screen` (live Firestore counters: pending orders/deliveries/low-stock/returns) → `task_priority_screen` (Urgent→Low) → `unified_scanner_hub` (9 modes, auto-routes scan results). Flows: attendance QR check-in (`attendance_screen`) → packing (`order_packing_screen`: scan items, weight-verify produce, photo proof, auto-print) → dispatch (`dispatch_scanner_screen`: assign rider) → employee-assisted delivery/POD → receiving (`inventory_receiving_screen`: barcode lookup, batch/expiry, AI label, shelf-tag print) → audit (`inventory_audit_screen`) → shelf refill → expiry mgmt → returns → damage reporting → inter-branch transfer → customer membership scan → clock-out.

**Services:** EmployeeScannerService, SmartScanService, OrderProvider, ProductProvider, ShopConfigProvider, OfflineSyncService.

---

## 3. Cross-cutting architecture & integration health

### 3.1 Router (`lib/utils/app_router.dart`, ~704 lines)
- **Customer:** ShellRoute, ~26 routes — well covered. Guest-allowed: home/search/product only. Verification-gated: orders, wallet, addresses, checkout, tracking, disputes. New users forced to `/profile-creation`.
- **Owner:** ~27 nested routes under `/owner`, **but** the dashboard also runs a tab-index shell holding ~18 pages — several screens are reachable *only* via tab index (no URL), e.g. reviews-moderation, dynamic-pricing, settlements, attendance, fleet-tracking, broadcast.
- **Employee:** 19 routes — complete ✅.
- **Delivery:** 5 routes (`orders`, `earnings`, `trip-sheet`, `smart-route`) + dashboard. `live_tracking` opened programmatically; `delivery_detail`/`cluster`/`rider_chat` unrouted.
- **Admin:** `/admin` only; 6 sub-screens tab-index.
- **Guards:** owner/admin PIN + device verification, role-dashboard enforcement, profile-completion mandate. Solid.

> **Routing's #1 architectural debt:** owner & admin use **tab index instead of routes** → no deep linking, broken browser/back history, no Firebase Dynamic Links, and screens that fall out of the tab list become orphans.

### 3.2 Providers (`lib/providers/`, 19) — all registered in `main.dart` MultiProvider, **no orphans**. `AuthProvider` & `GuestProvider` are singletons feeding the router `refreshListenable`; `ProductProvider` is a ProxyProvider on Auth (syncs shop context). Clean.

### 3.3 Services (`lib/services/`, 110+) — rich and mostly wired: Razorpay (live), WhatsApp sync (Gemini OCR), Gemini AI (warmed in `main.dart`), FCM/SMS/in-app notifications, ML Kit (barcode/text/label), thermal printer, fleet/routing, loyalty/membership. **Stubs/incomplete:** `order_notification_service`, `inventory_alert_service`, `thermal_label_service`, `pricing_engine`, `rider_payout_service`. **Verify-exist:** `user_service`, `chat_service`, `return_request_service`, `supabase_database_service` were referenced but not in the service glob — confirm presence.

### 3.4 Design system / theme (`lib/utils/app_theme.dart`, ~429 lines)
Central `AppTheme`: Material3, light+dark, Poppins, brand orange primary, role accents (owner blue / delivery green / employee purple / admin red), 24 category colors, status color+emoji helpers, spacing/radius/shadow constants. `AccessibilityProvider.effectiveFontScale` applied app-wide via `textScaler`; elderly mode + Hindi/English toggle.
**Problem = application, not definition:** routed/maintained screens ~90% consistent; orphaned/older screens hardcode `Color(0xFF…)`, font sizes, padding. **Overall consistency ≈ 50–60%.** This is the concrete meaning of "UI not properly designed for Android," and the unification plan in §5 targets it directly.

### 3.5 Rules / config / security (`firestore.rules` ~385 lines, `firebase_options.dart`, `app_config.dart`, `android/app/build.gradle`, `pubspec.yaml`)
- **RBAC rules:** comprehensive helper fns (`isAdmin/isOwner/isEmployee/isCustomer/isOwningUser/isApprovedEmployee/isShopOwner`), per-collection + subcollection coverage. Strong.
- **Rule gaps:** `analytics`, `audit_logs`, `cache` allow write to *any* signed-in user (pollution/DoS); **no data validation** (types, enums, ranges, formats); missing rules for some collections (coupons/discounts, push_tokens, ai logs); Supabase backup auth has **no RLS defined**.
- **Secrets:** Razorpay/Supabase/Sentry via `.env` ✅ — **BUT** `payment_provider.dart` hardcodes Razorpay **live** key `rzp_live_…` (HIGH severity, exposed in VCS).
- **Firebase config:** Android + Web real; **iOS/macOS/Windows are dummy creds** (app crashes on those platforms — Android is the target so lower urgency, but iOS will be needed).
- **Android build:** namespace `com.fufajis.online`, compileSdk 36, minSdk 24 (good for rural), Java 17, Play Integrity App Check, R8 minify, MultiDex. Healthy.
- **Dead deps:** `riverpod`/`flutter_riverpod` (unused — Provider is the manager), likely `video_player`.

---

## 4. Consolidated prioritized backlog

Severity: 🔴 critical · 🟠 high · 🟡 medium · ⚪ low. Effort in dev-hours. All edits require the **shell-safe edit path** (§0).

### P0 — security & correctness (do first, fast)
| # | Fix | Sev | File(s) | Est |
|---|---|---|---|---|
| 1 | Move hardcoded Razorpay **live** key to `.env`/`AppConfig` | 🔴 | `lib/providers/payment_provider.dart` (~L43) | 0.5h |
| 2 | Lock down `analytics`/`audit_logs`/`cache` writes to admin/approved-employee + ownership | 🔴 | `firestore.rules` (~L121, L366–375) | 0.5h |
| 3 | Fix dead **profile edit** button (empty `onPressed`) | 🟠 | `lib/screens/customer/profile_screen.dart` (~L150) | 0.25h |
| 4 | Remove dead/backup checkout files; keep one source of truth | 🟠 | `checkout_screen_v2/new/.backup…dart` | 0.5h |
| 5 | Add Firestore data validation (types/enums/ranges) for products, orders, reviews | 🟡 | `firestore.rules` | 2h |

### P1 — connect the built-but-orphaned screens (this is "build missing features")
| # | Fix | Sev | File(s) | Est |
|---|---|---|---|---|
| 6 | **Convert owner + admin dashboards from tab-index to GoRouter subroutes** (unblocks deep-link, back button, and ~21 orphans) | 🔴 | `owner_dashboard.dart`, `admin_dashboard.dart`, `app_router.dart` | 4h |
| 7 | Route + verify customer orphans: barcode scanner, family management, fast checkout, missing-item-choice, smart-kitchen, snap-to-shop, group-buying | 🟠 | those screens + `app_router.dart` | 3h |
| 8 | Route owner orphans actually wanted: broadcast-notification, mandi-pricing, smart-dispatch, barcode-inventory, device-management | 🟠 | those screens + `app_router.dart` | 2h |
| 9 | Verify delivery `earnings` route binds the class; route/retire `delivery_detail`, `cluster_view`, `rider_chat` | 🟡 | `app_router.dart`, delivery screens | 1.5h |
| 10 | De-dupe customer tracking: pick `track_order` (Maps) vs `delivery_tracking` (animated), retire the other | 🟡 | both tracking screens | 1h |

### P2 — finish the stubbed flows (look done, do nothing)
| # | Fix | Sev | File(s) | Est |
|---|---|---|---|---|
| 11 | Pending price changes → real Firestore stream + approve/reject | 🔴 | `pending_price_changes_screen.dart`, `product_provider.dart`, `pricing_service.dart` | 3h |
| 12 | Settlement approval → approve/reject buttons + Firestore txn | 🟠 | `settlements_management.dart`, `order_provider.dart` | 2h |
| 13 | Broadcast notifications → real FCM topic send (Cloud Function) | 🟠 | `broadcast_notification_screen.dart`, `notification_service.dart` | 3h |
| 14 | Reviews moderation → live data + reply/feature/flag actions | 🟡 | `reviews_moderation_screen.dart` | 2h |
| 15 | Bulk product upload (CSV) handler | 🟡 | `products_management.dart`, `product_service.dart` | 3h |
| 16 | Cash register UPI/Razorpay (currently cash-only) | 🟠 | `cash_register_screen.dart` | 2h |
| 17 | Link COD cash collection from POD when `paymentMethod == COD` | 🟠 | `delivery_pod_scanner_screen.dart`, `cash_collection_screen.dart` | 1h |
| 18 | Admin user list pagination (warned but absent) | 🟡 | `user_management_screen.dart` | 1.5h |

### P3 — UI/Android quality (the four pain areas you chose)
| # | Fix | Sev | Area | Est |
|---|---|---|---|---|
| 19 | **Theme unification pass** — replace hardcoded colors/fonts/padding with `AppTheme` across orphaned/older screens (see §5) | 🟠 | Consistency | 6–8h |
| 20 | Responsive grids (admin coupon/product-moderation, owner analytics/cash-register) via `MediaQuery` crossAxisCount | 🟠 | Overflow | 2h |
| 21 | Fix overflow risks: fixed-width horizontal rails (cart upsell, home Buy-Again), kanban columns on small screens | 🟠 | Overflow | 2h |
| 22 | Remove double-scroll anti-pattern in delivery orders | 🟠 | Overflow/jank | 0.5h |
| 23 | Shared empty/error-state widget + retry; apply to orders, support-chat, order-detail, delivery/employee streams | 🟡 | Polish | 3h |
| 24 | Offline sync badge on employee home (copy from delivery dashboard) | 🟡 | Polish | 0.5h |
| 25 | Expand Hindi `app_hi.arb` (~25 → ~250 strings) + wire `S.of(context)` in delivery/employee/owner | 🟠 | Polish/i18n | 6h |
| 26 | Extend elderly-mode scaling beyond home (loyalty, profile, wallet) + add `Semantics` labels to icon buttons | 🟡 | Accessibility | 4h |
| 27 | Loading skeletons for product detail / orders / analytics | ⚪ | Polish | 2h |

### P4 — cleanup / platform
| # | Fix | Sev | Est |
|---|---|---|---|
| 28 | Remove unused `riverpod`/`flutter_riverpod` (+ likely `video_player`) from `pubspec.yaml` | ⚪ | 0.25h |
| 29 | Confirm/locate referenced-but-unglobbed services (`user_service`, `chat_service`, `return_request_service`, `supabase_database_service`) | 🟡 | 0.5h |
| 30 | ~~iOS Firebase creds~~ — **DESCOPED: Android-only** (dummy iOS/macOS/Windows creds are fine; ignore) | ⚪ | — |
| 31 | Maps service abstraction + route `map_picker`; thermal-printer owner screen | 🟡 | 3h |

---

## 5. Design-system unification plan (the core of "fix the UI for Android")

The fastest, lowest-risk way to make the whole app feel consistently designed is to **stop hand-styling screens and route everything through `AppTheme`.** Plan:

1. **Audit + freeze tokens.** Confirm the `AppTheme` token set (colors, text styles, spacing 4/8/16/24, radius, elevation). Add any missing named tokens (e.g., `AppTheme.gap8`, `AppTheme.cardRadius`) so screens never need literals.
2. **Build a thin reusable widget kit** (new files, shell-safe): `FjScaffold`, `FjAppBar`, `FjButton` (primary/secondary/text), `FjCard`, `FjSectionHeader`, `FjEmptyState`, `FjErrorState`, `FjLoading`. Most inconsistency is buttons/cards/headers re-styled per screen; these kill it at the source.
3. **Lint the literals.** Grep for `Color(0xFF`, `fontSize:`, `EdgeInsets.all(` across `lib/screens/**` to get the exact offender list; replace with tokens. (Orphaned screens are the worst; do them as they're routed in §4 P1.)
4. **Responsive helper.** One `Responsive.cols(context)` util for grids; apply to admin/owner grid screens (#20).
5. **Dark-mode sweep.** Once literals are gone, dark mode largely works; spot-fix custom widgets.
6. **Per-screen definition of done:** no color/text/padding literals; uses kit widgets; has loading+empty+error states; no overflow at 320 px width; Hindi strings via `S.of(context)`; respects `effectiveFontScale`.

Order of attack: customer revenue screens → owner ops → delivery/employee → admin. Do theme cleanup **in the same PR** as routing each orphan, so a screen is connected *and* polished in one pass.

---

## 6. Orphaned / unrouted screens — triage

> Cross-agent counts differed (the infra agent counted modals/dialogs as "orphans"; the role agents didn't). **Verify each on-disk before acting.** Intentional non-routes (keep as modals/sheets): `map_picker_screen`, `checkout_auth_sheet`, `payment_verification_dialog`, `guest_profile_screen` (embedded).

| Screen | Role | Action |
|---|---|---|
| barcode_scanner_screen | customer | Route → `/customer/scan` |
| family_management_screen | customer | Route + profile entry |
| fast_checkout_screen | customer | Route for returning users |
| missing_item_choice_screen | customer | Route into partial-order dispute |
| smart_kitchen / snap_to_shop / group_buying_room | customer | Route (guard on Gemini warmup) |
| track_order vs delivery_tracking | customer | De-dupe; retire one |
| broadcast_notification_screen | owner | Route + real FCM |
| mandi_pricing_dashboard | owner | Route into pricing hub |
| smart_dispatch / barcode_inventory / device_management | owner | Route from dashboard |
| reviews_moderation / dynamic_pricing_console / settlements_management / attendance_management / fleet_tracking_dashboard | owner | Becomes routable after tab-index → routes refactor (#6) |
| voice_product_add_screen | owner | Route or retire |
| release_management_screen | owner | Confirm purpose; route or delete |
| order/shop/user/product/coupon/analytics management | admin | Routable after #6 |
| delivery_detail / delivery_cluster_view / rider_chat | delivery | Route or archive to `dead_code/` |

---

## 7. Verification, constraints & open questions

**Known cross-agent discrepancies to confirm on-disk (shell required):**
- Customer route count (role agent counted ~26 routed; infra agent flagged ~22 customer "orphans" — overlap is mostly modals). Reconcile via the actual `app_router.dart` route list.
- `DeliveryEarningsScreen`: one agent saw it routed, another saw an import without a binding. Confirm the GoRoute exists and points at the class.
- Existence of `user_service`, `chat_service`, `return_request_service`, `supabase_database_service` (referenced, not globbed).

**Verification step for every code change (since `flutter analyze` can't run in-sandbox):** Dart-aware brace lexer balance vs HEAD + API grep + on-disk `wc -c` size check; then a real device/emulator build before calling anything "done."

**Open questions for Gaurav:**
1. ~~iOS in scope?~~ → **Resolved: Android-only.** iOS/macOS/Windows dummy creds are acceptable; #30 descoped.
2. Are `release_management_screen`, `delivery_cluster_view`, `rider_chat` wanted features or abandoned experiments? (route vs archive) — *still open, not blocking*
3. Keep both customer tracking screens or consolidate to one? — *still open, not blocking*

---

## 8. Execution plan (once shell is restored)

- **Phase 0 (≈1.5h):** P0 security/correctness #1–4. Small, isolated, high value.
- **Phase 1 (≈9h):** Routing backbone #6 + connect customer/owner orphans #7–8; theme-unify each screen as it's routed.
- **Phase 2 (≈14h):** Finish stubbed flows #11–18 (pricing approval, settlements, broadcast FCM, COD-from-POD, bulk upload, cash-register UPI).
- **Phase 3 (≈20h):** UI/Android quality #19–27 (theme kit, responsive grids, overflow, empty/error states, Hindi, accessibility).
- **Phase 4 (≈4h):** Cleanup #28–31.

Each phase ends with a device build + the verification step. We design from the existing system — connect, finish, unify — not rebuild.

---

*Generated by parallel research agents over the live `lib/` tree on 2026-06-10. Treat file:line citations as starting points; verify against current code before editing (per §0).*
