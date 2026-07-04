# Phase H: Supabase Edge Functions Migration

**Status**: Complete (Migration to Supabase Edge Functions)
**Date Completed**: 2026-07-04
**Scope**: 6 order lifecycle handlers migrated from Firebase Cloud Functions to Supabase Edge Functions

---

## Overview

This migration moves all transactional backend logic from **Firebase Cloud Functions** (limited Spark plan) to **Supabase Edge Functions**, ensuring PostgreSQL remains the authoritative source of truth. Firestore continues as a read-only real-time sync layer updated via the existing `sync-to-firestore` Database Webhook.

---

## What Was Created

### Supabase Edge Function: `order-lifecycle`

**Location**: `supabase/functions/order-lifecycle/index.ts`

A single TypeScript Edge Function with 6 endpoints, all running on Deno runtime with direct PostgreSQL access:

#### Endpoints

1. **POST `/change-status`**
   - Enforces state machine matrix for order transitions
   - Restricts invalid status transitions
   - Generates OTP when status → `shipped`
   - Stores OTP hash in `order_otp_logs` table
   - Updates order status history
   - Returns: `{ success: true, orderId, newStatus }`

2. **POST `/dispatch-cluster`**
   - Assigns rider to multiple packed/retry_dispatch orders
   - Generates individual OTPs per order
   - Updates all orders to `shipped` status
   - Logs OTPs securely
   - Returns: `{ success: true, count, message }`

3. **POST `/verify-otp`**
   - Validates OTP hash against order
   - Enforces rider assignment check
   - Marks order as `delivered` on success
   - Logs cash collection for COD orders
   - Tracks delivery GPS coordinates
   - Returns: `{ success: true, orderId, message }`

4. **POST `/cancel-order`**
   - Reverses inventory reservations/sold quantities
   - Credits wallet balance on cancellation
   - Enforces role-based cancellation rules
   - Returns: `{ success: true, orderId, message }`

5. **POST `/fail-delivery`**
   - Records delivery failure with GPS coordinates
   - Transitions order to `failed_delivery` status
   - Logs exception reason
   - Returns: `{ success: true, orderId, message }`

6. **POST `/resolve-exception`**
   - Routes failed deliveries to: `retry_dispatch`, `returned`, or `refunded`
   - Only accessible to owner/admin
   - Returns: `{ success: true, orderId, newStatus, message }`

---

## What Was Changed

### 1. **Flutter Services** — Migrated to Supabase Functions

#### `lib/services/order_service.dart`

- **Removed**: `import 'package:cloud_functions/cloud_functions.dart'`
- **Added**: `import 'package:supabase_flutter/supabase_flutter.dart'` + `SupabaseConfig`

**Updated Methods**:
- `createOrder()`: `processCheckout` → Supabase Edge Function (future phase)
- `updateOrderStatus()`: `changeOrderStatus` → `order-lifecycle /change-status`
- `failOrderDelivery()`: `failOrderDelivery` → `order-lifecycle /fail-delivery`
- `resolveDeliveryException()`: `resolveDeliveryException` → `order-lifecycle /resolve-exception`

**Call Pattern**:
```dart
final response = await SupabaseConfig.client.functions.invoke(
  'order-lifecycle',
  method: HttpMethod.post,
  body: {
    'path': '/change-status',
    'orderId': orderId,
    'targetStatus': backendStatus,
    'note': note,
  },
);
```

#### `lib/services/delivery_verification_service.dart`

- **Removed**: `import 'package:cloud_functions/cloud_functions.dart'`
- **Added**: `import 'package:supabase_flutter/supabase_flutter.dart'` + `SupabaseConfig`

**Updated Methods**:
- `verifyDeliveryOTP()`: `verifyDeliveryOtp` → `order-lifecycle /verify-otp`

---

## What Needs to Be Deleted

Delete these Firebase Cloud Functions from `functions/src/`:

```
functions/src/changeOrderStatus.js          ✓ Migrated
functions/src/dispatchCluster.js            ✓ Migrated
functions/src/verifyDeliveryOtp.js          ✓ Migrated
functions/src/cancelOrder.js                ✓ Migrated
functions/src/failOrderDelivery.js          ✓ Migrated
functions/src/resolveDeliveryException.js   ✓ Migrated
```

**Keep (for now)**:
- `onOrderUpdated.js` — Triggers downstream sync
- `processCheckout.js` — Still needed until Phase H.2
- `verifyStaffCredentials.js` — Auth support function
- `releaseExpiredReservations.js` — Scheduled cleanup

**Note**: Can only delete from Windows terminal or via git commands (sandbox has no write perms). Use:
```bash
rm functions/src/{changeOrderStatus,dispatchCluster,verifyDeliveryOtp,cancelOrder,failOrderDelivery,resolveDeliveryException}.js
```

---

## Database Schema Requirements

Ensure these PostgreSQL tables exist in Supabase:

```sql
-- Orders table (existing, extended with new columns)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS otp_hash TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS otp_verified BOOLEAN DEFAULT false;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_agent_id TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_agent_name TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_agent_phone TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipped_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS packer_id TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS packer_name TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS packing_started_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS failure_reason TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS failure_latitude FLOAT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS failure_longitude FLOAT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS failure_timestamp TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS exception_resolution TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS resolution_notes TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cash_collected_amount NUMERIC;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cash_collected_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS status_history JSONB;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_verification JSONB;

-- OTP logs table (new)
CREATE TABLE IF NOT EXISTS order_otp_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id TEXT NOT NULL,
  otp_value TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (order_id) REFERENCES orders(id)
);

-- Delivery logs table (new)
CREATE TABLE IF NOT EXISTS delivery_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id TEXT NOT NULL,
  type TEXT NOT NULL, -- 'otp_verification_failed', 'otp_verification_success'
  actor_id TEXT,
  provided_otp TEXT,
  timestamp TIMESTAMP DEFAULT NOW(),
  latitude FLOAT,
  longitude FLOAT,
  FOREIGN KEY (order_id) REFERENCES orders(id)
);

-- Cash collection logs table (new)
CREATE TABLE IF NOT EXISTS cash_collection_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  collected_by TEXT,
  collected_at TIMESTAMP DEFAULT NOW(),
  status TEXT DEFAULT 'collected',
  FOREIGN KEY (order_id) REFERENCES orders(id)
);
```

---

## Authentication

The Edge Function validates requests using JWT from Authorization header:

```
Authorization: Bearer <JWT_TOKEN>
```

The JWT payload must contain `sub` (user ID). The function:
1. Extracts user ID from JWT
2. Fetches user record from PostgreSQL `users` table
3. Validates `role` and `is_active` status
4. Enforces role-based permissions per endpoint

---

## Testing Checklist

### 1. **Local Testing** (before deployment)

```bash
# Test /change-status
curl -X POST http://localhost:54321/functions/v1/order-lifecycle \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "path": "/change-status",
    "orderId": "test-123",
    "targetStatus": "shipped",
    "note": "Manual test"
  }'

# Test /verify-otp
curl -X POST http://localhost:54321/functions/v1/order-lifecycle \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "path": "/verify-otp",
    "orderId": "test-123",
    "otp": "1234",
    "latitude": 28.6139,
    "longitude": 77.2090
  }'
```

### 2. **Integration Tests** (post-deployment)

- [ ] Order status transition via app → PostgreSQL updated
- [ ] OTP generation on shipped → `order_otp_logs` populated
- [ ] OTP verification → order marked delivered, Firestore synced downstream
- [ ] Delivery failure → order status = `failed_delivery`, exception logged
- [ ] Exception resolution (retry/return/refund) → order routed correctly
- [ ] Inventory reversal on cancellation → product stock updated
- [ ] Wallet credit reversal on cancellation → wallet balance updated
- [ ] Cash collection for COD → `cash_collection_logs` entry created

### 3. **Firestore Sync Verification**

Confirm the existing `sync-to-firestore` Database Webhook is active and:
- Listens to PostgreSQL `orders` table changes
- Syncs updates to Firestore `orders` collection in real-time

**Webhook Status**:
Navigate to Supabase Dashboard → Database → Webhooks and verify:
```
✓ Event: INSERT, UPDATE
✓ Table: orders
✓ Webhook URL: <your_sync_endpoint>
✓ Status: Enabled
```

---

## Deployment Steps

### Step 1: Deploy Supabase Edge Function

```bash
# From repo root
supabase functions deploy order-lifecycle

# Or via Supabase CLI:
supabase functions deploy order-lifecycle --project-id YOUR_PROJECT_ID
```

### Step 2: Update Flutter App

- Pull latest code with updated `order_service.dart` and `delivery_verification_service.dart`
- Build and deploy APK to TestFlight/Play Store internal testing

### Step 3: Monitor & Verify

- Watch Supabase Logs (Dashboard → Logs) for Edge Function execution
- Verify PostgreSQL writes via Supabase Studio
- Confirm Firestore syncs happen within ~2 seconds

### Step 4: Delete Firebase Functions (optional, when confident)

Once migration is stable (24+ hours), delete old Firebase Cloud Functions:

```bash
# From functions/ directory
rm src/{changeOrderStatus,dispatchCluster,verifyDeliveryOtp,cancelOrder,failOrderDelivery,resolveDeliveryException}.js

# Deploy Firebase (clean deployment)
firebase deploy --only functions
```

---

## Fallback / Rollback Plan

If critical issues arise:

1. **Revert Flutter Code**:
   ```dart
   // Revert order_service.dart and delivery_verification_service.dart to use 
   // cloud_functions package instead of supabase_flutter
   ```

2. **Restore Firebase Functions**:
   ```bash
   git checkout functions/src/*.js
   firebase deploy --only functions
   ```

3. **Keep Supabase Edge Function Disabled**:
   Delete the `supabase/functions/order-lifecycle/` directory.

---

## Future Phases

**Phase H.2**: Migrate remaining Firebase Cloud Functions to Supabase:
- `processCheckout` → order-lifecycle `/process-checkout`
- `onOrderUpdated` → Supabase RLS policies + triggers
- `releaseExpiredReservations` → Supabase pg_cron job

---

## Key Differences: Firebase vs Supabase Edge Functions

| Aspect | Firebase Cloud Functions | Supabase Edge Functions |
|--------|--------------------------|-------------------------|
| Runtime | Node.js 18 | Deno (TypeScript/JavaScript) |
| Cost (Spark) | Limited | Unlimited invocations |
| Latency | ~500ms cold start | ~100ms cold start |
| Direct DB Access | Firestore only | PostgreSQL native |
| Concurrency | Rate limited | No limits |
| Region | Single (us-central1) | Global CDN |

---

## Notes for Future Maintainers

1. **OTP Storage**: OTPs are stored as SHA256 hashes in `order_otp_logs` to prevent plaintext exposure. The hash is `SHA256(otp + orderId)`.

2. **State Machine**: The matrix is enforced in TypeScript. Modify `VALID_TRANSITIONS` to change allowed state transitions.

3. **Role-Based Access**: Each endpoint validates user role against specific requirements (e.g., only owner/admin can resolve exceptions).

4. **Firestore Sync**: This migration does NOT change how Firestore is updated. The existing webhook handles downstream syncing automatically.

---

## Questions / Issues

- Edge Function won't start → Check Deno import URLs are accessible from Supabase runtime
- OTP verification fails → Verify JWT is valid and user record exists in PostgreSQL
- Orders not syncing to Firestore → Check Database Webhook is enabled and active

---

**Migration completed by Claude Agent** — 2026-07-04
**Next Action**: Delete Firebase functions from `functions/src/` and test end-to-end.
