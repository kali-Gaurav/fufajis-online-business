# PHASE 16A: BUILD FIX — QUICK START CHECKLIST
## Complete in 5–7 days to unlock Phase 16B

---

## DAY 1: GIT REPAIR + DIAGNOSTICS

### 1. REPAIR GIT INDEX (Windows Machine)
```powershell
cd C:\Projects\fufaji-online-business
cd .git
rm index
git reset --mixed
git status  # Should show files ready to commit
```
**If git still fails**:
```powershell
git fsck --full --strict
git gc --aggressive
git log --oneline -1  # Verify HEAD is intact
```
✅ **Success**: `git status` returns without errors

---

### 2. ENVIRONMENT VERIFICATION
```bash
flutter doctor -v
# Check:
# - Flutter SDK ✓
# - Dart SDK ✓
# - Android SDK API 35 ✓
# - Android NDK 28.2.13676358 ✓
# - Java 17 ✓
```

✅ **Success**: No ✗ marks in `flutter doctor`

---

### 3. INITIAL BUILD TEST (expect failure to establish baseline)
```bash
cd C:\Projects\fufaji-online-business
flutter clean
flutter pub get
flutter build apk --debug 2>&1 | tee build.log
```

**Common first errors**:
- `Kotlin Gradle Plugin (KGP)` errors → Skip, fix in Day 2
- `Unsupported class-file format version` → SDK mismatch → Skip, fix in Day 3
- Dependency resolution conflicts → Skip, fix in Day 4

✅ **Success**: Save `build.log` for Phase 16A debugging

---

## DAY 2: KOTLIN/KGP PLUGIN COMPATIBILITY

### 1. IDENTIFY KGP-INCOMPATIBLE PACKAGES
Check `pubspec.yaml` for these packages:
```
camera: ^0.7.2          → Needs camera: ^0.12.0+
firebase_analytics: *   → Check version in pubspec
firebase_app_check: *   → Check version in pubspec
google_mlkit_* : *      → Usually need updates
image_picker: ^1.2.2    → Needs ^1.3.0+
mobile_scanner: ^6.0.0  → Needs ^6.1.0+
sentry_flutter: ^8.14.2 → Needs ^9.21.0
speech_to_text: *       → Check version
```

### 2. UPDATE PUBSPEC.YAML (Sequential, not mass)
```bash
# STEP 1: Update Sentry (security priority)
flutter pub upgrade sentry_flutter
flutter build apk --debug
# If succeeds → continue
# If fails → revert: flutter pub downgrade sentry_flutter

# STEP 2: Update Camera
flutter pub upgrade camera
flutter build apk --debug

# STEP 3: Update other packages one-by-one
flutter pub upgrade image_picker
flutter build apk --debug

flutter pub upgrade mobile_scanner
flutter build apk --debug

flutter pub upgrade speech_to_text
flutter build apk --debug

# STEP 4: Final check
flutter pub upgrade  # All others
flutter build apk --debug
```

✅ **Success**: At least 2 packages updated without breaking build

---

## DAY 3: SDK VERSION & NDK ALIGNMENT

### 1. CHECK CURRENT VERSIONS
```bash
# Read current Android config
type android\gradle\libs.versions.toml | findstr "compileSdk\|minSdk\|targetSdk\|ndk"
# Read local properties
type android\local.properties | findstr "flutter.sdk\|flutter.ndkVersion"
```

**Expected output**:
```
compileSdk = "35"
minSdk = "24"
targetSdk = "35"
ndk = "28.2.13676358"  (should match local.properties)
```

### 2. FIX NDK MISMATCH (if present)
Edit `android/gradle/libs.versions.toml`:
```toml
[versions]
ndk = "28.2.13676358"  # Change this line only
compileSdk = "35"
minSdk = "24"
targetSdk = "35"
```

### 3. GRADLE SYNC CHECK
```bash
cd android
.\gradlew.bat dependencies --refresh-dependencies
# Should complete without "FAILED" messages
cd ..
```

✅ **Success**: `flutter doctor` shows Android SDK configured correctly

---

## DAY 4: DEPENDENCY VERSION CONFLICT RESOLUTION

### 1. CHECK OUTDATED PACKAGES
```bash
flutter pub outdated | tee outdated.txt
# Priority: HIGH (security) → MEDIUM → LOW
```

### 2. SELECTIVE UPGRADE (High Priority Only)
```bash
# Only upgrade HIGH priority items
flutter pub upgrade go_router  # HIGH (navigation edge cases)

# Test after each
flutter build apk --debug
```

### 3. LOCK PROBLEMATIC VERSIONS (if breaking)
If an upgrade breaks build, lock it in `pubspec.yaml`:
```yaml
dependency_overrides:
  go_router: 14.7.0  # Keep working version
```

✅ **Success**: `flutter pub outdated` shows ≤10 medium/low items remaining

---

## DAY 5: PROGUARD & R8 RULES

### 1. VERIFY PROGUARD-RULES.PRO EXISTS
```bash
type android\app\proguard-rules.pro
```

Should contain:
```proguard
# Native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Firebase
-keep class com.google.firebase.** { *; }

# ML Kit
-keep class com.google.mlkit.** { *; }

# Razorpay
-keep class com.razorpay.** { *; }

# Relinker
-keep class com.getkeepsafe.relinker.** { *; }
```

### 2. ADD MISSING RULES
If missing any of the above, add them to `android/app/proguard-rules.pro`

### 3. TEST RELEASE BUILD
```bash
flutter build apk --release --split-per-abi
# Should produce:
#   build/app/outputs/apk/release/app-armeabi-v7a-release.apk (~45 MB)
#   build/app/outputs/apk/release/app-arm64-v8a-release.apk (~48 MB)
```

✅ **Success**: Release APK builds without errors

---

## DAY 6–7: FINAL VALIDATION & GATE 1

### 1. FINAL CLEAN BUILD (Debug)
```bash
flutter clean
flutter pub get
flutter build apk --debug --no-tree-shake-icons
# Output: build/app/outputs/apk/debug/app-debug.apk (~150 MB)
```

✅ Check: APK size < 200 MB

### 2. FINAL CLEAN BUILD (Release)
```bash
flutter build apk --release --split-per-abi
# Output: Two APKs for arm64-v8a + armeabi-v7a
```

✅ Check: Both APKs size < 50 MB each

### 3. INSTALL & BASIC TEST
```bash
# Install debug APK on emulator/device
adb install -r build/app/outputs/apk/debug/app-debug.apk

# Launch app
adb shell am start -n com.fufajis.online/.MainActivity

# Check logs for crashes
adb logcat | findstr "FATAL\|ERROR"
```

✅ Check: App launches, no immediate crashes

### 4. GIT COMMIT
```bash
git add .
git commit -m "Phase 16A: Build fix - KGP compat, SDK alignment, ProGuard rules"
git log --oneline -1  # Verify commit succeeded
```

✅ Check: Commit created successfully

---

## GO/NO-GO GATE 1 VERIFICATION

**Run this command to verify all success criteria**:
```bash
# Check 1: Debug APK exists
ls -la build/app/outputs/apk/debug/app-debug.apk

# Check 2: Release APK exists
ls -la build/app/outputs/apk/release/app-*-release.apk

# Check 3: Git is clean
git status  # Should show "nothing to commit, working tree clean"

# Check 4: No build errors
flutter build apk --debug 2>&1 | grep -i "error" | wc -l  # Should be 0

# Check 5: APK sizes
du -h build/app/outputs/apk/debug/app-debug.apk
du -h build/app/outputs/apk/release/app-*-release.apk
```

---

## TROUBLESHOOTING QUICK REFERENCE

### "Kotlin Gradle Plugin (KGP) is not compatible"
```bash
flutter pub upgrade sentry_flutter camera image_picker
# OR downgrade AGP if needed
```

### "Unsupported class-file format version 65"
→ Java 21+ detected, need Java 17
```bash
# Set JAVA_HOME to Java 17
set JAVA_HOME=C:\Program Files\Java\jdk-17.0.x
flutter clean && flutter build apk --debug
```

### "Dependency conflict: X requires Y"
```bash
# Check which packages need which versions
flutter pub deps --style=tree | grep -A2 problematic_package

# Lock the working version
# Add to pubspec.yaml dependency_overrides
```

### "Permission denied" on Windows
→ Git index corruption (address in Day 1)

---

## TIMELINE

| Day | Task | Success Indicator |
|-----|------|------------------|
| 1 | Git repair + diagnostics | `git status` works |
| 2 | Kotlin/KGP updates | 2+ packages upgraded successfully |
| 3 | SDK/NDK alignment | `flutter doctor` clean |
| 4 | Dependency resolution | 10 or fewer medium/low items outdated |
| 5 | ProGuard rules | Release APK builds |
| 6–7 | Final validation | Both debug + release APKs < 200 MB |

---

## NEXT STEPS (Once Gate 1 Passes)

→ **Phase 16B: Wire Core Functionality** (7–10 days)
   - Cart → Checkout → Payment flow
   - Email & FCM notifications
   - Rider dashboard & GPS tracking
   - Customer signup & wallet

Start Phase 16B once:
- [ ] All 4 success criteria from Gate 1 verified
- [ ] Your team is ready to wire features (not just build fixes)

---

## NEED HELP?

If blocked on any day:
1. Save the error output: `flutter build apk --debug 2>&1 > error.log`
2. Escalate with:
   - `error.log` content
   - Output of `flutter doctor -v`
   - Which day you're on
   - Exact steps you ran

**Gemini AI Code Review**: Available for KGP, ProGuard, Gradle issues.
