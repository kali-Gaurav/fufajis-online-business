# 🔐 Secrets Configuration Guide for Fufaji

This guide walks through configuring all secrets for production deployment.

---

## 1️⃣ RENDER BACKEND CONFIGURATION

The Render backend serves the `/config/app-config` endpoint that provides runtime secrets to the Flutter app.

### Setup Steps:

1. **Go to [Render Dashboard](https://dashboard.render.com)**
2. **Select your service** (e.g., `fufajis-online-business-backend`)
3. **Click "Environment"** tab
4. **Add the following environment variables:**

```
# ── API Config ──────────────────────────────────────
NODE_ENV=production
PORT=8080

# ── Firebase (for backend to communicate with Firebase) ──
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"fufaji-online-business","private_key_id":"...","private_key":"...","client_email":"...","client_id":"...","auth_uri":"...","token_uri":"...","auth_provider_x509_cert_url":"...","client_x509_cert_url":"..."}

# ── Supabase (for backend database access) ──
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here

# ── Razorpay Payments ────────────────────────────
RAZORPAY_KEY_ID=rzp_live_xxxxxxxxxxxxx
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxx
RAZORPAY_WEBHOOK_SECRET=xxxxxxxxxxxxxxxx

# ── WhatsApp Business API ────────────────────────
WHATSAPP_TOKEN=your-whatsapp-token
WHATSAPP_PHONE_ID=your-phone-id

# ── Twilio (SMS) ────────────────────────────────
TWILIO_ACCOUNT_SID=your-account-sid
TWILIO_AUTH_TOKEN=your-auth-token
TWILIO_PHONE_NUMBER=+91xxxxxxxxxx

# ── Gemini AI ────────────────────────────────────
GEMINI_API_KEY=your-gemini-api-key

# ── AWS S3 (if using) ────────────────────────────
AWS_REGION=ap-south-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
```

### Get Firebase Service Account JSON:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: **fufaji-online-business**
3. Settings → Service Accounts
4. Click "Generate New Private Key"
5. Download JSON file
6. Minify it (remove spaces/newlines) and paste into `FIREBASE_SERVICE_ACCOUNT`

**To minify JSON in terminal:**
```bash
cat firebase-key.json | jq -c . | xargs echo
```

---

## 2️⃣ SUPABASE CONFIGURATION

### Get Your Credentials:

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select project: **fufajis-online-business**
3. Settings → API
   - Copy: **Project URL** → `SUPABASE_URL`
   - Copy: **anon public** → `SUPABASE_ANON_KEY` (for Flutter app)
   - Copy: **service_role** → `SUPABASE_SERVICE_ROLE_KEY` (for backend only)

### Store in Supabase Vault (Recommended):

1. Go to Supabase → Project Settings → Vault
2. Create secrets:
   ```
   supabase_url = https://your-project.supabase.co
   supabase_anon_key = eyJhbGc...
   razorpay_key_id = rzp_live_...
   razorpay_webhook_secret = xxxx...
   ```

---

## 3️⃣ FIREBASE CONFIGURATION

Firebase is already configured in the Flutter app code (`lib/firebase_options.dart`). The credentials are:

- **Project ID:** `fufaji-online-business`
- **Web Config:** ✅ Already in code
- **Android Config:** ✅ Already in code
- **iOS Config:** ⚠️ Needs to be updated (currently shows placeholders)

### For iOS (if building):

1. Go to Firebase Console
2. Settings → General → Download GoogleService-Info.plist (iOS)
3. Add to Xcode: `ios/Runner/GoogleService-Info.plist`

### Update iOS Credentials in Code:

Edit `lib/firebase_options.dart` and replace the iOS config placeholders with values from GoogleService-Info.plist.

---

## 4️⃣ FLUTTER BUILD CONFIGURATION

When building the app, pass secrets via `--dart-define`:

### Debug Build:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://fufajis-online-business.onrender.com \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGc... \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_... \
  --dart-define=GOOGLE_MAPS_KEY=your-maps-key \
  --dart-define=SENTRY_DSN=your-sentry-dsn
```

### Release Build (APK/AAB):

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://fufajis-online-business.onrender.com \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGc... \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_... \
  --dart-define=GOOGLE_MAPS_KEY=your-maps-key \
  --dart-define=SENTRY_DSN=your-sentry-dsn
```

### Or Use `.env` File (Development Only):

Create `.env` in project root:

```env
API_BASE_URL=https://fufajis-online-business.onrender.com
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...
RAZORPAY_KEY_ID=rzp_live_...
GOOGLE_MAPS_KEY=your-maps-key
SENTRY_DSN=your-sentry-dsn
```

**Note:** `.env` is NOT included in release builds (see pubspec.yaml)

---

## 5️⃣ RUNTIME CONFIG ENDPOINT

The Flutter app expects Render backend to serve `/config/app-config`:

### Response Format (JSON):

```json
{
  "data": {
    "apiBaseUrl": "https://fufajis-online-business.onrender.com",
    "payments": {
      "razorpayKeyId": "rzp_live_..."
    },
    "monitoring": {
      "sentryDsn": "https://..."
    },
    "supabase": {
      "url": "https://your-project.supabase.co",
      "anonKey": "eyJhbGc..."
    },
    "shop": {
      "latitude": 25.1006,
      "longitude": 76.5156,
      "maxDeliveryRadiusKm": 15
    },
    "features": {
      "whatsappEnabled": true
    }
  }
}
```

### Backend Endpoint (Node.js Example):

```javascript
// backend/routes/config.js
router.get('/config/app-config', (req, res) => {
  res.json({
    data: {
      apiBaseUrl: process.env.API_BASE_URL,
      payments: {
        razorpayKeyId: process.env.RAZORPAY_KEY_ID,
      },
      monitoring: {
        sentryDsn: process.env.SENTRY_DSN,
      },
      supabase: {
        url: process.env.SUPABASE_URL,
        anonKey: process.env.SUPABASE_ANON_KEY,
      },
      shop: {
        latitude: parseFloat(process.env.SHOP_LATITUDE || 25.1006),
        longitude: parseFloat(process.env.SHOP_LONGITUDE || 76.5156),
        maxDeliveryRadiusKm: parseFloat(process.env.MAX_DELIVERY_RADIUS || 15),
      },
      features: {
        whatsappEnabled: process.env.WHATSAPP_ENABLED === 'true',
      },
    },
  });
});
```

---

## 6️⃣ SECRETS CHECKLIST

### Before Building for Production:

- [ ] Render: All 12 environment variables set
- [ ] Firebase: Service account JSON minified and pasted
- [ ] Supabase: URL and anon key obtained
- [ ] Razorpay: Live API keys (not test keys)
- [ ] Google Maps: API key enabled for Android & Web
- [ ] Sentry: DSN configured (optional but recommended)
- [ ] Render: `/config/app-config` endpoint working
- [ ] Flutter: `--dart-define` flags for all required values
- [ ] `.env` file: Created for local development (NOT in git)

### Test the Setup:

1. **Test Render endpoint:**
   ```bash
   curl https://fufajis-online-business.onrender.com/config/app-config
   ```
   Should return JSON with all configuration

2. **Test Supabase connection:**
   - Open app
   - Try to sign up/login
   - Check Supabase console for auth records

3. **Test Firebase:**
   - Check Firestore console for sync data
   - Check Analytics for events

4. **Test Razorpay:**
   - Create order and attempt payment
   - Check Razorpay dashboard for transactions

---

## 7️⃣ SECURITY BEST PRACTICES

✅ **DO:**
- Keep `RAZORPAY_KEY_SECRET` server-side only
- Use `SUPABASE_SERVICE_ROLE_KEY` only on backend
- Rotate keys regularly (monthly recommended)
- Use environment variables, never hardcode secrets
- Enable HTTPS everywhere
- Use Row-Level Security (RLS) in Supabase

❌ **DON'T:**
- Commit `.env` file to git
- Embed secrets in Flutter code
- Use test keys in production
- Share secrets in Slack/email
- Log sensitive values
- Use same key across environments

---

## 8️⃣ ENVIRONMENT VARIABLES SUMMARY

| Variable | Source | Used In | Sensitivity |
|----------|--------|---------|-------------|
| `API_BASE_URL` | Flutter Build | RuntimeConfig | Low |
| `SUPABASE_URL` | Flutter Build | RuntimeConfig | Low |
| `SUPABASE_ANON_KEY` | Flutter Build | RuntimeConfig | Medium |
| `SUPABASE_SERVICE_ROLE_KEY` | Render Env | Backend Only | 🔴 High |
| `RAZORPAY_KEY_ID` | Flutter Build | RuntimeConfig | Low |
| `RAZORPAY_KEY_SECRET` | Render Env | Backend Payments | 🔴 High |
| `RAZORPAY_WEBHOOK_SECRET` | Render Env | Webhook Verification | 🔴 High |
| `FIREBASE_SERVICE_ACCOUNT` | Render Env | Backend Admin | 🔴 High |
| `GEMINI_API_KEY` | Render Env | AI Features | Medium |
| `WHATSAPP_TOKEN` | Render Env | WhatsApp Integration | 🔴 High |
| `TWILIO_ACCOUNT_SID` | Render Env | SMS Service | 🔴 High |
| `TWILIO_AUTH_TOKEN` | Render Env | SMS Service | 🔴 High |

---

## 9️⃣ TROUBLESHOOTING

### "Supabase has not been initialized"
- Check `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set
- Verify in RuntimeConfig logs: `[RuntimeConfig] Supabase Config: url=true, key=true`

### "Razorpay key not found"
- Ensure `RAZORPAY_KEY_ID` passed via `--dart-define`
- Check Render `/config/app-config` endpoint returns the key

### "Firebase connection failed"
- Check Firebase project ID: `fufaji-online-business`
- Verify API key in `firebase_options.dart`
- Check Firebase console for quota limits

### "Backend returns 401 on `/config/app-config`"
- Verify Render environment variables are set
- Check Render deployment logs: `render logs --service=...`
- Test with: `curl -H "Authorization: Bearer $TOKEN" https://...`

---

## 🔟 GETTING ACTUAL CREDENTIALS

### Razorpay:
1. Sign in at https://dashboard.razorpay.com
2. Settings → API Keys
3. Copy **Key ID** (starts with `rzp_live_`)
4. Copy **Key Secret** (keep server-side only)

### Supabase:
1. Sign in at https://app.supabase.com
2. Select project
3. Settings → API
4. Copy **Project URL** and **anon key**

### Firebase:
1. Go to https://console.firebase.google.com
2. Select `fufaji-online-business`
3. Settings → Service Accounts → Generate Key

### Google Maps:
1. Go to https://console.cloud.google.com
2. Enable Maps SDK for Android and Web
3. Create API key (Application restrictions: Android app)
4. Copy the key

### Sentry (Error Tracking - Optional):
1. Sign up at https://sentry.io
2. Create project for Flutter
3. Copy the DSN (looks like `https://xxx@xxx.ingest.sentry.io/xxx`)

---

## Setup Complete! ✅

Once all secrets are configured:

1. Build app: `flutter build apk --release ...`
2. Upload to Play Store or TestFlight
3. Test on real device
4. Monitor Sentry/Firebase for errors
5. Check Supabase/Firestore for data sync

If issues persist, check logs:
- **Render logs:** `render logs --service=fufajis-online-business-backend`
- **Flutter app logs:** Run with `flutter run -v`
- **Firebase console:** Firestore, Auth, Analytics tabs
- **Supabase console:** Logs tab in database

---

**Last Updated:** 2026-07-11  
**Maintainer:** Fufaji Dev Team
