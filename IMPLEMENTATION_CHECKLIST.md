# Implementation Checklist - Fufaji Package Update (July 2026)

## Executive Summary

**Issue:** Flutter version 3.29.0 incompatible with workmanager 0.8.1+  
**Solution:** Upgrade Flutter to 3.44.4 and update all packages to latest versions  
**Status:** ✅ Ready to implement  
**Risk Level:** 🟢 LOW (patch/minor updates only, no breaking changes)  
**Estimated Time:** 15-25 minutes  

---

## Pre-Implementation

### Preparation
- [ ] Read `QUICK_START_PACKAGE_UPDATE.md` (2 min)
- [ ] Read `PACKAGE_AUDIT_JULY_2026.md` (5 min)
- [ ] Backup current `pubspec.yaml` 
- [ ] Ensure IDE is closed
- [ ] Have terminal/command prompt ready
- [ ] Ensure 500MB disk space available

### Prerequisites
- [ ] Git repository is clean (no uncommitted changes)
- [ ] You have internet connection (downloads ~200MB)
- [ ] No other Flutter builds running

---

## Phase 1: Flutter Upgrade (Minutes 0-5)

### Task 1.1: Upgrade Flutter
```bash
flutter upgrade --force
```

**Success Indicator:**
```
✓ Flutter upgraded to version X.X.X
✓ Dart upgraded to version X.X.X
```

- [ ] Command completed without errors
- [ ] Flutter version shows 3.44.4+ when you run `flutter --version`

**If Failed:** 
```bash
# Try alternate method
flutter upgrade
# or download from https://flutter.dev/docs/development/tools/sdk/releases
```

---

## Phase 2: Package Update (Minutes 5-8)

### Task 2.1: Backup Current pubspec.yaml
```bash
cd /path/to/fufaji-online-business
cp pubspec.yaml pubspec.yaml.backup.jul2026
```

- [ ] Backup file created successfully

### Task 2.2: Replace pubspec.yaml
```bash
cp pubspec_UPDATED_JULY2026.yaml pubspec.yaml
```

- [ ] New pubspec.yaml in place
- [ ] File size is approximately same as original (~4KB)

### Task 2.3: Verify Changes
```bash
# Quick check that major packages updated
grep "workmanager" pubspec.yaml
grep "flutter_riverpod" pubspec.yaml
```

Expected:
```
workmanager: ^0.8.1
flutter_riverpod: ^3.3.1
```

- [ ] workmanager shows 0.8.1
- [ ] Other major packages show latest versions

---

## Phase 3: Dependency Resolution (Minutes 8-10)

### Task 3.1: Clean Pub Cache (if needed)
```bash
flutter pub cache clean
```

- [ ] Cache cleared (can skip if `flutter pub get` works)

### Task 3.2: Get Dependencies
```bash
flutter pub get
```

**Expected Output:**
```
Running "flutter pub get" in fufajis_online...
Resolving dependencies...
✓ Got dependencies in X seconds
```

**Troubleshooting:**
- [ ] No version conflict errors
- [ ] No "Could not find dependency" errors
- [ ] If errors occur, check `MIGRATION_GUIDE_JULY2026.md` section "If You Get Version Conflicts"

**If Failed:**
```bash
flutter clean
flutter pub get --verbose
# Check error message and cross-reference with migration guide
```

---

## Phase 4: Testing (Minutes 10-20)

### Task 4.1: Flutter Analyze
```bash
flutter analyze
```

**Expected:** 
- ✅ No critical errors
- ⚠️ Some warnings are OK (lint issues)
- 🔴 No "type error" or "undefined" errors

- [ ] Analysis completes
- [ ] No blocking errors

### Task 4.2: Build Debug APK
```bash
flutter build apk --debug
```

**Expected Output:**
```
✓ Built build/app/outputs/flutter-apk/app-debug.apk (XXX MB)
```

**Duration:** 3-5 minutes (first build slower)

- [ ] APK built successfully
- [ ] No build errors
- [ ] File size reasonable (~50-150MB for debug)

**If Failed:**
```bash
# Try clean build
flutter clean
flutter pub get
flutter build apk --debug --verbose
# Check error logs and refer to migration guide
```

### Task 4.3: Manual Testing (if possible)
Test on emulator or device:
```bash
flutter run
```

Then test these features:
- [ ] App starts cleanly
- [ ] No red debug errors in console
- [ ] Navigation works
- [ ] Firebase connection works (check logs)
- [ ] Can login/authentication works

**If issues found:**
- Check build output for errors
- Verify firestore rules are correct
- Ensure `.env` file or environment variables are set

---

## Phase 5: Shorebird Release (Minutes 20-25)

### Task 5.1: Verify Shorebird is Installed
```bash
shorebird --version
```

- [ ] Shorebird installed
- [ ] Version >= 1.0.0

**If not installed:**
```bash
dart pub global activate shorebird_cli
```

### Task 5.2: Execute Release Command
```bash
shorebird release android --flutter-version=3.44.4 -- \
  --dart-define=API_BASE_URL=https://fufajis-online-business.onrender.com
```

**Expected Output:**
```
✓ Fetching apps (1.4s)
✓ Building Android app bundle with Flutter 3.44.4
✓ Resolving dependencies...
✓ Building...
✓ Creating release...
Release successful!
```

**Duration:** 5-10 minutes

- [ ] Release completes without errors
- [ ] APK/AAB generated successfully
- [ ] Output shows "Release successful"

**If Failed:**
- [ ] Check error message carefully
- [ ] Scroll up to find first error
- [ ] Refer to error in `MIGRATION_GUIDE_JULY2026.md`
- [ ] Try `flutter clean && flutter pub get` and retry

### Task 5.3: Verify APK/AAB Artifacts
```bash
# Check Android build outputs
ls -la build/app/outputs/flutter-apk/
ls -la build/app/outputs/bundle/

# Or on Windows
dir build/app/outputs/flutter-apk/
dir build/app/outputs/bundle/
```

- [ ] APK file exists and has reasonable size (>30MB)
- [ ] AAB file exists (if building bundle)
- [ ] Timestamp shows it was just created

---

## Phase 6: Post-Release Verification

### Task 6.1: Smoke Test (if applicable)
```bash
# Install debug APK on test device
adb install build/app/outputs/flutter-apk/app-debug.apk

# Or use release APK if available
```

On device, verify:
- [ ] App installs without errors
- [ ] App launches successfully
- [ ] Key screens load (home, products, cart, etc.)
- [ ] No crash on startup
- [ ] Network requests work (check logs)

### Task 6.2: Document Changes
```bash
# Check what changed
git diff pubspec.yaml | head -20

# Create release notes
echo "Updated to Flutter 3.44.4 and latest package versions" > RELEASE_NOTES.txt
```

- [ ] Changes documented
- [ ] Team notified of update

### Task 6.3: Commit Changes (if applicable)
```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: update packages and flutter to 3.44.4

- Update workmanager from 0.7.0 to 0.8.1 (requires Flutter 3.32.0+)
- Update all Firebase packages to latest versions
- Update state management and utility packages
- Flutter upgraded to 3.44.4 for compatibility

Fixes: workmanager version constraint error in Shorebird release"
```

- [ ] Changes committed (if using git)
- [ ] Commit message clear and descriptive

---

## Success Criteria ✅

You can consider this update successful when:

- [x] Flutter version is 3.44.4+
- [x] `flutter pub get` completes without errors
- [x] `flutter analyze` shows no critical errors
- [x] Debug APK builds successfully
- [x] App runs on test device without crash
- [x] Shorebird release completes successfully
- [x] AAB/APK has reasonable file size
- [x] No new red errors in debug console

---

## Rollback Plan (If Needed)

If something goes wrong and you need to revert:

```bash
# Restore backup
cp pubspec.yaml.backup.jul2026 pubspec.yaml

# Clean and reinstall
flutter clean
flutter pub cache clean
flutter pub get

# Rebuild
flutter build apk --debug

# Verify
flutter run
```

**Rollback Time:** ~5 minutes

- [ ] Keep `pubspec.yaml.backup.jul2026` safe until release is stable (at least 24h)

---

## Common Issues & Quick Fixes

| Issue | Solution |
|-------|----------|
| "flutter --version shows old version" | `flutter upgrade` didn't work. Try `flutter clean` then `flutter upgrade --force` |
| "workmanager still requires 3.32.0" | Pub cache corrupted. Run `flutter pub cache clean` then `flutter pub get` |
| "Build fails with gradle error" | `cd android && ./gradlew clean && cd ..` then rebuild |
| "Dependencies still show old versions" | Delete `pubspec.lock` then `flutter pub get` |
| "APK build takes too long" | Normal for first build (5-10min). Subsequent builds faster. |

---

## Reference Documents

Read these if you encounter specific issues:

1. **General Overview** → `QUICK_START_PACKAGE_UPDATE.md`
2. **Detailed Audit** → `PACKAGE_AUDIT_JULY_2026.md`
3. **Step-by-Step Guide** → `MIGRATION_GUIDE_JULY2026.md`
4. **Updated Packages** → `pubspec_UPDATED_JULY2026.yaml`

---

## Sign-Off

Once complete, fill in this section:

**Update Completed By:** ________________  
**Date & Time:** ________________  
**Flutter Version Verified:** ________________  
**Shorebird Release Status:** ✅ Success / ⚠️ Needs review / 🔴 Failed  
**Notes:** ________________________________________________  

---

## Timeline Summary

| Phase | Tasks | Duration | Status |
|-------|-------|----------|--------|
| 1. Flutter Upgrade | Upgrade, verify | 5 min | |
| 2. Package Update | Backup, replace, verify | 3 min | |
| 3. Dependencies | Clean cache, get deps | 2 min | |
| 4. Testing | Analyze, build, test | 8-10 min | |
| 5. Shorebird | Release, verify artifacts | 5-10 min | |
| 6. Post-Release | Smoke test, document | 2-3 min | |
| **TOTAL** | | **25-33 min** | |

---

**CREATED:** July 1, 2026  
**UPDATED:** July 1, 2026  
**STATUS:** ✅ READY FOR IMPLEMENTATION  

---

## Next Steps After Completion

1. ✅ Monitor app for crashes in first 24 hours
2. ✅ Watch Firebase metrics for any anomalies
3. ✅ Plan firebase_messaging 17.x upgrade for next release cycle
4. ✅ Update CI/CD pipelines to use Flutter 3.44.4
5. ✅ Share this document with team members doing future updates
