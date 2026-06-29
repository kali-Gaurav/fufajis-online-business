# Firebase Phone Authentication — Implementation Guide
**Fufaji Store Android App**  
**Status:** Ready to integrate  
**Date:** 2026-06-26

---

## 📋 Quick Start (5 Steps)

1. ✅ **Firebase Console** — Enable phone auth (already done)
2. 📦 **Dependencies** — Add `intl_phone_number_input` + `pinput`
3. 📱 **Screens** — Add `PhoneLoginScreen` + `PhoneVerifyScreen`
4. 🔥 **Auth Provider** — Add phone OTP methods
5. 🛣️ **Routes** — Wire up screens in `app_router.dart`

---

## 🔧 Step 1: Firebase Console Setup

### 1.1 Enable Phone Sign-In

```
Firebase Console → Your Fufaji Project
  → Authentication → Sign-in method
  → Enable "Phone" provider
```

**Result:** Phone card shows "Enabled" ✅

### 1.2 SMS Region Policy

```
Firebase Console → Authentication → Settings → SMS region policy
  → Add "India 🇮🇳"
  → Block high-risk regions (optional)
```

**Why:** Prevents SMS abuse; required for India market.

### 1.3 App Check (Already Active)

```
Firebase Console → App Check
  → Verify "Android" shows "Play Integrity" ✅
  → Status: Active
```

**Already done per your June 2026 setup.**

---

## 📦 Step 2: Add Dependencies

### 2.1 Update `pubspec.yaml`

```bash
# Copy from pubspec_phone_additions.yaml OR manual:

flutter pub add intl_phone_number_input pinput phone_numbers_parser
```

### 2.2 Run

```bash
flutter pub get
```

### 2.3 Verify

```bash
flutter pub get --verbose | grep "intl_phone\|pinput"
```

---

## 📱 Step 3: Add Phone Auth Screens

### 3.1 Create Screens

Copy these 2 new files into your `lib/screens/auth/`:

1. **`phone_login_screen.dart`** — Phone number input + send OTP
2. **`phone_verify_screen.dart`** — OTP code entry + verification

**Location:**
```
lib/
  screens/
    auth/
      phone_login_screen.dart          ← NEW
      phone_verify_screen.dart         ← NEW
      login_screen.dart                ← Update (add phone button)
```

### 3.2 Update LoginScreen

In your existing `lib/screens/login_screen.dart`, add the phone sign-in button alongside Google:

```dart
// In LoginScreen build() method, after Google button:

SizedBox(height: 16),

OutlinedButton(
  onPressed: () {
    context.go('/auth/phone-login');
  },
  style: OutlinedButton.styleFrom(
    padding: EdgeInsets.symmetric(vertical: 14),
    side: BorderSide(color: Colors.blue[600]!),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.phone, color: Colors.blue[600]),
      SizedBox(width: 8),
      Text(
        'Sign in with Phone',
        style: TextStyle(color: Colors.blue[600]),
      ),
    ],
  ),
),
```

---

## 🔥 Step 4: Add Phone Auth Methods to AuthProvider

### 4.1 Open `lib/providers/auth_provider.dart`

Add these imports at the top:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
```

### 4.2 Add Properties (in your `_AuthProviderState` or main class)

```dart
late String? _verificationId;       // Firebase verification ID
late int? _resendToken;              // For OTP resend
```

### 4.3 Copy Phone Auth Methods

Copy all methods from `auth_provider_phone_additions.dart`:

- `sendPhoneOTP(String phoneNumber)` — Initiate OTP send
- `verifyPhoneOTP(String smsCode)` — Verify code
- `_signInWithPhoneCredential(PhoneAuthCredential credential)` — Complete sign-in
- `_createNewPhoneCustomer(...)` — Create user doc for first-time signup
- `_updateCustomerLogin(String userId)` — Update last login

**Paste into `auth_provider.dart` after your existing Google/Employee auth methods.**

### 4.4 Verify No Conflicts

Ensure you don't have duplicate method names:
- ✅ `sendPhoneOTP` — new (phone only)
- ✅ `signInWithGoogle` — existing (don't replace)
- ✅ `logout` — existing (should work for both)

---

## 🛣️ Step 5: Wire Routes

### 5.1 Open `lib/utils/app_router.dart`

Find your `routes` list or `_buildRoutes()` method.

### 5.2 Add Two Routes

```dart
// In your GoRouter routes list:

GoRoute(
  path: '/auth/phone-login',
  name: 'phone-login',
  builder: (context, state) => PhoneLoginScreen(),
),

GoRoute(
  path: '/auth/phone-verify',
  name: 'phone-verify',
  builder: (context, state) {
    final phone = state.extra as String?;
    if (phone == null) {
      return PhoneLoginScreen(); // Fallback
    }
    return PhoneVerifyScreen(phone: phone);
  },
),
```

### 5.3 Update LoginScreen Route (if using GoRouter)

Ensure your existing `/login` or `/auth/login` route includes the phone button that routes to `/auth/phone-login`.

---

## 🔒 Step 6: Security Hardening (Important!)

### 6.1 Add Phone Validation Utility

Create `lib/utils/phone_validator.dart`:

```dart
class PhoneValidator {
  static bool isValidIndianPhone(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    // Mobile: 10 digits starting with 6-9
    if (digits.length == 10) {
      return RegExp(r'^[6-9]').hasMatch(digits);
    }
    // Landline: 11-12 digits
    if (digits.length >= 11 && digits.length <= 12) {
      return true;
    }
    return false;
  }

  static String formatInternational(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91$digits';
    }
    return '+91$digits';
  }
}
```

### 6.2 Update PhoneLoginScreen

In `_handleSendOTP()`, add:

```dart
Future<void> _handleSendOTP() async {
  // Validate phone first
  if (!PhoneValidator.isValidIndianPhone(_phoneNumber.phoneNumber!)) {
    setState(() {
      _errorMessage = 'Invalid Indian phone number';
    });
    return;
  }

  // Rate limit (prevent spam)
  if (_lastOtpSentTime != null) {
    final timeSince = DateTime.now().difference(_lastOtpSentTime!);
    if (timeSince.inSeconds < 60) {
      setState(() {
        _errorMessage = 'Please wait 1 minute before requesting another code';
      });
      return;
    }
  }

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final formattedPhone = PhoneValidator.formatInternational(_phoneNumber.phoneNumber!);
    await context.read<AuthProvider>().sendPhoneOTP(formattedPhone);
    _lastOtpSentTime = DateTime.now();
    
    Navigator.of(context).pushNamed(
      '/auth/phone-verify',
      arguments: {'phone': formattedPhone},
    );
  } catch (e) {
    setState(() {
      _errorMessage = e.toString();
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
```

### 6.3 Update Firestore Rules

Ensure your Firestore rules block privilege escalation:

```javascript
// In your firestore.rules:

match /users/{userId} {
  // Prevent new users from setting own role
  allow create: if request.auth != null && 
                   request.auth.uid == userId &&
                   request.resource.data.role == 'customer'; // Force 'customer'
}
```

---

## ✅ Testing Checklist

| Test Case | Steps | Expected | Status |
|-----------|-------|----------|--------|
| **Valid phone** | Enter `+91 98765 43210` → Send | OTP sent, Verify screen shows | 🧪 |
| **Invalid format** | Enter `12345` → Send | Error: "Invalid format" | 🧪 |
| **Rapid sends** | Send OTP 5× in 10 sec | 4th/5th blocked by throttle | 🧪 |
| **Wrong OTP** | Enter `000000` | After 5 tries, error | 🧪 |
| **Correct OTP** | Receive code → Enter | Sign-in complete → Home | 🧪 |
| **First signup** | New phone → OTP → Home | User doc created in Firestore | 🧪 |
| **Returning user** | Existing phone → OTP → Home | lastLogin updated | 🧪 |
| **Session check** | Complete login → Check `active_sessions` | Entry created with `isActive=true` | 🧪 |
| **Remote logout** | Set `isActive=false` in Firestore | User forced to re-login | 🧪 |

---

## 🧪 Manual Test Flow

### Test 1: Happy Path (New Customer)

```
1. App Launch → LoginScreen
2. Tap "Sign in with Phone"
3. PhoneLoginScreen appears
4. Enter: +91 98765 43210
5. Tap "Send Verification Code"
   → OTP sent to phone (or Firebase emulator)
6. PhoneVerifyScreen appears
7. Enter 6-digit code from Firebase emulator console
   OR wait for actual SMS
8. Tap "Verify Code" or auto-complete
9. Success! User created in Firestore
10. Home screen appears
11. Check: `users` collection → new doc with role='customer'
```

### Test 2: Returning Customer

```
1. App Launch → LoginScreen
2. Tap "Sign in with Phone"
3. Enter SAME phone number as Test 1
4. Receive OTP, enter code
5. Success! User exists → lastLogin updated
6. Home screen
```

### Test 3: Rate Limiting

```
1. PhoneLoginScreen
2. Enter phone, tap Send → Sent ✅
3. Tap Send again (within 60s)
   → Error: "Wait 1 minute" ✅
4. Wait 60s
5. Tap Send → Sent ✅
```

---

## 🐛 Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| "Phone provider not enabled" | Firebase Console not updated | Go to Authentication → Sign-in Methods → Enable Phone |
| "Invalid phone format" | Number doesn't match India pattern | Use format: `+91 98765 43210` |
| OTP never arrives | SMS region policy blocks region | Check Settings → SMS region policy, add India |
| "Verification ID missing" | User goes back to PhoneLoginScreen mid-flow | Prevent back navigation with `WillPopScope` (already in PhoneVerifyScreen) |
| User not created in Firestore | `_createNewPhoneCustomer` failed | Check Firestore rules allow write; check Firebase logs |
| Session not created | `SessionService.createSession` error | Ensure SessionService imported; check `active_sessions` write permission |

---

## 📊 Architecture Diagram

```
┌─────────────────────┐
│   LoginScreen       │
│ [Phone] [Google]    │
└──────────┬──────────┘
           │
           ├─→ [Google] → AuthService → GoogleSignIn
           │
           └─→ [Phone] → PhoneLoginScreen
                           │
                           └─→ sendPhoneOTP()
                               │
                               ├─→ Firebase.verifyPhoneNumber()
                               │   (Play Integrity checks request)
                               │
                               └─→ codeSent callback
                                   │
                                   └─→ PhoneVerifyScreen
                                       (User enters 6-digit OTP)
                                           │
                                           └─→ verifyPhoneOTP()
                                               │
                                               ├─→ PhoneAuthProvider.getCredential()
                                               └─→ signInWithCredential()
                                                   │
                                                   ├─→ Check if user exists
                                                   │   ├─→ NO: _createNewPhoneCustomer()
                                                   │   └─→ YES: _updateCustomerLogin()
                                                   │
                                                   ├─→ SessionService.createSession()
                                                   │
                                                   └─→ notifyListeners()
                                                       │
                                                       └─→ GoRouter redirects to /home
                                                           (HomeScreen, CustomerScreen, etc.)
```

---

## 🚀 Deployment Checklist

Before shipping to Play Store:

- [ ] Phone auth enabled in Firebase Console
- [ ] SMS region policy set to India
- [ ] App Check (Play Integrity) active
- [ ] All 2 screens created + routes wired
- [ ] AuthProvider methods added + tested
- [ ] Phone validation utility in place
- [ ] Rate limiting implemented (60s throttle)
- [ ] Firestore rules enforce role='customer' on signup
- [ ] SessionService creates session on phone login
- [ ] No hardcoded API keys
- [ ] Security audit passed (PHONE_AUTH_SECURITY.md)
- [ ] 3 manual tests completed (happy path, returning, rate limit)
- [ ] APK generated & tested on device

---

## 📚 Files Summary

| File | Purpose | Status |
|------|---------|--------|
| `phone_login_screen.dart` | Phone input + send OTP | ✅ Created |
| `phone_verify_screen.dart` | OTP verification | ✅ Created |
| `auth_provider_phone_additions.dart` | AuthProvider methods | ✅ Created |
| `app_router_phone_additions.dart` | Route config | ✅ Created |
| `pubspec_phone_additions.yaml` | Dependencies | ✅ Created |
| `lib/utils/phone_validator.dart` | Phone validation | ⚠️ To create |
| Firestore rules | Security enforcement | ⚠️ To verify |
| `PHONE_AUTH_SECURITY.md` | Security audit | ✅ Created |

---

## 🔄 Next Steps

1. **Integrate files** — Copy each screen/method into your project
2. **Run & test** — Flutter run on emulator
3. **Manual testing** — Complete 3 test cases
4. **Security review** — Follow PHONE_AUTH_SECURITY.md
5. **Commit & push** — Git commit with message: "feat: add phone OTP authentication"
6. **Build APK** — `flutter build apk`
7. **Deploy to Play Store** — Internal testing track first

---

## 🤝 Support

If you hit issues:
1. Check troubleshooting table above
2. Review PHONE_AUTH_SECURITY.md for security errors
3. Check Firebase console logs: Authentication → Logs
4. Verify Firestore rules: Console → Firestore → Rules tab

---

**Status:** Ready to implement  
**Last Updated:** 2026-06-26  
**Team Lead:** 🤖
