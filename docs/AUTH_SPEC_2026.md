# Fufaji Authentication & Authorization Specification v2.0
**Status:** DESIGN PHASE  
**Date:** 2026-07-11  
**Audience:** Architects, Backend Engineers, Frontend Engineers

---

## 1. EXECUTIVE SUMMARY

Complete authentication & authorization overhaul with role-based hierarchical access control:

- **Customer**: Google Sign-In (anonymous/optional), no pre-registration
- **Owner**: Email/Password only (set by Admin), pre-registered by Admin
- **Employee**: Email/ID + Password (set by Owner), managed by Owner
- **Delivery Agent**: Email/ID + Password (set by Owner), managed by Owner
- **Supplier**: Email/ID + Password (set by Admin/Owner), managed by Admin or Owner
- **Admin**: Pre-authorized master account, manages all Owners and system

---

## 2. AUTHENTICATION FLOWS

### 2.1 Customer Login Flow
```
Customer App → Firebase Auth (Google Sign-In)
            → Backend verification
            → Supabase customers table check/create
            → Custom JWT token
            → Firestore user profile sync
```

**Key Points:**
- Google Sign-In optional (can use email/password for existing customers)
- Auto-create customer profile on first Google login
- No admin approval needed
- Immediate access to shop browsing

### 2.2 Owner Login Flow
```
Owner App → Email/ID + Password entry
         → Backend validation (Supabase query)
         → Verify password hash (bcrypt)
         → Check if owner_id matches shops table
         → Issue custom JWT token
         → Firestore owner profile sync
         → Load owned shops & inventory access
```

**Key Points:**
- Email/ID and Password stored in `operational_users` table (Supabase)
- Password must be hashed (bcrypt), NEVER plain text
- Cannot use Google Sign-In
- Must be pre-registered by Admin (cannot self-register)
- Access to own shop(s) only via RLS

### 2.3 Employee/Rider/Supplier Login Flow
```
Employee/Rider/Supplier App → ID/Email + Password entry
                           → Backend validation
                           → Verify against operational_users table
                           → Verify role matches (employee/rider/supplier)
                           → Check if assigned to owner
                           → Issue custom JWT token
                           → Firestore profile sync
                           → Load assigned owner's operations
```

**Key Points:**
- Similar to Owner but with owner_id verification
- Must be pre-registered by Owner
- Role-based access to operations (orders, deliveries, inventory)

### 2.4 Admin Login Flow
```
Admin App → Email/ID + Password entry
        → Backend validation
        → Query admin_accounts table
        → Verify password
        → Issue admin JWT token
        → Firestore admin profile sync
        → Load all system data
```

**Key Points:**
- Pre-authorized accounts only
- Access to all system data
- Can create/update Owner accounts
- Can audit all operations

---

## 3. DATABASE SCHEMA CHANGES

### 3.1 New Table: `operational_users`
Stores credentials for Owner, Employee, Delivery Agent, Supplier

```sql
CREATE TABLE operational_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Ownership & Role
  user_type TEXT NOT NULL CHECK (user_type IN ('owner', 'employee', 'rider', 'supplier')),
  owner_id UUID REFERENCES shops(owner_id) ON DELETE CASCADE,  -- Who manages this user
  
  -- Identity
  email TEXT NOT NULL,
  phone TEXT,
  full_name TEXT,
  
  -- Credentials
  password_hash TEXT NOT NULL,  -- bcrypt hashed, NEVER plain text
  password_changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  password_expires_at TIMESTAMP,  -- Optional: enforce password rotation
  
  -- Status & Permissions
  is_active BOOLEAN DEFAULT TRUE,
  is_verified BOOLEAN DEFAULT FALSE,  -- Email verified
  login_attempts INT DEFAULT 0,
  locked_until TIMESTAMP,  -- Account lockout on too many failed attempts
  
  -- Metadata
  created_by UUID REFERENCES auth.users(id),  -- Admin or Owner who created
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login_at TIMESTAMP,
  
  -- Audit
  ip_address_on_create TEXT,
  device_info_on_create TEXT,
  
  UNIQUE(email),
  UNIQUE(phone)
);

CREATE INDEX idx_operational_users_user_type ON operational_users(user_type);
CREATE INDEX idx_operational_users_owner_id ON operational_users(owner_id);
CREATE INDEX idx_operational_users_email ON operational_users(email);
```

### 3.2 New Table: `admin_accounts`
Pre-authorized admin accounts

```sql
CREATE TABLE admin_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Identity
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  full_name TEXT,
  
  -- Credentials
  password_hash TEXT NOT NULL,  -- bcrypt hashed
  password_changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  password_expires_at TIMESTAMP,
  
  -- Permissions
  admin_level INT DEFAULT 1,  -- 1=superadmin, 2=admin, 3=limited
  permissions JSONB DEFAULT '{}',
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  login_attempts INT DEFAULT 0,
  locked_until TIMESTAMP,
  
  -- Audit
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login_at TIMESTAMP
);

CREATE INDEX idx_admin_accounts_email ON admin_accounts(email);
```

### 3.3 Modify: `customers` Table
Add Google Sign-In tracking

```sql
ALTER TABLE customers ADD COLUMN IF NOT EXISTS google_id TEXT UNIQUE;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS google_email TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS login_method TEXT DEFAULT 'email' CHECK (login_method IN ('email', 'google'));
ALTER TABLE customers ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP;

CREATE INDEX idx_customers_google_id ON customers(google_id);
```

### 3.4 Modify: `shops` Table
Add owner authentication info

```sql
ALTER TABLE shops ADD COLUMN IF NOT EXISTS owner_email TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS owner_phone TEXT;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS owner_verified BOOLEAN DEFAULT FALSE;

CREATE INDEX idx_shops_owner_email ON shops(owner_email);
```

---

## 4. BACKEND API ENDPOINTS

### 4.1 Customer Authentication

**POST /api/auth/customer/signup**
```json
{
  "email": "customer@example.com",
  "password": "secure_password",
  "full_name": "John Doe"
}
```
Response: JWT token, customer profile

**POST /api/auth/customer/login**
```json
{
  "email": "customer@example.com",
  "password": "secure_password"
}
```
Response: JWT token

**POST /api/auth/customer/google**
```json
{
  "google_id_token": "..."
}
```
Response: JWT token (create profile if doesn't exist)

### 4.2 Owner/Employee/Rider Authentication

**POST /api/auth/operational/login**
```json
{
  "email_or_id": "owner@example.com",
  "password": "secure_password"
}
```
Backend:
1. Query `operational_users` table by email
2. Verify password (bcrypt compare)
3. Check `is_active = true`
4. Check role matches expected type
5. Update `last_login_at`
6. Issue JWT token with role in payload

Response: JWT token with user_type in claims

**POST /api/auth/operational/request-password-reset**
```json
{
  "email": "owner@example.com"
}
```
Backend:
1. Generate reset token
2. Store in `password_reset_tokens` table (expires in 1 hour)
3. Send email with reset link

**POST /api/auth/operational/reset-password**
```json
{
  "reset_token": "...",
  "new_password": "secure_new_password"
}
```

### 4.3 Admin Operations

**POST /api/admin/create-owner**
```json
{
  "email": "owner@business.com",
  "phone": "+919999999999",
  "full_name": "Owner Name",
  "temporary_password": "TempPass123!",
  "shop_id": "uuid"
}
```
Backend:
1. Hash password (bcrypt)
2. Create in `operational_users` table
3. Update `shops.owner_email`
4. Send email with login credentials
5. Require password change on first login

**POST /api/admin/create-employee** (same pattern for rider/supplier)

**POST /api/admin/disable-user**
```json
{
  "user_id": "uuid",
  "user_type": "owner|employee|rider|supplier"
}
```

---

## 5. FIREBASE AUTH CONFIGURATION

### 5.1 Customer Sign-In (Keep Current)
- Google Sign-In enabled
- Email/Password enabled
- Phone auth optional

### 5.2 Operational Users (NEW)
- **DO NOT** create Firebase Auth accounts for Owner/Employee/Rider
- Use Supabase `operational_users` table only
- Backend validates password, issues custom JWT
- Custom JWT includes:
  - `sub`: user_id from operational_users
  - `role`: user_type (owner, employee, rider, supplier)
  - `owner_id`: which owner they work for

### 5.3 Admin (NEW)
- Pre-authorized Firebase account OR custom JWT
- Recommended: Custom JWT from admin_accounts table
- Can optionally federate with corporate directory

---

## 6. AUTHORIZATION & RLS POLICIES

### 6.1 operational_users RLS

```sql
-- Admins can see all operational users
CREATE POLICY "Admin see all operational users"
  ON operational_users FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM admin_accounts WHERE id = auth.uid() AND is_active = true)
  );

-- Owners can see their employees/riders/suppliers
CREATE POLICY "Owner see own team"
  ON operational_users FOR SELECT
  USING (
    owner_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  );

-- Users can see themselves
CREATE POLICY "Users see self"
  ON operational_users FOR SELECT
  USING (id = auth.uid());

-- Prevent direct inserts (only via API)
CREATE POLICY "Prevent inserts"
  ON operational_users FOR INSERT
  WITH CHECK (false);
```

### 6.2 admin_accounts RLS

```sql
-- Only superadmins can read admin accounts
CREATE POLICY "Superadmin see all admins"
  ON admin_accounts FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM admin_accounts 
            WHERE id = auth.uid() AND admin_level = 1 AND is_active = true)
  );

-- Prevent inserts
CREATE POLICY "Prevent inserts"
  ON admin_accounts FOR INSERT
  WITH CHECK (false);
```

---

## 7. SECURITY REQUIREMENTS

### 7.1 Password Policy
- Minimum 8 characters
- At least 1 uppercase, 1 lowercase, 1 number, 1 special char
- Cannot reuse last 5 passwords
- Expires after 90 days (optional: configurable)
- Bcrypt hashing (salt rounds: 12)

### 7.2 Login Security
- Max 5 failed attempts → 15 minute lockout
- Rate limiting: 10 login attempts per 5 minutes per IP
- Log all login attempts (success & failure)
- Monitor for suspicious patterns

### 7.3 Token Security
- JWT expiry: 24 hours for customer, 8 hours for operational users
- Refresh tokens: 30 days
- No sensitive data in token payload
- HTTPS only, secure cookies

### 7.4 Account Lifecycle
- Owner creation: Admin sets temporary password
- First login: Force password change
- Inactivity: Lock after 90 days no login
- Deletion: Soft delete, flag as `is_active = false`

---

## 8. IMPLEMENTATION ROADMAP

### Phase 1: Database Schema
- [ ] Create `operational_users` table
- [ ] Create `admin_accounts` table
- [ ] Modify `customers` table (Google Sign-In tracking)
- [ ] Add RLS policies
- [ ] Create audit tables

### Phase 2: Backend APIs
- [ ] Customer signup/login/google endpoints
- [ ] Operational user login endpoint
- [ ] Password reset flow
- [ ] Admin user management endpoints
- [ ] Token generation & validation

### Phase 3: Frontend Updates
- [ ] Update customer login screen (Google + Email/Password)
- [ ] New owner/employee/rider login screens
- [ ] Password change flow
- [ ] Admin dashboard for user management

### Phase 4: Testing & Security
- [ ] Load testing (login endpoints)
- [ ] Security audit (password storage, token handling)
- [ ] Manual testing of all flows
- [ ] Edge cases (account lockout, password reset, etc.)

### Phase 5: Migration & Rollout
- [ ] Data migration (existing users)
- [ ] Blue/green deployment
- [ ] Monitoring & alerting
- [ ] Gradual rollout to users

---

## 9. TESTING MATRIX

| Scenario | Test Case | Expected Result |
|----------|-----------|-----------------|
| Customer Google Sign-In | First-time login | Auto-create profile, issue token |
| Customer Email Login | Existing email | Verify password, issue token |
| Owner Login | Valid email + password | Verify owner, issue token with owner role |
| Owner Invalid Password | Wrong password | Fail, increment attempts |
| Owner Account Lockout | 5 failed attempts | Lock for 15 minutes |
| Employee Login | Valid ID + password | Verify owner_id, issue token |
| Admin Create Owner | Valid data | Create user, send email, owner can login |
| Password Reset | Valid email | Send reset link, reset password |
| Expired Token | Old JWT | Refresh or re-login |

---

## 10. MIGRATION GUIDE (Existing Users)

For existing customers/owners in Firebase:
1. Extract email from Firebase Auth
2. Create entry in appropriate table
3. Auto-generate temporary password (if operational user)
4. Send password reset link
5. Verify on first new-platform login

---

## 11. ROLLBACK PLAN

If issues discovered:
1. Keep old auth system running in parallel (2 weeks)
2. Gradual migration (10% users per day)
3. Switch via feature flag
4. Complete rollback possible until day 14

---

## Next: IMPLEMENTATION DETAILS

See: `AUTH_IMPLEMENTATION.md` (to be created)

