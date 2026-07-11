# ✅ Secrets Configuration Checklist

Complete this checklist before deploying to production.

## 1. Render Backend Setup

- [ ] Created Render account at https://render.com
- [ ] Deployed backend service: `fufajis-online-business-backend`
- [ ] Added environment variables in Render dashboard:
  - [ ] `NODE_ENV=production`
  - [ ] `PORT=8080`
  - [ ] `FIREBASE_SERVICE_ACCOUNT` (minified JSON)
  - [ ] `SUPABASE_URL`
  - [ ] `SUPABASE_SERVICE_ROLE_KEY`
  - [ ] `RAZORPAY_KEY_ID` (live key)
  - [ ] `RAZORPAY_KEY_SECRET` (live key)
  - [ ] `RAZORPAY_WEBHOOK_SECRET`
  - [ ] `WHATSAPP_TOKEN`
  - [ ] `TWILIO_ACCOUNT_SID`
  - [ ] `TWILIO_AUTH_TOKEN`
  - [ ] `TWILIO_PHONE_NUMBER`
  - [ ] `GEMINI_API_KEY`
- [ ] Tested `/config/app-config` endpoint:
  ```bash
  curl https://fufajis-online-business.onrender.com/config/app-config
  ```
  Returns JSON with all configuration? ✓

## 2. Supabase Setup

- [ ] Created Supabase project: `fufajis-online-business`
- [ ] Obtained credentials from Settings → API:
  - [ ] Project URL → `SUPABASE_URL`
  - [ ] Anon Key → `SUPABASE_ANON_KEY`
  - [ ] Service Role Key → `SUPABASE_SERVICE_ROLE_KEY` (Render only)
- [ ] Database migrations applied:
  - [ ] `20260711_create_subscription_system.sql` ✓
  - [ ] `20260712_create_vendor_system.sql` ✓
- [ ] Row-Level Security (RLS) enabled on critical tables
- [ ] Backup configured (Settings → Backups)
- [ ] Real-time features enabled for tables:
  - [ ] subscriptions
  - [ ] vendor_payouts
  - [ ] orders
  - [ ] delivery (if using real-time tracking)

## 3. Firebase Setup

- [ ] Firebase project created: `fufaji-online-business`
- [ ] Firebase config in code verified (`lib/firebase_options.dart`):
  - [ ] Web: ✓ Already configured
  - [ ] Android: ✓ Already configured
  - [ ] iOS: ⚠️ Needs GoogleService-Info.plist
- [ ] Downloaded GoogleService-Info.plist for iOS
- [ ] Added to Xcode: `ios/Runner/GoogleService-Info.plist`
- [ ] Firebase services enabled:
  - [ ] Authentication
  - [ ] Firestore
  - [ ] Cloud Messaging (FCM)
  - [ ] Storage (optional)
  - [ ] Analytics
- [ ] Service Account JSON generated (for Render backend):
  - [ ] Created in Firebase Console
  - [ ] Minified and added to Render env vars

## 4. Razorpay Setup

- [ ] Created Razorpay account at https://razorpay.com
- [ ] Obtained live credentials (not test):
  - [ ] Key ID: `rzp_live_...`
  - [ ] Key Secret (server-side only)
  - [ ] Webhook Secret
- [ ] Webhook configured in Razorpay dashboard:
  - [ ] URL: `https://fufajis-online-business.onrender.com/webhooks/razorpay`
  - [ ] Events: payment.authorized, payment.failed, refund.created
- [ ] Tested payment flow:
  - [ ] Create order
  - [ ] Process payment
  - [ ] Verify webhook received
  - [ ] Check Razorpay dashboard for transaction

## 5. Google Maps API Setup

- [ ] Created Google Cloud project
- [ ] Enabled Maps SDK:
  - [ ] Maps SDK for Android
  - [ ] Maps SDK for Web
- [ ] Created API key
- [ ] Restricted to Android app:
  - [ ] Added Android SHA-1 fingerprint
  - [ ] Added bundle ID
- [ ] Tested in app:
  - [ ] Map loads on home screen ✓
  - [ ] Delivery tracking map shows ✓

## 6. Sentry Setup (Optional)

- [ ] Created Sentry account at https://sentry.io (optional)
- [ ] Created Flutter project in Sentry
- [ ] Obtained DSN
- [ ] Added to Flutter build flags

## 7. .env File Setup (Development)

- [ ] Copied `.env.example` to `.env`
- [ ] Filled in all values:
  - [ ] API_BASE_URL
  - [ ] SUPABASE_URL
  - [ ] SUPABASE_ANON_KEY
  - [ ] RAZORPAY_KEY_ID
  - [ ] GOOGLE_MAPS_KEY
  - [ ] SENTRY_DSN
- [ ] `.env` added to `.gitignore` ✓
- [ ] `.env` NOT committed to git ✓

## 8. Flutter Build Setup

- [ ] Ran: `flutter clean`
- [ ] Ran: `flutter pub get`
- [ ] Ran: `flutter pub run build_runner build`
- [ ] Verified build script: `scripts/build.sh`
- [ ] Made build script executable: `chmod +x scripts/build.sh`

## 9. Testing Secrets

- [ ] **Test 1: Local Development**
  ```bash
  flutter run --dart-define=API_BASE_URL=... --dart-define=SUPABASE_URL=...
  ```
  - [ ] App launches ✓
  - [ ] Can sign up ✓
  - [ ] Can place order ✓

- [ ] **Test 2: Supabase Connection**
  - [ ] Sign up creates user in Supabase Auth ✓
  - [ ] Firestore syncs user data ✓
  - [ ] Real-time updates work ✓

- [ ] **Test 3: Razorpay Connection**
  - [ ] Create order ✓
  - [ ] Razorpay form opens ✓
  - [ ] Test payment completes ✓
  - [ ] Webhook received (check backend logs) ✓

- [ ] **Test 4: Firebase Connection**
  - [ ] Analytics events tracked ✓
  - [ ] Auth signs in via Firebase ✓
  - [ ] Firestore reads work ✓

- [ ] **Test 5: Render Backend**
  ```bash
  curl https://fufajis-online-business.onrender.com/config/app-config | jq .
  ```
  - [ ] Returns valid JSON ✓
  - [ ] Contains supabase section ✓
  - [ ] Contains razorpay section ✓

## 10. Pre-Release Build

- [ ] Used production Razorpay keys (not test)
- [ ] Used Supabase production database
- [ ] Used Firebase production project
- [ ] Reviewed all environment variables
- [ ] Tested on physical Android device
- [ ] Built APK: `./scripts/build.sh apk`
- [ ] Build output size reasonable (~50-100 MB)
- [ ] No secrets embedded in APK:
  ```bash
  # Check APK doesn't contain secrets
  unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -i secret
  # Should return nothing
  ```

## 11. Play Store Release

- [ ] Created Google Play Developer account
- [ ] Created app listing
- [ ] Built signed APK with:
  ```bash
  ./scripts/build.sh aab
  ```
- [ ] Uploaded AAB to Play Store
- [ ] Added screenshots and description
- [ ] Set pricing and distribution
- [ ] Submitted for review
- [ ] Waited for approval (24-48 hours)

## 12. Post-Release Monitoring

- [ ] Set up Sentry alerts
- [ ] Created Firebase alert policies
- [ ] Monitored first 24 hours for errors
- [ ] Checked Razorpay dashboard for transactions
- [ ] Verified Supabase performance metrics
- [ ] Reviewed app store reviews and ratings
- [ ] Set up customer support email

## 13. Security Audit

- [ ] No secrets visible in git history
  ```bash
  git log --all -S "rzp_live" # Should be empty
  git log --all -S "supabase" # Should be empty
  ```
- [ ] All server secrets in Render env vars only
- [ ] Firebase Service Account JSON never committed
- [ ] Razorpay Secret Key never in Flutter code
- [ ] HTTPS enforced everywhere
- [ ] RLS policies configured in Supabase
- [ ] Firebase Security Rules configured
- [ ] Regular key rotation scheduled (monthly)

## ✅ All Set!

Once all items are checked, your Fufaji app is ready for production with secure secrets management.

**Critical Reminders:**
- 🔐 Never share `.env` file
- 🔐 Never commit secrets to git
- 🔐 Rotate keys monthly
- 🔐 Monitor Sentry for security issues
- 🔐 Keep Supabase RLS policies strict
- 🔐 Review Firebase Security Rules quarterly

---

**Last Updated:** 2026-07-11
**Questions?** Check SECRETS_SETUP.md for detailed instructions
