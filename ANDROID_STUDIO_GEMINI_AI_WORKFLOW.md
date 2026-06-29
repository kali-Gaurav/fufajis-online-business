# ANDROID STUDIO + GEMINI AI WORKFLOW
## Completing Fufaji Android App Build & Release

---

## OVERVIEW

This guide explains how to use **Android Studio** (IDE) and **Gemini AI** (code review/debugging) together to:
1. Fix build failures
2. Wire remaining functionalities
3. Build & test APK
4. Prepare for Play Store release

**Note**: Fufaji is built with **Flutter** (not pure Android), so Android Studio's primary role is:
- Android Gradle build system management
- Emulator/device testing
- Profiling & crash debugging
- APK signing & release configuration

---

## PART 1: ANDROID STUDIO SETUP FOR FLUTTER

### 1.1 Open Project in Android Studio

```
File → Open → C:\Projects\fufaji-online-business
```

### 1.2 Verify Android Environment

**Check Android SDK Installation**:
- `Tools → SDK Manager`
- Verify installed:
  - ✅ Android SDK Platform 35 (Android 15)
  - ✅ Android SDK Build-tools 35.0.0+
  - ✅ Android NDK 28.2.13676358
  - ✅ Android Emulator

**Check Project SDK**:
- `File → Project Structure → SDK Location`
- Should show:
  - Android SDK path: `C:\Android\Sdk` (or your path)
  - JDK: Java 17 (set `JAVA_HOME=C:\Program Files\Java\jdk-17.0.x`)
  - NDK: 28.2.13676358

### 1.3 Sync Gradle

1. **Open Gradle Console**: `View → Tool Windows → Gradle`
2. **Refresh Gradle**: Click ⟳ icon or run:
   ```bash
   cd android
   .\gradlew.bat clean
   .\gradlew.bat --refresh-dependencies
   ```
3. **Check for errors** in Gradle Sync output

---

## PART 2: GEMINI AI FOR BUILD DEBUGGING

### 2.1 When to Use Gemini AI

**Use Gemini AI for:**
- Kotlin Gradle Plugin (KGP) compatibility errors
- Gradle dependency resolution failures
- ProGuard/R8 minification issues
- Plugin version conflicts
- Class-file format errors
- Manifest merging failures

**DO NOT use Gemini AI for:**
- Feature implementation (use Android Studio + Flutter documentation)
- UI/UX issues (use Flutter Preview/Emulator)
- Runtime crashes (use Sentry + logcat first)

### 2.2 Escalate to Gemini AI: Step-by-Step

**Step 1: Reproduce & Capture Error**
```bash
cd C:\Projects\fufaji-online-business
flutter clean
flutter pub get
flutter build apk --debug 2>&1 | tee build.log
```

**Step 2: Extract Error Summary**
Open `build.log` and copy the relevant section:
- Search for `BUILD FAILED` or `ERROR`
- Copy 10–20 lines of context before/after error
- Include the full error message (usually 3–5 lines)

**Example**:
```
BUILD FAILED
Task: :app:compileReleaseKotlin
Error: Kotlin Gradle Plugin (KGP) error
Caused by: Class 'com.android.build.gradle.AppPlugin' not found
Location: android/app/build.gradle:3
```

**Step 3: Provide Context to Gemini AI**

**For build.gradle errors**, provide:
```
ERROR: [Your Error Message]
FILE: android/app/build.gradle
CONTEXT: [Relevant snippet from build.gradle, ~10 lines around error]
PUBSPEC: [Your pubspec.yaml dependencies section]
FLUTTER_VERSION: [Output of `flutter --version`]
```

**For Kotlin/KGP errors**, provide:
```
ERROR: [Your Error Message]
AFFECTED_PACKAGE: [Package causing issue, e.g., camera_android_camerax]
CURRENT_VERSION: [From pubspec.yaml]
FLUTTER_DOCTOR: [Output of `flutter doctor -v`]
GRADLE_LOG: [Gradle build log excerpt, 20 lines]
```

**For Dependency conflicts**, provide:
```
ERROR: [Your Error Message]
DEPENDENCY_TREE: [Output of `flutter pub deps --style=tree`]
PUBSPEC: [Full pubspec.yaml]
FLUTTER_BUILD_OUTPUT: [Full output of `flutter build apk --debug` failure]
```

### 2.3 Example Gemini AI Conversation

**You ask Gemini AI**:
```
ERROR: "Kotlin Gradle Plugin (KGP) is not compatible with Kotlin 2.1.0"

FILE: android/app/build.gradle
```
id "com.android.application"
id "com.google.gms.google-services"
id "org.jetbrains.kotlin.android"  # ← This line causing issue
```

CURRENT PUBSPEC VERSIONS:
- camera: ^0.7.2
- firebase_analytics: ^11.4.0
- sentry_flutter: ^8.14.2

FLUTTER_VERSION: 3.27.1
DART_VERSION: 3.5.0

What do I do to fix this?
```

**Gemini AI responds**:
```
The issue is that your plugins (camera_android_camerax, sentry_flutter, etc.) 
are compiled with older KGP and don't support Kotlin 2.1.0.

FIX (in order):
1. Remove explicit `org.jetbrains.kotlin.android` from build.gradle
   - The Flutter Gradle plugin handles Kotlin configuration
   
2. Update pubspec.yaml to KGP-compatible versions:
   camera: ^0.12.0  # camera_android_camerax 0.12+ supports latest KGP
   sentry_flutter: ^9.21.0
   speech_to_text: ^7.5.0
   
3. Run:
   flutter clean
   flutter pub get
   flutter build apk --debug
```

---

## PART 3: ANDROID STUDIO FOR FEATURE WIRING

### 3.1 Dart/Flutter Plugin Setup

**Install Flutter & Dart plugins** (if not already):
1. `File → Settings → Plugins`
2. Search: "Flutter" → Install
3. Search: "Dart" → Install
4. Restart Android Studio

### 3.2 Running App on Emulator

**Start Emulator**:
1. `Tools → Device Manager`
2. Click ▶️ (Play) on "Pixel 6 API 35" (or create new)

**Run App on Emulator**:
```bash
flutter run -v
```
or in Android Studio:
```
Run → Run 'main.dart'
```

**Hot Reload** (for rapid development):
- Code → Hot Reload (or press `r` in terminal)
- Reloads Dart code without restarting app

### 3.3 File Navigation for Feature Wiring

**Phase 16B Features** (from Feature Wiring):

**1. Cart → Checkout → Payment**:
- Right-click in Android Studio → `Go to File`
- Open in sequence:
  1. `lib/providers/cart_provider.dart`
  2. `lib/screens/customer/cart_screen.dart`
  3. `lib/screens/customer/checkout_screen.dart`
  4. `lib/services/payment_service.dart`

**2. Notifications**:
1. `lib/services/notification_service.dart`
2. `lib/services/email_service.dart`
3. `functions/src/notifications.ts` (Cloud Functions, in separate window)

**3. Rider Tracking**:
1. `lib/screens/rider/rider_dashboard.dart`
2. `lib/services/delivery_tracking_service.dart`
3. `lib/screens/delivery/order_tracking_screen.dart`

**4. Customer Signup & Wallet**:
1. `lib/screens/auth/signup_screen.dart`
2. `lib/screens/customer/wallet_screen.dart`
3. `lib/providers/wallet_provider.dart`

### 3.4 Code Review in Android Studio

**To review wired features**:

1. **Open file** (e.g., `cart_provider.dart`)
2. **Review critical methods**:
   - `addToCart()` — Should sync to Firestore
   - `removeItem()` — Should update Firestore
   - `getCart()` — Should stream from Firestore
3. **Test via debugger**:
   - Set breakpoint in method
   - Click Run → Debug 'main.dart'
   - Trigger action (add to cart)
   - Inspect variables, step through code

---

## PART 4: BUILDING APK IN ANDROID STUDIO

### 4.1 Build Menu

**Access Build Menu**:
```
Build → Flutter → Build APK
```
or
```
Build → Build Bundle(s) / APK(s) → Build APK(s)
```

### 4.2 Build Configuration

**Select Build Type**:
- **Debug**: For testing (unoptimized, ~150 MB)
- **Release**: For Play Store (optimized, ~48 MB arm64)

**For Release Build**:
1. Ensure `android/app/key.properties` exists:
   ```properties
   storeFile=fufaji-upload-key.jks
   storePassword=YourPasswordHere
   keyAlias=fufaji_key
   keyPassword=YourPasswordHere
   ```

2. Build → Build Bundle(s) / APK(s) → Build Signed Bundle/APK
   - Select "APK"
   - Choose keystore (fufaji-upload-key.jks)
   - Fill password fields
   - Verify Version Code (6) & Version Name (1.3.0)

3. Click **Build**

### 4.3 APK Output Location

**Debug APK**:
```
build/app/outputs/apk/debug/app-debug.apk
```

**Release APK (split per ABI)**:
```
build/app/outputs/apk/release/
├── app-armeabi-v7a-release.apk (~45 MB)
└── app-arm64-v8a-release.apk (~48 MB)
```

**App Bundle** (for Play Store):
```
build/app/outputs/bundle/release/app-release.aab (~45 MB)
```

---

## PART 5: TESTING & PROFILING

### 5.1 Install APK on Emulator/Device

**Via Android Studio**:
1. Build APK (see 4.1)
2. `Run → Run 'main.dart'` (auto-installs on emulator)

**Via Command Line**:
```bash
adb install -r build/app/outputs/apk/debug/app-debug.apk
```

### 5.2 Monitor Logs

**View Logs in Android Studio**:
1. `View → Tool Windows → Logcat`
2. Filter by:
   - `com.fufajis.online` (app logs)
   - `flutter` (Flutter framework logs)

**Search for crashes**:
```
Filter: "FATAL ERROR" or "Exception"
```

### 5.3 Profile Performance

**CPU Usage**:
1. `View → Tool Windows → Profiler`
2. Start recording
3. Perform action (add to cart, navigate)
4. Stop recording
5. Review CPU timeline

**Memory Usage**:
1. Same as above
2. Check memory allocations
3. Look for spikes or leaks

**Frame Rendering**:
1. Device → Show System Wide CPU Usage
2. Monitor jank in scrolling/animations
3. Target: 60 FPS (no red frames)

### 5.4 Crash Debugging

**If app crashes on emulator**:
1. Check Logcat for `Exception` stack trace
2. Scroll up to find root cause
3. Note file name + line number
4. Open file in editor (click file path in logcat)
5. Add debugging:
   ```dart
   print('DEBUG: Reached point X with value $y');
   ```
6. Hot reload (`r`) and test again

---

## PART 6: RELEASE CHECKLIST (Android Studio)

### 6.1 Pre-Release Verification

**In Android Studio**, verify:

1. **AndroidManifest.xml**:
   - Open `android/app/src/main/AndroidManifest.xml`
   - Check:
     - ✅ `package="com.fufajis.online"`
     - ✅ All required permissions present (INTERNET, LOCATION, CAMERA, POST_NOTIFICATIONS)
     - ✅ Deep links configured (if any)

2. **build.gradle Signing**:
   - Open `android/app/build.gradle`
   - Verify `signingConfigs` block:
     ```gradle
     signingConfigs {
       release {
         storeFile file("../key.properties")
         storePassword System.getenv("KEYSTORE_PASSWORD")
         keyAlias "fufaji_key"
         keyPassword System.getenv("KEY_PASSWORD")
       }
     }
     buildTypes {
       release {
         signingConfig signingConfigs.release
         minifyEnabled true
         proguardFiles getDefaultProguardFile(...)
       }
     }
     ```

3. **Versioning**:
   - `defaultConfig` section:
     ```gradle
     versionCode 6  # Incremented for this release
     versionName "1.3.0"  # Semantic versioning
     ```

### 6.2 Final Build

**Build Release APK**:
```bash
cd C:\Projects\fufaji-online-business
flutter build apk --release --split-per-abi
```

**Verify Output**:
```bash
ls -lah build/app/outputs/apk/release/
# Should show two files:
# app-armeabi-v7a-release.apk (~45 MB)
# app-arm64-v8a-release.apk (~48 MB)
```

### 6.3 Test Release APK

```bash
adb install -r build/app/outputs/apk/release/app-arm64-v8a-release.apk
adb shell am start -n com.fufajis.online/.MainActivity
adb logcat  # Monitor for crashes
```

**Quick Tests**:
- [ ] App launches without errors
- [ ] Login works
- [ ] Add product to cart
- [ ] Proceed to checkout
- [ ] Click payment button
- [ ] No Sentry crashes in 1 minute

---

## PART 7: PLAY STORE SUBMISSION

### 7.1 Prepare Assets in Android Studio

**App Icon**:
- Should already be at: `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- Verify size: 512×512 px minimum

**Verify in build.gradle**:
```gradle
android {
  ...
  defaultConfig {
    applicationId = "com.fufajis.online"
  }
}
```

### 7.2 Generate App Bundle

**In Android Studio**:
```
Build → Build Bundle(s) / APK(s) → Build Bundle(s)
```
or via CLI:
```bash
flutter build appbundle --release
```

**Output**:
```
build/app/outputs/bundle/release/app-release.aab (~45 MB)
```

### 7.3 Verify Signing

```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
# Should show your certificate info
```

---

## PART 8: CONTINUOUS INTEGRATION WITH GEMINI AI

### 8.1 Gemini AI for Post-Launch Issues

**If crash reported post-launch**:

**Step 1**: Check Sentry dashboard
```
Sentry.io → Fufaji's Online → Issues
```

**Step 2**: Click crash, copy stack trace

**Step 3**: Ask Gemini AI:
```
I have a crash in production (Fufaji v1.3.0, Android API 28):

STACK TRACE:
java.lang.NullPointerException: Attempt to invoke virtual method 'double android.location.Location.getLatitude()' on a null object reference
  at com.fufajis.online.delivery.DeliveryTrackingService.startTracking(DeliveryTrackingService.kt:45)
  at com.fufajis.online.rider.RiderDashboardActivity.onLocationUpdate(RiderDashboardActivity.kt:78)

This is affecting 5% of users. What's the fix?
```

**Step 4**: Gemini AI suggests fix (add null check, handle permission denial, etc.)

**Step 5**: Implement fix in Android Studio, test locally, build hotfix APK

**Step 6**: Upload hotfix to Play Store with explanation

---

## WORKFLOW SUMMARY

### Phase 16A (Build Fixes)
```
Android Studio Role: Gradle sync, error messages
Gemini AI Role: Debug KGP/Gradle errors

Daily Workflow:
1. Android Studio → Build → Build APK (debug)
2. If error → Copy error message
3. Escalate to Gemini AI with context
4. Gemini AI suggests fix (dependency version, Gradle config)
5. Implement fix in Android Studio
6. Rebuild until success
```

### Phase 16B (Feature Wiring)
```
Android Studio Role: Code editing, hot reload, emulator testing
Gemini AI Role: Code review (optional), architecture guidance

Daily Workflow:
1. Android Studio → Open file (cart_provider.dart)
2. Edit code (add Firestore sync)
3. Hot reload (press 'r') to test
4. Debug with breakpoints if needed
5. Repeat for next file
6. Escalate to Gemini AI only if stuck on logic
```

### Phase 16C (APK Build & QA)
```
Android Studio Role: Build APK, install on emulator/device
Gemini AI Role: Crash debugging (from Sentry stack trace)

Daily Workflow:
1. Android Studio → Build → Build APK (debug + release)
2. Install APK on emulator
3. Test features (cart, payment, notifications)
4. If crash → Check Logcat for exception
5. Escalate to Gemini AI with Logcat + stack trace
6. Fix, rebuild, test again
```

### Phase 16D (Release)
```
Android Studio Role: Build release APK/Bundle, verify signing
Gemini AI Role: None (release is configuration-only)

Workflow:
1. Android Studio → Build → Build Bundle (signed)
2. Verify output size < 50 MB
3. Upload to Google Play Console
4. Monitor Crash Rate dashboard (Sentry)
5. Post-launch: Use Sentry + Gemini AI for hotfixes
```

---

## KEYBOARD SHORTCUTS (Android Studio)

| Action | Shortcut |
|--------|----------|
| Find file | Ctrl+Shift+O |
| Find in files | Ctrl+Shift+F |
| Go to line | Ctrl+G |
| Run app | Shift+F10 |
| Debug app | Shift+F9 |
| Hot reload (running) | Ctrl+Alt+R (or `r` in terminal) |
| Toggle breakpoint | Ctrl+F8 |
| Step into | F7 |
| Reformat code | Ctrl+Alt+L |
| Comment/uncomment | Ctrl+/ |

---

## TROUBLESHOOTING QUICK LINKS

| Issue | Solution |
|-------|----------|
| "Gradle sync failed" | Android Studio → File → Sync Now |
| "Emulator not starting" | Device Manager → Wipe Data → Start |
| "App crashes immediately" | Logcat → Search "Exception" → Note line number |
| "Slow hot reload" | Flutter → Clean → Build → Run |
| "APK too large (> 200 MB)" | Analyze Size → Remove unused assets |

---

## NEXT STEPS

✅ **Step 1**: Set up Android Studio (Section 1)
✅ **Step 2**: Follow Phase 16A Quick Start (PHASE_16A_QUICK_START.md)
✅ **Step 3**: For each blocker, escalate to Gemini AI (Section 2)
✅ **Step 4**: Wire features (Section 3)
✅ **Step 5**: Build & test (Section 5)
✅ **Step 6**: Release (Section 7)

**Good luck! 🚀**
