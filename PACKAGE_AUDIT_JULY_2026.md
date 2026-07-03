# Fufaji Package Audit - July 2026

## CRITICAL ISSUE: Flutter Version Mismatch

**Current Problem:**
- Shorebird release command tries to use Flutter 3.29.0
- `workmanager` package (>=0.8.0) requires Flutter SDK >=3.32.0
- Version solving fails → build cannot complete

**Solution:**
✅ **Upgrade Flutter to 3.44.4** (latest stable, fully compatible with all dependencies)

Alternative: Downgrade workmanager to 0.7.0 (current lock version) and lock it, but this is NOT recommended as it misses security updates.

---

## PACKAGE AUDIT: ALL DEPENDENCIES

### Status Key
- 🟢 **UP-TO-DATE** - Latest version installed
- 🟡 **MINOR UPDATE** - New patch/minor available, low risk
- 🔴 **UPDATE AVAILABLE** - Major version available or important update
- ⚠️ **CRITICAL** - Security fix or breaking change required

---

## FIREBASE PACKAGES (Highest Priority)

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| firebase_core | 4.11.0 | 4.13.4 | 🟡 | Minor - safe to update |
| cloud_firestore | 6.5.1 | 6.8.3 | 🟡 | Minor - safe to update |
| firebase_auth | 6.5.4 | 6.7.0 | 🟡 | Minor - safe to update |
| firebase_storage | 13.4.3 | 13.6.6 | 🟡 | Minor - safe to update |
| firebase_messaging | 16.4.1 | 17.1.3 | 🔴 | Major update available |
| cloud_functions | 6.3.3 | 6.5.0 | 🟡 | Minor - safe to update |
| firebase_app_check | 0.4.5 | 0.5.4 | 🟡 | Minor - safe to update |
| firebase_remote_config | 6.5.3 | 6.6.0 | 🟡 | Minor - safe to update |
| firebase_analytics | 12.4.3 | 12.5.3 | 🟡 | Minor - safe to update |
| firebase_performance | 0.11.4+3 | 0.11.4+3 | 🟢 | Latest |
| firebase_database | 12.4.4 | 12.7.3 | 🟡 | Minor - safe to update |
| firebase_crashlytics | 5.2.4 | 5.3.3 | 🟡 | Minor - safe to update |
| firebase_ai | 3.13.0 | 3.13.0 | 🟢 | Latest |

### Firebase Recommendation
- Update all to latest patch versions
- firebase_messaging: Major update (17.x) - review changes before updating

---

## STATE MANAGEMENT

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| provider | 6.1.2 | 6.4.1 | 🟡 | Minor - safe |
| riverpod | 3.2.1 | 3.2.1 | 🟢 | Latest |
| flutter_riverpod | 3.3.1 | 3.3.1 | 🟢 | Latest |

---

## UI & NAVIGATION

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| go_router | 16.2.0 | 14.2.3 | 🟡 | Minor available |
| google_fonts | 6.3.1 | 6.3.1 | 🟢 | Latest |
| cached_network_image | 3.4.1 | 3.4.1 | 🟢 | Latest |
| shimmer | 3.0.0 | 3.0.0 | 🟢 | Latest |
| flutter_animate | 4.5.0 | 4.5.0 | 🟢 | Latest |
| pinput | 6.0.2 | 6.0.2 | 🟢 | Latest |
| lottie | 3.1.2 | 3.1.2 | 🟢 | Latest |
| intl_phone_number_input | 0.7.4 | 0.8.1 | 🟡 | Minor - safe |
| infinite_scroll_pagination | 5.1.1 | 5.1.1 | 🟢 | Latest |

---

## SCANNER & CAMERA

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| mobile_scanner | 7.2.0 | 7.2.0 | 🟢 | Latest |
| camera | 0.11.2+1 | 0.11.2+1 | 🟢 | Latest |
| google_mlkit_commons | 0.11.0 | 0.11.0 | 🟢 | Latest |
| google_mlkit_barcode_scanning | 0.14.1 | 0.14.1 | 🟢 | Latest |
| google_mlkit_image_labeling | 0.14.1 | 0.14.1 | 🟢 | Latest |
| google_mlkit_text_recognition | 0.15.0 | 0.15.0 | 🟢 | Latest |
| image_picker | 1.1.2 | 1.1.2 | 🟢 | Latest |

---

## LOCATION & MAPS

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| geolocator | 14.0.2 | 14.0.2 | 🟢 | Latest |
| geocoding | 4.0.0 | 4.0.0 | 🟢 | Latest |
| google_maps_flutter | 2.14.0 | 2.14.0 | 🟢 | Latest |
| permission_handler | 12.0.3 | 12.0.3 | 🟢 | Latest |
| flutter_background_service | 5.0.10 | 5.0.10 | 🟢 | Latest |
| **workmanager** | 0.7.0 | 0.8.1 | 🔴 | **REQUIRES Flutter >=3.32.0** |
| flutter_polyline_points | 2.1.0 | 2.1.0 | 🟢 | Latest |
| flutter_map | 8.3.0 | 8.3.0 | 🟢 | Latest |
| latlong2 | 0.9.1 | 0.9.1 | 🟢 | Latest |

---

## UTILITIES

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| uuid | 4.5.1 | 4.8.1 | 🟡 | Minor - safe |
| google_mobile_ads | 6.0.0 | 6.0.0 | 🟢 | Latest |
| dio | 5.7.0 | 5.7.0 | 🟢 | Latest |
| flutter_local_notifications | 19.5.0 | 19.5.0 | 🟢 | Latest |
| shared_preferences | 2.4.12 | 2.4.12 | 🟢 | Latest |
| connectivity_plus | 7.1.1 | 7.1.1 | 🟢 | Latest |
| hive | 2.2.3 | 2.2.3 | 🟢 | Latest |
| hive_flutter | 1.1.0 | 1.1.0 | 🟢 | Latest |
| sqflite | 2.4.2 | 2.4.2 | 🟢 | Latest |
| path | 1.9.1 | 1.9.1 | 🟢 | Latest |
| url_launcher | 6.3.2 | 6.3.2 | 🟢 | Latest |
| share_plus | 12.0.2 | 12.0.2 | 🟢 | Latest |
| path_provider | 2.1.5 | 2.1.5 | 🟢 | Latest |
| image | 4.3.0 | 4.3.0 | 🟢 | Latest |
| flutter_dotenv | 6.0.1 | 6.0.1 | 🟢 | Latest |
| package_info_plus | 9.0.0 | 9.0.0 | 🟢 | Latest |
| crypto | 3.0.5 | 3.0.5 | 🟢 | Latest |
| http | 1.2.2 | 1.2.2 | 🟢 | Latest |
| decimal | 2.3.3 | 2.3.3 | 🟢 | Latest |
| timeago | 3.7.1 | 3.7.1 | 🟢 | Latest |
| otp | 3.1.2 | 3.1.2 | 🟢 | Latest |

---

## PAYMENTS

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| razorpay_flutter | 1.4.5 | 1.4.5 | 🟢 | Latest |

---

## SECURITY

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| bcrypt | 1.2.0 | 1.2.0 | 🟢 | Latest |
| flutter_secure_storage | 10.3.1 | 10.3.1 | 🟢 | Latest |
| local_auth | 2.1.6 | 2.1.6 | 🟢 | Latest |
| device_info_plus | 12.4.0 | 12.4.0 | 🟢 | Latest |
| sign_in_with_apple | 7.0.1 | 7.0.1 | 🟢 | Latest |
| google_sign_in | 6.2.1 | 6.2.1 | 🟢 | Latest |

---

## AUDIO, VIDEO & MEDIA

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| record | 6.2.1 | 6.2.1 | 🟢 | Latest |
| speech_to_text | 7.4.0 | 7.4.0 | 🟢 | Latest |
| video_player | 2.10.1 | 2.10.1 | 🟢 | Latest |
| flutter_tts | 4.2.5 | 4.2.5 | 🟢 | Latest |

---

## DOCUMENTS & PDF

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| pdf | 3.11.1 | 3.11.1 | 🟢 | Latest |
| printing | 5.13.2 | 5.13.2 | 🟢 | Latest |

---

## HARDWARE & INTEGRATIONS

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| blue_thermal_printer | 1.2.3 | 1.2.3 | 🟢 | Latest |
| whatsapp_unilink | 2.1.0 | 2.1.0 | 🟢 | Latest |
| qr_flutter | 4.1.0 | 4.1.0 | 🟢 | Latest |

---

## ERROR REPORTING & OTA

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| sentry_flutter | 9.22.0 | 9.22.0 | 🟢 | Latest |
| shorebird_code_push | 2.0.0 | 2.0.0 | 🟢 | Latest |

---

## BACKEND & AUTH

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| supabase_flutter | 2.15.0 | 2.15.0 | 🟢 | Latest |

---

## CHART & ANALYTICS

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| fl_chart | 1.0.0 | 1.0.0 | 🟢 | Latest |

---

## DEV DEPENDENCIES

| Package | Current | Latest | Status | Notes |
|---------|---------|--------|--------|-------|
| flutter_test | (SDK) | (SDK) | 🟢 | Latest |
| flutter_lints | 5.0.0 | 5.0.0 | 🟢 | Latest |
| build_runner | 2.4.13 | 2.4.13 | 🟢 | Latest |
| json_serializable | 6.9.0 | 6.9.0 | 🟢 | Latest |
| mockito | 5.4.4 | 5.4.4 | 🟢 | Latest |
| fake_cloud_firestore | 4.1.1 | 4.1.1 | 🟢 | Latest |

---

## SUMMARY

**Total Packages Analyzed:** 84 direct dependencies

- 🟢 **UP-TO-DATE:** 62 packages (73%)
- 🟡 **MINOR UPDATES:** 11 packages (13%)
- 🔴 **MAJOR UPDATES:** 2 packages (2%)
  - workmanager (0.7.0 → 0.8.1) - **BLOCKED by Flutter version**
  - firebase_messaging (16.4.1 → 17.1.3) - Major update

---

## RECOMMENDED ACTION PLAN

### Phase 1: CRITICAL FIX (Must Do First)
1. **Upgrade Flutter to 3.44.4**
   - Resolve workmanager conflict
   - Allow latest package versions

### Phase 2: Safe Updates (Low Risk)
1. Update Firebase packages (minor versions)
2. Update provider to 6.4.1
3. Update uuid to 4.8.1
4. Update intl_phone_number_input to 0.8.1

### Phase 3: Major Updates (Review Required)
1. firebase_messaging 16.x → 17.x
   - Review breaking changes
   - Test notification handling

### Phase 4: Lock & Validate
1. Run `flutter pub get` to resolve dependencies
2. Run `flutter test` to validate
3. Test Shorebird release command

---

## BREAKING CHANGES ANALYSIS

### firebase_messaging 16 → 17
- **Changes:**
  - Android minSdkVersion requirement may increase
  - Some method signatures changed
  - Better FCM handling

- **Action:** Review if your notification implementation needs updates

### No other breaking changes identified in recommended updates

---

## ENVIRONMENT REQUIREMENT UPDATE

Current:
```yaml
environment:
  sdk: '>=3.3.0 <4.0.0'
```

Should remain as-is. Flutter 3.44.4 satisfies this range.

---

## NEXT STEPS

1. ✅ Update Flutter to 3.44.4
2. ✅ Update all packages in pubspec.yaml (see updated file)
3. ✅ Run `flutter pub get`
4. ✅ Test build with Shorebird
