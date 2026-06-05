# Fufaji's Online — Complete Build & Release Guide
## App: com.fufajis.online | Shop: Baran, Rajasthan

---

## ⚡ QUICK START (5 steps to APK)

```powershell
# Step 1: Get packages
flutter pub get

# Step 2: Build debug APK (for testing)
flutter build apk --debug --no-tree-shake-icons

# Step 3: Build release APK
flutter build apk --release --no-tree-shake-icons

# APK is at: build\app\outputs\flutter-apk\app-release.apk
```

---

## 🔑 BEFORE FIRST BUILD — Required Setup

### 1. Rotate ALL Compromised Credentials (CRITICAL)
The old credentials were exposed. Rotate them NOW before doing anything else:

| Service | Where to Rotate | Old Key Prefix |
|---------|----------------|----------------|
| **Razorpay** | dashboard.razorpay.com → Settings → API Keys → Regenerate | `rzp_live_Sr7...` |
| **Twilio** | console.twilio.com → Account → API Keys → Revoke | `SKcdeec...` |
| **Gemini** | aistudio.google.com → API Keys → Delete & New | `AIzaSyA9...` |
| **WhatsApp** | Meta Business Manager → System Users → Revoke | `EASZA...` |
| **Upstash Redis** | console.upstash.com → Database → Reset Token | — |

### 2. Update .env with New Razorpay Public Key
```
# .env (project root)
LIVE_API_KEY=rzp_live_YOUR_NEW_PUBLIC_KEY_HERE
SUPPORT_WHATSAPP_NUMBER=91XXXXXXXXXX    # Your WhatsApp number
APK_DOWNLOAD_URL=https://yoursite.com/fufajis.apk
```

### 3. Set Firebase Functions Config (server-side secrets only)
```bash
firebase functions:config:set \
  razorpay.key_id="rzp_live_YOUR_KEY" \
  razorpay.key_secret="YOUR_SECRET_AFTER_ROTATION" \
  razorpay.webhook_secret="YOUR_WEBHOOK_SECRET" \
  twilio.account_sid="ACxx_NEW" \
  twilio.auth_token="xx_NEW" \
  twilio.phone_number="+91XXXXXXXXXX" \
  whatsapp.token="YOUR_NEW_TOKEN" \
  whatsapp.phone_id="YOUR_PHONE_ID" \
  gemini.api_key="YOUR_NEW_GEMINI_KEY"

# Deploy functions
firebase deploy --only functions
```

---

## 🏗️ Complete Setup Checklist

### Firebase Setup
- [ ] Firebase project ID: `fufaji-online-business`
- [ ] `android/app/google-services.json` — EXISTS ✓
- [ ] Enable **Phone Authentication** in Firebase Console
- [ ] Add test phone numbers in Firebase Auth console (for dev)
- [ ] Deploy Firestore rules: `firebase deploy --only firestore:rules`
- [ ] Enable Firebase App Check (optional for debug, required for production)

### Android Signing (for Release APK)
```powershell
# Generate a keystore (run once)
keytool -genkey -v -keystore android\upload-keystore.jks `
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload

# Then update android\key.properties:
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

### AdMob (Google Ads)
- Current test Ad Unit ID in `lib/services/ad_service.dart` is real production ID
- Replace with your AdMob App ID in `android/app/src/main/AndroidManifest.xml`
- Look for: `com.google.android.gms.ads.APPLICATION_ID`

---

## 📱 Build Commands

```powershell
# Debug build (faster, for testing)
flutter build apk --debug

# Release build (optimized, for distribution)
flutter build apk --release --no-tree-shake-icons

# Split APKs by ABI (smaller download size)
flutter build apk --release --split-per-abi

# App Bundle (for Play Store)
flutter build appbundle --release
```

---

## 🧪 Testing Before Release

### Test Flow 1: Customer
1. Open app → Enter phone number → Enter OTP
2. Browse products → Add to cart → Checkout
3. Place COD order → Check order in Orders tab
4. Test Razorpay payment (use test mode first)

### Test Flow 2: Owner
1. Login with owner phone (must be pre-authorized in Firestore)
2. Add product → Check inventory
3. View incoming orders → Update status

### Test Flow 3: Delivery Agent  
1. Login with delivery phone (must be pre-authorized)
2. View assigned orders → Update delivery status

### Pre-authorize Owner/Delivery phones
In Firebase Firestore, create document:
```
Collection: pre_authorized_users
Document ID: 91XXXXXXXXXX (phone without +)
Fields:
  role: "UserRole.shopOwner"   (or "UserRole.deliveryAgent")
  name: "Your Name"
```

---

## 🚨 Common Build Issues & Fixes

### "Gradle build failed"
```powershell
cd android && .\gradlew clean && cd ..
flutter clean && flutter pub get
flutter build apk --release
```

### "Package not found"
```powershell
flutter pub cache repair
flutter pub get
```

### ".env not found warning"
Normal — the app runs without it, but Razorpay won't work.
Make sure `.env` exists in project root with `LIVE_API_KEY=rzp_live_...`

### "Firebase App Check failed"
Normal in debug mode. App Check is optional for development.
Disable it in `lib/main.dart` for debug builds if needed.

### "Kotlin version mismatch"
Already handled in `android/build.gradle` with jvmTarget = "21".

---

## 📦 APK Distribution to Customers

### Option 1: Direct Share (QR Code)
1. Build APK: `flutter build apk --release`
2. Upload to Google Drive or Firebase Hosting
3. Generate QR code pointing to download URL
4. Print QR and put it in your shop

### Option 2: WhatsApp Share
Send APK directly to customers via WhatsApp.

### Option 3: Play Store (future)
Build App Bundle: `flutter build appbundle --release`
Upload to Google Play Console.

---

## 🔧 App Configuration

Key settings in `lib/config/app_config.dart`:
- Shop coordinates: Baran, Rajasthan (25.1006°N, 76.5156°E)
- Delivery radius: 15km default
- Free delivery above: ₹499
- Minimum order: configurable in Firestore `settings/shop_config`

Runtime config (editable without app update) stored in:
`Firestore → settings → shop_config`

---

## 📞 Support
- Company: Routemaster Intelligent Systems Pvt. Ltd.
- App: Fufaji's Online
- Package: com.fufajis.online
