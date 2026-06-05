# 🏪 Fufaji's Online — Pre-Build Checklist
**"Aapki Apni Dukaan — Now on Android"**

Complete every item before building the release APK.

---

## ✅ PHASE 1 — Firebase Setup (One-Time)

### 1.1 Firebase Project
- [ ] Firebase project created at https://console.firebase.google.com
- [ ] `google-services.json` placed at `android/app/google-services.json` ✅ (already done)
- [ ] Firebase Authentication enabled → Phone sign-in enabled
- [ ] Firebase Firestore created in production mode
- [ ] Firebase Storage bucket created
- [ ] Firebase App Check enabled (Play Integrity for Android)

### 1.2 Deploy Firestore Security Rules
```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
```

### 1.3 Deploy Cloud Functions
```bash
cd functions
npm install
cd ..

# Set all server-side secrets (run setup script):
scripts\setup_functions_config.bat

# Deploy all 25 functions:
firebase deploy --only functions
```

### 1.4 Set Remote Config defaults
Go to Firebase Console → Remote Config → Publish defaults:
```json
{
  "festival_mode": "none",
  "maintenance_mode": false,
  "force_update_version": "0.0.0",
  "force_update_url": "",
  "min_supported_version": "1.0.0"
}
```

---

## ✅ PHASE 2 — API Keys & Secrets

### 2.1 Razorpay
- [ ] Live account active at https://dashboard.razorpay.com
- [ ] `.env` has `LIVE_API_KEY=rzp_live_Sr7JfZt4NbXzMw` ✅
- [ ] `LIVE_KEY_SECRET` set in Firebase Functions config only (NOT in .env) ✅
- [ ] Webhook URL configured in Razorpay Dashboard:
  ```
  https://us-central1-YOUR_PROJECT.cloudfunctions.net/razorpayWebhook
  ```
- [ ] Webhook secret added to Functions config:
  ```bash
  firebase functions:config:set razorpay.webhook_secret="YOUR_SECRET"
  ```

### 2.2 WhatsApp Business API
- [ ] Meta Business account verified
- [ ] WhatsApp Business API token active (check expiry — rotate if needed)
- [ ] WHATSAPP_TOKEN set in Firebase Functions config (NOT in Flutter .env) ✅
- [ ] WhatsApp webhook verified in Meta Developer Console:
  ```
  Webhook URL: https://us-central1-YOUR_PROJECT.cloudfunctions.net/whatsappWebhook
  Verify Token: fufaji_webhook_verify_2026
  ```
- [ ] Message templates approved in Meta:
  - `order_confirmed`
  - `order_out_for_delivery`
  - `order_delivered`

### 2.3 Gemini AI
- [ ] `GEMINI_API_KEY` in `.env` ✅ `AIzaSyA9OOupynXhH77Mw2CMaqh7W2GniXOXZwo`
- [ ] API key restrictions set to Android app only in Google Cloud Console

### 2.4 Google Maps
- [ ] Google Maps API key added to `android/app/src/main/AndroidManifest.xml`
  ```xml
  <meta-data android:name="com.google.android.geo.API_KEY"
             android:value="YOUR_GOOGLE_MAPS_KEY"/>
  ```
- [ ] Maps SDK for Android enabled in Google Cloud Console
- [ ] Directions API enabled (for route optimization)
- [ ] Geocoding API enabled

### 2.5 Twilio SMS (optional — for OTP fallback)
- [ ] Twilio Account SID & Auth Token in Firebase Functions config ✅

---

## ✅ PHASE 3 — Android Configuration

### 3.1 Keystore (Release Signing)
- [ ] Keystore generated: `android/fufaji-upload-key.jks`
  - If missing, `BUILD_APK.bat` generates it automatically
- [ ] `android/key.properties` configured ✅
  ```
  storePassword=fufaji123
  keyPassword=fufaji123
  keyAlias=upload
  storeFile=fufaji-upload-key.jks
  ```
- [ ] **⚠️ CRITICAL: Back up `fufaji-upload-key.jks` to Google Drive / external drive**
  - Losing this file = cannot update the app on Play Store

### 3.2 App Identity
- [ ] Package name: `com.fufajis.online` ✅
- [ ] Version in `pubspec.yaml`: `1.1.0+3` ✅
- [ ] App icons placed at `assets/icons/` ✅
- [ ] App name: `Fufaji's Online` ✅

### 3.3 AndroidManifest.xml
- [ ] All required permissions declared ✅
- [ ] UPI app query intents declared (Paytm, PhonePe, GPay) ✅
- [ ] Network security config: `android:usesCleartextTraffic="false"` ✅

### 3.4 Google Play Billing (if needed)
- [ ] `com.android.billingclient` in `build.gradle` if subscriptions are added

---

## ✅ PHASE 4 — Firebase Data Seeding

Seed the Firestore database before first launch:

```bash
# Run the in-app seeder by logging in as Shop Owner
# OR manually add documents:
```

### 4.1 Required Firestore Documents
- [ ] `settings/shop_config` — shop hours, location, delivery radius
- [ ] `pre_authorized_users/` — your owner phone number doc
  ```json
  {
    "role": "UserRole.shopOwner",
    "name": "Gaurav Nagar",
    "isMfaRequired": false
  }
  ```
  Document ID = phone without `+` e.g. `919XXXXXXXXX`
- [ ] `products/` — at least 5 products to test

### 4.2 Required Firestore Indexes (auto-deploy via CLI)
```bash
firebase deploy --only firestore:indexes
```

---

## ✅ PHASE 5 — Real Functionality Testing

Test each feature on a real Android phone before sharing:

### Auth & OTP ✅
- [ ] Phone OTP login — Firebase sends SMS ✅
- [ ] Customer role → routes to home screen ✅
- [ ] Owner role → routes to owner dashboard ✅
- [ ] OTP resend after 60 seconds ✅
- [ ] Invalid OTP shows error ✅

### Payments ✅
- [ ] Razorpay opens when payment method = Online ✅
- [ ] UPI apps listed (GPay, PhonePe, Paytm) ✅
- [ ] Payment success → order status = confirmed ✅
- [ ] Payment failure → order stays pending ✅
- [ ] COD checkout → order created without payment ✅
- [ ] Udhaar checkout → ledger entry created ✅

### Orders ✅
- [ ] Order created in Firestore `orders` collection ✅
- [ ] Order number generated (HLM-XXXXXXXX format) ✅
- [ ] Customer gets WhatsApp confirmation message ✅
- [ ] Owner sees new order in dashboard ✅
- [ ] Order status changes: placed → confirmed → packed → out_for_delivery → delivered ✅
- [ ] Delivery OTP sent to customer via WhatsApp ✅

### WhatsApp Notifications ✅
- [ ] Order confirmed message sent ✅
- [ ] Out for delivery + OTP message sent ✅
- [ ] Invoice sent after delivery ✅
- [ ] Bahi-Khata reminder sent for overdue credit ✅
- [ ] Daily shop report sent at 9 PM ✅

### WhatsApp Bot ✅
- [ ] Webhook receives messages from customers ✅
- [ ] Bill photo → Gemini OCR → inventory updated ✅
- [ ] WhatsApp catalog browsing (if enabled) ✅

### AI Features ✅
- [ ] Snap-to-Shop: camera captures product → cart populated ✅
- [ ] Voice search: Hindi/English commands work ✅
- [ ] Bill scanner: supplier invoice parsed ✅

### Delivery Agent ✅
- [ ] Agent sees assigned orders ✅
- [ ] Route optimized on map ✅
- [ ] OTP verification on delivery ✅
- [ ] COD collection recorded ✅

---

## ✅ PHASE 6 — Build APK

### Option A: Debug APK (for testing)
```batch
BUILD_DEBUG_APK.bat
```
Output: `build\app\outputs\flutter-apk\app-debug.apk`

### Option B: Release APK (for sharing/distribution)
```batch
BUILD_APK.bat
```
Output: `build\app\outputs\flutter-apk\app-release.apk`

### Manual build commands:
```bash
flutter clean
flutter pub get
flutter build apk --release --no-tree-shake-icons
```

### Install on phone via USB:
```bash
adb install build\app\outputs\flutter-apk\app-release.apk
```

---

## ✅ PHASE 7 — Post-Build Verification

- [ ] APK installs without "package not installed" error
- [ ] App launches on Android 7.0+ (minSdk 24) ✅
- [ ] Firebase connection works (no auth errors)
- [ ] Razorpay payment sheet opens
- [ ] Maps loads on delivery screen
- [ ] Push notification received from Firebase
- [ ] WhatsApp message sent on test order
- [ ] Crash reporting working in Sentry dashboard

---

## 🚨 Common Build Errors & Fixes

| Error | Fix |
|-------|-----|
| `flutter SDK not found` | Add Flutter to PATH: `C:\flutter\bin` |
| `keytool not found` | Install JDK: https://adoptium.net/ |
| `google-services.json missing` | Download from Firebase Console |
| `minSdkVersion too low` | Already set to 24 ✅ |
| `Razorpay crash on release` | ProGuard rules already added ✅ |
| `DexArchiveMergerException` | `flutter clean` then rebuild |
| `Gradle build failed` | Run `cd android && gradlew clean` |
| `AAPT: error: resource not found` | Check `assets/images/` folder exists |
| `AppCheck failed` | Normal in debug mode — add test device token |

---

## 📞 Support

- **Firebase Console**: https://console.firebase.google.com
- **Razorpay Dashboard**: https://dashboard.razorpay.com
- **Meta WhatsApp Manager**: https://business.facebook.com/wa/manage
- **Sentry Dashboard**: https://sentry.io
- **Flutter Docs**: https://flutter.dev/docs

---

*Last updated: June 2026 | Fufaji's Online v1.1.0*
