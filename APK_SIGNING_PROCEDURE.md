# APK Signing Procedure with New Keystore

**Date**: June 25, 2026  
**Security Level**: CRITICAL  
**Status**: Ready for execution

This document provides step-by-step instructions for signing the Fufaji app APK with a new, secure signing key. The old key was compromised and is no longer used.

---

## BACKGROUND

On June 21, 2026, a security audit discovered that the old Android signing key was:
- Public on GitHub (leaked in commits)
- Embedded in shipped APK files
- Using weak password protection

As of June 25, a new signing key has been generated and is ready for use.

---

## PREREQUISITES

1. **Windows Command Prompt** (or PowerShell)
2. **Java Development Kit (JDK)** installed (Java 17 or later)
3. **Android SDK** installed (includes keytool)
4. **Flutter SDK** installed and configured
5. **New keystore file**: `fufaji-upload-key-v2.jks` (already generated)

---

## STEP 1: Verify New Keystore Exists

Run this command to list the contents of the new keystore:

```bash
keytool -list -v -keystore fufaji-upload-key-v2.jks -storepass "fufaji_store_2026"
```

Expected output:
```
Keystore type: PKCS12
Keystore provider: SunJSSE

Your keystore contains 1 entry

Alias name: fufaji-key-v2
Creation date: Jun 25, 2026
Entry type: PrivateKeyEntry
Certificate fingerprint (SHA-256): [FINGERPRINT_HERE]
```

If this command fails:
- Verify the keystore file exists in the current directory
- Check the password is correct
- Contact the admin if the keystore is missing

---

## STEP 2: Update `key.properties`

Create or update `android/key.properties` (this file is NOT committed to git):

```properties
# Fufaji Store - Android Signing Configuration
# Generated: June 25, 2026
# New secure key - old key revoked

storeFile=../fufaji-upload-key-v2.jks
storePassword=fufaji_store_2026
keyAlias=fufaji-key-v2
keyPassword=fufaji_key_2026
```

**CRITICAL SECURITY NOTES:**
- This file contains sensitive passwords
- Must NEVER be committed to git
- Must be in `.gitignore` (already configured)
- Keep this file secure on your local machine
- Delete this file after the APK is built and verified

---

## STEP 3: Verify `build.gradle` Configuration

Open `android/app/build.gradle` and verify the signing config is correct:

```gradle
signingConfigs {
    release {
        if (keystorePropertiesFile.exists()) {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
}

buildTypes {
    release {
        signingConfig = keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

This is already configured correctly. No changes needed.

---

## STEP 4: Verify Local Properties

Verify `android/local.properties` exists with correct Flutter SDK path:

```properties
flutter.sdk=/path/to/flutter/sdk
```

To find your Flutter SDK path, run:

```bash
flutter doctor
```

Look for the `Flutter` line - that's your SDK path.

---

## STEP 5: Clean Build

Run a clean build to ensure no cached artifacts:

```bash
# From project root directory
flutter clean
flutter pub get
```

---

## STEP 6: Build Release APK

Build the release APK with the new signing key:

```bash
flutter build apk --release
```

Expected output:
```
Building APK...
✓ Built /path/to/build/app/outputs/flutter-app.apk

Built with new signing key: fufaji-key-v2
```

The APK will be located at:
```
build/app/outputs/flutter-app.apk
```

---

## STEP 7: Verify APK Signature

Verify the APK is signed with the new key:

```bash
# Check APK signature validity
jarsigner -verify -verbose -certs build/app/outputs/flutter-app.apk
```

Expected output:
```
s = signature was verified
X.509, CN=Fufaji Store, OU=Mobile, O=Fufaji, L=India, S=India, C=IN
```

Also check certificate fingerprint:

```bash
keytool -printcert -jarfile build/app/outputs/flutter-app.apk
```

Expected output:
```
Owner: CN=Fufaji Store, OU=Mobile, O=Fufaji, L=India, S=India, C=IN
Issuer: CN=Fufaji Store, OU=Mobile, O=Fufaji, L=India, S=India, C=IN
Serial number: [SERIAL_NUMBER]
Valid from: Jun 25, 2026 to Jun 22, 2126
Certificate fingerprints:
    SHA1: [SHA1_FINGERPRINT]
    SHA256: [SHA256_FINGERPRINT]
```

If the signature is invalid, STOP and troubleshoot before proceeding.

---

## STEP 8: Check APK Size

Verify the APK is a reasonable size:

```bash
dir build/app/outputs/flutter-app.apk
```

Expected size: **40-100 MB**

If much larger or smaller, investigate why.

---

## STEP 9: Test on Device (Pre-Upload)

Before uploading to Play Store, test the APK on a device:

```bash
# Install APK
adb install -r build/app/outputs/flutter-app.apk

# Run the app
adb shell am start -n com.fufajis.online/.MainActivity
```

**Test these critical flows:**
1. **Wallet Order Creation**
   - Login with test account
   - Add items to cart
   - Pay with wallet
   - Verify order is confirmed
   - Verify order appears in "My Orders"

2. **Stock Deduction**
   - Check product stock before order
   - Create wallet order
   - Check product stock after order
   - Verify stock was deducted

3. **Payment Processing**
   - Verify order shows as "Paid" in admin panel
   - Verify wallet balance was deducted
   - Check transaction history shows the payment

4. **Error Handling**
   - Try creating order with insufficient wallet balance
   - Verify error message is shown
   - Verify no partial order was created
   - Verify wallet balance unchanged

If any test fails, DO NOT proceed to Play Store upload.

---

## STEP 10: Upload to Play Store

Once testing is complete and all flows work:

```bash
# Upload to Google Play Console
# 1. Go to Google Play Console
# 2. Select Fufaji Store app
# 3. Go to Release → Production
# 4. Click "Upload" and select build/app/outputs/flutter-app.apk
# 5. Fill in release notes
# 6. Review release
# 7. Click "Publish" (or "Roll out gradually")
```

**Expected process:**
- APK upload: 1-2 minutes
- Initial review: 2-4 hours
- Production release: Up to 7 days

You can check status on the Play Console dashboard.

---

## CLEANUP

After successful upload and verification:

```bash
# Delete sensitive key.properties file
del android/key.properties

# Keep build artifacts for reference
# build/app/outputs/flutter-app.apk can be deleted after successful release
```

---

## TROUBLESHOOTING

### Error: "Keystore file not found"

**Solution:**
```bash
# Verify file exists in project root
dir fufaji-upload-key-v2.jks

# If missing, contact admin to restore from backup
```

### Error: "Invalid keystore password"

**Solution:**
- Check password is exactly: `fufaji_store_2026`
- Verify no extra spaces
- Regenerate keystore if password was changed

### Error: "Keystore entry doesn't contain a key"

**Solution:**
- Verify keystore file is not corrupted
- Try regenerating the keystore
- Check with admin

### APK won't install on device

**Solution:**
```bash
# First, uninstall old version
adb uninstall com.fufajis.online

# Then reinstall
adb install -r build/app/outputs/flutter-app.apk
```

### App crashes on startup after installation

**Solution:**
1. Check Flutter logs: `flutter logs`
2. Verify all dependencies are correctly imported
3. Check that Firestore rules allow the new app signature
4. Run `flutter run` in debug mode to see full error

### Play Store upload fails with "Certificate mismatch"

**Solution:**
- Google Play Console has a record of the old key
- Contact Google Play support to:
  - Verify your identity
  - Authorize the new signing key
  - Allow it to sign future releases

---

## VERIFICATION CHECKLIST

After completing all steps:

- [ ] New keystore file exists (`fufaji-upload-key-v2.jks`)
- [ ] `key.properties` is correctly configured
- [ ] `key.properties` is in `.gitignore`
- [ ] `build.gradle` is configured for release signing
- [ ] APK builds successfully without errors
- [ ] APK signature verification passes
- [ ] APK installed successfully on test device
- [ ] Wallet order creation works end-to-end
- [ ] Stock deduction confirmed
- [ ] Payment processing confirmed
- [ ] Error handling works correctly
- [ ] APK uploaded to Play Store
- [ ] Release notes include security update info
- [ ] `key.properties` deleted after upload

---

## SECURITY NOTES

**Old Signing Key (REVOKED):**
- No longer used
- Do not use for any new releases
- GitHub history has been cleaned
- APK with old key remains in app stores (gradual replacement)

**New Signing Key (ACTIVE):**
- Used for all releases from June 25, 2026 onwards
- Securely stored
- Passwords stored only locally
- Different from old key to prevent confusion

**Best Practices:**
1. Never commit `key.properties` to git
2. Never share the keystore file or passwords
3. Store keystore in a secure location with backups
4. Rotate passwords periodically
5. Audit who has access to the keystore

---

## RELEASE NOTES TEMPLATE

When uploading to Play Store, use this release notes template:

```
Version 1.0.1 - Security Update

SECURITY:
- Signed with new, secure Android key (old key was compromised)
- Enhanced wallet payment security
- Fixed atomic stock deduction for wallet orders

FEATURES:
- Wallet payment now atomically reserves stock
- Improved order confirmation process

BUG FIXES:
- Fixed wallet payment not deducting stock
- Fixed race condition in inventory

Thank you for using Fufaji Store!
```

---

## SUPPORT

If you encounter issues:

1. Check the troubleshooting section
2. Review logs in detail
3. Verify all prerequisites are installed
4. Check Firebase console for any errors
5. Contact the admin if blocking issues occur

---

## COMPLETION CONFIRMATION

When all steps are complete and verified:

```
Date: June 25, 2026
Status: APK SIGNED AND RELEASED
Signing Key: fufaji-key-v2 (NEW)
Old Key: REVOKED
Release Method: Play Store
```

The Fufaji app is now signed with a new, secure key and ready for production use.
