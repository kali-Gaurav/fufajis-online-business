# 🚀 FUFAJI STORE - COMPLETE DEPLOYMENT GUIDE

**Last Updated:** June 28, 2026  
**Status:** Production Ready  
**Version:** 1.0.0

---

## 📋 TABLE OF CONTENTS

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Environment Variables Setup](#environment-variables-setup)
3. [Mobile App Release (Google Play Store)](#mobile-app-release)
4. [Backend Deployment (Supabase Edge Functions)](#backend-deployment)
5. [Database Setup (PostgreSQL)](#database-setup)
6. [Third-Party Services Configuration](#third-party-services)
7. [Storage Setup (Supabase Storage)](#storage-setup)
8. [Monitoring & Analytics](#monitoring--analytics)
9. [Domain & DNS Setup](#domain--dns-setup)
10. [Post-Deployment Verification](#post-deployment-verification)
11. [Troubleshooting](#troubleshooting)

---

## 🔍 PRE-DEPLOYMENT CHECKLIST

Before starting deployment, verify:

- [ ] GitHub repo is PRIVATE
- [ ] All secrets rotated (from earlier steps)
- [ ] APK/AAB signed with production key
- [ ] Firebase project created and credentials exported
- [ ] Supabase project created
- [ ] Razorpay account with live keys
- [ ] Twilio account with auth token
- [ ] SendGrid account with API key
- [ ] Sentry project created
- [ ] Google Play Store developer account
- [ ] Database backups configured
- [ ] All tests passing locally

---

## 🔐 ENVIRONMENT VARIABLES SETUP

### PART 1: Collect All Secrets

Create a secure spreadsheet or password manager entry with:

**Firebase Credentials:**
- Project ID: `fufaji-store-prod`
- Private Key: `-----BEGIN PRIVATE KEY-----...-----END PRIVATE KEY-----`
- Client Email: `firebase-adminsdk-xxxxx@fufaji-store-prod.iam.gserviceaccount.com`
- Client ID: `123456789`
- Auth Domain: `fufaji-store-prod.firebaseapp.com`
- Database URL: `https://fufaji-store-prod.firebaseio.com`
- Storage Bucket: `fufaji-store-prod.appspot.com`
- Public API Key: `AIzaSyDxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

**Razorpay Credentials:**
- Key ID (Public): `rzp_live_xxxxx`
- Key Secret (Private): `xxxxxxxxxxxxxxxxxxxxx`
- Webhook Secret: `xxxxxxxxxxxxxxxxxxxxx`

**Supabase Credentials:**
- Project ID: `mxjtgpunctckovtuyfmz`
- URL: `https://mxjtgpunctckovtuyfmz.supabase.co`
- Public Key (anon): `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
- Secret Key (service role): `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
- Database Password: `xxxxxxxxxxxxxxxxxxxxx`

**Twilio Credentials:**
- Account SID: `ACxxxxxxxxxxxxxxxxxxxxx`
- Auth Token: `xxxxxxxxxxxxxxxxxxxxx`
- Phone Number: `+1XXXXXXXXXX`

**SendGrid Credentials:**
- API Key: `SG.xxxxxxxxxxxxxxxxxxxxx`
- From Email: `noreply@fufaji.com`

**Sentry Credentials:**
- DSN (Public): `https://xxxxx@xxxxx.ingest.sentry.io/xxxxxx`
- Auth Token: `sntrys_eyJ...`

**Other Secrets:**
- JWT Secret: `your-super-secret-jwt-key-min-32-chars`
- OTP Secret (optional): `your-otp-secret-key`

---

## 📱 MOBILE APP RELEASE

### STEP 1: Prepare APK/AAB for Google Play Store

**Location:** `android/app/build.gradle`

```gradle
android {
    signingConfigs {
        release {
            storeFile file("./keystore.jks")
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias System.getenv("KEY_ALIAS")
            keyPassword System.getenv("KEY_PASSWORD")
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

**Build Commands:**
```bash
# Set environment variables
export KEYSTORE_PASSWORD="your-keystore-password"
export KEY_ALIAS="fufaji-store"
export KEY_PASSWORD="your-key-password"

# Build release APK
flutter build apk --release

# Build release AAB (for Play Store)
flutter build appbundle --release

# Output locations:
# APK: build/app/outputs/flutter-apk/app-release.apk
# AAB: build/app/outputs/bundle/release/app-release.aab
```

### STEP 2: Configure Firebase for Mobile App

**Location:** `android/app/google-services.json`

This file is auto-generated from Firebase Console:

1. Go to Firebase Console → Your Project → Project Settings
2. Click "Google Services JSON" download button
3. Place it at: `android/app/google-services.json`

**Content format:**
```json
{
  "type": "service_account",
  "project_id": "fufaji-store-prod",
  "private_key_id": "xxxxx",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@fufaji-store-prod.iam.gserviceaccount.com",
  "client_id": "123456789",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/..."
}
```

### STEP 3: Upload to Google Play Store

1. **Create Google Play Developer Account:**
   - Go to: https://play.google.com/console
   - Pay one-time $25 fee
   - Verify payment method

2. **Create App:**
   - Click "Create app"
   - App name: "Fufaji Store"
   - Category: Shopping
   - Type: App

3. **Setup App Signing:**
   - Google Play Console → App signing → Upload signing key (optional but recommended)
   - Or let Google Play manage signing

4. **Upload AAB:**
   - Go to "Release" → "Internal testing"
   - Click "Create release"
   - Upload `app-release.aab`
   - Fill out release notes

5. **Setup Store Listing:**
   - Icon (512x512 PNG)
   - Screenshots (up to 8, 1080x1920)
   - Short description (80 chars)
   - Full description (4000 chars)
   - Category: Shopping
   - Content rating: Fill questionnaire

6. **Setup Pricing & Distribution:**
   - Price: Free or Paid
   - Countries: Select target countries
   - Content rating: Unrated or rate

7. **Submit for Review:**
   - Review all information
   - Submit for review
   - Wait 2-3 hours for initial review

---

## 🔧 BACKEND DEPLOYMENT

### STEP 1: Deploy Supabase Edge Functions

**Prerequisite:** Supabase CLI installed

```bash
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
cd C:\Projects\fufaji-online-business
supabase link --project-ref mxjtgpunctckovtuyfmz
```

**Deploy Auth Endpoints:**
```bash
supabase functions deploy auth-endpoints
```

**Expected output:**
```
✓ Function auth-endpoints deployed
  Endpoint: https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/auth-endpoints
```

**Deploy Payment Endpoints:**
```bash
supabase functions deploy payment-endpoints
```

**Deploy Error Handling:**
```bash
supabase functions deploy error-handling
```

### STEP 2: Set Environment Secrets

**For Auth Endpoints:**
```bash
supabase secrets set FIREBASE_PROJECT_ID "fufaji-store-prod"
supabase secrets set FIREBASE_PRIVATE_KEY "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
supabase secrets set FIREBASE_CLIENT_EMAIL "firebase-adminsdk-xxxxx@fufaji-store-prod.iam.gserviceaccount.com"
supabase secrets set JWT_SECRET "your-super-secret-jwt-key-min-32-chars"
supabase secrets set TWILIO_ACCOUNT_SID "ACxxxxxxxxxxxxxxxxxxxxx"
supabase secrets set TWILIO_AUTH_TOKEN "xxxxxxxxxxxxxxxxxxxxx"
supabase secrets set TWILIO_PHONE_NUMBER "+1XXXXXXXXXX"
supabase secrets set SENDGRID_API_KEY "SG.xxxxxxxxxxxxxxxxxxxxx"
```

**For Payment Endpoints:**
```bash
supabase secrets set RAZORPAY_KEY_ID "rzp_live_xxxxx"
supabase secrets set RAZORPAY_KEY_SECRET "xxxxxxxxxxxxxxxxxxxxx"
supabase secrets set RAZORPAY_WEBHOOK_SECRET "xxxxxxxxxxxxxxxxxxxxx"
supabase secrets set FIREBASE_SERVICE_ACCOUNT "{\"type\":\"service_account\",\"project_id\":\"fufaji-store-prod\",...}"
```

**Verify Secrets:**
```bash
supabase secrets list
```

---

## 🗄️ DATABASE SETUP

### STEP 1: Run Database Migrations

**Initial Setup:**
```bash
# Push all migrations to database
supabase db push

# Output:
# ✓ Running migration 01_init_core_schema.sql
# ✓ Running migration 02_rls_policies.sql
# ✓ Running migration 03_production_schema_advanced.sql
# ✓ Running migration 04_storage_buckets_firestore_sync.sql
# ✓ Running migration 03_update_role_constraint.sql
```

### STEP 2: Verify Database Tables

```bash
# Connect to Supabase SQL Editor
# Go to: Supabase Dashboard → SQL Editor

# Run this query to verify tables:
SELECT table_name FROM information_schema.tables 
WHERE table_schema='public' 
ORDER BY table_name;

# Expected tables:
# - customers
# - shops
# - products
# - inventory
# - orders
# - deliveries
# - wallets
# - wallet_transactions
# - refunds
# - reviews
# - payment_transactions
# - coupons
# - audit_log
# - storage_references
```

### STEP 3: Verify Firestore Rules

**Location:** Supabase Dashboard → Storage → Policies

Check that these policies exist:
- ✓ Public can read product images
- ✓ Shop owners upload product images
- ✓ Customers upload own KYC documents
- ✓ Riders upload delivery proofs
- ✓ All delivery* collections secured

---

## 🔌 THIRD-PARTY SERVICES CONFIGURATION

### Firebase Setup

**Step 1: Create Firebase Project**
1. Go to: https://console.firebase.google.com
2. Click "Add project"
3. Project name: "Fufaji Store Production"
4. Accept terms
5. Create project (wait 1-2 minutes)

**Step 2: Enable Authentication Methods**
1. Firebase Console → Authentication → Sign-in method
2. Enable:
   - Email/Password
   - Google
   - Phone
3. Add authorized domains:
   - yourapp.com
   - www.yourapp.com
   - localhost:3000 (for testing)

**Step 3: Create Service Account**
1. Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Save JSON file (keep secure!)

### Razorpay Setup

**Step 1: Create Live Account**
1. Go to: https://dashboard.razorpay.com
2. Create business account
3. Verify phone and email
4. Complete KYC verification

**Step 2: Get Live Credentials**
1. Dashboard → Settings → API Keys
2. Copy "Key ID" (public key)
3. Copy "Key Secret" (private key - KEEP SECRET!)
4. Note: Key Secret used for signature verification

**Step 3: Configure Webhook**
1. Dashboard → Settings → Webhooks
2. Click "Add New Webhook"
3. URL: `https://your-domain.com/functions/v1/razorpay-webhook`
4. Events: Select:
   - payment.authorized
   - payment.failed
   - payment.captured
   - refund.created
   - refund.failed
5. Active: Yes
6. Save and note Webhook Secret

**Step 4: Test in Sandbox First**
1. Switch to Test mode (toggle at top)
2. Use test credentials
3. Complete full test payment flow
4. Verify webhook received
5. Then switch to Live mode

### Twilio Setup

**Step 1: Create Account**
1. Go to: https://www.twilio.com/console
2. Create account
3. Verify email and phone

**Step 2: Get Live Credentials**
1. Console → Account Info
2. Copy "Account SID"
3. Copy "Auth Token"
4. Note down both

**Step 3: Get Phone Number**
1. Console → Phone Numbers → Manage
2. Click "Get started" (if first time)
3. Buy a phone number (select country: India)
4. Cost: ~$1-2/month

**Step 4: Setup SMS Service**
1. Console → Messaging → Services
2. Create service
3. Select phone number
4. Save Service SID

### SendGrid Setup

**Step 1: Create Account**
1. Go to: https://sendgrid.com
2. Create free account
3. Verify email

**Step 2: Get API Key**
1. Settings → API Keys
2. Create API Key (Full Access)
3. Copy and save (won't show again!)

**Step 3: Verify Sender Email**
1. Settings → Sender Authentication
2. Click "Verify a Single Sender"
3. Enter: noreply@yourdomain.com
4. Verify email sent to that address
5. Click link in email

### Sentry Setup

**Step 1: Create Account**
1. Go to: https://sentry.io
2. Create account
3. Create organization

**Step 2: Create Project**
1. Projects → Create Project
2. Platform: Flutter
3. Project name: "Fufaji Store Mobile"
4. Copy DSN (looks like: `https://xxxxx@xxxxx.ingest.sentry.io/xxxxx`)

**Step 3: Get Auth Token**
1. Settings → Auth Tokens
2. Create token
3. Scopes: project:read, project:write, org:read
4. Copy token

---

## 📦 STORAGE SETUP

### Supabase Storage Configuration

**Step 1: Verify Buckets Created**

```bash
# In Supabase SQL Editor, run:
SELECT id, name, public FROM storage.buckets;

# Expected output:
# product-images | true
# customer-documents | false
# order-receipts | false
# delivery-proofs | false
```

**Step 2: Verify RLS Policies**

```bash
# In Supabase SQL Editor, run:
SELECT bucket_id, name FROM storage.policies;

# Expected policies:
# product-images → Public can read product images
# product-images → Shop owners upload product images
# customer-documents → Customers upload own KYC documents
# order-receipts → Customers read own receipts
# delivery-proofs → Riders upload delivery proofs
```

**Step 3: Configure CORS** (if needed)

```bash
# In Supabase SQL Editor:
INSERT INTO storage.buckets (id, name, public, file_size_limit, avif_autodetection)
VALUES ('product-images', 'product-images', true, 52428800, true)
ON CONFLICT DO NOTHING;

# Update CORS headers - done automatically by Supabase
```

---

## 📊 MONITORING & ANALYTICS

### Sentry Configuration (Mobile App)

**Location:** `lib/main.dart`

```dart
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://xxxxx@xxxxx.ingest.sentry.io/xxxxx';
      options.tracesSampleRate = 0.1; // 10% sampling
      options.environment = 'production';
      options.release = '1.0.0+1'; // Match your app version
    },
    appRunner: () => runApp(MyApp()),
  );
}
```

### Firebase Analytics

**Automatically enabled in:**
- `google-services.json`
- `pubspec.yaml` → `firebase_analytics: ^latest`

**Verify in Firebase Console:**
1. Analytics → Dashboard
2. Should show events like:
   - app_open
   - screen_view
   - session_start

### Performance Monitoring

**Location:** `lib/services/performance_monitor.dart`

Already implemented with:
- Order creation latency < 2s
- Payment webhook < 500ms
- Firestore sync < 2s
- Storage upload < 5s

---

## 🌐 DOMAIN & DNS SETUP

### Step 1: Buy Domain

**Options:**
- Namecheap (cheapest)
- Google Domains (best)
- Godaddy (most popular)

**Example:** fufaji.com

### Step 2: Setup DNS Records

**If using Supabase Storage (recommended):**

```
Type: CNAME
Name: api
Value: mxjtgpunctckovtuyfmz.supabase.co
```

**If using Firebase Hosting:**

```
Type: A
Name: @
Value: 199.36.158.100
```

**If using Railway/Render:**

```
Type: CNAME
Name: api
Value: your-railway-domain.railway.app
(or your-render-domain.onrender.com)
```

### Step 3: Setup Email Domain Authentication

**For SendGrid:**
1. SendGrid → Settings → Sender Authentication
2. Add domain: yourdomain.com
3. Add these DNS records:

```
Type: CNAME
Name: s1._domainkey.yourdomain.com
Value: s1.domainkey.sendgrid.net

Type: CNAME
Name: k1._domainkey.yourdomain.com
Value: k1.domainkey.sendgrid.net

Type: CNAME
Name: sendgrid.yourdomain.com
Value: sendgrid.net
```

---

## ✅ POST-DEPLOYMENT VERIFICATION

### Step 1: Test Authentication Flows

**Test Email/Password:**
```
1. Open app
2. Sign up with: test@example.com / Password123!
3. Verify account created in Firebase Console
4. Verify user created in PostgreSQL
5. Verify user doc created in Firestore
```

**Test Google Sign-in:**
```
1. Click "Sign in with Google"
2. Select test Google account
3. Verify Firebase custom claims set
4. Verify Firestore doc has Google info
```

**Test Phone OTP:**
```
1. Click "Phone Sign-in"
2. Enter: +919876543210 (test number)
3. Check Twilio console for SMS sent
4. Enter OTP from SMS
5. Verify Firebase auth created
```

### Step 2: Test Payment Flow

**Test Order Creation:**
```
1. Login as customer
2. Browse products
3. Add item to cart
4. Proceed to checkout
5. Verify order created in PostgreSQL
6. Verify inventory reserved
7. Verify Razorpay order created
```

**Test Payment:**
```
1. Click "Pay with Razorpay"
2. Use test card: 4111111111111111 (Razorpay test card)
3. Expiry: 12/25
4. CVV: 123
5. Complete payment
6. Verify webhook received (check Supabase logs)
7. Verify payment_transactions row created
8. Verify order status = 'confirmed'
9. Verify inventory deducted
10. Verify customer notified
```

**Test Refund:**
```
1. Request refund for order
2. Verify refunds row created
3. Verify Razorpay refund created
4. Wait for refund webhook
5. Verify wallet credited
6. Verify inventory restored
```

### Step 3: Verify Database Sync

**Check PostgreSQL:**
```sql
-- In Supabase SQL Editor
SELECT COUNT(*) FROM orders WHERE created_at > NOW() - INTERVAL '1 hour';
SELECT COUNT(*) FROM payment_transactions WHERE created_at > NOW() - INTERVAL '1 hour';
```

**Check Firestore:**
```
-- In Firebase Console → Firestore Database
-- Collections → orders
-- Should see same data as PostgreSQL
```

### Step 4: Verify Monitoring

**Check Sentry:**
1. Sentry Console → Issues
2. Should see mobile app events
3. Should see no errors (or only expected test errors)

**Check Firebase Analytics:**
1. Firebase Console → Analytics → Dashboard
2. Should see:
   - Active users
   - Top screens
   - App crashes (should be 0)

### Step 5: Test All User Roles

**Customer Role:**
```
1. Login as customer
2. Verify home screen shows products
3. Verify cart works
4. Verify checkout works
5. Verify order tracking works
6. Verify real-time updates work
```

**Shop Owner Role:**
```
1. Login as owner
2. Verify dashboard shows KPIs
3. Verify orders appear in real-time
4. Verify can mark order ready
5. Verify can view inventory
```

**Delivery Agent Role:**
```
1. Login as rider
2. Verify can see assignments
3. Verify map works
4. Verify GPS tracking works
5. Verify can capture proof
```

---

## 🐛 TROUBLESHOOTING

### Issue: Authentication Fails

**Symptom:** "Unauthorized" error on login

**Diagnosis:**
1. Check Firebase credentials in `google-services.json`
2. Verify Firebase project settings
3. Verify authorized domains in Firebase Console

**Fix:**
```bash
# Re-download google-services.json from Firebase Console
# Place at: android/app/google-services.json
# Rebuild app: flutter build apk --release
```

### Issue: Razorpay Payment Fails

**Symptom:** "Signature verification failed" error

**Diagnosis:**
1. Check Razorpay key_secret in secrets
2. Verify signature verification logic
3. Check webhook configuration

**Fix:**
```bash
# Re-verify Razorpay credentials:
# 1. Dashboard → Settings → API Keys
# 2. Copy exact Key Secret
# 3. Set in Supabase secrets:
supabase secrets set RAZORPAY_KEY_SECRET "xxx"
# 4. Re-deploy functions:
supabase functions deploy payment-endpoints
```

### Issue: Database Errors

**Symptom:** "Connection refused" or "relation does not exist"

**Diagnosis:**
1. Check if migrations ran successfully
2. Check database permissions
3. Verify connection string

**Fix:**
```bash
# Check migration status:
supabase db list-migrations

# Re-run migrations if needed:
supabase db push --dry-run  # Preview changes
supabase db push              # Apply changes
```

### Issue: Emails Not Sending

**Symptom:** SendGrid API key error

**Diagnosis:**
1. Check SendGrid API key
2. Verify sender email verified
3. Check SendGrid rate limits

**Fix:**
```bash
# Test SendGrid API key:
curl -X GET "https://api.sendgrid.com/v3/mail/validate" \
  -H "Authorization: Bearer YOUR_API_KEY"

# If error, regenerate API key in SendGrid Console
supabase secrets set SENDGRID_API_KEY "new-key"
```

### Issue: SMS Not Sending

**Symptom:** Twilio SMS error

**Diagnosis:**
1. Check Twilio Account SID and Auth Token
2. Verify phone number is active
3. Check country restrictions

**Fix:**
```bash
# Verify Twilio credentials:
# 1. Console → Account Info
# 2. Copy exact Account SID and Auth Token
# 3. Set in Supabase:
supabase secrets set TWILIO_ACCOUNT_SID "AC..."
supabase secrets set TWILIO_AUTH_TOKEN "..."
# 4. Verify phone number:
# 5. Console → Phone Numbers → Manage
```

### Issue: Firestore Sync Not Working

**Symptom:** Data in PostgreSQL but not in Firestore

**Diagnosis:**
1. Check Firestore RLS policies
2. Check Firebase bridge initialization
3. Check async sync errors in logs

**Fix:**
```bash
# Check Sentry for errors:
# 1. Sentry → Issues
# 2. Look for "Firestore sync failed"
# 3. Check error message
# 4. Fix in Edge Function code
# 5. Re-deploy: supabase functions deploy payment-endpoints
```

---

## 📋 FINAL DEPLOYMENT CHECKLIST

Before going live to production:

- [ ] All environment secrets set in Supabase
- [ ] All migrations applied to database
- [ ] All Edge Functions deployed
- [ ] Firebase credentials configured
- [ ] Razorpay live mode activated
- [ ] Twilio phone number verified
- [ ] SendGrid sender domain verified
- [ ] Sentry project connected
- [ ] Mobile app signed and built
- [ ] Google Play Store listing complete
- [ ] App submitted for review
- [ ] Database backups configured
- [ ] Monitoring dashboards set up
- [ ] All test flows completed successfully
- [ ] Error handling tested
- [ ] Performance monitoring verified
- [ ] Security audit completed
- [ ] Documentation updated
- [ ] Support contact info added to app

---

## 📞 PRODUCTION SUPPORT

### Monitoring Dashboards

**Sentry:** https://sentry.io/organizations/your-org/issues/
**Firebase:** https://console.firebase.google.com/
**Supabase:** https://app.supabase.com/
**Razorpay:** https://dashboard.razorpay.com/

### Emergency Contacts

- Firebase Support: https://firebase.google.com/support
- Razorpay Support: support@razorpay.com
- Twilio Support: https://support.twilio.com
- SendGrid Support: https://support.sendgrid.com

### Incident Response

1. **If payment fails:** Check Razorpay dashboard + Sentry logs
2. **If SMS not sending:** Check Twilio console + Sentry logs
3. **If app crashes:** Check Sentry → Issues
4. **If database down:** Check Supabase status page

---

## ✨ DEPLOYMENT COMPLETE

Your Fufaji Store production system is now live!

**Live URLs:**
- Mobile App: Google Play Store → "Fufaji Store"
- Dashboard: https://yourdomain.com/admin
- API: https://yourdomain.com/api

**Next Steps:**
1. Monitor Sentry for errors
2. Monitor Firebase Analytics for user activity
3. Monitor Razorpay for payment trends
4. Respond to user support requests
5. Plan next feature releases

---

**Questions?** Check the troubleshooting section or contact your development team.
