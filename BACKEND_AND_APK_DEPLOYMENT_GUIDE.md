# Fufaji Complete Deployment Guide
## Backend (Node.js on Render) + APK Release

**Status**: READY FOR PRODUCTION  
**Date**: 2026-06-22  
**Backend**: Node.js + Express (Render free tier)  
**APK**: Flutter release build  
**Timeline**: 30 minutes to live

---

## STEP 1: Set Up Node.js Backend on Render (10 minutes)

### 1A. Create GitHub repo for backend

```bash
# Create directory
mkdir -p ~/fufaji-backend
cd ~/fufaji-backend

# Initialize git
git init
git branch -M main
```

Copy ALL files from the Node.js backend (provided in outputs) into this directory.

### 1B. Get Firebase Service Account JSON

1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Download `fufaji-online-business-firebase-adminsdk.json`
4. **DO NOT COMMIT THIS FILE** - add to .gitignore

### 1C. Create .env.example (committed to GitHub)

```
FIREBASE_PROJECT_ID=fufaji-online-business
FIREBASE_SERVICE_ACCOUNT_PATH=/tmp/firebase-key.json
RAZORPAY_KEY_ID=your_razorpay_key_id
RAZORPAY_KEY_SECRET=your_razorpay_key_secret
RAZORPAY_WEBHOOK_SECRET=your_razorpay_webhook_secret
ENVIRONMENT=production
PORT=8000
NODE_ENV=production
```

### 1D. Push to GitHub

```bash
git add .
git commit -m "feat: Node.js + Express backend for Render free tier"
git remote add origin https://github.com/YOUR_USERNAME/fufaji-backend.git
git push -u origin main
```

### 1E. Deploy on Render

1. Go to https://render.com
2. Sign up (free account)
3. Click "New" → "Web Service"
4. Connect your GitHub repo (fufaji-backend)
5. Fill in:
   - **Name**: `fufaji-api`
   - **Runtime**: Node
   - **Build command**: `npm install`
   - **Start command**: `npm start`
   - **Instance Type**: Free

6. Add Environment Variables (in Render dashboard):
   ```
   FIREBASE_PROJECT_ID=fufaji-online-business
   FIREBASE_SERVICE_ACCOUNT_PATH=/tmp/firebase-key.json
   RAZORPAY_KEY_ID=(your key)
   RAZORPAY_KEY_SECRET=(your secret)
   RAZORPAY_WEBHOOK_SECRET=(your webhook secret)
   ENVIRONMENT=production
   NODE_ENV=production
   ```

7. Upload Firebase JSON:
   - In "Build & Deploy" settings
   - Add file environment variable
   - Name: `FIREBASE_SERVICE_ACCOUNT_PATH`
   - Value: Upload the `fufaji-online-business-firebase-adminsdk.json` file

8. Click "Create Web Service"

**⏳ Wait 2-3 minutes for deployment**

**✅ Your backend URL**: `https://fufaji-api.render.com`

---

## STEP 2: Update Flutter App (5 minutes)

### 2A. Update lib/config/app_config.dart

Find this (around line 23-24):
```dart
static String get apiBaseUrl {
  return const String.fromEnvironment('API_BASE_URL', defaultValue: '');
}
```

Replace with:
```dart
static String get apiBaseUrl {
  // Use Render backend (Node.js + Express)
  return const String.fromEnvironment(
    'API_BASE_URL', 
    defaultValue: 'https://fufaji-api.render.com'
  );
}
```

### 2B. Update lib/services/payment_verification_service.dart

Find the `verifySignature` method (around line 29):

Replace:
```dart
Future<bool> verifySignature({
  required String paymentId,
  required String orderId,
  required String signature,
}) async {
  try {
    final FirebaseFunctions functions = FirebaseFunctions.instance;
    final HttpsCallable callable = functions.httpsCallable(
      'verifyRazorpayPayment',
    );
    // ... Firebase Cloud Function call
```

With:
```dart
Future<bool> verifySignature({
  required String paymentId,
  required String orderId,
  required String signature,
}) async {
  try {
    // Call Node.js backend endpoint
    final response = await ApiClient().post(
      '/payments/razorpay/verify',
      {
        'razorpay_payment_id': paymentId,
        'razorpay_order_id': orderId,
        'razorpay_signature': signature,
        'order_id': orderId,
      },
    );

    if (response.data['success'] == true) {
      debugPrint('Payment verification succeeded');
      return true;
    }

    debugPrint('Payment verification failed: ${response.data}');
    return false;
```

### 2C. Verify these files exist in Flutter

- ✅ `lib/services/razorpay_service.dart` - Already calls `/payments/razorpay/order`
- ✅ `lib/services/api_client.dart` - Already has Firebase token injection
- ✅ `lib/config/app_config.dart` - You just updated this

---

## STEP 3: Build APK Release (10 minutes)

### 3A. Get Flutter dependencies

```bash
cd /path/to/flutter/app
flutter pub get
```

### 3B. Build release APK

```bash
flutter build apk --release --split-per-abi
```

**Output**: 
- `build/app/outputs/flutter-app-release.apk` (universal)
- `build/app/outputs/app-arm64-v8a-release.apk` (optimized for modern phones)

### 3C. (Optional) Use Shorebird for OTA Updates

Shorebird lets you update APK without rebuilding:

```bash
# Install
curl https://raw.githubusercontent.com/shorebirdio/install/main/install.sh | bash

# Login
shorebird auth login

# Release
shorebird release android
```

---

## STEP 4: Test Backend Locally (Optional)

```bash
cd fufaji-backend
npm install
npm start
```

Test endpoint:
```bash
curl http://localhost:8000/health
# Expected: {"status": "healthy", ...}
```

Test payment endpoint:
```bash
curl -X POST http://localhost:8000/payments/razorpay/order \
  -H "Authorization: Bearer YOUR_FIREBASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "test-order-123",
    "amount": 10000,
    "customerId": "test-customer",
    "customerPhone": "+919999999990",
    "customerEmail": "test@fufaji.com"
  }'
```

---

## STEP 5: Push Everything to GitHub

### 5A. Push Flutter app

```bash
cd /path/to/flutter/app
git add .
git commit -m "feat: update API backend to Render endpoint"
git push origin main
```

### 5B. Verify Render deployment is working

Visit: `https://fufaji-api.render.com/health`

You should see:
```json
{
  "status": "healthy",
  "timestamp": "2026-06-22T...",
  "version": "1.0.0",
  "environment": "production"
}
```

---

## STEP 6: Release APK to Users

### Option A: Manual Upload to Play Store

1. Go to Google Play Console
2. Upload APK
3. Set release notes
4. Submit for review (~2 hours)

### Option B: Shorebird OTA Update (Faster)

```bash
shorebird release android --staging
# Users auto-get update within hours
```

### Option C: Direct Distribution

Share APK file with users via:
- Email
- WhatsApp
- Website download link
- Telegram

---

## TROUBLESHOOTING

### Backend not responding

1. Check Render dashboard: https://render.com/dashboard
2. Look at logs for errors
3. Verify environment variables are set
4. Check Firebase service account JSON is valid

### APK crashes on startup

1. Check logcat:
   ```bash
   flutter run -v
   # or
   adb logcat | grep flutter
   ```
2. Verify Firebase app is initialized
3. Check `API_BASE_URL` is correct

### Payment verification fails

1. Verify Razorpay credentials in .env
2. Check webhook_secret is correct (NOT key_secret)
3. Look at backend logs in Render dashboard

---

## PRODUCTION CHECKLIST

- [ ] Firebase Spark Plan features set up (Firestore, Auth, FCM, Remote Config)
- [ ] Firestore security rules deployed
- [ ] Node.js backend deployed on Render
- [ ] Backend health check: https://fufaji-api.render.com/health → ✅
- [ ] Flutter app updated (API_BASE_URL, payment verification)
- [ ] APK built in release mode
- [ ] APK tested on device
- [ ] APK uploaded to Play Store OR distributed via Shorebird
- [ ] Users notified of update

---

## MONITORING

**Render Dashboard**: https://render.com/dashboard
- View logs
- Monitor CPU/memory
- Check error rates

**Firebase Console**: https://console.firebase.google.com
- Monitor Firestore reads/writes (50k/day free limit)
- Check Crashlytics for app crashes
- View Authentication usage
- Monitor Storage usage

**Play Store Console**: https://play.google.com/console
- View installs & ratings
- Monitor crash reports
- Check user reviews

---

## WHAT'S LIVE NOW

✅ **Backend**: Node.js + Express on Render free tier  
✅ **Database**: Firestore (1GB, 50k reads/day)  
✅ **Auth**: Firebase Auth (50k MAUs)  
✅ **Payments**: Razorpay integration (webhook_secret fix)  
✅ **Notifications**: FCM push notifications  
✅ **App**: Flutter with all services connected  

**Total cost**: $0 (everything on free tier)

---

## NEXT STEPS AFTER LAUNCH

1. **Monitor**: Watch Firestore quota usage
2. **Scale**: When you exceed free tier limits, upgrade to Blaze (pay-as-you-go)
3. **Consolidate services**: Gradually refactor 4 order engines into unified service
4. **Add features**: Group buy, loyalty program, AI recommendations

---

**You're ready to launch! 🚀**
