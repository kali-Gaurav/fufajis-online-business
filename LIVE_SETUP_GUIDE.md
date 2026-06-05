# 🚀 Fufaji's Online — Complete Live Setup Guide
**Everything you need to make every feature work in production**

> Do these steps IN ORDER. Each section is independent but the order matters.

---

## 📊 Current Status at a Glance

| Feature | Key Location | Status |
|---------|-------------|--------|
| Firebase (Auth, DB, FCM) | `google-services.json` | ✅ Configured |
| Razorpay Payments | `.env` + Functions config | ✅ Key in app / ⚙️ Secret needs Functions config |
| Google Maps + Routes | `AndroidManifest.xml` | ✅ `AIzaSyAcxtNxcPCuqoJN...` |
| Gemini AI (OCR, Voice) | `.env` | ✅ `AIzaSyA9OOupynXhH77M...` |
| Shorebird OTA Updates | `shorebird.yaml` | ✅ App ID set |
| WhatsApp Notifications | Functions config | ⚙️ Set once via script |
| Twilio SMS (OTP fallback) | Functions config | ⚙️ Set once via script |
| Release Keystore | `android/` folder | ⚠️ Auto-generated on first BUILD_APK.bat run |
| Sentry Crash Reporting | Build argument | ⚠️ Optional — add DSN when ready |
| Firebase SHA-1 for Phone OTP | Firebase Console | 🔴 MUST DO — phone auth won't work without this |

---

## 🔴 STEP 1 — Firebase SHA-1 (Phone OTP will not work without this)

Firebase Phone Authentication requires your app's **SHA-1 fingerprint** registered in the Firebase Console. Without this, the OTP SMS will never be sent on real devices.

### 1A. Get your debug SHA-1 (for testing now)

Open a terminal in your project folder and run:

```bash
cd android
gradlew signingReport
```

Look for the `debug` block output:
```
Variant: debug
Config: debug
Store: C:\Users\YourName\.android\debug.keystore
Alias: androiddebugkey
MD5:  XX:XX:XX...
SHA1: AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12   ← COPY THIS
SHA-256: ...
```

### 1B. Get your release SHA-1 (for the signed APK)

After running `BUILD_APK.bat` (which creates the keystore), run:

```bash
keytool -list -v -keystore android\fufaji-upload-key.jks -alias upload -storepass fufaji123
```

Copy the **SHA1** line from the output.

### 1C. Add both SHA-1s to Firebase Console

1. Go to → https://console.firebase.google.com/project/fufaji-online-business
2. Click **Project Settings** (gear icon, top left)
3. Scroll to **Your apps** → Android app `com.fufajis.online`
4. Click **Add fingerprint**
5. Paste your **debug SHA-1** → Save
6. Click **Add fingerprint** again
7. Paste your **release SHA-1** → Save
8. Click **Download google-services.json** → Replace `android/app/google-services.json`

> ✅ Phone OTP will now work on real Android devices.

---

## ⚙️ STEP 2 — Firebase Functions Secrets (One-time setup)

All server-side secrets are set here — they never go in the app.

### 2A. Install Firebase CLI (if not already)

```bash
npm install -g firebase-tools
firebase login
```

### 2B. Run the config script

Double-click: **`scripts\setup_functions_config.bat`**

Or run manually:

```bash
# Razorpay (server-side secret — NEVER in .env)
firebase functions:config:set razorpay.key_secret="ieGG9GcxgN0km2ZVcGyaGEG6"
firebase functions:config:set razorpay.webhook_secret="YOUR_RAZORPAY_WEBHOOK_SECRET"

# WhatsApp Business API
firebase functions:config:set whatsapp.token="EAASZAhYl2VnEB..."
firebase functions:config:set whatsapp.phone_id="1086896934513865"
firebase functions:config:set whatsapp.verify_token="fufaji_webhook_verify_2026"

# Twilio SMS (OTP fallback)
firebase functions:config:set twilio.account_sid="AC33d253da4a1076582dc464d9d5e5835f"
firebase functions:config:set twilio.auth_token="e1a666462f5476a669d9058c059831ce"
firebase functions:config:set twilio.phone_number="+91XXXXXXXXXX"

# App settings
firebase functions:config:set app.owner_phone="+919XXXXXXXXX"
```

### 2C. Deploy Cloud Functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

This deploys all **25 Cloud Functions** including:
- `razorpayWebhook` — payment reconciliation
- `verifyRazorpayPayment` — server-side signature check
- `whatsappWebhook` — bot messages
- `onOrderUpdate` — auto-WhatsApp on order status change
- `checkInventoryAlerts` — hourly stock checks
- `sendDailyOwnerReport` — nightly WhatsApp report
- `processNotificationQueue` — FCM push delivery

---

## 💳 STEP 3 — Razorpay Webhook Setup

Your Razorpay dashboard must point to your Cloud Function for payment reconciliation.

### 3A. Get your Cloud Function URL

After deploying functions, run:
```bash
firebase functions:list
```
Note the URL for `razorpayWebhook`:
```
https://us-central1-fufaji-online-business.cloudfunctions.net/razorpayWebhook
```

### 3B. Configure in Razorpay Dashboard

1. Go to → https://dashboard.razorpay.com/app/webhooks
2. Click **Add New Webhook**
3. Webhook URL: `https://us-central1-fufaji-online-business.cloudfunctions.net/razorpayWebhook`
4. Secret: Create a strong secret (e.g. `Fufaji@Webhook2026!`)
5. Events to subscribe:
   - ✅ `payment.captured`
   - ✅ `payment.failed`
   - ✅ `payment.authorized`
   - ✅ `order.paid`
   - ✅ `refund.created`
6. Click **Create Webhook**

### 3C. Update the webhook secret in Functions config

```bash
firebase functions:config:set razorpay.webhook_secret="Fufaji@Webhook2026!"
firebase deploy --only functions
```

---

## 📱 STEP 4 — WhatsApp Business API Webhook

Your WhatsApp bot won't receive customer messages without this.

### 4A. Get Cloud Function URL

```
https://us-central1-fufaji-online-business.cloudfunctions.net/whatsappWebhook
```

### 4B. Configure in Meta Developer Console

1. Go to → https://developers.facebook.com/apps
2. Select your WhatsApp app → **WhatsApp → Configuration**
3. **Webhook URL**: paste the Cloud Function URL above
4. **Verify Token**: `fufaji_webhook_verify_2026`
5. Click **Verify and Save**
6. Subscribe to webhooks:
   - ✅ `messages` — incoming customer messages
   - ✅ `message_deliveries`
   - ✅ `message_reads`

### 4C. Check WhatsApp Token Expiry

WhatsApp tokens expire! Check yours at:
→ https://developers.facebook.com/tools/accesstoken/

If expired, generate a new **System User Token** (never-expiring) in Meta Business Settings.

---

## 🗺️ STEP 5 — Google Maps API Key Restrictions

Your Maps key `AIzaSyAcxtNxcPCuqoJN...` is in the AndroidManifest. Restrict it so it can only be used from your app.

1. Go to → https://console.cloud.google.com/apis/credentials
2. Find the key used in AndroidManifest
3. Under **Application restrictions** → Select **Android apps**
4. Click **Add an item**:
   - Package name: `com.fufajis.online`
   - SHA-1: (same fingerprints from Step 1)
5. Under **API restrictions** → **Restrict key** → Select:
   - ✅ Maps SDK for Android
   - ✅ Directions API
   - ✅ Geocoding API
   - ✅ Places API (for address autocomplete)
6. **Save**

---

## 🔒 STEP 6 — Firebase App Check (Prevents API abuse)

Already configured in code. Activate in Firebase Console:

1. Go to → https://console.firebase.google.com/project/fufaji-online-business/appcheck
2. Click **Get started**
3. Register your Android app with **Play Integrity** provider
4. Enable enforcement for:
   - ✅ Firestore
   - ✅ Cloud Functions
   - ✅ Storage
   - ✅ Authentication

> For debug testing: Add your debug token to avoid App Check blocking during development.
> Firebase Console → App Check → Apps → Your app → **Manage debug tokens** → Add token from your device logs.

---

## 🔔 STEP 7 — Firebase Cloud Messaging (Push Notifications)

FCM is already configured. Enable these in Firebase Console:

1. Go to → https://console.firebase.google.com/project/fufaji-online-business/messaging
2. **No action needed** — FCM works automatically with `google-services.json` ✅

### Set up notification categories (optional but recommended):

In your Firestore, create `settings/notification_config`:
```json
{
  "order_updates": true,
  "promotions": true,
  "inventory_alerts": true,
  "daily_report": true,
  "report_time": "21:00"
}
```

---

## 📦 STEP 8 — Deploy Firestore Rules & Indexes

```bash
# Deploy security rules (locks down your database)
firebase deploy --only firestore:rules

# Deploy indexes (required for complex queries)
firebase deploy --only firestore:indexes

# Deploy storage rules
firebase deploy --only storage
```

---

## 🌱 STEP 9 — Seed Initial Data

Your app needs this data in Firestore to work on first launch:

### 9A. Add your owner phone as authorized

In Firebase Console → Firestore → `pre_authorized_users` collection:

Create document with ID = your phone number (digits only, no +):
```
Document ID: 919XXXXXXXXX

Fields:
  role: "UserRole.shopOwner"
  name: "Gaurav Nagar"
  isMfaRequired: false
  createdAt: (timestamp)
```

### 9B. Create Shop Config

In Firestore → `settings` → `shop_config`:
```json
{
  "shopName": "Fufaji's Online",
  "shopPhone": "+91XXXXXXXXXX",
  "shopLatitude": 25.1006,
  "shopLongitude": 76.5156,
  "maxDeliveryRadiusKm": 15,
  "isOpen": true,
  "openTime": "09:00",
  "closeTime": "21:00",
  "freeDeliveryAbove": 499,
  "standardDeliveryFee": 30,
  "expressDeliveryFee": 60,
  "minimumOrderValue": 99,
  "whatsappNumber": "+91XXXXXXXXXX",
  "upiId": "yourname@upi"
}
```

### 9C. Add at least 5 products to test

In Firestore → `products` → Add documents:
```json
{
  "name": "Aata (Wheat Flour)",
  "category": "groceries",
  "price": 45.0,
  "originalPrice": 52.0,
  "unit": "1 kg",
  "stockQuantity": 200,
  "isActive": true,
  "isFeatured": true,
  "tags": ["aata", "flour", "wheat", "atta"],
  "imageUrl": "https://...",
  "createdAt": (timestamp)
}
```

---

## 🔑 STEP 10 — Sentry Crash Reporting (Optional but Recommended)

1. Sign up at → https://sentry.io (free tier available)
2. Create a new project → Platform: Flutter
3. Copy your DSN: `https://XXXX@oXXXX.ingest.sentry.io/XXXXX`
4. Add to your build command:

```bash
# Instead of:
flutter build apk --release

# Use:
flutter build apk --release --dart-define=SENTRY_DSN=https://XXXX@oXXXX.ingest.sentry.io/XXXXX
```

Or add to `BUILD_APK.bat` (already has the slot for it).

---

## ✅ FINAL LIVE CHECKLIST

Run through this after completing all steps:

### Auth & OTP
- [ ] Sent SMS OTP to your own phone number — received within 30 seconds
- [ ] Logged in as Customer → reached Home screen
- [ ] Logged in as Owner → reached Owner Dashboard (must be in `pre_authorized_users`)
- [ ] OTP resend button appears after 60 seconds

### Payments
- [ ] Added item to cart → went to checkout
- [ ] Chose "Online Payment" → Razorpay sheet opened
- [ ] Made ₹1 test payment → got confirmation
- [ ] Checked Firestore `orders` → `paymentStatus: "paid"`
- [ ] Checked Razorpay Dashboard → webhook events received

### WhatsApp
- [ ] Placed test order → received WhatsApp message within 30 seconds
- [ ] Message shows order number, items, total
- [ ] Sent "Hi" to your WhatsApp Business number → bot replies

### Orders
- [ ] Owner Dashboard shows new order
- [ ] Changed order to "Out for Delivery" → customer got WhatsApp with OTP
- [ ] Delivery agent sees order in their dashboard
- [ ] Marked delivered → order status updated in Firestore

### AI Features
- [ ] Voice search: say "sugar" → products appear
- [ ] Snap-to-Shop: take photo of product → added to cart suggestion
- [ ] Bill scanner: photograph a bill → items auto-populated

### Maps
- [ ] Delivery tracking screen shows map
- [ ] Route optimization works for delivery agent
- [ ] Address picker shows map with pin

---

## 🆘 Quick Fixes

| Problem | Solution |
|---------|----------|
| Phone OTP never arrives | Complete Step 1 (SHA-1 in Firebase Console) |
| Razorpay shows "Invalid key" | Check `.env` has `LIVE_API_KEY` (not test key) |
| WhatsApp messages not sent | Deploy Functions (Step 2C) + set `whatsapp.token` |
| Maps shows grey screen | API key not restricted properly, or billing not enabled in Google Cloud |
| App crashes on launch | Run `flutter clean && flutter pub get` then rebuild |
| "App not installed" on phone | Enable "Install unknown apps" in phone settings |
| Firebase permission denied | Deploy Firestore rules (Step 8) |
| Cloud Functions error 500 | Check `firebase functions:log` for details |
| Payment webhook not firing | Verify webhook URL in Razorpay dashboard (Step 3) |

---

## 📞 Your Service Dashboards (Bookmark These)

| Service | Dashboard URL |
|---------|--------------|
| Firebase Console | https://console.firebase.google.com/project/fufaji-online-business |
| Razorpay Dashboard | https://dashboard.razorpay.com |
| Meta WhatsApp Manager | https://business.facebook.com/wa/manage |
| Google Cloud Console | https://console.cloud.google.com |
| Sentry | https://sentry.io |
| Shorebird (OTA) | https://console.shorebird.dev |
| Upstash Redis | https://console.upstash.com |
| Twilio Console | https://console.twilio.com |

---

*Fufaji's Online v1.1.0 | Baran, Rajasthan | "Aapki Apni Dukaan"*
