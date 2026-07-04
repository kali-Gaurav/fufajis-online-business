# Fufaji Store Error Analysis & Fix Plan
**Date**: 2026-07-03  
**Source**: Android Logcat from app testing

---

## 🔴 CRITICAL ERRORS

### 1. Firestore PERMISSION_DENIED - reorder_templates (REPEATED ~40x)
**Error**:
```
W/Firestore(14104): Listen for QueryWrapper(query=Query(target=Query(users/KvbIF1rSfPbF9vYfwX6Ld9hEBqh2/reorder_templates order by -updatedAt, -__name__);limitType=LIMIT_TO_FIRST)) failed: Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions.
```

**Impact**: Users cannot fetch their reorder templates. ReorderService fails silently.

**Root Cause**: Firestore security rules don't allow users to read their own `users/{uid}/reorder_templates` collection.

**Fix Required**:
- [ ] Check Firebase Console Firestore Rules
- [ ] Add rule: Allow authenticated users to read their own reorder_templates
- [ ] Verify rule format and test in Firebase Emulator
- [ ] Deploy to production

**Firestore Rule Needed**:
```
match /users/{uid}/reorder_templates/{document=**} {
  allow read: if request.auth.uid == uid;
  allow write: if request.auth.uid == uid;
}
```

---

### 2. Flutter ListTile Widget Warnings (REPEATED ~15x)
**Error**:
```
E/flutter: ListTile background color or ink splashes may be invisible.
The ListTile is wrapped in a DecoratedBox that has a background color. Because ListTile paints its background and ink splashes on the nearest Material ancestor, this DecoratedBox will hide those effects.
To fix this, wrap the ListTile in its own Material widget, or remove the background color from the intermediate DecoratedBox.
```

**Impact**: Minor visual issues - ink splashes won't show on ListTile interactions.

**Files to Check**:
- [ ] Search for ListTile widgets in: `lib/screens/`, `lib/widgets/`
- [ ] Check: `lib/screens/orders/reorder_templates_screen.dart` (likely location)
- [ ] Check: `lib/screens/customer/customer_home.dart`
- [ ] Check: Any screen with product lists

**Fix Options**:
Option A: Remove background color from DecoratedBox  
Option B: Wrap ListTile in Material widget  
Option C: Use Container instead of DecoratedBox with proper Material setup

---

### 3. Google Play Services - FilePhenotypeFlags (REPEATED ~3x)
**Error**:
```
E/FilePhenotypeFlags(14104): Config package com.google.android.gms.clearcut_client#com.fufajis.online cannot use FILE backing without declarative registration.
This will lead to stale flags.
```

**Impact**: Google crash reporting and analytics flags may not work correctly.

**Location**: `android/app/src/main/AndroidManifest.xml`

**Fix Required**:
Add declarative phenotype registration in AndroidManifest.xml:
```xml
<meta-data
    android:name="com.google.android.gms.clearcut_client.log_source"
    android:value="@integer/google_play_services_version" />
```

or configure Phenotype provider properly per: https://g.co/phenotype-android-integration

---

## 🟡 WARNINGS TO MONITOR

### Offline Sync Service - OK
```
I/flutter: [OfflineOrderQueueService] Initialized successfully
I/flutter: [OfflineOrderQueueService] Syncing 0 orders
I/flutter: [OfflineOrderQueueService] Sync complete: 0/0 successful
```
✅ This is working correctly. Queue is empty (no offline orders pending).

---

## 📋 TASK PRIORITY

1. **P0 - Firestore Permissions** → Blocks reorder feature
2. **P1 - ListTile Widget** → UI/UX issue (non-blocking)
3. **P2 - Phenotype Registration** → Analytics/crash reporting
4. **P3 - Verify Offline Service** → Already working, just verify

---

## 🔍 DEBUG APPROACH

```bash
# For Firestore rules:
1. Go to Firebase Console → Firestore → Rules
2. Check current rules for users/{uid}/reorder_templates
3. Update and test with Firestore Emulator
4. Deploy to production

# For Flutter:
1. grep -r "ListTile" lib/ | grep -i "decorat"
2. Review widget tree structure
3. Apply fix
4. Run: flutter clean && flutter pub get && flutter run

# For Phenotype:
1. Check android/app/src/main/AndroidManifest.xml
2. Add declarative registration
3. Rebuild APK: flutter build apk --release
```

---

## ✅ VERIFICATION CHECKLIST

- [ ] Firestore rules updated and deployed
- [ ] User can fetch reorder_templates without errors
- [ ] ListTile ink splash effects visible on tap
- [ ] Google Play Services phenotype flags register correctly
- [ ] Offline sync queue still works
- [ ] No new logcat errors on fresh build

