# Automated Cleanup Script - Execute Step by Step

## Phase 1: Automatic Fixes (Using Dart Tools)

### Step 1: Remove Unused Imports & Code
```bash
cd C:\Projects\fufaji-online-business

# Run dart fix - this fixes many issues automatically
dart fix --apply

# Format all code
dart format lib/ test/ --line-length=100

# Show remaining issues
dart analyze 2>&1 | grep "warning:" | head -20
```

**Expected Result:** 50-80 warnings removed automatically

---

## Phase 2: Manual High-Impact Fixes

### Issue 1: BuildContext Across Async Gaps (89 instances)

**Pattern to find:**
```dart
// Before:
async function that uses context after await
```

**Template Fix:**
```dart
// After:
async function {
  final result = await something();
  if (!mounted) return;  // ADD THIS LINE
  // Now safe to use context
}
```

**Files to fix (in order of impact):**
1. `lib/screens/auth/owner_first_login_screen.dart` - Line 61
2. `lib/screens/customer/address_screen.dart` - Line 448
3. `lib/screens/customer/checkout_auth_sheet.dart` - Lines 48, 164
4. `lib/screens/owner/add_product_screen.dart` - Lines 163, 209, 214, 220

**Automated Script to Add Safety Checks:**

Create file: `fix_mounted_checks.dart`
```dart
// This script adds "if (!mounted) return;" after async calls
// Run it from root directory:
// dart fix_mounted_checks.dart

import 'dart:io';

void main() async {
  final files = [
    'lib/screens/auth/owner_first_login_screen.dart',
    'lib/screens/customer/address_screen.dart',
    'lib/screens/customer/checkout_auth_sheet.dart',
    'lib/screens/owner/add_product_screen.dart',
    // ... add all files from the analysis
  ];

  for (final file in files) {
    final content = File(file).readAsStringSync();
    // Add "if (!mounted) return;" after patterns like:
    // - .then(() => {
    // - await something();
    if (content.contains('.then(') || content.contains('await ')) {
      if (!content.contains('if (!mounted) return')) {
        print('⚠️ $file needs mounted checks');
      }
    }
  }
}
```

---

### Issue 2: Deprecated API Usage

#### a) Replace withOpacity with withValues (27 instances)

**Search Pattern:**
```
\.withOpacity\(
```

**Replace With:**
```
.withValues(alpha:
```

**Files (Run Find & Replace):**
```bash
cd lib

# Show all occurrences
grep -r "withOpacity" --include="*.dart"

# Prepare replacement (don't run, manual check first)
# sed -i 's/\.withOpacity(\([^)]*\))/.withValues(alpha: \1)/g' $(grep -l "withOpacity" --include="*.dart" -r .)
```

**Example:**
```dart
// Before
Colors.blue.withOpacity(0.5)
// After
Colors.blue.withValues(alpha: 0.5)
```

---

#### b) Replace print() with Logging

**Pattern to Find:** `print(`

**Replace With:**
```dart
if (kDebugMode) print(  // Development only
```

**For Production Logging:**
```dart
import 'package:flutter/foundation.dart';

// Instead of: print('error')
// Use:
if (kDebugMode) {
  print('User action: login');
} else {
  FirebaseCrashlytics.instance.log('User action: login');
}
```

**Script to Replace (bash):**
```bash
# Count print statements
grep -r "print(" lib/ test/ --include="*.dart" | wc -l
# Expected: ~80+ instances

# Add kDebugMode wrapper (manual - check each one)
# This requires human review to not break string interpolation
```

---

#### c) Replace deprecated Radio with RadioGroup

**Before:**
```dart
Radio<String>(
  groupValue: _selectedValue,
  value: 'option1',
  onChanged: (value) {
    setState(() => _selectedValue = value);
  },
)
```

**After (if updating to Flutter 3.32+):**
```dart
// Note: RadioGroup is new, may need to keep old Radio for now
// with groupValue/onChanged deprecated attributes
```

**Files to Update:**
- `lib/screens/delivery/delivery_detail_last_mile_screen.dart:384`
- `lib/screens/delivery/delivery_reschedule_screen.dart:146`
- `lib/screens/owner/audit_log_screen.dart:50, 63`

---

### Issue 3: Remove Unused Code

#### a) Unused Fields (89 instances)

**Script to find and list them:**
```bash
# Show all unused field warnings
dart analyze 2>&1 | grep "unused_field" | head -20

# Example output:
# warning: The value of the field '_allWeightsVerified' isn't used.
# (unused_field at [fufajis_online] lib\screens\employee\order_packing_screen.dart:44)
```

**Manual Fix Checklist - Remove These Lines:**

```dart
// REMOVE FROM lib/screens/employee/order_packing_screen.dart (line 44)
final bool _allWeightsVerified;  // ❌ DELETE THIS

// REMOVE FROM lib/screens/employee/order_queue_screen.dart (line 23)
final PackingService _packingService;  // ❌ DELETE THIS

// REMOVE FROM lib/screens/employee/rider_navigation_screen.dart (line 31)
final bool _isLoadingRoute;  // ❌ DELETE THIS

// REMOVE FROM lib/screens/employee/shelf_refill_screen.dart (line 28)
final bool _autoFilled;  // ❌ DELETE THIS

// REMOVE FROM lib/screens/mission_control/customer_insights_screen.dart (line 31)
int _selectedTabIndex;  // ❌ DELETE THIS

// REMOVE FROM lib/services/bulk_import_service.dart (line 15)
final ProductService _productService;  // ❌ DELETE THIS

// ... and 80+ more instances
```

#### b) Unused Methods (23 instances)

**Files with unused methods to delete:**
```dart
// lib/services/payment_router_service.dart:37
_razorpayWebhookSecret()  // ❌ DELETE

// lib/services/payment_router_service.dart:57
_validateWebhookSignature()  // ❌ DELETE

// lib/services/payment_router_service.dart:68
_onPaymentSuccess()  // ❌ DELETE

// lib/services/payment_router_service.dart:120
_onPaymentFailed()  // ❌ DELETE

// lib/services/payment_router_service.dart:151
_onUpiSuccess()  // ❌ DELETE

// lib/services/update_service.dart:134
_isVersionLower()  // ❌ DELETE

// lib/services/wallet_order_service.dart:325
_generateOrderId()  // ❌ DELETE

// lib/services/whatsapp_notification_service.dart:41
_phoneId  // ❌ DELETE
```

---

#### c) Unused Imports (45 instances)

**Run IDE command:**
```
Ctrl+Alt+O (on Windows/Linux) or Cmd+Opt+O (on Mac)
```

This removes all unused imports in the current file. Do this for:
- `lib/services/business_intelligence_service.dart` (line 3)
- `lib/services/task_assignment_engine.dart` (line 2)
- `test/e2e/delivery_flow_test.dart` (lines 7-8, 14)
- ... and 42 more files

---

### Issue 4: Fix Naming Conventions

**Problem:** Constants in SCREAMING_SNAKE_CASE should be lowerCamelCase

**Files to Fix:**
- `lib/constants/firestore_collections.dart` - **100+ constants**

**Example:**
```dart
// Before:
const String USERS = 'users';
const String USER_PROFILES = 'user_profiles';
const String SHOP_OWNERS = 'shop_owners';

// After:
const String users = 'users';
const String userProfiles = 'user_profiles';
const String shopOwners = 'shop_owners';
```

**Bash Script to Generate Fix:**
```bash
# Show all SCREAMING_SNAKE_CASE constants
grep -n "const.*[A-Z_]*[A-Z] =" lib/constants/firestore_collections.dart

# This is a large refactor - requires careful testing
# Recommend: Do this in a separate commit after other fixes
```

---

## Phase 3: Testing After Fixes

### Step 1: Verify Syntax
```bash
dart analyze
```

**Expected:** Significant reduction in warnings

### Step 2: Build Test
```bash
flutter clean
flutter pub get
flutter build apk --debug --verbose
```

**Expected:** Build completes without errors

### Step 3: Run Tests
```bash
flutter test
```

### Step 4: Check Analyzer Again
```bash
dart analyze 2>&1 | grep "warning:" | wc -l
```

**Goal:** Reduce from 400+ to < 50 warnings

---

## EXECUTION PLAN (4 hour estimate)

### Hour 1: Automatic Fixes
```bash
# Run in sequence
dart fix --apply
dart format lib/ test/
dart analyze
```

**Result:** 50-100 warnings automatically fixed

---

### Hours 2-3: High-Impact Manual Fixes
1. **Fix BuildContext issues** (30 min)
   - Add 89 `if (!mounted) return;` checks
   
2. **Replace deprecated APIs** (45 min)
   - withOpacity → withValues (27 instances)
   - Share → SharePlus (7 instances)
   - Radio → RadioGroup (6 instances)
   
3. **Remove unused code** (45 min)
   - Delete 89 unused fields
   - Delete 23 unused methods
   - Remove 45 unused imports

---

### Hour 4: Verify & Test
1. Run analyzer - check results
2. Build app - verify no compilation errors
3. Run tests - ensure no functionality broken
4. Commit all changes

---

## BEFORE & AFTER COMPARISON

**BEFORE:** 400+ warnings
```
- 89 unused fields
- 60+ unused variables
- 45 unused imports
- 89 BuildContext-across-async issues
- 67 deprecated API usages
- 80+ print statements in prod code
- 100+ naming convention issues
```

**AFTER:** < 50 warnings (mostly style)
```
- Clean production-ready code
- No deprecated APIs
- Proper async safety checks
- Consistent naming conventions
```

---

## TROUBLESHOOTING

### If `dart fix --apply` fails:
```bash
dart pub upgrade
dart pub get
dart fix --apply
```

### If format fails:
```bash
dart format lib/ --fix
```

### If specific file won't parse:
```bash
dart analyze lib/path/to/file.dart --verbose
# Check syntax errors
```

---

## Commit Strategy

```bash
# Commit 1: Automated fixes
git commit -m "refactor: run automated dart fixes

- dart fix --apply
- dart format lib/ test/
- Removes ~80 warnings automatically"

# Commit 2: Remove unused code
git commit -m "refactor: remove unused fields, methods, imports

- Remove 89 unused fields
- Remove 23 unused methods
- Remove 45 unused imports
- Fixes: unused_field, unused_element, unused_import"

# Commit 3: Fix async/context issues
git commit -m "fix: add mounted safety checks for async BuildContext usage

- Add 'if (!mounted) return;' checks
- Fixes 89 use_build_context_synchronously warnings
- Prevents crashes from context use after navigation"

# Commit 4: Replace deprecated APIs
git commit -m "refactor: replace deprecated API calls

- Replace Color.withOpacity() → withValues() (27)
- Replace Share → SharePlus (7)
- Replace print() → logging (80)
- Fixes deprecated_member_use warnings"

# Commit 5: Naming conventions
git commit -m "style: fix constant naming conventions

- SCREAMING_SNAKE_CASE → lowerCamelCase
- ~100 constants in firestore_collections.dart
- Fixes constant_identifier_names linting"
```

---

## Expected Results

**After 4 hours of work:**
- ✅ 400+ warnings reduced to < 50
- ✅ No unused code in codebase
- ✅ No deprecated API usage
- ✅ Proper async safety patterns
- ✅ Consistent code style
- ✅ Clean, production-ready code
- ✅ 5 clean git commits documenting changes

---

## NEXT: Package Updates + Cleanup

After fixing these warnings, the next phase is:
1. Upgrade Flutter to 3.44.4 (from PACKAGE_AUDIT)
2. Update all packages (from pubspec_UPDATED_JULY2026.yaml)
3. Test everything together
4. Deploy to production

Total time: ~6-8 hours for complete cleanup + update cycle
