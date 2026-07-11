# Authentication System Implementation Guide
**Status:** READY FOR DEPLOYMENT  
**Date:** 2026-07-11

---

## PHASE 1: Database Deployment

### Step 1: Apply Supabase Migration

```bash
# Run migration 11 in Supabase SQL Editor or via CLI:
supabase migration up --linked

# Or manually run: supabase/migrations/11_operational_auth_schema.sql
```

This creates:
- `operational_users` table (Owner, Employee, Rider, Supplier)
- `admin_accounts` table (pre-authorized admin accounts)
- `login_audit_log` table (audit trail)
- `password_reset_tokens` table (password reset tokens)
- RLS policies for all new tables
- Helper functions (check_login_lockout, increment_login_attempts, reset_login_attempts)

### Step 2: Verify Tables Created

```sql
-- Verify in Supabase SQL Editor:
SELECT tablename FROM pg_tables WHERE schemaname='public' 
  AND tablename IN ('operational_users', 'admin_accounts', 'login_audit_log', 'password_reset_tokens');
-- Should return: 4 rows
```

### Step 3: Create Initial Admin Account

```sql
-- Run in Supabase SQL Editor to create super admin:
INSERT INTO admin_accounts (email, full_name, password_hash, admin_level, is_active)
VALUES (
  'admin@fufaji.com',
  'System Administrator',
  '$2a$12$...',  -- bcrypt hash of password (use online bcrypt tool or Node.js)
  1,  -- SuperAdmin level
  true
);
```

**To generate bcrypt hash:**
```bash
# Using Node.js:
node -e "const bcrypt = require('bcrypt'); console.log(bcrypt.hashSync('YourPassword123!', 12))"

# Using online tool: https://bcrypt-generator.com/
```

---

## PHASE 2: Backend Deployment

### Step 1: Copy New Route Files

```bash
# Copy to backend:
cp backend/src/routes/auth-operational.js backend/src/routes/
cp backend/src/routes/admin-auth.js backend/src/routes/
```

### Step 2: Register Routes in Express App

In `backend/src/app.js` or `backend/src/index.js`:

```javascript
const authOperationalRoutes = require('./routes/auth-operational');
const adminAuthRoutes = require('./routes/admin-auth');

// Register routes
app.use('/api/auth', authOperationalRoutes);
app.use('/api/admin/auth', adminAuthRoutes);

// Make sure middleware is applied BEFORE routes:
// - Authentication middleware for protected endpoints
// - Rate limiting middleware
```

### Step 3: Update Middleware

Ensure you have JWT middleware that sets `req.user` from token:

```javascript
// In middleware.js or auth.js:
const verifyOperationalToken = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

app.use('/api/auth/operational/me', verifyOperationalToken);
app.use('/api/auth/operational/change-password', verifyOperationalToken);
app.use('/api/admin/auth', verifyOperationalToken);
```

### Step 4: Configure Environment Variables

Add to `.env` or `.env.local`:

```env
# JWT Configuration
JWT_SECRET=your_super_secret_key_min_32_chars
JWT_EXPIRY=8h

# Email Configuration (for password reset emails)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your_app_password
EMAIL_FROM=noreply@fufaji.com

# App URLs
APP_BASE_URL=https://fufaji.app
ADMIN_PANEL_URL=https://admin.fufaji.app
```

### Step 5: Implement Email Service

Create `backend/src/services/email-service.js`:

```javascript
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: process.env.SMTP_PORT,
  secure: true,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS
  }
});

const sendPasswordResetEmail = async (email, resetToken) => {
  const resetLink = `${process.env.APP_BASE_URL}/auth/reset-password?token=${resetToken}`;

  await transporter.sendMail({
    from: process.env.EMAIL_FROM,
    to: email,
    subject: 'Password Reset Request',
    html: `
      <h2>Password Reset</h2>
      <p>Click the link below to reset your password (expires in 1 hour):</p>
      <a href="${resetLink}">${resetLink}</a>
      <p>If you didn't request this, ignore this email.</p>
    `
  });
};

module.exports = { sendPasswordResetEmail };
```

### Step 6: Test Backend Endpoints

```bash
# Test Owner Login
curl -X POST http://localhost:3000/api/auth/operational/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "owner@shop.com",
    "password": "YourPassword123!"
  }'

# Expected response:
# {
#   "success": true,
#   "token": "eyJhbGc...",
#   "user": { "id": "uuid", "email": "...", "user_type": "owner" }
# }
```

---

## PHASE 3: Flutter App Updates

### Step 1: Update Login Screen Routing

In `lib/screens/login_screen.dart`:

```dart
class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String selectedUserType = 'customer'; // customer, owner, employee, rider

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Tab selector
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'customer', label: Text('Customer')),
              ButtonSegment(value: 'owner', label: Text('Owner')),
              ButtonSegment(value: 'employee', label: Text('Employee')),
            ],
            selected: {selectedUserType},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                selectedUserType = newSelection.first;
              });
            },
          ),
          
          // Conditional login UI
          if (selectedUserType == 'customer')
            CustomerLoginForm()
          else
            OperationalLoginForm(userType: selectedUserType)
        ],
      ),
    );
  }
}
```

### Step 2: Create OperationalLoginForm Widget

In `lib/screens/operational_login_form.dart`:

```dart
class OperationalLoginForm extends StatefulWidget {
  final String userType;
  
  const OperationalLoginForm({required this.userType});

  @override
  State<OperationalLoginForm> createState() => _OperationalLoginFormState();
}

class _OperationalLoginFormState extends State<OperationalLoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${APIConstants.baseUrl}/api/auth/operational/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Save token to secure storage
        await secureStorage.write(
          key: 'auth_token',
          value: data['token'],
        );

        // Save user type
        await secureStorage.write(
          key: 'user_type',
          value: widget.userType,
        );

        // Navigate to home
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        final error = jsonDecode(response.body)['error'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _login,
            child: _isLoading
              ? CircularProgressIndicator()
              : Text('Login'),
          ),
          TextButton(
            onPressed: () {
              // Navigate to password reset
              Navigator.of(context).pushNamed('/forgot-password');
            },
            child: Text('Forgot Password?'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
```

### Step 3: Create Password Reset Screen

In `lib/screens/password_reset_screen.dart`:

```dart
class PasswordResetScreen extends StatefulWidget {
  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _emailController = TextEditingController();
  final _resetTokenController = TextEditingController();
  final _newPasswordController = TextEditingController();

  int _step = 1; // 1: request, 2: reset

  Future<void> _requestReset() async {
    try {
      final response = await http.post(
        Uri.parse('${APIConstants.baseUrl}/api/auth/operational/request-password-reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text}),
      );

      if (response.statusCode == 200) {
        setState(() => _step = 2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check your email for reset link')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _resetPassword() async {
    try {
      final response = await http.post(
        Uri.parse('${APIConstants.baseUrl}/api/auth/operational/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reset_token': _resetTokenController.text,
          'new_password': _newPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reset Password')),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: _step == 1
          ? Column(
              children: [
                Text('Enter your email to receive reset instructions'),
                SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _requestReset,
                  child: Text('Send Reset Link'),
                ),
              ],
            )
          : Column(
              children: [
                TextField(
                  controller: _resetTokenController,
                  decoration: InputDecoration(labelText: 'Reset Token'),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'New Password'),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _resetPassword,
                  child: Text('Reset Password'),
                ),
              ],
            ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _resetTokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
}
```

### Step 4: Update AuthService

In `lib/services/auth_service.dart`:

```dart
class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userTypeKey = 'user_type';

  final secureStorage = FlutterSecureStorage();

  Future<bool> operationalLogin(String email, String password, String userType) async {
    try {
      final response = await http.post(
        Uri.parse('${APIConstants.baseUrl}/api/auth/operational/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        await secureStorage.write(key: _tokenKey, value: data['token']);
        await secureStorage.write(key: _userTypeKey, value: userType);
        
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<String?> getToken() async {
    return await secureStorage.read(key: _tokenKey);
  }

  Future<String?> getUserType() async {
    return await secureStorage.read(key: _userTypeKey);
  }

  Future<void> logout() async {
    await secureStorage.delete(key: _tokenKey);
    await secureStorage.delete(key: _userTypeKey);
  }
}
```

---

## PHASE 4: Testing

### Test Checklist

- [ ] **Database**: All tables created with RLS enabled
- [ ] **Admin Account**: Can log in with super admin credentials
- [ ] **Owner Creation**: Admin can create owner account
- [ ] **Owner Login**: Owner can log in with email + password
- [ ] **Employee Creation**: Owner can create employee account
- [ ] **Employee Login**: Employee can log in with email + password
- [ ] **Password Reset**: Reset link sent and works
- [ ] **Account Lockout**: Account locks after 5 failed attempts
- [ ] **Audit Logging**: All logins logged in login_audit_log
- [ ] **Token Expiry**: Token expires after 8 hours
- [ ] **RLS Policies**: Customers can't access operational_users, owners can see their team
- [ ] **Rate Limiting**: Login endpoint rate-limited to 10 per 5 minutes
- [ ] **Password Hashing**: Passwords stored as bcrypt hashes (never plain text)

### Manual Testing Commands

```bash
# 1. Create Admin Account
curl -X POST http://localhost:3000/api/admin/auth/create-admin \
  -H "Authorization: Bearer <existing_admin_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newadmin@fufaji.com",
    "password": "SecurePass123!",
    "full_name": "New Admin"
  }'

# 2. Create Owner Account
curl -X POST http://localhost:3000/api/admin/auth/create-owner \
  -H "Authorization: Bearer <admin_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "owner@shop.com",
    "phone": "+919999999999",
    "full_name": "Shop Owner",
    "shop_id": "uuid"
  }'

# 3. Owner Login
curl -X POST http://localhost:3000/api/auth/operational/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "owner@shop.com",
    "password": "TempPassword123!"
  }'

# 4. Create Employee
curl -X POST http://localhost:3000/api/admin/auth/create-employee \
  -H "Authorization: Bearer <owner_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "emp@shop.com",
    "full_name": "Employee Name",
    "user_type": "employee",
    "owner_id": "uuid"
  }'

# 5. Employee Login
curl -X POST http://localhost:3000/api/auth/operational/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "emp@shop.com",
    "password": "TempPassword123!"
  }'

# 6. Get Current User
curl -X GET http://localhost:3000/api/auth/operational/me \
  -H "Authorization: Bearer <token>"

# 7. Change Password
curl -X POST http://localhost:3000/api/auth/operational/change-password \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "current_password": "OldPassword123!",
    "new_password": "NewPassword123!"
  }'

# 8. Request Password Reset
curl -X POST http://localhost:3000/api/auth/operational/request-password-reset \
  -H "Content-Type: application/json" \
  -d '{"email": "owner@shop.com"}'

# Response includes: _test_token field with reset token (FOR TESTING ONLY)

# 9. Reset Password
curl -X POST http://localhost:3000/api/auth/operational/reset-password \
  -H "Content-Type: application/json" \
  -d '{
    "reset_token": "...",
    "new_password": "NewPassword123!"
  }'
```

---

## PHASE 5: Security Hardening

### Post-Deployment

1. **Enable HTTPS Only**
   - Set secure flag on cookies
   - Add HSTS headers
   - Update CORS to whitelist only known domains

2. **Monitor Logins**
   - Check login_audit_log for suspicious patterns
   - Set up alerts for multiple failed attempts from same IP
   - Monitor for unusual geographic login locations

3. **Password Policy**
   - Enforce minimum 8 characters
   - Require: uppercase, lowercase, number, special char
   - Send expiration warnings at 80 days
   - Force change every 90 days

4. **MFA (Future)**
   - Add TOTP support for sensitive roles (admin, owner)
   - Make MFA mandatory for admin accounts
   - Support authenticator apps (Google Authenticator, Authy)

---

## ROLLBACK PLAN

If issues discovered:

1. Keep old auth system available (if applicable)
2. Switch traffic back via feature flags
3. Keep new tables in sync as backup
4. Rollback within 48 hours if critical issues

---

## MIGRATION FROM FIREBASE AUTH

For existing users currently using Firebase:

1. **Extract Firebase Users**
   ```javascript
   const users = await admin.auth().listUsers();
   // For each user with role, create in operational_users or admin_accounts
   ```

2. **Send Password Reset Links**
   - Notify users they need to set a password
   - Send password reset links via email
   - Provide 7-day grace period before forcing reset

3. **Gradual Migration**
   - Migrate 10% of users per day
   - Monitor auth errors closely
   - Be ready to rollback

---

**Next Steps:**
1. Review and approve implementation
2. Deploy to staging environment
3. Run full test suite
4. Deploy to production with monitoring

