# Fufaji Store - Pubspec Migration Guide
**Date**: June 7, 2026  
**Target Version**: 1.2.2+ (post-optimization)

---

## 📋 Migration Overview

This guide walks you through updating your `pubspec.yaml` to fix dependency issues and add missing packages.

### Changes Summary
- **Removed**: 1 redundant package (provider)
- **Unpinned**: 4 exact-version packages
- **Added**: 3 recommended packages
- **Updated**: 1 package to latest minor version

---

## 🔄 Step-by-Step Migration

### Step 1: Backup Current pubspec.yaml
```bash
cd /path/to/fufaji-online-business
cp pubspec.yaml pubspec.yaml.backup
```

### Step 2: Choose Your State Management Approach

Before making changes, determine if you're using **Provider** or **Riverpod** in your codebase.

#### Option A: Using Riverpod (RECOMMENDED)
```bash
grep -r "import 'package:flutter_riverpod" lib/
grep -r "Provider(" lib/
```

If you see `flutter_riverpod` imports but NOT `package:provider` imports:
- **Action**: Remove `provider: ^6.1.2` from dependencies
- **Keep**: `riverpod: ^2.5.0` and `flutter_riverpod: ^2.5.0`

#### Option B: Using Provider
```bash
grep -r "import 'package:provider" lib/
grep -r "import 'package:flutter_riverpod" lib/
```

If you see `provider` imports but NOT `flutter_riverpod`:
- **Action**: Remove `riverpod` and `flutter_riverpod`
- **Keep**: `provider: ^6.2.0` (update to latest)

---

### Step 3: Apply Changes to pubspec.yaml

#### Change 1: Remove Redundant State Management
```yaml
# BEFORE
dependencies:
  # State management
  provider: ^6.1.2
  riverpod: ^2.5.0
  flutter_riverpod: ^2.5.0

# AFTER (if using Riverpod)
dependencies:
  # State management
  riverpod: ^2.5.0
  flutter_riverpod: ^2.5.0
```

#### Change 2: Unpin Exact Versions
```yaml
# BEFORE
google_maps_flutter: 2.10.0
flutter_local_notifications: 17.2.4
sqflite: 2.4.1
speech_to_text: 7.4.0

# AFTER
google_maps_flutter: ^2.10.0
flutter_local_notifications: ^17.2.4
sqflite: ^2.4.1
speech_to_text: ^7.4.0
```

#### Change 3: Add New Dependencies
```yaml
# In dependencies section, add:
  # ADDED: Immutable Models & Code Generation
  freezed_annotation: ^2.4.1

  # ADDED: Timezone Support for Notifications
  flutter_timezone: ^0.0.0

# In dev_dependencies section, add:
  # ADDED: Code Generation for Freezed Models
  freezed: ^2.4.7

  # ADDED: Hive Code Generation (if using Hive models)
  hive_generator: ^2.0.1
```

---

### Step 4: Download New Pubspec Template (Optional)

We've created an updated version:

**Location**: `pubspec_UPDATED.yaml` in your project root

```bash
# Review the changes
diff pubspec.yaml pubspec_UPDATED.yaml

# Apply the changes (backup first!)
cp pubspec.yaml pubspec.yaml.backup
cp pubspec_UPDATED.yaml pubspec.yaml
```

---

### Step 5: Fetch and Build

#### 5a. Clean Previous Builds
```bash
flutter clean
```

#### 5b. Get New Dependencies
```bash
flutter pub get
```

#### 5c. Generate Code (for Freezed/Hive/json_serializable)
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

#### 5d. Check for Issues
```bash
flutter analyze
```

**Expected Output**:
```
Analyzing fufajis_online...
✓ No issues found! (0 issues)
```

#### 5e. Test Everything
```bash
# Run tests
flutter test

# Build debug APK
flutter build apk --debug

# Or build release APK
flutter build apk --release
```

---

## 📊 What Changed & Why

### 1. Provider vs Riverpod (State Management)

| Aspect | Provider | Riverpod |
|--------|----------|----------|
| **Learning Curve** | Easier | Moderate |
| **Type Safety** | Good | Excellent |
| **Code Generation** | Not needed | Needed |
| **Testing** | Good | Excellent |
| **Use Case** | Simple to medium | Medium to complex |

**Recommendation**: If both are imported, consolidate to **Riverpod** for modern patterns.

---

### 2. Why Unpin Versions?

**Before (Pinned)**:
```yaml
sqflite: 2.4.1  # Locked to exactly 2.4.1
```
- ❌ Misses bug fixes: 2.4.2, 2.4.3
- ❌ Misses security patches
- ❌ Harder to update

**After (Caret)**:
```yaml
sqflite: ^2.4.1  # Allows 2.4.1, 2.4.2, 2.5.0, but NOT 3.0.0
```
- ✅ Gets patches automatically: 2.4.2+
- ✅ Security updates included
- ✅ Flexibility for minor updates

---

### 3. Freezed (Code Generation)

**What It Does**:
```dart
// BEFORE: Manual immutable classes
class User {
  final String id;
  final String name;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  // Copy constructor, equality, hashCode, toString...
  // ~50 lines of boilerplate
}

// AFTER: With Freezed
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    required DateTime createdAt,
  }) = _User;
}
// ~ 10 lines, everything else auto-generated
```

**Why Recommended**:
- ✅ Less boilerplate code
- ✅ Immutability guaranteed
- ✅ Better with Riverpod
- ✅ Pattern matching support

---

### 4. Flutter Timezone

**Current Issue**:
```dart
// Scheduling notifications without timezone
await flutterLocalNotificationsPlugin.zonedSchedule(
  0,
  'Title',
  'Body',
  scheduledDate, // What timezone is this in?
  const NotificationDetails(),
  androidScheduleMode: AndroidScheduleMode.exactAndAllowWhileIdle,
  uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
);
```

**With flutter_timezone**:
```dart
import 'package:flutter_timezone/flutter_timezone.dart';

final tz = await FlutterTimezone.getLocalTimezone();
final location = tz.getLocation(tz);

// Now schedule with proper timezone handling
final scheduledDate = tz.TZDateTime.from(
  DateTime.now().add(Duration(minutes: 5)),
  location,
);
```

---

### 5. Hive Generator (Optional)

Only needed if you're using **Hive with custom models**:

```dart
import 'package:hive/hive.dart';

@HiveType(typeId: 0)  // Requires hive_generator
class CartItem {
  @HiveField(0)
  String productId;

  @HiveField(1)
  int quantity;
}
```

Run code generation:
```bash
flutter pub run build_runner build
```

---

## ✅ Verification Checklist

After migration, verify everything:

- [ ] `flutter clean` runs without errors
- [ ] `flutter pub get` shows no conflicts
- [ ] `flutter analyze` returns 0 issues
- [ ] `flutter pub run build_runner build` completes successfully
- [ ] `flutter test` passes all tests
- [ ] `flutter build apk --debug` builds successfully
- [ ] App runs on emulator/device without crashes
- [ ] All state management still works
- [ ] Notifications schedule properly
- [ ] Local storage (Hive/SQLite) works
- [ ] Firebase authentication still works

---

## 🔍 If You Encounter Issues

### Issue 1: Version Conflict
```
Because provider >=6.0.0 depends on riverpod >=2.0.0 and
firebase_auth >=5.0.0 depends on provider <6.0.0, provider is forbidden.
```

**Solution**: 
- Remove `provider` if using `flutter_riverpod`
- Or remove `flutter_riverpod` if using `provider`

### Issue 2: Build Runner Fails
```
Could not run build_runner build
```

**Solution**:
```bash
flutter pub clean
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue 3: Pub.dev Timeout
```
Resolving dependencies... (timeout)
```

**Solution**:
```bash
flutter pub cache repair
flutter pub get --verbose
```

### Issue 4: Freezed Not Generating
```
Missing part directive for freezed file
```

**Solution**:
```dart
// Add to top of your model file
part 'user.freezed.dart';
```

Then regenerate:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 📝 Post-Migration Checklist

1. **Update Code** (if removing Provider)
   - Search for `import 'package:provider` 
   - Convert to Riverpod patterns if needed

2. **Update Git**
   ```bash
   git add pubspec.yaml pubspec.lock
   git commit -m "build(deps): fix dependency versions and add missing packages
   
   - Consolidate state management to Riverpod only
   - Unpin exact versions to allow patches (^)
   - Add Freezed for immutable models
   - Add flutter_timezone for notification scheduling
   - Add hive_generator for Hive code generation"
   ```

3. **Update Documentation**
   - Document Riverpod usage patterns
   - Document Freezed usage in new models
   - Update contribution guidelines

4. **Test on Devices**
   - Test on Android device
   - Test on iOS device (if applicable)
   - Test all critical features

---

## 📞 Support

If you encounter issues:

1. Check the [Flutter Pub Docs](https://pub.dev)
2. Review individual package changelogs
3. Search existing GitHub issues
4. Create a detailed bug report with:
   - Flutter version: `flutter --version`
   - Dart version: `dart --version`
   - Error messages and stack traces
   - Steps to reproduce

---

## 🎉 You're Done!

After completing this migration:

✅ Dependencies are optimized  
✅ Security patches enabled  
✅ Code generation ready  
✅ Better development experience  
✅ Prepared for future updates  

Happy coding! 🚀
