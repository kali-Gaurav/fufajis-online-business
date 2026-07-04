# SECURITY HARDENING — BLOCK 2 VERIFICATION

**Status:** MANDATORY for production  
**Target Score:** 100/100  
**Current Assessment:** 80/100

---

## S1: Edge Functions Authentication

### ✅ Checklist

- [ ] **create-product** requires Firebase JWT
  ```typescript
  const authHeader = req.headers.get("Authorization");
  const token = authHeader?.replace("Bearer ", "");
  const { data: { user } } = await supabase.auth.getUser(token);
  if (!user) return 401;
  ```

- [ ] **bulk-import-products** requires Firebase JWT
  ```typescript
  // Same JWT verification as create-product
  ```

- [ ] Role check: Only `admin` or `super_admin`
  ```typescript
  const { data: profile } = await supabase
    .from("user_profiles")
    .select("role")
    .eq("user_id", user.id)
    .single();

  if (!["admin", "super_admin"].includes(profile?.role)) {
    return 403; // Forbidden
  }
  ```

- [ ] Request validation (no empty fields)
  ```typescript
  if (!body.name || !body.productCode) {
    return 400; // Bad Request
  }
  ```

- [ ] Rate limiting (optional but recommended)
  ```typescript
  // Limit: 10 products/minute per user
  // Implement via Supabase middleware
  ```

---

## S2: Supabase RLS (Row Level Security)

### ✅ Products Table Policy

```sql
-- PUBLIC: Can only READ active products
CREATE POLICY "public_read_active_products"
  ON catalog_products FOR SELECT
  USING (is_active = TRUE AND is_deleted = FALSE);

-- ADMIN: Can do all operations
CREATE POLICY "admin_all_products"
  ON catalog_products FOR ALL
  USING (auth.jwt() ->> 'role' = 'admin'
    OR auth.jwt() ->> 'role' = 'super_admin')
  WITH CHECK (auth.jwt() ->> 'role' = 'admin'
    OR auth.jwt() ->> 'role' = 'super_admin');

-- SERVICE ROLE: Full access (backend only)
-- (automatically granted)
```

### ✅ Variants Table Policy

```sql
-- PUBLIC: Can only READ active variants
CREATE POLICY "public_read_active_variants"
  ON catalog_variants FOR SELECT
  USING (is_active = TRUE);

-- ADMIN: Can do all operations
CREATE POLICY "admin_all_variants"
  ON catalog_variants FOR ALL
  USING (auth.jwt() ->> 'role' = 'admin'
    OR auth.jwt() ->> 'role' = 'super_admin')
  WITH CHECK (auth.jwt() ->> 'role' = 'admin'
    OR auth.jwt() ->> 'role' = 'super_admin');
```

### ✅ Inventory Table Policy

```sql
-- PUBLIC: Can only READ inventory
CREATE POLICY "public_read_inventory"
  ON shop_inventory FOR SELECT
  USING (TRUE);

-- ADMIN: Can UPDATE only (for stock management)
CREATE POLICY "admin_update_inventory"
  ON shop_inventory FOR UPDATE
  USING (auth.jwt() ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() ->> 'role' = 'admin');
```

### ✅ Verification Commands

```bash
# 1. Test as anonymous user
curl -H "Authorization: Bearer anon_key" \
  https://your-supabase.com/rest/v1/catalog_products \
  -H "Content-Type: application/json" \
  -d '{"name": "Hack", "category_id": "x"}'
# Expected: 403 Forbidden

# 2. Test as customer (user role)
curl -H "Authorization: Bearer customer_jwt" \
  https://your-supabase.com/rest/v1/catalog_products \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"name": "Hack"}'
# Expected: 403 Forbidden (not admin)

# 3. Test as admin
curl -H "Authorization: Bearer admin_jwt" \
  https://your-supabase.com/rest/v1/catalog_products \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{...valid product...}'
# Expected: 201 Created
```

---

## S3: API Keys & Secrets Management

### ✅ Required Secrets (Environment Variables)

```bash
# .env.local (NEVER commit)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...  # Safe - public
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...  # SECRET - backend only
FIREBASE_API_KEY=AIzaSyC...  # Safe - public
FIREBASE_ADMIN_CREDENTIALS={...}  # SECRET - backend only
RAZORPAY_KEY_ID=rzp_live_...  # SECRET
RAZORPAY_KEY_SECRET=...  # ULTRA SECRET
```

### ✅ Secret Storage

**Frontend (Flutter App):**
```dart
// ❌ NEVER do this
const API_KEY = "AIzaSyC...";  // Exposed in APK

// ✅ DO THIS: Request from backend
final key = await getApiKey(); // Backend returns safe key
```

**Backend (Supabase Edge Functions):**
```typescript
// ✅ Use Deno.env (runtime injection)
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const FIREBASE_ADMIN = Deno.env.get("FIREBASE_ADMIN_CREDENTIALS");

// ❌ NEVER hardcode
const KEY = "eyJhbGc...";  // Exposed in source
```

### ✅ Verification Checklist

- [ ] No secrets in `.env.example` (only templates)
- [ ] `.env.local` is in `.gitignore`
- [ ] No API keys in source code (grep check)
- [ ] Supabase service role only used server-side
- [ ] Firebase admin SDK only in backend
- [ ] Razorpay keys rotated every 90 days

**Audit Commands:**
```bash
# 1. Search for hardcoded secrets
grep -r "AIza\|rzp_live\|eyJhbGc" --include="*.dart" --include="*.ts" .

# 2. Check git history
git log -p | grep -i "api_key\|secret\|password"

# 3. Verify .gitignore
cat .gitignore | grep ".env"
```

---

## S4: Firebase JWT Verification

### ✅ In Edge Functions

```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

async function verifyFirebaseJWT(token: string) {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // Method 1: Supabase JWT verification
  const { data: { user }, error } = await supabase.auth.getUser(token);
  
  if (error || !user) {
    throw new Error("Invalid JWT");
  }

  // Method 2: Manual JWT verification (if needed)
  // const decoded = jwt.verify(token, FIREBASE_PUBLIC_KEY);
  // if (!decoded.aud.includes(FIREBASE_PROJECT_ID)) {
  //   throw new Error("Wrong Firebase project");
  // }

  return user;
}
```

### ✅ Verification

- [ ] JWT is verified on every API call
- [ ] JWT expiration checked
- [ ] Wrong Firebase project rejected
- [ ] Invalid signatures rejected

---

## S5: SQL Injection Prevention

### ✅ Use Parameterized Queries

**❌ VULNERABLE:**
```typescript
const query = `SELECT * FROM products WHERE name = '${userInput}'`;
const { data } = await supabase.rpc('raw_query', { sql: query });
```

**✅ SAFE:**
```typescript
const { data } = await supabase
  .from('catalog_products')
  .select()
  .eq('name', userInput);  // Parameterized
```

### ✅ Checklist

- [ ] No raw SQL queries in Edge Functions
- [ ] All user input goes through `.eq()`, `.like()`, `.ilike()` (Supabase filters)
- [ ] No string concatenation in queries

---

## S6: CORS & CSRF Protection

### ✅ CORS Configuration

```typescript
// Restrict to specific origins
const ALLOWED_ORIGINS = [
  'https://fufaji.com',
  'https://app.fufaji.com',
  'http://localhost:3000', // Dev only
];

if (!ALLOWED_ORIGINS.includes(req.headers.get('origin'))) {
  return new Response('CORS not allowed', { status: 403 });
}
```

### ✅ CSRF Token

```typescript
// For state-changing operations (POST/PUT/DELETE)
// Require CSRF token from frontend
const csrfToken = req.headers.get('x-csrf-token');
if (!csrfToken || !verifyCSRFToken(csrfToken)) {
  return new Response('Invalid CSRF token', { status: 403 });
}
```

### ✅ Checklist

- [ ] CORS headers set correctly
- [ ] Only `POST`, `PUT`, `DELETE` allowed for mutations
- [ ] CSRF tokens validated
- [ ] No credentials in cookie (use Bearer token instead)

---

## S7: Rate Limiting

### ✅ Edge Function Rate Limiting

```typescript
// Per-user rate limit: 10 requests/minute
async function checkRateLimit(userId: string) {
  const key = `rate_limit:${userId}`;
  const count = await redis.incr(key);
  
  if (count === 1) {
    await redis.expire(key, 60); // 60 second window
  }
  
  if (count > 10) {
    return { allowed: false, retryAfter: 60 };
  }
  
  return { allowed: true };
}

// In handler
const rateLimit = await checkRateLimit(user.id);
if (!rateLimit.allowed) {
  return new Response('Too many requests', {
    status: 429,
    headers: { 'Retry-After': rateLimit.retryAfter.toString() },
  });
}
```

### ✅ Checklist

- [ ] Product creation rate limited (10/minute per user)
- [ ] Bulk import rate limited (1/minute per user)
- [ ] Search queries rate limited (100/minute per user)
- [ ] 429 response returned on limit exceeded

---

## S8: Input Validation

### ✅ Product Creation Validation

```typescript
interface ProductRequest {
  name: string;
  hindiName: string;
  productCode: string;
  categoryId: string;
  unitType: 'weight' | 'volume' | 'count';
  unit: string;
  quantity: number;
  mrp: number;
  sellingPrice: number;
  gst?: number;
}

function validateProductRequest(body: any): ProductRequest {
  // Check required fields
  if (!body.name || typeof body.name !== 'string') {
    throw new Error('Invalid name');
  }
  if (!body.productCode || !/^[A-Z0-9_]{3,20}$/.test(body.productCode)) {
    throw new Error('Invalid productCode format');
  }

  // Check numeric ranges
  if (body.mrp <= 0 || body.sellingPrice <= 0) {
    throw new Error('Price must be > 0');
  }
  if (body.sellingPrice > body.mrp) {
    throw new Error('Selling price cannot exceed MRP');
  }

  // Check gst
  if (body.gst && (body.gst < 0 || body.gst > 28)) {
    throw new Error('GST must be 0-28');
  }

  return body as ProductRequest;
}
```

### ✅ Checklist

- [ ] All numeric inputs validated (range checks)
- [ ] String inputs validated (length, charset)
- [ ] Enum inputs validated (allowed values only)
- [ ] Business logic validated (e.g., sellingPrice <= MRP)
- [ ] No null/undefined values accepted

---

## S9: Audit Logging

### ✅ Log All Admin Actions

```sql
CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  action VARCHAR(50),
  table_name VARCHAR(50),
  record_id UUID,
  old_values JSONB,
  new_values JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Trigger on product updates
CREATE TRIGGER audit_product_changes
  AFTER INSERT, UPDATE, DELETE ON catalog_products
  FOR EACH ROW
  EXECUTE FUNCTION audit_trigger();
```

### ✅ Log entries for:
- [ ] Product created
- [ ] Product updated (field changes)
- [ ] Product deleted
- [ ] Bulk import executed
- [ ] Admin role granted/revoked

---

## S10: Deployment Verification

### ✅ Pre-deployment Checklist

```bash
# 1. Scan for secrets
npm run audit:secrets

# 2. Security linter
npm run lint:security

# 3. Dependency vulnerabilities
npm audit

# 4. RLS policies activated
supabase db check-rls

# 5. All Edge Functions have auth
grep -r "verifyAuth\|requireAdmin" functions/

# 6. No console.log of sensitive data
grep -r "console.log.*token\|console.log.*password" --include="*.ts"
```

### ✅ Post-deployment

- [ ] Test as anonymous user (should get 403 on mutations)
- [ ] Test as customer user (should get 403 on product writes)
- [ ] Test as admin (should succeed)
- [ ] Verify logs don't contain JWTs
- [ ] Monitor error rates for 429 responses

---

## SECURITY SCORE CARD

| Area | Check | Status | Score |
|------|-------|--------|-------|
| JWT Auth | Edge functions verify JWT | ⏳ TODO | 0/10 |
| RLS Policies | Products table RLS enforced | ⏳ TODO | 0/10 |
| Secrets | No hardcoded keys in code | ⏳ TODO | 0/10 |
| SQL Injection | All queries parameterized | ⏳ TODO | 0/10 |
| CORS | CORS headers set correctly | ⏳ TODO | 0/10 |
| Rate Limiting | Per-user rate limits active | ⏳ TODO | 0/10 |
| Input Validation | All inputs validated | ⏳ TODO | 0/10 |
| Audit Logging | Admin actions logged | ⏳ TODO | 0/10 |
| Deployment | Pre/post checks passed | ⏳ TODO | 0/10 |
| Response Codes | 401/403/429 returned correctly | ⏳ TODO | 0/10 |
| **TOTAL** | | **⏳ 0/100** | |

---

## IMMEDIATE ACTIONS (TODAY)

```bash
# 1. Verify RLS policies in Supabase console
# 2. Test authentication on all Edge Functions
# 3. Run secret scan
# 4. Deploy audit logging
# 5. Re-run security score
```

**Pass criteria:** 100/100 (no exceptions)

---

## CONTINUE TO BLOCK 3 WHEN: Security score = 100/100
