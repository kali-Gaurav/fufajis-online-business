# Launch Readiness: 20-Point Verification Plan

Date reviewed: 2026-06-02

## Executive Status

The app is not ready for production launch yet. Several core flows exist, but some are incomplete, inconsistent, or not proven by automated tests. The biggest launch blockers are Google login, production-safe OTP, Razorpay order creation/verification, delivery status consistency, employee workflow collection mismatch, and failing/unfinished test harnesses.

## 20-Point Checklist

| # | Feature | Current status | Action needed before launch |
|---|---|---|---|
| 1 | Customer registration works | Partial | Phone auth exists, but test setup is failing. Add Firebase emulator-backed auth tests. |
| 2 | Phone OTP works | Partial | Firebase phone OTP exists. Verify in staging with real SMS quotas and resend/timeout UX. |
| 3 | Google login works | Fail | `linkGoogleAccount()` is a placeholder. Implement `google_sign_in` or Firebase OAuth provider flow. |
| 4 | Product search works | Partial | Search services/screens exist. Add tests for empty, typo, Hindi/Hinglish, barcode, and category search. |
| 5 | Cart works | Partial | Cart logic exists, but tests show setup issues and one coupon expectation failure. Fix tests and persistence edge cases. |
| 6 | Checkout works | Partial | Checkout screen creates orders, but online payment flow needs backend Razorpay order creation first. |
| 7 | Razorpay payment succeeds | Risk | SDK integration exists, but it passes a local `txn_...` as `order_id`. Use backend-created Razorpay order IDs. |
| 8 | Failed payment handled | Partial | Failure callback exists. Persist failed payment attempts and show retry/recovery screen. |
| 9 | Order created in Firestore | Pass with risk | Root `orders` transaction exists. Add idempotency keys and emulator integration tests. |
| 10 | Inventory decreases correctly | Partial | Firestore transaction decrements root `products`. Ensure all employee screens use the same root stock source. |
| 11 | Employee scanner works | Partial | Scanner UI exists. Employee service uses branch subcollections that do not match root order/product flows. |
| 12 | Packing workflow works | Partial | Owner packing terminal reads root `orders`; employee scanner packing reads branch subcollections. Standardize. |
| 13 | Delivery assignment works | Fail/Partial | Delivery provider uses raw status strings inconsistent with `OrderStatus.*`. Fix status schema. |
| 14 | OTP delivery verification works | Partial | Secure OTP flow exists in `OrderService`, but delivery provider still checks `order.otp`. Use one secure path. |
| 15 | WhatsApp notifications arrive | Partial | WhatsApp service calls exist. Needs real Meta/Twilio staging test and fallback logging. |
| 16 | Push notifications arrive | Partial | FCM queue Cloud Function parses. Need device-token staging test and invalid-token cleanup test. |
| 17 | Offline sync works | Partial | SQLite queue exists for orders/employee actions. Add conflict and replay integration tests. |
| 18 | Refund process works | Partial | Webhook marks refunded. Need Razorpay Refund API initiation, partial refund, and inventory restore rules. |
| 19 | Backup process exists | Partial | Scheduled Firestore backup function exists. Confirm IAM, bucket, restore drill, and alerting. |
| 20 | Owner dashboard metrics are correct | Partial | Metrics are client-side from loaded orders only. Replace with server-side daily aggregate queries. |

## Step-by-Step Implementation Plan

### Phase 1: Stop-Launch Blockers

1. Implement real Google login.
   - Add the proper Google sign-in dependency and configure Android SHA keys/Firebase OAuth.
   - Replace placeholder logic in `AuthProvider.linkGoogleAccount()`.
   - Add emulator or mocked provider tests.

2. Move all OTP generation/sending to the backend.
   - Keep Firebase phone OTP for phone auth.
   - Replace client-side email OTP generation with a callable Cloud Function.
   - Never print OTPs in production logs.

3. Fix Razorpay production flow.
   - Create a callable Cloud Function to create Razorpay orders server-side.
   - Pass the real Razorpay `order_id` to checkout.
   - On success, verify signature server-side and rely on webhook reconciliation.
   - Persist failed/cancelled payment records.

4. Standardize order statuses.
   - Use one schema everywhere: preferably enum string names such as `pending`, `confirmed`, `processing`, `packed`, `outForDelivery`, `delivered`, `cancelled`.
   - Update all queries and writes to match.
   - Add migration for existing `OrderStatus.*` documents.

5. Standardize order/product collections.
   - Customer, owner, employee, and delivery flows should all use the same canonical root `orders` and root `products` documents.
   - Keep branch subcollections only as read models or audit trails if needed.

### Phase 2: Operational Workflow Hardening

6. Lock packing with transactions.
   - Claim an order by `packerId` in a transaction.
   - Prevent two employees from packing the same order.
   - Record scanned/packed quantities per item.

7. Fix delivery assignment.
   - Assign rider with a transaction from `packed` to `outForDelivery`.
   - Generate delivery OTP only through `OrderService.updateOrderStatus(..., outForDelivery)`.
   - Require secure OTP verification plus location proximity for delivery.

8. Add refund and partial fulfillment.
   - Add refund initiation Cloud Function.
   - Support replacement, missing item, partial refund, full refund.
   - Reconcile Razorpay refund webhooks into order/payment ledger.

9. Prove WhatsApp and push notification delivery.
   - Add notification ledger collection with `queued`, `sent`, `failed`, `fallback` states.
   - Test order placed, packed, out for delivery OTP, delivered, failed payment, refund.

10. Prove offline sync.
   - Test delivery status update while offline.
   - Test employee stock receive/damage while offline.
   - Test replay conflict where server data changed first.

### Phase 3: Metrics, Backup, and Release Readiness

11. Replace owner dashboard client metrics.
   - Create daily aggregate docs: revenue, order count, pending count, refunds, failed payments, stock alerts.
   - Update dashboard to read aggregate docs.

12. Verify backup and restore.
   - Confirm GCS bucket exists.
   - Confirm service account IAM.
   - Run one manual export.
   - Run one restore drill into a staging project.

13. Fix automated tests.
   - Initialize `TestWidgetsFlutterBinding` where needed.
   - Mock Firebase or run against Firebase Emulator Suite.
   - Add launch-flow integration tests for the 20 checklist items.

14. Add release gates.
   - CI must run format, analyze, unit tests, functions syntax check, Firestore rules tests, and Android build.
   - Block release if any critical launch flow fails.

## Extra Ideas Worth Adding

- Payment recovery screen for orders stuck in `pending` or `awaiting_verification`.
- Owner "launch health" dashboard showing payment webhook health, notification failures, backup status, and offline sync backlog.
- Customer reorder from past orders.
- Packing audio scan feedback and large-button mode for busy staff.
- Rider fallback assignment if no rider accepts within 60 seconds.
- Daily low-stock purchase-order generator.
- Crash/error monitoring dashboard with Sentry/Firebase Crashlytics.
- Staging environment with separate Firebase project, Razorpay test keys, and WhatsApp sandbox.

## Verification Commands Tried

- `node --check functions/index.js`: passed.
- Targeted Flutter tests: failed. Main causes were missing Firebase initialization in provider tests, missing Flutter test binding for cart persistence tests, and one coupon expectation failure.
- Full `flutter analyze` / `flutter test`: timed out in this workspace before producing actionable results.
