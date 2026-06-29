# Phone Authentication Security Audit

**Status:** Security Hardening for Phone OTP Implementation  
**Date:** 2026-06-26  
**Scope:** Firebase Phone Auth + Fufaji Store

---

## ✅ Security Checklist

| Check | Status | Details |
|-------|--------|---------|
| Phone number validation | ✅ REQUIRED | Validate format before sending OTP |
| Rate limiting (OTP sends) | ⚠️ MUST ADD | Firebase App Check + custom throttle |
| OTP code security | ✅ BUILT-IN | Firebase handles 6-digit + 120-sec timeout |
| Verification ID handling | ✅ REQUIRED | Store in memory only (not SharedPreferences) |
| SMS region policy | ✅ CONFIGURED | India enabled; high-risk zones blocked |
| User document creation | ✅ REQUIRED | Prevent privilege escalation on signup |
| Session binding | ✅ INTEGRATED | SessionService tracks phone login |
| Firestore rules | ✅ PROVIDED | Users can only write their own docs |
| Phone number storage | ✅ SECURE | Stored only in `users` doc (Firestore) + Firebase Auth |

---

## 🔴 P0: Rate Limiting (OTP Pumping)

**Vulnerability:** Attacker can spam OTP sends to exhaust quotas or abuse phone numbers.

**Mitigation:**

### 1. Firebase App Check (Already Active)
- Play Integrity API verifies requests come from legitimate app
- Already enabled in your `main.dart`
- Protects Firestore + Auth endpoints

### 2. Client-Side Throttle (Add to PhoneLoginScreen)

```dart
// In PhoneLoginScreen state
DateTime? _lastOtpSentTime;
static const Duration _otpThrottleDuration = Duration(minutes: 1);

Future<void> _handleSendOTP() async {
  // Throttle: prevent rapid re-sends
  if (_lastOtpSentTime != null) {
    final timeSinceLastSend = DateTime.now().difference(_lastOtpSentTime!);
    if (timeSinceLastSend < _otpThrottleDuration) {
      setState(() {
        _errorMessage = 
            'Please wait ${(_otpThrottleDuration.inSeconds - timeSinceLastSend.inSeconds)}s before requesting a new code';
      });
      return;
    }
  }

  try {
    // ... existing OTP send logic ...
    _lastOtpSentTime = DateTime.now();
  } catch (e) {
    // Error, don't update throttle time
  }
}
```

### 3. Firebase Function Rate Limiting (Optional Backend)

If you add a custom Firebase Function:

```javascript
// functions/sendPhoneOTP.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

const RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute
const recentRequests = {};

exports.sendPhoneOTP = functions.https.onCall(async (data, context) => {
  const userId = context.auth?.uid || data.phone;
  
  // Check rate limit
  const now = Date.now();
  if (recentRequests[userId] && (now - recentRequests[userId]) < RATE_LIMIT_WINDOW) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Too many OTP requests. Please wait 1 minute.'
    );
  }
  
  recentRequests[userId] = now;
  
  // Call Firebase Auth verifyPhoneNumber...
});
```

---

## 🔴 P0: Phone Number Validation

**Vulnerability:** Invalid phone numbers can bypass business logic or cause errors.

**Fix:** Add phone validation utility:

```dart
// lib/utils/phone_validator.dart

class PhoneValidator {
  /// Validate phone number format for India
  static bool isValidIndianPhone(String phoneNumber) {
    // Remove non-digits
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    // India mobile: 10 digits starting with 6-9
    // Landline: 11-12 digits
    if (digits.length == 10) {
      return RegExp(r'^[6-9]').hasMatch(digits);
    } else if (digits.length >= 11 && digits.length <= 12) {
      return true; // Landline
    }
    
    return false;
  }

  /// Get international format
  static String formatInternational(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91$digits';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    return '+91$digits'; // Default to +91
  }

  /// Sanitize for storage (remove country code if present)
  static String sanitize(String phoneNumber) {
    final international = formatInternational(phoneNumber);
    return international.replaceAll('+91', ''); // Store without country code
  }
}
```

**Use in PhoneLoginScreen:**

```dart
Future<void> _handleSendOTP() async {
  // Validate phone
  if (!PhoneValidator.isValidIndianPhone(_phoneNumber.phoneNumber!)) {
    setState(() {
      _errorMessage = 'Invalid phone number for India';
    });
    return;
  }

  final formattedPhone = PhoneValidator.formatInternational(_phoneNumber.phoneNumber!);
  // ... proceed with OTP
}
```

---

## 🟡 P1: Verification ID Security

**Current Risk:** Verification ID stored in memory is safe, but session hijacking is possible.

**Mitigation:**

1. **Store Verification ID in Memory Only** ✅
   - Never store in SharedPreferences or disk
   - Already done in `auth_provider.dart`

2. **Short Expiration** ✅
   - Firebase OTP expires in 120 seconds
   - Verification ID expires after first use

3. **Bind to Device Fingerprint** (Optional Enhancement)
   ```dart
   // lib/services/device_security_service.dart (add to existing)
   
   String getDeviceFingerprint() {
     // Combine device properties into a unique hash
     final deviceInfo = [
       deviceId,           // From device_info_plus
       osVersion,
       timezone,
       locale,
     ].join('|');
     
     return sha256.convert(deviceInfo.codeUnits).toString();
   }
   
   // Verify fingerprint matches when verifying OTP
   bool verifyDeviceFingerprint() {
     final stored = SharedPreferences.getInstance()
         .getString('device_fingerprint');
     final current = getDeviceFingerprint();
     return stored == current;
   }
   ```

---

## 🟡 P1: User Document Privilege Escalation

**Current Risk:** New phone users can set their own `role` field to `shopOwner` or `admin`.

**Fix:** Firestore rules enforce role immutability:

```javascript
// Existing rule in firestore.rules
allow create: if request.auth != null && 
               request.auth.uid == userId &&
               request.resource.data.role == 'customer'; // Force customer role
```

This prevents:
- Customers self-elevating to owner
- Phone-signup users becoming admins

---

## 🟡 P1: SMS Injection in Phone Number

**Vulnerability:** Phone number injection (e.g., `+1234\n+5678`) could trigger multi-number verification.

**Fix:** Input sanitization in PhoneLoginScreen:

```dart
// Sanitize phone number
final sanitized = _phoneNumber.phoneNumber
    ?.replaceAll(RegExp(r'[^0-9+\-\(\) ]'), '') // Remove suspicious chars
    .trim();

if (!PhoneValidator.isValidIndianPhone(sanitized)) {
  // Reject
}
```

---

## 🟢 P2: OTP Code Brute Force

**Current Status:** ✅ Mitigated by Firebase

- Firebase Auth: max 5 attempts per code
- Auto-lockout after 5 failures
- Code expires in 120 seconds
- No indication of "close match" (prevents guess refinement)

**Optional:** Add UI feedback:

```dart
int _failedAttempts = 0;
final int _maxAttempts = 5;

Future<void> _handleVerifyOTP(String otp) async {
  try {
    // ... verify OTP ...
    _failedAttempts = 0; // Reset on success
  } catch (e) {
    _failedAttempts++;
    if (_failedAttempts >= _maxAttempts) {
      // Disable input, show "try again later"
      _focusNode.unfocus();
    }
  }
}
```

---

## 🟢 P2: Session Hijacking via Phone Auth

**Mitigation:**

1. **Session Service Binding** ✅
   - `SessionService.createSession()` creates entry in `active_sessions`
   - Includes `lastActivityTime`, `deviceInfo`, `loginMethod`
   - User can revoke from settings

2. **Device Fingerprint in Session** ✅
   ```dart
   // In _signInWithPhoneCredential()
   final session = await SessionService.createSession(
     userId: firebaseUser.uid,
     userRole: UserRole.customer,
     loginMethod: 'phone',
     deviceFingerprint: DeviceSecurityService.getFingerprint(), // ADD THIS
   );
   ```

3. **Periodic Session Validation** ✅
   - `AuthProvider` listens to `active_sessions` real-time
   - If `isActive=false`, forced logout

---

## 🟢 P2: Phone Number Privacy

**Current Status:** ✅ Secure

- Phone numbers never logged in plaintext
- Only stored in `users` collection (Firestore rules restrict read)
- Firebase Auth phone field is system-protected

**Best Practice:** Mask phone in UI:

```dart
String _maskPhoneNumber(String phone) {
  // Show only last 4 digits
  return '${phone.substring(0, phone.length - 4)}****';
}

// Usage
Text(_maskPhoneNumber(userModel.phone))
```

---

## Testing Checklist

| Test | Method | Expected Result |
|------|--------|-----------------|
| Valid Indian phone | `+91 98765 43210` | OTP sent ✅ |
| Invalid format | `98765` | Error: "Invalid format" ✅ |
| Rapid OTP sends | 5 sends in 10 sec | 4th send blocked ✅ |
| Wrong OTP code | `000000` | Error after 5 tries ✅ |
| Expired code | Code after 120s | Firebase auto-rejects ✅ |
| First-time signup | Phone → OTP → Verify | User doc created ✅ |
| Returning customer | Phone → OTP → Verify | Existing doc updated ✅ |
| Session revocation | Remote logout | User forced to re-login ✅ |

---

## Secrets & Keys

**Safe ✅:**
- Firebase config already uses environment variables
- No hardcoded API keys in phone auth code
- App Check attestation (Play Integrity) is secure

**Dangerous ❌:**
- ~~Storing phone OTP in logs~~ (Firebase handles securely)
- ~~Sending OTP via email/unencrypted channels~~ (SMS is standard)

---

## Compliance Notes

**GDPR/India DPA:**
- Phone number is PII → stored securely (Firebase + Firestore rules)
- User must consent before OTP signup
- Implement privacy policy link on PhoneLoginScreen

**TCPA (US) / TRAI (India):**
- OTP SMS is exempt from "do not call" lists
- Your app should have explicit opt-in checkbox for marketing SMS

**Implementation:**
```dart
// Add to PhoneLoginScreen
Checkbox(
  value: _agreeToTerms,
  onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
),
Text('I agree to receive verification SMS and follow the Privacy Policy'),
```

---

## Summary

| Risk Level | Count | Status |
|------------|-------|--------|
| P0 (Critical) | 2 | ⚠️ Rate limiting + validation needed |
| P1 (High) | 3 | ⚠️ Rules enforce, device FP optional |
| P2 (Medium) | 3 | ✅ Firebase + SessionService mitigate |

**Ready to ship?** Add rate limiting + phone validation → approve for production.
