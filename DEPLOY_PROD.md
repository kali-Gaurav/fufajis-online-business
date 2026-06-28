# 🚀 Fufaji's Online Business — Production Deployment Guide

This guide covers the secure deployment of the Backend (Firebase Functions), Frontend (Flutter Web/Hosting), and the Production APK.

## 📋 Prerequisites
1.  **Firebase CLI**: Installed and logged in (`firebase login`).
2.  **Flutter SDK**: Installed and configured.
3.  **Secrets Rotated**: You **MUST** rotate all secrets in your dashboards (Razorpay, Twilio, WhatsApp) if they were previously exposed in git.

---

## 🔐 Phase 1: Secure Backend Secrets (Firebase Secret Manager)

Firebase Secret Manager is now the source of truth for all sensitive backend keys. These are stored encrypted in Google Cloud.

### 1. Set the Secrets
Run these commands in your terminal. You will be prompted to paste each value securely (it won't appear on screen).

```powershell
# Razorpay
firebase functions:secrets:set RAZORPAY_KEY_ID
firebase functions:secrets:set RAZORPAY_KEY_SECRET
firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET

# Twilio (SMS)
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_PHONE_NUMBER

# WhatsApp (Meta API)
firebase functions:secrets:set WHATSAPP_TOKEN
firebase functions:secrets:set WHATSAPP_PHONE_ID

# Gemini (AI Search)
firebase functions:secrets:set GEMINI_API_KEY
```

### 2. Verify Storage
Check that the names (not values) appear in your project:
```powershell
firebase functions:secrets:list
```

---

## ⚙️ Phase 2: Deploy Backend (Cloud Functions)

Deploy the updated logic that uses these secrets:

```powershell
firebase deploy --only functions
```

---

## 🌐 Phase 3: Deploy Frontend (Firebase Hosting / Web)

Build the web version of the app and deploy it to Firebase Hosting.

```powershell
# Build web with production defines
flutter build web --release `
  --dart-define=API_BASE_URL=https://fufaji-api.render.com `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key `
  --dart-define=RAZORPAY_KEY_ID=rzp_live_your_id

# Deploy to Hosting
firebase deploy --only hosting
```

---

## 📱 Phase 4: Build Production APK

The APK is now "hardened" — it contains **zero** secrets. It only contains public keys.

### 1. Configure the Build Script
Open [BUILD_APK_PRODUCTION.ps1](file:///C:/Projects/fufaji-online-business/BUILD_APK_PRODUCTION.ps1) and update the variables under the `⚠️ UPDATE THESE VALUES` section with your live production values.

### 2. Run the Build
```powershell
.\BUILD_APK_PRODUCTION.ps1
```

The script will:
1.  Clean the project.
2.  Ensure `.env` is **not** bundled in the assets.
3.  Inject public config via `--dart-define`.
4.  Generate signed APKs in `build/app/outputs/flutter-apk/`.

---

## ✅ Verification Checklist

- [ ] **Secret Access**: Verify Cloud Functions don't error out on start (check `firebase functions:log`).
- [ ] **Razorpay Webhook**: Go to Razorpay Dashboard -> Webhooks. Send a "Test Webhook" to `https://us-central1-fufaji-online-business.cloudfunctions.net/razorpayWebhook` and confirm a `200 OK` response.
- [ ] **APK Check**: Use a tool like [APK Analyzer](https://developer.android.com/studio/build/apk-analyzer) in Android Studio to confirm `assets/.env` no longer exists.
- [ ] **SMS/WhatsApp**: Trigger a test order to ensure notifications reach your phone using the new rotated secrets.

---

## 🆘 Troubleshooting

- **"Secret not found" error**: Ensure you ran `firebase functions:secrets:set` for the exact name used in `functions/index.js`.
- **Signature Mismatch**: Double check your `RAZORPAY_WEBHOOK_SECRET` in both the Razorpay Dashboard and Firebase Secrets.
- **Build Errors**: Ensure you have the latest Flutter dependencies (`flutter pub get`).

---
*Created by Gemini AI for Fufaji's Online Business*
