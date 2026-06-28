# 🌍 Fufaji's Online Business — Master Deployment Guide

This document provides the definitive orchestration for deploying the entire Fufaji ecosystem. 

## 🏗️ Architecture Overview

The system operates on a hybrid-cloud architecture:
- **Firebase**: Authentication, Cloud Functions (Triggers), Firestore (Real-time data).
- **Render.com**: Primary Node.js REST API (fufaji-api).
- **AWS (Lambda/S3)**: Heavy-duty background logic and object storage.
- **Supabase**: Primary Relational Database (PostgreSQL).

---

## 🛠️ Phase 1: Database Setup & Migration (Supabase)

Before deploying application code, the database schema must be current.

### 1. Apply Migrations
Use the Supabase CLI or the SQL Editor in the Supabase Dashboard to run all scripts in:
`supabase/migrations/*.sql` (Run in order: 001, 002, 003...)

### 2. Backfill from Firestore (Optional/Sync)
If you have existing data in Firestore that needs to move to Postgres:
```powershell
cd scripts/migration
npm install
# Set DATABASE_URL and FIREBASE_CONFIG in .env
node migrate.js --all
```

---

## ⚡ Phase 2: Backend Deployments

### 1. Firebase (Functions & Rules)
Deploys triggers for Order updates, WhatsApp webhooks, and security rules.
```powershell
firebase deploy --only functions,firestore:rules,storage:rules
```
*Required Secrets (via `firebase functions:secrets:set`):*
`RAZORPAY_WEBHOOK_SECRET`, `TWILIO_AUTH_TOKEN`, `WHATSAPP_TOKEN`, `GEMINI_API_KEY`.

### 2. Render.com (REST API)
Deploys the main API service.
1. **GitHub Push**: Merging to `main` triggers auto-deploy if configured.
2. **Environment Variables**: Ensure all variables in [RENDER_BACKEND_ENV_SETUP.md](file:///C:/Projects/fufaji-online-business/RENDER_BACKEND_ENV_SETUP.md) are set in the Render Dashboard.

### 3. AWS Lambda
Deploys specialized backend services.
```powershell
cd backend
sam build
sam deploy --stack-name fufaji-backend-prod
```

---

## 📱 Phase 3: Client Deployment (Web & APK)

### 1. Flutter Web
```powershell
flutter build web --release `
  --dart-define=API_BASE_URL=https://fufaji-api.render.com `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

firebase deploy --only hosting
```

### 2. Production APK
Use the hardened build script to generate the Android application:
```powershell
.\BUILD_APK_PRODUCTION.ps1
```
*Note: Ensure you've updated the production values inside the script first.*

---

## 🔄 Phase 4: Integration Verification

Run the verification suite to ensure all parts are communicating:

1. **API Health**: `curl https://fufaji-api.render.com/health`
2. **Database Connectivity**: Check Render logs for "Connected to PostgreSQL".
3. **Webhook Loop**: 
   - Trigger Razorpay Test Webhook.
   - Check Firebase Logs (`firebase functions:log`) to see the event reach Firestore.
   - Check Render Logs to see the event propagate to Postgres.

---

## 🆘 Emergency Recovery

- **Database Rollback**: Migrations are additive. To revert, you must use a database snapshot from the Supabase dashboard.
- **Function Rollback**: `firebase deploy --only functions` from a previous stable git commit.
- **Secret Rotation**: If any key is compromised, update it in BOTH Render Dashboard and Firebase Secrets immediately.

---
*Status: Ready for Production Launch 🚀*
