# Phase 3: Flutter Backend Integration & APK Release Setup

## Overview

This document guides you through setting up the Flutter app to use the FastAPI backend, building release APKs, and deploying via Shorebird OTA updates.

## Prerequisites

- Flutter 3.16+ installed
- Java 21+ (for APK building)
- Git configured on your machine
- GitHub repository with write access
- Shorebird account (for OTA updates)

## Step 1: Environment Configuration

### Development Setup

1. Copy `.env.development` to your local environment:
```bash
# On your machine (Windows/Mac/Linux)
cp .env.development .env.local
```

2. Update with your local values:
```bash
API_BASE_URL=http://localhost:8000
RAZORPAY_KEY_ID=rzp_test_your_key
RAZORPAY_KEY_SECRET=test_secret
```

3. Load environment during development:
```bash
# Run the Flutter app with local API
flutter run --dart-define-from-file=.env.development
```

### Production Setup

1. Update `.env.production` with your production values:
```bash
API_BASE_URL=https://api.fufaji.com
RAZORPAY_KEY_ID=rzp_live_your_key
# ... other secrets
```

2. These values are passed via GitHub Secrets during CI/CD builds (no need to commit)

## Step 2: Local Testing with FastAPI Backend

### Terminal 1: Start FastAPI Backend

```bash
# Assuming you have the FastAPI backend in backend/ directory
cd backend
pip install -r requirements.txt
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Terminal 2: Run Flutter App

```bash
cd flutter
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000  # Android emulator
# or for device:
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

### Terminal 3 (Optional): Start Firestore Emulator

```bash
firebase emulators:start --only firestore,auth
```

### Test Payment Flow

1. Open app and sign in
2. Create an order
3. Click "Pay Now"
4. Complete Razorpay payment (use test credentials)
5. Verify order status changes to "Paid" in Firestore
6. Check backend logs for signature verification success

## Step 3: Building Release APK Locally

### Verify Signing Configuration

```bash
# Check if signing key exists
ls android/app/upload-keystore.jks
cat android/key.properties
```

If missing, create a new signing key:
```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload -storepass password -keypass password
```

### Build Release APK

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.fufaji.com \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_your_key \
  --dart-define=RAZORPAY_KEY_SECRET=your_secret \
  --dart-define=RAZORPAY_WEBHOOK_SECRET=your_webhook_secret
```

Output:
```
build/app/outputs/flutter-apk/app-release.apk
Size: ~65 MB
```

### Test APK Locally

```bash
# Connect Android device
flutter install

# Or install APK directly:
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Grant permissions and test:
# 1. Sign in
# 2. Browse products
# 3. Create order
# 4. Verify payment flow works
```

## Step 4: Release via Shorebird (OTA Updates)

Shorebird allows instant code updates without Play Store review!

### Prerequisites

```bash
# Install Shorebird CLI
# macOS:
brew install shorebird

# Windows/Linux: See https://docs.shorebird.dev/cli
```

### First Time Setup

```bash
# Login to Shorebird
shorebird login

# Initialize Shorebird for your app (interactive)
shorebird init

# This updates shorebird.yaml with your app_id
```

### Release to Production

```bash
# Build and release via Shorebird (replaces direct APK builds)
shorebird release android

# This:
# 1. Builds the app
# 2. Signs with your keystore
# 3. Uploads to Shorebird servers
# 4. Users auto-update instantly
```

### Release Patch Update (Dart-only changes)

```bash
# Patch releases are fast (Dart code only, no native rebuild)
shorebird patch android

# This makes updates available instantly to all users
```

## Step 5: GitHub Secrets Configuration

Set these in your GitHub repository Settings → Secrets and variables → Actions:

```
API_BASE_URL=https://api.fufaji.com
RAZORPAY_KEY_ID=rzp_live_your_key
RAZORPAY_KEY_SECRET=your_secret
RAZORPAY_WEBHOOK_SECRET=your_webhook_secret
SENTRY_DSN=https://your-sentry-dsn
GOOGLE_MAPS_KEY=your_maps_key
STRIPE_PUBLISHABLE_KEY=pk_live_your_key

# For signing APK
KEYSTORE_BASE64=<base64 encoded keystore>
STORE_PASSWORD=your_password
KEY_PASSWORD=your_password
KEY_ALIAS=upload

# For Firebase Distribution
FIREBASE_APP_ID=your_app_id
FIREBASE_TOKEN=your_firebase_token
```

### Generate KEYSTORE_BASE64

```bash
# On your machine
base64 -w 0 android/app/upload-keystore.jks | pbcopy  # macOS
# Windows PowerShell:
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android/app/upload-keystore.jks")) | Set-Clipboard
```

## Step 6: Trigger GitHub Actions Build

### Via Git Push

```bash
# Commit your changes
git add .
git commit -m "feat: Phase 3 - FastAPI backend integration + APK release ready"

# Push to main (triggers build_and_release.yml)
git push origin main
```

### Via Manual Trigger

1. Go to GitHub Actions
2. Select "Build & Release Custom APK"
3. Click "Run workflow"

## Step 7: Create Release on GitHub

Once build succeeds:

```bash
# Create release tag
git tag -a v1.0.0-production -m "Production ready: FastAPI backend integration"

# Push tag (GitHub Actions creates release automatically)
git push origin v1.0.0-production
```

Or create manually:
1. Go to GitHub Releases
2. Click "Create a new release"
3. Tag: `v1.0.0-production`
4. Title: "Fufaji Store v1.0.0 - Production Ready"
5. Add release notes (see RELEASE_NOTES.md)
6. Upload APK from Actions artifacts

## Step 8: User Installation

### From GitHub Release

1. Visit: https://github.com/your-user/fufaji-online-business/releases
2. Download latest `app-release.apk`
3. Enable "Unknown Sources" in Android settings
4. Install APK

### Via Shorebird Auto-Update

1. Install app from GitHub
2. App auto-updates on next launch (if configured)
3. No Play Store needed!

### Via Play Store (Future)

When ready to publish:

```bash
# Create Play Store release
flutter build appbundle --release
# Upload to Google Play Console
```

## Troubleshooting

### "API_BASE_URL is not configured"

```bash
# Ensure you're passing --dart-define when building
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

### "Payment fails with 400 error"

Check:
1. Backend API is running: `curl http://localhost:8000/health`
2. Firebase Auth token is valid: Check Logcat logs
3. Razorpay credentials in backend match Flutter app

### "Shorebird patch fails"

```bash
# Clear Shorebird cache
rm -rf ~/.shorebird

# Re-login
shorebird login

# Try again
shorebird patch android
```

## Next Steps

1. Deploy FastAPI backend to production VPS
2. Set up SSL/TLS certificate for `api.fufaji.com`
3. Configure database backups
4. Set up monitoring and alerting
5. Create deployment runbook
6. Test end-to-end payment flow in production

## References

- [Shorebird Documentation](https://docs.shorebird.dev)
- [Flutter APK Building](https://docs.flutter.dev/deployment/android)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)
- [GitHub Actions Flutter](https://github.com/subosito/flutter-action)

---

**Last Updated:** 2026-06-22
**Status:** Ready for execution
