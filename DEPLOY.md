# Fufaji Update & Release Management Guide

This guide explains how to release updates for the Fufaji Online Business app using the 3-layer architecture.

## Versioning Policy
Use **MAJOR.MINOR.PATCH+BUILD** (e.g., `1.2.0+4`) in `pubspec.yaml`.

---

## Layer 1: Instant Config Updates (Firebase Remote Config)
**Use for:** Changing prices, disabling features, maintenance mode, or changing the home banner.

1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Navigate to **Remote Config**.
3. Update the desired keys (e.g., `is_maintenance_mode`, `announcement_message`).
4. Click **Publish Changes**.
5. All apps will receive the change within 15 minutes (or instantly on next restart).

---

## Layer 2: Rapid Code Fixes (Shorebird OTA)
**Use for:** Dart bug fixes, UI tweaks, business logic changes.
**Limitation:** Cannot be used if you added a new Flutter package or changed native (Android/iOS) files.

1. Ensure you are on the `main` branch.
2. Run the patch command:
   ```bash
   shorebird patch android
   ```
3. Users will download the fix in the background. It will apply when they next restart the app.

---

## Layer 3: Full App Release (APK/AAB)
**Use for:** New features, new permissions, new SDKs, or major version bumps.

### Step 1: Prepare the Release
1. Update version in `pubspec.yaml` (e.g., `1.3.0+5`).
2. Commit and push to GitHub.
3. Add release notes in the **Owner Dashboard -> Releases** section within the app.

### Step 2: Build & Publish
**Option A: Manual Build (APK)**
```bash
flutter build apk --release
```
Upload the APK to Firebase Storage or your website.

**Option B: Play Store (AAB)**
```bash
flutter build appbundle --release
```
Upload the `.aab` to the Google Play Console.

### Step 3: Trigger the Update Prompt
Once the new version is live:
1. Go to Firebase Remote Config.
2. Set `latest_app_version` to your new version (e.g., `1.3.0`).
3. (Optional) Set `min_app_version` to `1.3.0` if you want to **Force Update** everyone.
4. Update `latest_apk_url` if you are distributing via a direct link.
5. Publish Changes.

---

## Deployment Checklist
- [ ] Ran `flutter test` and all passed.
- [ ] Version number bumped in `pubspec.yaml`.
- [ ] Native changes? Use Layer 3. Logic fix? Use Layer 2.
- [ ] Verified Firebase Remote Config keys match `remote_config_service.dart`.
