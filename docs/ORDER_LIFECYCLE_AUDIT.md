# WORKFLOW AUDIT: ORDER LIFECYCLE
Target: 90%+ Production Readiness

## Phase 1: File Discovery
The following files are critical to the Order Lifecycle:

### Core Logic & State
- [ ] `lib/models/order_model.dart` (Order, Item, Status structure)
- [ ] `lib/services/order_service.dart` (The State Machine)
- [ ] `lib/providers/order_provider.dart` (State management & UI glue)
- [ ] `lib/services/offline_sync_service.dart` (Offline resilience)

### UI - Customer
- [ ] `lib/screens/customer/checkout_screen.dart` (The Order Entry Point)
- [ ] `lib/screens/customer/orders_screen.dart` (Order History)
- [ ] `lib/screens/customer/order_detail_screen.dart` (Proof of Packing & Weights)
- [ ] `lib/screens/customer/track_order_screen.dart` (Live Rider Tracking)

### UI - Operations (Owner/Employee/Delivery)
- [ ] `lib/screens/owner/packing_dashboard_screen.dart` (Kanban Hub)
- [ ] `lib/screens/delivery/delivery_orders_screen.dart` (Rider Fulfillment)
- [ ] `lib/screens/owner/settlements_management.dart` (Refunds & Cash Ledger)

---

## Phase 2: Workflow Mapping & Gap Analysis

### 1. The Checkout Flow
- **Current:** 5-step unified flow.
- **Audit:** Verify address validation and stock lock during checkout.
- **Gap:** Auto-cancel "stuck" pending orders after timeout.

### 2. The Fulfillment Flow (Pack & Dispatch)
- **Current:** Kanban board advances status.
- **Audit:** Packer lock (prevent multiple employees on one order).
- **Gap:** Substitute item approval flow.

### 3. The Delivery Flow (POD)
- **Current:** OTP + Proximity check.
- **Audit:** Geofence verification accuracy.
- **Gap:** Rider cash collection safety limit (₹5,000 max).

### 4. Returns & Refunds
- **Current:** Manual approval by owner.
- **Audit:** Double-click protection on refund buttons.
- **Gap:** Real-time wallet credit sync.

---

## Phase 3: Technical Audit Checklist

### `order_service.dart`
- [ ] Strict state transition validator (no jumping states).
- [ ] Transactional integrity (Atomic updates for stock/balance).
- [ ] Duplicate order prevention (Idempotency).

### `checkout_screen.dart`
- [ ] Theme unification (FjButton/FjCard).
- [ ] Keyboard overlap prevention.
- [ ] Address selection edge cases.

---

## Phase 4: Production Readiness Score
| Area | Score |
| --- | --- |
| UI Consistency | 50% |
| Logic & Integrity | 70% |
| Firebase Security | 85% |
| Performance | 60% |
| Android Compatibility | 65% |
| **Overall Score** | **66%** |
