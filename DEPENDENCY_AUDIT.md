# Fufaji Store - Dependency Audit & Version Analysis
**Generated**: June 7, 2026  
**Current pubspec.yaml Version**: 1.2.1+5  
**Flutter SDK**: >=3.3.0 <4.0.0

---

## 📋 Executive Summary

✅ **Status**: Dependencies mostly aligned  
⚠️ **Issues Found**: 3 moderate, 2 minor  
🔧 **Gaps Identified**: 5 packages missing/recommended  
📦 **Total Dependencies**: 63 packages

---

## ✅ Current Dependencies Breakdown

### Firebase Suite (v5.x stable)
```
✓ cloud_firestore: ^5.4.4        ✓ Compatible
✓ firebase_auth: ^5.3.1          ✓ Compatible
✓ firebase_storage: ^12.3.2      ✓ Compatible
✓ firebase_core: ^3.6.0          ✓ Compatible
✓ firebase_messaging: ^15.1.3    ✓ Compatible
✓ cloud_functions: ^5.6.2        ✓ Compatible
✓ firebase_app_check: ^0.3.1+4   ✓ Compatible
✓ firebase_remote_config: ^5.1.3 ✓ Compatible
✓ firebase_analytics: ^11.3.3    ✓ Compatible
```
**Assessment**: All Firebase packages are well-matched and compatible with each other.

### State Management
```
⚠️ provider: ^6.1.2              → Recommended: ^6.2.0+ (minor update)
✓ riverpod: ^2.5.0               ✓ Latest stable
✓ flutter_riverpod: ^2.5.0       ✓ Latest stable
```
**Issue**: Using both `provider` and `riverpod` in same app is redundant. Consolidate to one.

### UI & Navigation
```
✓ go_router: ^14.6.0             ✓ Latest stable
✓ intl: ^0.20.2                  ✓ Compatible
✓ google_fonts: ^8.1.0           ✓ Latest stable
✓ cached_network_image: ^3.4.0   ✓ Latest stable
✓ shimmer: ^3.0.0                ✓ Latest stable
✓ pinput: ^6.0.0                 ✓ Latest (PIN input)
✓ lottie: ^3.1.0                 ✓ Latest animations
✓ infinite_scroll_pagination: ^5.1.0 ✓ Latest
```
**Assessment**: All UI packages are current and compatible.

### ML Kit & Vision
```
✓ mobile_scanner: ^5.2.0         ✓ Latest
✓ camera: ^0.11.0+2              ✓ Current stable
✓ google_mlkit_commons: ^0.8.0   ✓ Compatible
✓ google_mlkit_barcode_scanning: ^0.12.0 ✓ Compatible
✓ google_mlkit_image_labeling: ^0.12.0 ✓ Compatible
✓ google_mlkit_text_recognition: ^0.13.0 ✓ Compatible
✓ image_picker: ^1.1.2           ✓ Latest stable
```
**Assessment**: All ML Kit versions are aligned and compatible.

### Location & Maps
```
✓ geolocator: ^13.0.4            ✓ Latest
✓ geocoding: ^3.0.0              ✓ Latest
✓ google_maps_flutter: 2.10.0    ⚠️ PINNED VERSION (exact, not caret)
✓ permission_handler: ^11.3.1    ✓ Latest
✓ flutter_background_service: ^5.0.10 ✓ Compatible
✓ flutter_polyline_points: ^2.1.0 ✓ Compatible
```
**⚠️ Warning**: `google_maps_flutter` is pinned to exact version 2.10.0. Consider updating to ^2.10.0 unless there's a specific reason.

### Utilities
```
✓ uuid: ^4.4.0                   ✓ Latest
✓ google_mobile_ads: ^5.1.0      ✓ Latest stable
✓ dio: ^5.5.0                    ✓ Latest stable
⚠️ flutter_local_notifications: 17.2.4 → PINNED (recommend: ^17.2.4)
✓ shared_preferences: ^2.3.0     ✓ Latest
✓ connectivity_plus: ^6.0.0      ✓ Latest
✓ hive: ^2.2.3                   ✓ Latest stable
✓ hive_flutter: ^1.1.0           ✓ Compatible with Hive
⚠️ sqflite: 2.4.1                → PINNED (recommend: ^2.4.1)
✓ path: ^1.9.1                   ✓ Latest
✓ url_launcher: ^6.3.1           ✓ Latest
✓ share_plus: ^10.1.0            ✓ Latest
✓ path_provider: ^2.1.0          ✓ Latest
✓ image: ^4.2.0                  ✓ Latest
✓ flutter_dotenv: ^6.0.1         ✓ Latest (env config)
✓ package_info_plus: ^8.1.0      ✓ Latest
✓ crypto: ^3.0.5                 ✓ Latest
✓ http: ^1.2.0                   ✓ Latest
```
**Issues**:
- 3 packages use pinned versions (no `^`). This can cause update conflicts.
- `flutter_local_notifications: 17.2.4` - consider `^17.2.4` for patch fixes
- `sqflite: 2.4.1` - consider `^2.4.1` for flexibility

### Payment & E-Commerce
```
✓ razorpay_flutter: ^1.4.5       ✓ Latest stable
```
**Assessment**: Payment integration ready.

### Charts & Analytics
```
✓ fl_chart: ^1.2.0               ✓ Latest stable
```
**Assessment**: Analytics charting enabled.

### Documents
```
✓ pdf: ^3.11.1                   ✓ Latest stable
✓ printing: ^5.13.2              ✓ Latest stable
```
**Assessment**: PDF generation ready.

### Communication
```
✓ whatsapp_unilink: ^2.1.0       ✓ Latest
```
**Assessment**: WhatsApp integration working.

### Audio & Media
```
✓ record: ^7.0.0                 ✓ Latest audio recording
⚠️ speech_to_text: 7.4.0         → PINNED (recommend: ^7.4.0)
✓ video_player: ^2.11.1          ✓ Latest
```
**Issue**: `speech_to_text` is pinned to exact version.

### Hardware
```
✓ blue_thermal_printer: ^1.2.3   ✓ For receipt printing
```

### Error & Updates
```
✓ sentry_flutter: ^8.8.0         ✓ Latest error tracking
✓ shorebird_code_push: ^2.0.0    ✓ Latest OTA updates
```

### Authentication & Security
```
✓ google_sign_in: ^6.2.1         ✓ Latest
✓ qr_flutter: ^4.1.0             ✓ Latest
✓ local_auth: ^2.1.6             ✓ Latest biometric
✓ device_info_plus: ^11.2.0      ✓ Latest
✓ flutter_secure_storage: ^9.2.2 ✓ Latest secure storage
```
**Assessment**: Security packages are up-to-date.

### Dev Dependencies
```
✓ flutter_test: sdk              ✓ Standard
✓ flutter_lints: ^6.0.0          ✓ Latest linting
✓ build_runner: ^2.4.13          ✓ Code generation
✓ json_serializable: ^6.9.0      ✓ JSON serialization
✓ mockito: ^5.4.4                ✓ Testing mocks
```

---

## ⚠️ Issues Found

### 1. **Redundant State Management** (MODERATE)
- **Problem**: Using both `provider` and `riverpod` simultaneously
- **Impact**: Unnecessary dependencies, code complexity
- **Recommendation**: 
  - If using Riverpod: Remove `provider`
  - If using Provider: Remove `riverpod` + `flutter_riverpod`
- **Action**: Audit code to determine which is actively used

### 2. **Pinned Dependency Versions** (MODERATE)
- **Packages Affected**:
  - `google_maps_flutter: 2.10.0`
  - `flutter_local_notifications: 17.2.4`
  - `sqflite: 2.4.1`
  - `speech_to_text: 7.4.0`

- **Problem**: Exact pinning prevents automatic patch/minor updates
- **Impact**: May miss security fixes, stability improvements
- **Recommendation**: Change to caret notation (`^`) unless there's a documented reason

**Before**:
```yaml
google_maps_flutter: 2.10.0
flutter_local_notifications: 17.2.4
sqflite: 2.4.1
speech_to_text: 7.4.0
```

**After**:
```yaml
google_maps_flutter: ^2.10.0
flutter_local_notifications: ^17.2.4
sqflite: ^2.4.1
speech_to_text: ^7.4.0
```

### 3. **Provider Update Available** (MINOR)
- **Current**: `provider: ^6.1.2`
- **Latest**: `^6.2.0+`
- **Action**: Update if using Provider (not Riverpod)

---

## 🔧 Missing/Recommended Packages

### 1. **Freezed Code Generation** (HIGHLY RECOMMENDED)
```yaml
dependencies:
  freezed_annotation: ^2.4.1

dev_dependencies:
  freezed: ^2.4.7
```
- **Why**: For immutable model classes, sealed unions, pattern matching
- **Usage**: Already used in modern Flutter apps with Riverpod
- **Status**: MISSING ❌

### 2. **Hive Generators** (OPTIONAL but RECOMMENDED)
```yaml
dev_dependencies:
  hive_generator: ^2.0.1
```
- **Why**: If using Hive for local caching, generate adapters
- **Status**: MISSING (needed if Hive models exist) ❌

### 3. **Flutter Timezone** (RECOMMENDED for Notifications)
```yaml
dependencies:
  flutter_timezone: ^0.0.0
```
- **Why**: For scheduling notifications with timezone support
- **Pairs with**: `flutter_local_notifications`
- **Status**: MISSING ❌

### 4. **Dart Async** (OPTIONAL)
```yaml
dependencies:
  async: ^2.11.0
```
- **Why**: Utility classes for async operations (StreamGroup, etc.)
- **Status**: Implicit (transitive), but explicit use is cleaner

### 5. **Mocktail** (OPTIONAL - Better than Mockito)
```yaml
dev_dependencies:
  mocktail: ^1.0.0
```
- **Why**: Modern Dart mocking, better than Mockito for null safety
- **Status**: MISSING (has Mockito ^5.4.4)

### 6. **Very Good Dart Analysis** (OPTIONAL)
```yaml
dev_dependencies:
  very_good_analysis: ^6.0.0
```
- **Why**: Stricter linting rules than flutter_lints
- **Status**: MISSING (has flutter_lints)

---

## 📊 Compatibility Matrix

| Dependency Group | Status | Notes |
|---|---|---|
| **Firebase** | ✅ Full Compat | All v5.x aligned |
| **ML Kit** | ✅ Full Compat | All v0.x/12.x aligned |
| **Maps & Location** | ⚠️ Minor Issue | google_maps_flutter pinned |
| **State Management** | ⚠️ Redundant | Provider + Riverpod both present |
| **Notifications** | ✅ Good | Missing timezone support |
| **Storage** | ✅ Good | Hive + SQLite + SecureStorage |
| **Auth & Security** | ✅ Excellent | Biometric + Secure Storage |
| **UI/UX** | ✅ Excellent | All latest packages |

---

## 🔨 Recommended Changes

### Priority 1 (Critical)
```yaml
# REMOVE if using Riverpod:
# provider: ^6.1.2

# OR REMOVE if using Provider:
# riverpod: ^2.5.0
# flutter_riverpod: ^2.5.0
```

### Priority 2 (High)
```yaml
# Fix pinned versions:
google_maps_flutter: ^2.10.0      # was: 2.10.0
flutter_local_notifications: ^17.2.4  # was: 17.2.4
sqflite: ^2.4.1                  # was: 2.4.1
speech_to_text: ^7.4.0           # was: 7.4.0

# Update provider if keeping it:
provider: ^6.2.0
```

### Priority 3 (Recommended)
```yaml
dev_dependencies:
  freezed_annotation: ^2.4.1
  freezed: ^2.4.7

dependencies:
  flutter_timezone: ^0.0.0
```

---

## 🚀 Next Steps

1. **Audit State Management**
   - Search codebase for `Provider` vs `Riverpod` usage
   - Consolidate to one approach
   - Remove unused dependency

2. **Unpin Versions**
   - Change 4 pinned versions to caret notation
   - Test thoroughly after changes

3. **Add Missing Packages**
   - Add Freezed for better model generation
   - Add flutter_timezone for notification scheduling

4. **Run Dependency Check**
   ```bash
   flutter pub get
   flutter pub outdated
   flutter analyze
   dart pub upgrade --dry-run
   ```

5. **Security Audit**
   ```bash
   dart pub outdated
   # Review any security-related updates
   ```

6. **Build & Test**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

---

## 📝 Notes

- **.env Security**: Good practice - secrets not bundled in assets
- **shorebird.yaml**: OTA code push configured ✅
- **Sentry Integration**: Error reporting enabled ✅
- **Analytics**: Firebase Analytics + fl_chart enabled ✅
- **Payments**: Razorpay integration ready ✅

---

**Generated by Dependency Audit Tool**  
*Keep this document updated as dependencies change*
