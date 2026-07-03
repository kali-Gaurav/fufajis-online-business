# Warnings Cleanup Checklist

**Start Date:** ___________  
**Target Completion:** 7 days  
**Time Budget:** 12-16 hours total  

---

## PHASE 1: Automatic Fixes (30 min - 1 hour)

- [ ] Step 1.1: Backup code
  ```bash
  git commit -am "backup: pre-cleanup backup"
  ```

- [ ] Step 1.2: Run dart fix
  ```bash
  dart fix --apply
  ```
  
- [ ] Step 1.3: Format code
  ```bash
  dart format lib/ test/ --line-length=100
  ```
  
- [ ] Step 1.4: Analyze results
  ```bash
  dart analyze 2>&1 | grep "warning:" | wc -l
  ```
  **Target: Warnings reduced to ~350-320**

- [ ] Step 1.5: Commit automated fixes
  ```bash
  git commit -m "refactor: run automated dart fixes"
  ```

---

## PHASE 2: Remove Unused Code (2-3 hours)

### Section A: Unused Fields (89 instances)

- [ ] Remove from `lib/screens/employee/order_packing_screen.dart` (line 44)
  - `_allWeightsVerified`
  
- [ ] Remove from `lib/screens/employee/order_queue_screen.dart` (line 23)
  - `_packingService`
  
- [ ] Remove from `lib/screens/employee/rider_navigation_screen.dart` (line 31)
  - `_isLoadingRoute`
  
- [ ] Remove from `lib/screens/employee/shelf_refill_screen.dart` (line 28)
  - `_autoFilled`
  
- [ ] Remove from `lib/screens/mission_control/customer_insights_screen.dart` (line 31)
  - `_selectedTabIndex`

- [ ] Remove from `lib/services/bulk_import_service.dart` (line 15)
  - `_productService`

- [ ] Remove from `lib/services/delivery_proof_service.dart` (line 22)
  - `_signedUrlService`

- [ ] Remove from `lib/services/kyc_document_service.dart` (line 22)
  - `_signedUrlService`

- [ ] Remove from `lib/services/product_image_service.dart` (line 23)
  - `_signedUrlService`

- [ ] Remove from `lib/services/refund_inventory_service.dart` (lines 21-22)
  - `_wallet`, `_ledger`

- [ ] Remove from `lib/services/customer_analyst_service.dart` (line 14)
  - `_geminiModel`

- [ ] Remove from `lib/services/otp_hash_service.dart` (line 17)
  - `_hashLength`

- [ ] Remove from `lib/services/payment_router_service.dart` (line 37)
  - `_razorpayWebhookSecret`

- [ ] Remove from `lib/utils/payment_service.dart` (lines 78-80)
  - `EVENT_PAYMENT_SUCCESS`, `EVENT_PAYMENT_ERROR`, `EVENT_EXTERNAL_WALLET`

- [ ] Continue with remaining ~75 files
  - Reference: `WARNINGS_ANALYSIS_AND_FIXES.md` for complete list

**Progress: ___/89 fields removed**

### Section B: Unused Methods (23 instances)

- [ ] `lib/services/payment_router_service.dart` - Remove methods:
  - `_validateWebhookSignature()` (line 57)
  - `_onPaymentSuccess()` (line 68)
  - `_onPaymentFailed()` (line 120)
  - `_onUpiSuccess()` (line 151)

- [ ] `lib/services/update_service.dart` - Remove:
  - `_isVersionLower()` (line 134)

- [ ] `lib/services/wallet_order_service.dart` - Remove:
  - `_generateOrderId()` (line 325)

- [ ] Continue with remaining ~16 files
  - Reference: `WARNINGS_ANALYSIS_AND_FIXES.md` for complete list

**Progress: ___/23 methods removed**

### Section C: Unused Imports (45 instances)

- [ ] Run IDE cleanup on each file:
  - Windows/Linux: `Ctrl+Alt+O`
  - Mac: `Cmd+Opt+O`

**Files to clean (use IDE auto-fix):**
- [ ] `lib/services/business_intelligence_service.dart` (line 3)
- [ ] `lib/services/task_assignment_engine.dart` (line 2)
- [ ] `test/e2e/delivery_flow_test.dart` (lines 7-8, 14)
- [ ] ... and 42 more (reference `WARNINGS_ANALYSIS_AND_FIXES.md`)

**Progress: ___/45 imports removed**

- [ ] Commit unused code removal:
  ```bash
  git commit -m "refactor: remove unused fields, methods, imports"
  ```

---

## PHASE 3: Fix Async/BuildContext Issues (1-2 hours)

**89 instances to fix**

Template to add after every `await` or `.then()` that uses context:
```dart
if (!mounted) return;
```

### Critical Files (Fix First - 30 min):

- [ ] `lib/screens/auth/owner_first_login_screen.dart:61`
- [ ] `lib/screens/customer/address_screen.dart:448`
- [ ] `lib/screens/customer/checkout_auth_sheet.dart:48, 164`
- [ ] `lib/screens/customer/dispute_screen.dart:65`
- [ ] `lib/screens/delivery/delivery_detail_screen.dart:201-210`
- [ ] `lib/screens/delivery/delivery_detail_last_mile_screen.dart:*`
- [ ] `lib/screens/employee/delivery_pod_scanner_screen.dart:231`
- [ ] `lib/screens/employee/order_packing_screen.dart:149, 258`
- [ ] `lib/screens/employee/packing_screen.dart:97, 107, 168-183`
- [ ] `lib/screens/owner/add_product_screen.dart:163, 209, 214, 220`

**Progress: ___/89 mounted checks added**

- [ ] Commit async fixes:
  ```bash
  git commit -m "fix: add mounted safety checks for async BuildContext"
  ```

---

## PHASE 4: Replace Deprecated APIs (1-2 hours)

### Section A: Color.withOpacity → withValues (27 instances)

**Files with withOpacity (search & replace):**
- [ ] `lib/screens/owner/mission_control/activity_feed_screen.dart:88`
- [ ] `lib/screens/owner/mission_control/broadcast_compose_screen.dart:214, 222`
- [ ] `lib/screens/owner/mission_control/team_room_screen.dart:468, 470`
- [ ] `lib/widgets/mission_control/churn_alert_card.dart:61, 71, 386`
- [ ] `lib/widgets/mission_control/customer_segment_card.dart:92, 428, 431`
- [ ] `lib/widgets/mission_control/price_diff_preview.dart:47, 116, 144, 166, 174, 185`
- [ ] `lib/widgets/missing_animations.dart:25`
- [ ] Continue with remaining files

**Progress: ___/27 withOpacity replaced**

### Section B: Share → SharePlus (7 instances)

Replace:
```dart
Share.share('text')
// with
SharePlus.instance.share('text')
```

Files:
- [ ] `lib/screens/customer/group_buying_room.dart:20`
- [ ] `lib/screens/customer/loyalty_screen.dart:508`
- [ ] `lib/screens/customer/product_detail_screen.dart:191`
- [ ] `lib/screens/customer/refer_earn_screen.dart:68`
- [ ] `lib/screens/owner/settlement_reporting_screen.dart:152`
- [ ] `lib/screens/user_settings_screen.dart:75`
- [ ] `lib/services/chat_export_service.dart:70`

**Progress: ___/7 Share replaced**

### Section C: print() → Logging (80+ instances)

Replace:
```dart
print('message')
// with
if (kDebugMode) print('message');
```

**Affected files (use find & replace):**
- [ ] All files in `lib/services/` containing print
- [ ] All files in `lib/config/` containing print
- [ ] Test files (these can be left as-is)

**Progress: ___/80 print statements updated**

### Section D: Other Deprecated APIs

- [ ] `Geolocator.desiredAccuracy` → Use settings parameters
  - `lib/screens/onboarding/location_screen.dart:103`
  - `lib/screens/employee/delivery_pod_scanner_screen.dart:161`
  - `lib/services/delivery_tracking_service.dart:78`
  - `lib/services/gps_tracking_service.dart:332, 374`
  - `lib/services/location_tracking_service.dart:173`

- [ ] `SpeechToText` deprecated options
  - `lib/services/speech_to_text_service.dart:88-90`
  - `lib/services/voice_assistant_service.dart:79-82`
  - `lib/services/voice_command_executor.dart`

- [ ] PDF library updates
  - `lib/services/business_intelligence_service.dart:557, 585, 625`
  - Update: `Table.fromTextArray()` → `TableHelper.fromTextArray()`

- [ ] `EncryptedSharedPreferences` deprecation
  - `lib/services/mfa_service.dart:63`

- [ ] `Supabase.anonKey` → `publishableKey`
  - `lib/config/supabase_config.dart:24`

- [ ] `Radio/Checkbox` deprecation warnings (if Flutter 3.32+)
  - 6 instances across multiple files
  - Consider: Leave as-is for now or update to RadioGroup

**Progress: ___/15+ other deprecations fixed**

- [ ] Commit deprecated API fixes:
  ```bash
  git commit -m "refactor: replace deprecated API calls

  - Color.withOpacity() → withValues() (27)
  - Share → SharePlus (7)
  - print() → logging (80)
  - Geolocator settings (5)
  - SpeechToText options (6)
  - And other deprecated APIs"
  ```

---

## PHASE 5: Code Style & Naming (1-2 hours)

### Section A: Constant Naming (100+ instances)

Convert from SCREAMING_SNAKE_CASE to lowerCamelCase

**Main file: `lib/constants/firestore_collections.dart`**

Examples:
```dart
// Before
const String USERS = 'users';
const String USER_PROFILES = 'user_profiles';

// After
const String users = 'users';
const String userProfiles = 'user_profiles';
```

- [ ] Rename all constants in firestore_collections.dart (~100+)
- [ ] Update all usages of these constants throughout codebase
- [ ] Verify build succeeds after rename

**Progress: ___/100+ constants renamed**

### Section B: Other Style Issues

- [ ] Fix unreachable switch default (1 instance)
  - `lib/screens/owner/mission_control/team_room_screen.dart:1240`

- [ ] Fix unnecessary casts (3 instances)
  - `lib/services/customer_analyst_service.dart:521`
  - `lib/services/invoice_service.dart:298, 302, 395`

- [ ] Fix unrelated type equality checks (3 instances)
  - `lib/services/order_status_engine.dart:483, 612`
  - `lib/screens/owner/mandi_pricing_dashboard.dart:37`

- [ ] Commit style fixes:
  ```bash
  git commit -m "style: fix naming conventions and code style

  - Constants: SCREAMING_SNAKE_CASE → lowerCamelCase (~100)
  - Fix unreachable code (1)
  - Fix unnecessary casts (4)
  - Fix type equality checks (3)"
  ```

---

## PHASE 6: Verification & Testing (1-2 hours)

### Step 1: Static Analysis
- [ ] Run analyzer:
  ```bash
  dart analyze 2>&1 | grep "warning:" | wc -l
  ```
  **Target: < 50 warnings**

- [ ] Check specific warning categories:
  ```bash
  dart analyze 2>&1 | grep "unused_field" | wc -l  # Should be 0
  dart analyze 2>&1 | grep "unused_import" | wc -l  # Should be 0
  dart analyze 2>&1 | grep "unused_element" | wc -l  # Should be 0
  ```

### Step 2: Build Verification
- [ ] Clean project:
  ```bash
  flutter clean
  flutter pub get
  ```

- [ ] Build debug APK:
  ```bash
  flutter build apk --debug --verbose
  ```
  **Expected: ✅ Build succeeds**

- [ ] Build release APK (optional):
  ```bash
  flutter build apk --release
  ```

### Step 3: Test Execution
- [ ] Run unit tests:
  ```bash
  flutter test
  ```
  **Expected: All tests pass**

- [ ] Manual smoke test (if possible)
  - Launch app
  - Test login flow
  - Verify no crashes

### Step 4: Final Analysis
- [ ] Generate final warning report:
  ```bash
  dart analyze > final_analysis.txt 2>&1
  grep "warning:" final_analysis.txt | wc -l
  ```

- [ ] Compare before/after:
  ```
  BEFORE: 400+ warnings
  AFTER:  ____ warnings
  
  Reduction: ____%
  ```

- [ ] Commit final state:
  ```bash
  git commit -m "test: verify all fixes and cleanup complete"
  ```

---

## TIME TRACKING

| Phase | Task | Estimated | Actual | Status |
|-------|------|-----------|--------|--------|
| 1 | Automatic fixes | 30 min | ___ | ⬜ |
| 2 | Remove unused code | 2 hrs | ___ | ⬜ |
| 3 | Fix async/context | 1.5 hrs | ___ | ⬜ |
| 4 | Replace deprecated APIs | 2 hrs | ___ | ⬜ |
| 5 | Code style/naming | 1.5 hrs | ___ | ⬜ |
| 6 | Test & verify | 1.5 hrs | ___ | ⬜ |
| **Total** | | **9.5 hrs** | ___ | ⬜ |

---

## SUCCESS CRITERIA

- [x] ✅ Remove all 89 unused fields
- [x] ✅ Remove all 60+ unused local variables  
- [x] ✅ Remove all 45 unused imports
- [x] ✅ Add 89 mounted safety checks
- [x] ✅ Replace 67 deprecated APIs
- [x] ✅ Remove/update 80+ print statements
- [x] ✅ Fix 100+ constant naming conventions
- [x] ✅ Reduce warnings from 400+ to < 50
- [x] ✅ Build succeeds without warnings
- [x] ✅ All tests pass
- [x] ✅ App runs without crashes

---

## NEXT PHASE (After Cleanup)

Once warnings are cleaned up:
1. ✅ Upgrade Flutter to 3.44.4
2. ✅ Update all packages (use `pubspec_UPDATED_JULY2026.yaml`)
3. ✅ Run full test suite
4. ✅ Deploy to production

---

## NOTES

- Keep backups at each major phase
- Commit frequently (don't lose work)
- Test after each section
- Document any issues found
- Review changes before committing

**Start Date:** ___________  
**Completion Date:** ___________  
**Total Time Spent:** _________ hours

