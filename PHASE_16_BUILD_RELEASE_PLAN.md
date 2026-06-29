# COMPREHENSIVE PHASE 16 BUILD & RELEASE PLAN
## Fufaji Store Flutter Android App (June 15–July 15, 2026)

---

## EXECUTIVE SUMMARY

**Current Status (as of June 15, 2026):**
- **679 Dart files** across 8 major modules (auth, customer, rider, owner, employee, supplier, admin, core)
- **196 screen files** with complete multi-role navigation architecture
- **45+ service files** providing Firebase, Supabase, payment, AI, and analytics integration
- **Git corruption issue**: `.git/index` has bad signature on Windows (user must repair before next commit)
- **Build target**: API 35 (Android 15), minSDK 24 (Android 7.0), with Play Integrity API
- **Dependencies**: 18 packages outdated; Kotlin 2.1.0 + AGP 8.7.0 require Built-in Kotlin migration for plugins
- **Critical blockers**: KGP (Kotlin Gradle Plugin) incompatibilities in camera_android_camerax, Firebase plugins, and others

**Deliverables (Expected):**
1. Step-by-step build fix sequence with blocking dependencies identified
2. Dependency & platform compatibility audit (versions, SDK levels, ProGuard rules)
3. Core functionality wiring priority (cart→checkout→payment→orders)
4. APK build strategy (debug, staging, release signing, versioning)
5. Release readiness checklist (testing, compliance, Play Store submission)

---

## PHASE 16A: BUILD DIAGNOSTICS & DEPENDENCY FIX (Week 1)
### Goal: Achieve clean `flutter build apk` compilation

### BLOCKER 1: Git Index Corruption
**Issue**: `.git/index` has bad signature (cannot commit on Windows)
**Fix Sequence**:
1. On Windows in `C:\Projects\fufaji-online-business`:
   ```powershell
   cd .git
   rm index
   git reset --mixed
   git status  # Should show staged changes from prior session
   ```
2. If still corrupt:
   ```powershell
   git fsck --full --strict
   git gc --aggressive
   ```
3. Verify git is functional:
   ```powershell
   git log --oneline -1  # Should show recent commits
   ```

**Owner Action**: User repairs on Windows machine before next commit.
**Timing**: ~10 minutes

---

### BLOCKER 2: Kotlin/KGP Plugin Compatibility
**Issue**: Multiple Flutter plugins apply KGP without migrating to Built-in Kotlin
**Affected Plugins**:
- camera_android_camerax (0.7.2)
- firebase_analytics, firebase_app_check, firebase_remote_config, firebase_storage
- google_mlkit_text_recognition
- image_picker_android
- mobile_scanner
- sentry_flutter
- speech_to_text
- share_plus

**Fix Sequence**:
1. **Update pubspec.yaml** dependency versions to KGP-compatible releases:
   ```yaml
   camera: ^0.12.0+  (or higher with Built-in Kotlin)
   sentry_flutter: ^9.21.0  (from 9.14.2)
   speech_to_text: ^7.5.0+
   image_picker: ^1.3.0+
   mobile_scanner: ^6.1.0+
   ```

2. **Verify in android/app/build.gradle**:
   ```gradle
   plugins {
       id "com.android.application"
       id "com.google.gms.google-services"
       id "dev.flutter.flutter-gradle-plugin"
       // NO explicit org.jetbrains.kotlin.android — Flutter plugin handles it
   }
   ```

3. **Test compilation**:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --debug  # Should succeed with warnings only
   ```

**Owner Action**: Update 8 dependencies, test locally
**Timing**: ~30 minutes (30 min download + test)

---

### BLOCKER 3: SDK Version & NDK Alignment
**Issue**: Mismatch between `android/gradle/libs.versions.toml`, `android/local.properties`, and pubspec versions

**Current State**:
- compileSdk: 35 (correct for 2025)
- targetSdk: 35 (correct for Play Store requirement)
- minSdk: 24 (Android 7.0, good for market reach)
- NDK: 27.0.12077973 in toml; 28.2.13676358 in local.properties

**Fix Sequence**:
1. **Standardize NDK version** in `android/gradle/libs.versions.toml`:
   ```toml
   ndk = "28.2.13676358"  # Match local.properties
   ```

2. **Verify local.properties** (should already be correct)

3. **Gradle sync test**:
   ```bash
   cd android
   .\gradlew.bat dependencies  # Verify no conflicts
   ```

**Owner Action**: Fix NDK mismatch in libs.versions.toml
**Timing**: ~5 minutes

---

### BLOCKER 4: Dependency Version Conflicts
**Issue**: 18 packages have newer versions incompatible with constraints

**Key Outdated Packages**:
| Package | Current | Available | Priority |
|---------|---------|-----------|----------|
| sentry_flutter | 8.14.2 | 9.21.0 | HIGH (security) |
| go_router | 14.7.0 | 17.3.0 | MEDIUM |
| image | 4.8.0 | 4.9.1 | LOW |
| qr | 3.0.2 | 4.0.0 | MEDIUM |

**Fix Strategy**:
```bash
# Group 1: Security (Sentry)
flutter pub upgrade sentry_flutter
flutter build apk --debug  # Verify

# Group 2: Navigation (GoRouter)
flutter pub upgrade go_router
flutter build apk --debug

# Group 3: Utilities
flutter pub upgrade image qr
```

**Owner Action**: Sequential upgrade & test cycles
**Timing**: ~45 minutes

---

### BLOCKER 5: ProGuard & R8 Rules for Release Builds
**Issue**: ML Kit, Firebase, and Razorpay require custom ProGuard rules

**Fix Sequence**:
1. **Verify proguard-rules.pro** contains:
   ```proguard
   -keepclasseswithmembernames class * {
       native <methods>;
   }
   
   -keep class com.google.mlkit.** { *; }
   -keep class com.razorpay.** { *; }
   -keep class com.getkeepsafe.relinker.** { *; }
   ```

2. **Test release build**:
   ```bash
   flutter build apk --release
   ```

**Owner Action**: Expand proguard-rules.pro, test release build
**Timing**: ~20 minutes

---

### PHASE 16A Checkpoint: GO/NO-GO GATE 1
**Success Criteria**:
- [ ] `flutter build apk --debug` completes without errors
- [ ] `flutter build apk --release` completes without errors
- [ ] Git index repaired and `git status` works on Windows
- [ ] All 18 outdated packages assessed & updated
- [ ] ProGuard rules verified
- [ ] APK size < 200MB (typically 120–150MB)

**Estimated Timeline**: 5–7 days

---

## PHASE 16B: WIRE CORE FUNCTIONALITY (Week 2–3)
### Goal: Complete customer checkout, payment, and rider workflows

### Priority 1: Cart → Checkout → Payment Flow

**Files to Review/Wire**:
- `/lib/screens/customer/cart_screen.dart`
- `/lib/screens/customer/checkout_screen.dart`
- `/lib/services/cart_service.dart`
- `/lib/services/payment_service.dart`
- `/lib/providers/cart_provider.dart`

**Known Issues**:
1. Cart persistence loss when user switches tabs
2. Checkout address validation incomplete
3. Razorpay webhook may not update order status atomically

**Wiring Checklist**:
- [ ] Cart saves to Firestore on add/remove
- [ ] Real-time sync via `.snapshots()`
- [ ] Offline cache with Hive fallback
- [ ] Pincode format validation (6 digits)
- [ ] Delivery zone availability check
- [ ] GST calculation included
- [ ] Coupon application with validation
- [ ] Razorpay payment initiation
- [ ] Order created post-payment
- [ ] Email confirmation sent

**Testing Checkpoints**:
- [ ] Add 3 items to cart, verify all appear
- [ ] Close app, reopen, items still there
- [ ] Edit quantity, verify subtotal updates
- [ ] Enter pincode, see delivery charge calculated
- [ ] Apply coupon, verify discount applied
- [ ] Click Pay, Razorpay modal appears
- [ ] Complete payment, order created in Firestore

**Timing**: 3–4 days

---

### Priority 2: Email Notifications & FCM Setup

**Files to Wire**:
- `/lib/services/notification_service.dart`
- `/lib/services/email_service.dart`
- Cloud Functions: `onOrderCreated`, `onOrderStatusChange`

**Wiring Checklist**:
- [ ] FCM token obtained and saved to Firestore
- [ ] Topic subscription for user-specific notifications
- [ ] Foreground message handler implemented
- [ ] Background message handler set up
- [ ] Cloud Function triggers on order creation
- [ ] FCM notification sent to customer
- [ ] Email sent via SendGrid
- [ ] Deep link navigation on notification tap

**Testing Checkpoints**:
- [ ] FCM token in Firestore user doc
- [ ] Place order, FCM notification appears
- [ ] Click notification, navigates to order detail
- [ ] Email sent to registered email

**Timing**: 2–3 days

---

### Priority 3: Rider Dashboard & Live Tracking

**Files to Wire**:
- `/lib/screens/rider/rider_dashboard.dart`
- `/lib/screens/delivery/order_tracking_screen.dart`
- `/lib/services/delivery_tracking_service.dart`

**Wiring Checklist**:
- [ ] Stream of assigned orders loads
- [ ] Rider can accept order
- [ ] Order status changes to 'assigned'
- [ ] GPS tracking starts on app open
- [ ] Location updates to Firestore
- [ ] Customer sees live map
- [ ] Route polyline displays
- [ ] ETA recalculates as rider moves

**Testing Checkpoints**:
- [ ] Rider dashboard shows pending orders
- [ ] Accept order changes status
- [ ] GPS permission granted
- [ ] Location updates every 10–30 seconds
- [ ] Map displays customer location + destination
- [ ] Polyline shows route

**Timing**: 2–3 days

---

### Priority 4: Customer Signup & Wallet UI

**Files to Wire**:
- `/lib/screens/auth/signup_screen.dart`
- `/lib/screens/customer/wallet_screen.dart`
- `/lib/providers/wallet_provider.dart`
- `/lib/services/wallet_service.dart`

**Wiring Checklist**:
- [ ] Phone number validation
- [ ] Name & email input
- [ ] Referral code input optional
- [ ] User document created in Firestore
- [ ] Wallet initialized with ₹0 balance
- [ ] Referral bonus applied if code valid
- [ ] Transaction history displays
- [ ] Add Money button works (Razorpay flow)

**Testing Checkpoints**:
- [ ] New user signup with phone, name, email
- [ ] Wallet created with ₹0 balance
- [ ] Referral code input applies ₹200 bonus
- [ ] Transaction history appears
- [ ] Add Money button opens Razorpay

**Timing**: 1–2 days

---

### PHASE 16B Checkpoint: GO/NO-GO GATE 2
**Success Criteria**:
- [ ] Cart add/remove/update works end-to-end
- [ ] Checkout flow complete
- [ ] Payment via Razorpay integrates & creates order
- [ ] FCM & email notifications work
- [ ] Rider can accept & track delivery
- [ ] Customer sees live map
- [ ] New customer signup with referral bonus
- [ ] Wallet balance displays & updates

**Estimated Timeline**: 7–10 days

---

## PHASE 16C: APK BUILD & QA TESTING (Week 4)
### Goal: Build release-ready APK with comprehensive testing

### Build Commands

**Debug APK**:
```bash
flutter clean
flutter pub get
flutter build apk --debug --no-tree-shake-icons
# Output: build/app/outputs/apk/debug/app-debug.apk (~150–160 MB)
```

**Staging APK (split per architecture)**:
```bash
flutter build apk --release --split-per-abi
# Outputs:
# - app-armeabi-v7a-release.apk (~45 MB)
# - app-arm64-v8a-release.apk (~48 MB)
```

**App Bundle (for Play Store)**:
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab (~45 MB)
```

### QA Testing Checklist

**Phase 1: Smoke Tests (Day 1)**
```
☐ Phone login with OTP
☐ Google Sign-in
☐ OTP retry (rate limiter)
☐ Session persistence (force stop → reopen)
☐ Home screen loads, products display
☐ Category filter works
☐ Search bar autocomplete
☐ Product detail page (images, description, reviews)
```

**Phase 2: Core Workflows (Day 2–3)**
```
☐ Add product to cart
☐ Quantity +/- works
☐ Remove item from cart
☐ Cart persists after app restart
☐ Checkout address entry
☐ Pincode validation
☐ Delivery zone check
☐ Coupon code application
☐ Razorpay modal opens
☐ UPI/Card payment (test mode)
☐ Wallet deduction
☐ Order created in Firestore
☐ Order confirmation email sent
☐ Order appears in order history
☐ FCM notification on order placed
☐ Notification click navigates to order
```

**Phase 3: Rider & Delivery (Day 4)**
```
☐ Rider dashboard loads
☐ Pending orders list displays
☐ Accept order changes status
☐ Order detail shows address, items, total
☐ GPS permission granted
☐ Location updates every 10–30 seconds
☐ Map displays customer + destination
☐ Polyline shows route
☐ ETA updates as rider moves
```

**Phase 4: Edge Cases & Performance (Day 5)**
```
☐ Disable internet, try adding to cart
☐ Cart action queued locally
☐ Enable internet, queue processes
☐ Location permission (foreground + background)
☐ Notifications permission (POST_NOTIFICATIONS on Android 13+)
☐ Camera permission (QR scanner)
☐ Microphone permission (voice order)
☐ Cold start time < 5 seconds
☐ Product list scroll smooth (no jank)
☐ Search results < 500ms response time
☐ Memory footprint < 200 MB after 5 min use
```

### Performance Monitoring

**1. Enable Sentry Crash Reporting**:
   - Crashes auto-reported to Sentry
   - Review Sentry Issues tab for errors
   - Fix any pre-release crashes

**2. Enable Firebase Performance Monitoring**:
   - Monitor screen load times
   - API latency tracking
   - ANR detection

**3. APK Size Analysis**:
   ```bash
   flutter build appbundle --release --analyze-size
   ```
   - Expect: ~50 MB arm64
   - If > 80 MB, compress images or review dependencies

### PHASE 16C Checkpoint: GO/NO-GO GATE 3
**Success Criteria**:
- [ ] Debug APK builds & installs without crashes
- [ ] Release APK builds & runs smoothly
- [ ] App Bundle creates successfully
- [ ] 18/20 smoke tests pass
- [ ] Payment flow tested in Razorpay test mode
- [ ] Order created in Firestore post-payment
- [ ] Rider can accept & track delivery
- [ ] No new Sentry crashes
- [ ] APK size ≤ 80 MB (arm64)
- [ ] Cold start time < 5 seconds

**Estimated Timeline**: 5 days

---

## PHASE 16D: RELEASE READINESS & PLAY STORE SUBMISSION (Week 5)
### Goal: Submit app to Google Play Store for review

### Pre-Submission Checklist

**1. App Metadata & Assets**
```
☐ App title: "Fufaji's Online"
☐ Short description: "Shop local, pay online. Fast delivery."
☐ Full description: Key features & value proposition
☐ Screenshots (5):
  • Home screen with categories
  • Product detail page
  • Cart screen
  • Checkout screen
  • Order confirmation
☐ Feature graphic: 1024×500 px (landscape hero)
☐ App icon: 512×512 px (ic_launcher)
☐ Promo video: Optional (skip for v1)
```

**2. Compliance & Legal**
```
☐ Privacy Policy: https://fufajis.online/privacy
  • Data collection (location, payment, order history)
  • GDPR/CCPA compliance
  • User rights & data deletion
  
☐ Terms of Service: https://fufajis.online/terms
  • Liability disclaimer
  • Prohibited activities
  • Refund policy
  
☐ Contact Email: support@fufajis.online

☐ Content Rating Questionnaire:
  • Violence: NONE
  • Adult content: NONE
  • Location data: YES
  • Payment info: YES
  • Personal info: YES
  
☐ COPPA Compliance:
  • NOT COPPA-DESIGNATED (target age 13+)
```

**3. Technical Requirements**
```
☐ Target API Level: 35 (Android 15)
☐ Min SDK: 24 (Android 7.0)
☐ 64-bit ARM support: arm64-v8a + armeabi-v7a
☐ Permissions justified:
  • INTERNET: Orders, payments, notifications
  • LOCATION: Delivery address, rider tracking
  • CAMERA: QR code scanning
  • MICROPHONE: Voice order
  • POST_NOTIFICATIONS: Order updates
☐ No restricted permissions (SMS_READ, CALL_LOG, etc.)
☐ Signed APK ready
☐ Version Code: 5 → 6 (increment)
☐ Version Name: 1.2.1 → 1.3.0
```

**4. Store Listing Configuration**
```
☐ Category: Shopping
☐ Content Rating: Complete questionnaire
☐ Pricing: FREE
☐ Available in all countries: YES (or exclude as needed)
☐ Release rollout: STAGED
  • Start with 10% rollout
  • Monitor crashes for 24–48 hours
  • Expand to 50% → 100% if stable
```

### Release Configuration

**Update pubspec.yaml**:
```yaml
version: 1.3.0+6  # 1.3.0 (name), 6 (code)
```

**Update android/app/build.gradle**:
```gradle
defaultConfig {
    versionCode = 6
    versionName = "1.3.0"
}
```

### Release Notes Template

```
Version 1.3.0 Release Notes

[What's New]
✓ Complete checkout flow with address validation
✓ Real-time order tracking with live GPS map
✓ Razorpay payment integration (UPI, cards, wallet)
✓ FCM notifications for order updates
✓ Customer wallet with referral bonuses
✓ Rider dashboard for order management

[Bug Fixes]
✓ Fixed cart persistence on app restart
✓ Fixed delivery zone validation
✓ Improved search performance
✓ Fixed Kotlin/KGP compatibility issues

[Known Issues]
• Offline order queue may delay sync in low-connectivity areas

[Minimum Requirements]
• Android 7.0+ (API 24)
• 100 MB free storage
• Internet connection required
```

### Google Play Console Submission

1. **Create New Release**:
   - Go to Google Play Console > Fufaji's Online
   - Production > Create New Release
   - Upload app-release.aab

2. **Fill Store Listing**:
   - Title, description, screenshots, graphics
   - Content rating questionnaire

3. **Set Pricing & Distribution**:
   - Pricing: FREE
   - Countries: ALL
   - Rollout: Staged (10%)

4. **Submit for Review**:
   - Expected review: 2–7 days
   - Monitor for feedback

### Post-Submission Monitoring

**1. Review Status**:
   - Check Play Console daily
   - If rejected, fix & resubmit

**2. Crash Metrics**:
   - ANR rate < 1%
   - Crash rate < 0.5%
   - Sentry dashboard review

**3. User Feedback**:
   - Star rating (target 4.0+)
   - Top reviews & responses

**4. Analytics**:
   - DAU (Daily Active Users)
   - Retention rate (Day 1, 7, 30)
   - Funnel: install → login → first order

### PHASE 16D Checkpoint: SHIP!
**Success Criteria**:
- [ ] App approved & published in Play Store
- [ ] App visible in search
- [ ] Crash rate < 1%
- [ ] ANR rate < 1%
- [ ] Star rating ≥ 3.5

**Estimated Timeline**: 7–10 days

---

## CRITICAL FILES FOR IMPLEMENTATION

1. **`/lib/main.dart`** — App init, provider setup, routing, Firebase init
2. **`/lib/utils/app_router.dart`** — Route definitions, navigation guards
3. **`/android/app/build.gradle`** — Gradle config, signing, minification
4. **`/android/gradle/libs.versions.toml`** — SDK versions, Kotlin, NDK
5. **`/lib/services/payment_service.dart`** — Razorpay integration
6. **`/lib/providers/cart_provider.dart`** — Cart state & Firestore sync
7. **`/lib/services/notification_service.dart`** — FCM setup
8. **`/lib/screens/customer/checkout_screen.dart`** — Address, delivery validation
9. **`/lib/services/delivery_tracking_service.dart`** — GPS tracking
10. **`/lib/screens/rider/rider_dashboard.dart`** — Order management
11. **`/pubspec.yaml`** — Dependencies, version constraints
12. **`/android/app/proguard-rules.pro`** — R8 minification
13. **`/android/app/src/main/AndroidManifest.xml`** — Permissions, activities

---

## TIMELINE SUMMARY

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| 16A | 5–7 days | Clean `flutter build apk` |
| 16B | 7–10 days | Cart→Payment, Notifications, Rider tracking |
| 16C | 5 days | Debug APK, Release APK, QA testing |
| 16D | 7–10 days | Play Store submission & approval |
| **Total** | **24–32 days** | **Published in Play Store** |

---

## CONCLUSION

This comprehensive plan provides everything needed to complete the Fufaji Store Android app and release it on Google Play Store. Follow the phases sequentially, verify each GO/NO-GO gate, and escalate blockers to Gemini AI code review as needed.

**Success = Ship v1.3.0 by early July 2026** 🚀
