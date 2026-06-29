# Fufaji Store Flutter App - Bug Fixes Guide (2026-06-09)

## Critical Issues Found

### 1. ❌ FIRESTORE PERMISSION_DENIED Errors
**Severity**: CRITICAL - App cannot load data

**Root Cause**: Firestore security rules are blocking all read operations
- Error: `[cloud_firestore/permission-denied] Missing or insufficient permissions.`
- Affects: products, settings, pre_authorized_users, release_notes, lightning_deals, low_stock_alerts

**Fix**: Update Firebase Firestore Security Rules

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users full access
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Allow public read for specific collections
    match /products/{document=**} {
      allow read: if true;
    }
    match /settings/{document=**} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.token.shop_admin == true;
    }
    match /pre_authorized_users/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.token.shop_admin == true;
    }
    match /release_notes/{document=**} {
      allow read: if true;
    }
    match /lightning_deals/{document=**} {
      allow read: if true;
    }
    match /low_stock_alerts/{document=**} {
      allow read, write: if request.auth != null && request.auth.token.shop_admin == true;
    }
    match /settings/shop_config/branches/{document=**} {
      allow read: if true;
    }
  }
}
```

**Action**: 
1. Go to Firebase Console → Firestore Database → Rules
2. Replace existing rules with the above
3. Publish rules
4. Test the app

---

### 2. ❌ Missing Asset: google_logo.png
**Severity**: HIGH - App crashes on splash/login screen

**Error**: `Unable to load asset: assets/google_logo.png`

**Fix Options**:
A) Add the missing image (Recommended if Google Sign-In is used)
B) Remove the reference from code

**Action**:
1. Search for `google_logo.png` in all `.dart` files
2. Either:
   - Add image to `assets/images/google_logo.png`, OR
   - Remove/comment out the reference

```bash
grep -r "google_logo" lib/
```

---

### 3. ❌ SliverGeometry Layout Error (Pinned Header)
**Severity**: MEDIUM - UI rendering errors

**Error**: `SliverGeometry is not valid: The "layoutExtent" exceeds the "paintExtent"`
- paintExtent: 89.0-92.0
- layoutExtent: 108.0
- maxExtent: 108.0

**Root Cause**: Pinned header (SliverPersistentHeader) has constraints that don't match

**Fix**: Adjust pinned header in scroll views

```dart
// BEFORE (BROKEN):
SliverPersistentHeader(
  pinned: true,
  delegate: CustomHeaderDelegate(
    maxExtent: 108.0,  // Problem: too large for available space
    minExtent: 56.0,
  ),
)

// AFTER (FIXED):
SliverPersistentHeader(
  pinned: true,
  floating: true,  // Add floating
  delegate: CustomHeaderDelegate(
    maxExtent: 89.0,   // Match actual available space
    minExtent: 56.0,
  ),
)
```

**Action**:
1. Find all `SliverPersistentHeader` widgets
2. Ensure `maxExtent` doesn't exceed available viewport
3. Add `floating: true` for better behavior
4. Test on actual device (not emulator - size calculations differ)

---

### 4. ❌ Null Check Operator Errors
**Severity**: HIGH - App crashes

**Error**: `Null check operator used on a null value`

**Root Cause**: Using `!` operator on nullable values that are actually null

**Examples from logs**:
```dart
// BEFORE (BROKEN):
var value = someNullableValue!;  // Crashes if null

// AFTER (FIXED):
var value = someNullableValue ?? defaultValue;
// OR
if (someNullableValue != null) {
  // use it
}
```

**Action**:
1. Search for all occurrences of `!` operator:
   ```bash
   grep -rn "!" lib/ | grep -v "//" | grep -v "!=" | grep -v "!in"
   ```
2. Add null checks before using null-coalescing (`??`) or if-guards
3. Test thoroughly

---

### 5. ❌ GoError: "There is nothing to pop"
**Severity**: MEDIUM - Navigation crashes

**Error**: `GoError: There is nothing to pop`

**Root Cause**: Attempting to pop from navigation stack when it's empty

**Fix**: Add safety checks before popping

```dart
// BEFORE (BROKEN):
context.pop();  // Crashes if only one route in stack

// AFTER (FIXED):
if (Navigator.of(context).canPop()) {
  context.pop();
} else {
  // Handle root screen scenario
}

// OR with GoRouter:
if (context.canPop()) {
  context.pop();
} else {
  context.go('/home');  // Go to default route instead
}
```

**Action**:
1. Identify all `context.pop()` or navigation.pop() calls
2. Add `canPop()` checks before popping
3. Handle root route case explicitly

---

### 6. ❌ RenderFlex Overflow (19 pixels)
**Severity**: MEDIUM - UI layout issue

**Error**: `A RenderFlex overflowed by 19 pixels on the right`

**Root Cause**: Child widgets exceed parent width

**Fix**: Adjust layout

```dart
// BEFORE (BROKEN):
Row(
  children: [
    Text('Label'),
    SizedBox(width: 8),
    Expanded(
      child: TextField(),  // Might be too wide
    ),
  ],
)

// AFTER (FIXED):
Row(
  children: [
    Text('Label'),
    SizedBox(width: 8),
    Flexible(
      child: TextField(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
)

// OR reduce padding:
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12.0),  // Reduced from 19
  child: yourWidget,
)
```

**Action**:
1. Find layouts with overflow errors
2. Wrap children in `Flexible` or reduce padding
3. Test on actual device with different screen sizes

---

## Implementation Priority

1. **First**: Fix Firestore rules (blocks entire app)
2. **Second**: Add missing google_logo.png asset
3. **Third**: Fix null check operators
4. **Fourth**: Fix navigation GoError
5. **Fifth**: Fix layout issues (SliverGeometry, RenderFlex)

## Testing Checklist

- [ ] Firestore rules published and working
- [ ] App loads without permission errors
- [ ] google_logo.png asset exists/reference removed
- [ ] No null check crashes
- [ ] Navigation stack properly managed
- [ ] Layout renders without overflow/geometry errors
- [ ] Test on real device (not just emulator)
- [ ] Test all major screens
- [ ] Test offline mode
