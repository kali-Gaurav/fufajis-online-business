# Fufaji Edge Functions API Reference

## Base URL
```
https://[PROJECT_ID].supabase.co/functions/v1
```

---

## Authentication Endpoints

### 1. Signup with Email
```
POST /auth-endpoints/auth/signup-email
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePass@123",
  "phone": "+919876543210",
  "name": "John Doe"
}

Response 201:
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "phone": "+919876543210",
      "name": "John Doe",
      "role": "customer"
    },
    "token": "eyJhbGc..."
  }
}

Error 400: Email already registered, weak password
Error 429: Rate limited (5 signups/hour per IP)
```

### 2. Login with Email
```
POST /auth-endpoints/auth/login-email
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePass@123"
}

Response 200:
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "phone": "+919876543210",
      "role": "customer"
    },
    "token": "eyJhbGc..."
  }
}

Error 401: Invalid credentials
Error 403: Account suspended
Error 429: Rate limited (10 attempts/hour per IP)
```

### 3. Request Phone OTP
```
POST /auth-endpoints/auth/phone-otp/request
Content-Type: application/json

{
  "phone": "+919876543210"
}

Response 200:
{
  "success": true,
  "data": {
    "message": "OTP sent successfully",
    "phone": "****3210"
  }
}

Error 400: Invalid phone format
Error 429: Rate limited (3 requests/hour per phone)
```

### 4. Verify Phone OTP
```
POST /auth-endpoints/auth/phone-otp/verify
Content-Type: application/json

{
  "phone": "+919876543210",
  "otp": "123456",
  "name": "John Doe" (optional)
}

Response 200:
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "phone_9876543210@fufaji.temp",
      "phone": "+919876543210",
      "role": "customer"
    },
    "token": "eyJhbGc..."
  }
}

Error 401: Invalid or expired OTP
```

### 5. Google Sign-In
```
POST /auth-endpoints/auth/google-signin
Content-Type: application/json
Authorization: Bearer [google_id_token]

{
  "idToken": "eyJhbGciOiJSUzI1NiIs..."
}

Response 200:
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@gmail.com",
      "name": "John Doe",
      "role": "customer"
    },
    "token": "eyJhbGc..."
  }
}

Error 401: Invalid Google token
Error 400: Email required from Google account
```

### 6. Logout
```
POST /auth-endpoints/auth/logout
Authorization: Bearer [jwt_token]

Response 200:
{
  "success": true,
  "data": {
    "message": "Logged out successfully"
  }
}

Error 401: Unauthorized (no token)
```

### 7. Request Password Reset
```
POST /auth-endpoints/auth/password-reset/request
Content-Type: application/json

{
  "email": "user@example.com"
}

Response 200:
{
  "success": true,
  "data": {
    "message": "If email exists, reset link sent"
  }
}

Note: Returns same message regardless of email existence (security)
Error 429: Rate limited (3 requests/hour per email)
```

### 8. Verify Password Reset
```
POST /auth-endpoints/auth/password-reset/verify
Content-Type: application/json

{
  "token": "abc123def456...",
  "newPassword": "NewSecurePass@123"
}

Response 200:
{
  "success": true,
  "data": {
    "message": "Password reset successfully"
  }
}

Error 401: Invalid or expired reset token
Error 400: Weak password
```

### 9. Refresh Token
```
POST /auth-endpoints/auth/refresh-token
Content-Type: application/json

{
  "token": "eyJhbGc..." (current JWT)
}

Response 200:
{
  "success": true,
  "data": {
    "token": "eyJhbGc..." (new JWT),
    "expiresIn": 86400
  }
}

Error 401: Invalid, expired, or blacklisted token
```

---

## Payment Endpoints

### 1. Create Order
```
POST /payment-endpoints/api/orders/create
Authorization: Bearer [jwt_token]
Content-Type: application/json

{
  "items": [
    {
      "productId": "uuid",
      "quantity": 2
    }
  ],
  "deliveryAddress": {
    "latitude": 28.6139,
    "longitude": 77.2090,
    "street": "123 Main Street",
    "city": "Delhi",
    "zipCode": "110001"
  },
  "couponCode": "WELCOME10" (optional)
}

Response 201:
{
  "success": true,
  "data": {
    "order": {
      "id": "uuid",
      "total": 1299.50,
      "razorpayOrderId": "order_1234567890",
      "razorpayKey": "rzp_live_XXXXXXXXX"
    }
  }
}

Error 401: Unauthorized
Error 400: Invalid address, invalid items
Error 409: Item out of stock
```

### 2. Verify Payment
```
POST /payment-endpoints/api/payments/verify
Authorization: Bearer [jwt_token]
Content-Type: application/json

{
  "orderId": "uuid",
  "paymentId": "pay_1234567890",
  "signature": "abc123def456..."
}

Response 200:
{
  "success": true,
  "data": {
    "message": "Payment verified successfully",
    "order": {
      "id": "uuid",
      "status": "confirmed",
      "paymentStatus": "completed"
    }
  }
}

Error 401: Fraud detected (invalid signature)
Error 404: Order not found
Error 409: Payment already processed
```

### 3. Razorpay Payment Webhook
```
POST /payment-endpoints/functions/razorpay-webhook-dual-write
X-Razorpay-Signature: [signature]
Content-Type: application/json

{
  "event": "payment.authorized",
  "payload": {
    "payment": {
      "id": "pay_1234567890"
    },
    "order": {
      "receipt": "order_uuid"
    }
  }
}

Response 200:
{
  "ok": true
}

Note: Always returns 200 OK for webhook compatibility
```

### 4. Create Refund
```
POST /payment-endpoints/api/refunds/create
Authorization: Bearer [jwt_token]
Content-Type: application/json

{
  "orderId": "uuid",
  "amount": 500.00
}

Response 201:
{
  "success": true,
  "data": {
    "refund": {
      "id": "uuid",
      "orderId": "uuid",
      "amount": 500.00,
      "status": "processing"
    }
  }
}

Error 401: Unauthorized
Error 404: Order not found
Error 400: Order not paid, refund window expired
```

### 5. Refund Webhook
```
POST /payment-endpoints/functions/refund-webhook
X-Razorpay-Signature: [signature]
Content-Type: application/json

{
  "event": "refund.processed",
  "payload": {
    "refund": {
      "id": "rfnd_1234567890"
    }
  }
}

Response 200:
{
  "ok": true
}

Note: Always returns 200 OK for webhook compatibility
```

---

## Error Responses

All errors follow this format:
```json
{
  "success": false,
  "error": "Human-readable error message",
  "code": "ERROR_CODE"
}
```

### Common Error Codes
- `UNAUTHORIZED` (401) - Missing or invalid JWT
- `VALIDATION_ERROR` (400) - Invalid input data
- `RATE_LIMITED` (429) - Too many requests
- `NOT_FOUND` (404) - Resource not found
- `CONFLICT` (409) - Duplicate resource
- `INVALID_CREDENTIALS` (401) - Wrong email/password
- `FRAUD_DETECTED` (401) - Invalid Razorpay signature
- `OUT_OF_STOCK` (409) - Item not available
- `DB_ERROR` (500) - Database operation failed
- `INTERNAL_ERROR` (500) - Unexpected server error

---

## Request/Response Headers

All requests should include:
```
Content-Type: application/json
Authorization: Bearer [jwt_token] (except signup, login, OTP request, Google signin)
```

All responses include:
```
Content-Type: application/json
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
```

---

## Authentication

After signup/login, use returned JWT in Authorization header:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

JWT Structure:
- Header: `{ "alg": "HS256", "typ": "JWT" }`
- Payload: `{ "sub": "user_id", "email": "...", "role": "customer", "iat": ..., "exp": ... }`
- Signature: HMAC-SHA256(header.payload, JWT_SECRET)

Token expiry: 24 hours
Refresh endpoint available to extend session

---

## Rate Limits

| Endpoint | Limit | Window |
|----------|-------|--------|
| Signup | 5 | Per hour per IP |
| Login | 10 | Per hour per IP |
| OTP Request | 3 | Per hour per phone |
| Password Reset Request | 3 | Per hour per email |
| All others | 100 | Per hour per user |

Responses include rate limit info in headers:
```
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 7
X-RateLimit-Reset: 1234567890
```

---

## Validation Rules

### Email
- Must be valid RFC 5322 format
- Max 254 characters
- Must be unique

### Password
- Minimum 8 characters
- Must contain uppercase letter (A-Z)
- Must contain lowercase letter (a-z)
- Must contain number (0-9)
- Must contain special character (!@#$%^&*)

### Phone
- E.164 format: +[country code][number]
- Example: +919876543210
- Must be valid international format

### Delivery Address
- Latitude: -90 to 90
- Longitude: -180 to 180
- Street, city, zip code required

### Currency Amount
- Positive number
- Maximum 10,000,000 INR
- Proper decimal format

---

## Example Flows

### Complete Signup & Purchase Flow
```
1. POST /auth/signup-email
   → get JWT token

2. POST /api/orders/create
   → include JWT, get razorpay_order_id

3. POST /api/payments/verify (client verifies with Razorpay)
   → order status: "confirmed"

4. Webhook: /razorpay-webhook-dual-write
   → inventory deducted, notifications sent

5. POST /auth/logout
   → token blacklisted
```

### Phone OTP Flow
```
1. POST /auth/phone-otp/request
   → SMS sent with OTP

2. POST /auth/phone-otp/verify
   → get JWT token, user created if new

3. Can proceed with orders using JWT
```

### Refund Flow
```
1. POST /api/refunds/create
   → refund initiated with Razorpay

2. Webhook: /refund-webhook
   → refund.processed event updates status
   → wallet credited

3. User sees wallet balance increase
```

---

## Testing with cURL

### Signup
```bash
curl -X POST https://[project].supabase.co/functions/v1/auth-endpoints/auth/signup-email \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test@123456",
    "phone": "+919876543210",
    "name": "Test User"
  }'
```

### Create Order
```bash
curl -X POST https://[project].supabase.co/functions/v1/payment-endpoints/api/orders/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [jwt_token]" \
  -d '{
    "items": [{"productId": "[uuid]", "quantity": 1}],
    "deliveryAddress": {
      "latitude": 28.6139,
      "longitude": 77.2090,
      "street": "123 Main St",
      "city": "Delhi",
      "zipCode": "110001"
    }
  }'
```

---

## Monitoring & Debugging

### Sentry Integration
All errors automatically logged to Sentry with:
- Full error message & stack trace
- Request context (user, IP, headers)
- Custom tags (error code, status)
- Environment information

### Logs Location
- Cloud Function logs: Supabase dashboard
- Application errors: Sentry dashboard
- Database logs: PostgreSQL audit logs
- Webhook logs: Razorpay dashboard

### Common Issues
1. **Invalid signature**: Check RAZORPAY_KEY_SECRET matches webhook secret
2. **Rate limited**: Wait for window to reset or use different IP/email
3. **Payment not verifying**: Ensure signature includes order_id|payment_id format
4. **Token expired**: Use refresh endpoint to get new token
5. **Inventory mismatch**: Check product availability before order creation

---

## Support

For API issues:
1. Check error code & message
2. Verify all required fields in request
3. Check Sentry for detailed error logs
4. Review rate limit status
5. Verify JWT token validity & expiry
