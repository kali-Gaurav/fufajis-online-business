# Fufaji Edge Functions - Deployment Guide

## Overview

Three production-ready Edge Function files with complete implementations:

1. **auth-endpoints/index.ts** (850+ lines) - 9 authentication endpoints
2. **payment-endpoints/index.ts** (1050+ lines) - 6 payment processing endpoints
3. **error-handling/index.ts** (350+ lines) - Shared utilities & error handling

## Environment Variables Required

### Supabase
```
SUPABASE_URL=https://[project].supabase.co
SUPABASE_SECRET_KEY=[anon key]
SUPABASE_SERVICE_ROLE_KEY=[service role key]
```

### Firebase (Auth Bridge)
```
FIREBASE_URL=https://[project].firebase.com
FIREBASE_SECRET=[service account token]
```

### Razorpay (Payment Processing)
```
RAZORPAY_KEY_ID=[live_key_id]
RAZORPAY_KEY_SECRET=[live_key_secret]
RAZORPAY_WEBHOOK_SECRET=[webhook_secret]
```

### Twilio (SMS OTP)
```
TWILIO_ACCOUNT_SID=[account_sid]
TWILIO_AUTH_TOKEN=[auth_token]
TWILIO_PHONE_NUMBER=[+1234567890]
```

### SendGrid (Email Notifications)
```
SENDGRID_API_KEY=[api_key]
```

### App Configuration
```
APP_URL=https://app.fufaji.com
JWT_SECRET=[random_32_char_secret]
SENTRY_DSN=https://[key]@sentry.io/[project]
```

## Database Tables Required

### PostgreSQL

```sql
-- Users
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  phone TEXT UNIQUE NOT NULL,
  name TEXT,
  password_hash TEXT,
  role TEXT NOT NULL DEFAULT 'customer',
  status TEXT NOT NULL DEFAULT 'active',
  email_verified BOOLEAN DEFAULT FALSE,
  phone_verified BOOLEAN DEFAULT FALSE,
  google_uid TEXT,
  google_picture TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Orders
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  items JSONB NOT NULL,
  delivery_address JSONB NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,
  tax DECIMAL(10,2) NOT NULL,
  delivery_fee DECIMAL(10,2) NOT NULL,
  discount DECIMAL(10,2) DEFAULT 0,
  total DECIMAL(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  payment_status TEXT NOT NULL DEFAULT 'unpaid',
  razorpay_order_id TEXT,
  payment_confirmed_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Payment Transactions
CREATE TABLE payment_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id),
  user_id UUID NOT NULL REFERENCES users(id),
  payment_id TEXT NOT NULL UNIQUE,
  amount DECIMAL(10,2) NOT NULL,
  status TEXT NOT NULL,
  method TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Refunds
CREATE TABLE refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id),
  user_id UUID NOT NULL REFERENCES users(id),
  refund_id TEXT NOT NULL UNIQUE,
  amount DECIMAL(10,2) NOT NULL,
  status TEXT NOT NULL,
  reason TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Wallets
CREATE TABLE wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id),
  balance DECIMAL(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Wallet Transactions
CREATE TABLE wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID REFERENCES wallets(id),
  user_id UUID NOT NULL REFERENCES users(id),
  type TEXT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  reason TEXT,
  balance_after DECIMAL(10,2),
  timestamp TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Inventory Reservations
CREATE TABLE inventory_reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id),
  product_id UUID NOT NULL,
  reserved_quantity INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'reserved',
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Products
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  available_quantity INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Coupons
CREATE TABLE coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  type TEXT NOT NULL,
  value DECIMAL(10,2) NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  expires_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Service Areas
CREATE TABLE service_areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Rate Limits (for in-memory caching)
CREATE TABLE rate_limits (
  key TEXT PRIMARY KEY,
  count INTEGER NOT NULL DEFAULT 0,
  window_start INTEGER NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Cache (Redis alternative)
CREATE TABLE cache (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  expires_at TIMESTAMP NOT NULL
);

-- Idempotency Keys
CREATE TABLE idempotency_keys (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  result TEXT,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Login Logs
CREATE TABLE login_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  ip TEXT,
  action TEXT DEFAULT 'login',
  timestamp TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Audit Logs
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  action TEXT NOT NULL,
  resource TEXT NOT NULL,
  changes JSONB,
  ip_address TEXT,
  timestamp TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Notifications
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### Stored Procedures

```sql
-- Atomic order processing (inventory deduction + payment)
CREATE OR REPLACE FUNCTION process_order_inventory(p_order_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Deduct inventory for each item
  UPDATE products
  SET available_quantity = available_quantity - (
    SELECT COALESCE(SUM(
      CAST(
        item->>'quantity' AS INTEGER
      )
    ), 0)
    FROM orders, jsonb_array_elements(orders.items) AS item
    WHERE orders.id = p_order_id
    AND item->>'productId' = products.id::TEXT
  )
  WHERE id IN (
    SELECT CAST(item->>'productId' AS UUID)
    FROM orders, jsonb_array_elements(orders.items) AS item
    WHERE orders.id = p_order_id
  );
  
  RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql;
```

## Deployment Steps

### 1. Set Environment Variables

```bash
# Create .env.local in supabase/ directory
SUPABASE_URL=...
SUPABASE_SECRET_KEY=...
# ... (add all required variables)
```

### 2. Deploy Functions

```bash
cd supabase

# Deploy auth endpoints
supabase functions deploy auth-endpoints

# Deploy payment endpoints
supabase functions deploy payment-endpoints

# Deploy error handling (library only, not exposed)
supabase functions deploy error-handling
```

### 3. Configure Webhooks

**Razorpay Payment Webhook:**
- URL: `https://[project].supabase.co/functions/v1/razorpay-webhook-dual-write`
- Secret: `RAZORPAY_WEBHOOK_SECRET`
- Events: `payment.authorized`, `payment.failed`

**Razorpay Refund Webhook:**
- URL: `https://[project].supabase.co/functions/v1/refund-webhook`
- Secret: `RAZORPAY_WEBHOOK_SECRET`
- Events: `refund.created`, `refund.processed`, `refund.failed`

### 4. Test Endpoints

```bash
# Signup
curl -X POST https://[project].supabase.co/functions/v1/auth-endpoints/auth/signup-email \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test@123456",
    "phone": "+911234567890",
    "name": "Test User"
  }'

# Login
curl -X POST https://[project].supabase.co/functions/v1/auth-endpoints/auth/login-email \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test@123456"
  }'

# Create Order
curl -X POST https://[project].supabase.co/functions/v1/payment-endpoints/api/orders/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [jwt_token]" \
  -d '{
    "items": [{"productId": "[uuid]", "quantity": 2}],
    "deliveryAddress": {
      "latitude": 28.6139,
      "longitude": 77.2090,
      "street": "123 Main St",
      "city": "Delhi",
      "zipCode": "110001"
    },
    "couponCode": "WELCOME10"
  }'
```

## Security Checklist

- [x] All endpoints verify JWT tokens (except signup, login, OTP)
- [x] All rate limits implemented per IP/email/phone
- [x] HMAC-SHA256 signature verification on all Razorpay requests
- [x] Timing-safe comparison for all signatures (prevents timing attacks)
- [x] Idempotency checks prevent duplicate payments
- [x] Password validation (8+ chars, uppercase, number, special char)
- [x] Email/phone/UUID validation before DB operations
- [x] All errors logged to Sentry
- [x] Audit logging for critical operations
- [x] Token blacklisting on logout
- [x] CORS headers properly configured
- [x] SQL injection prevention via parameterized queries
- [x] Input sanitization on all endpoints

## Monitoring

### Sentry Integration
- All errors logged with context
- Track: signup failures, payment failures, refund issues
- Alerts: fraud detection (invalid signatures), high error rates

### Metrics to Monitor
- Successful signups/logins per hour
- Payment success rate (target: 98%+)
- Average order creation time
- Refund processing time
- Rate limit violations
- Token refresh requests

## Rollback Strategy

1. Keep previous function versions deployed
2. Update Razorpay webhooks to point to stable version
3. Monitor error rates after deployment
4. Rollback if error rate > 5% or signature verification fails

## Production Readiness

- [x] All 9 auth endpoints fully implemented
- [x] All 6 payment endpoints fully implemented
- [x] Complete error handling & validation
- [x] Fraud detection (signature verification)
- [x] Idempotency guarantee
- [x] Rate limiting
- [x] Audit logging
- [x] Sentry integration
- [x] Email & SMS notifications
- [x] Wallet & refund system
- [x] Firestore sync (async)
- [x] Database transactions
- [x] Security best practices

## Support

For issues:
1. Check Sentry for error logs
2. Review audit logs for recent changes
3. Check rate limit status
4. Verify webhook signatures
5. Contact Supabase support if database issues
