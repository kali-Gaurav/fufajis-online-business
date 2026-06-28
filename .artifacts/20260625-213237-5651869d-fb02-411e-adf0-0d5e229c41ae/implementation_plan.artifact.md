# Production Secret Management & Deployment Plan

Deploy secrets to their correct production locations (Firebase Secret Manager and Build-time injection) and provide a guide for full stack deployment (Backend, Frontend, and APK).

## User Review Required

> [!IMPORTANT]
> **Secret Rotation is MANDATORY**: Since your secrets were previously committed to a public repo, you **MUST** rotate them in their respective dashboards (Razorpay, Twilio, WhatsApp, etc.) before proceeding. Using the old values is a security risk.

- **Backend Location**: We will use **Firebase Secret Manager** for server-side secrets. This is the modern, secure way to handle secrets in Firebase Functions.
- **Frontend Location**: The Flutter app will use `--dart-define` at build time for public keys (like `RAZORPAY_KEY_ID`). True secrets will **NOT** be bundled in the APK.
- **Deployment**: I will provide scripts and commands to deploy the Backend (Firebase Functions), Frontend (Firebase Hosting/Web), and build the Production APK.

## Proposed Changes

### [Secret Management Infrastructure]

We will transition from `.env` files and `functions.config()` to Firebase Secrets and Dart Defines.

#### [Firebase Secrets Setup](file:///C:/Projects/fufaji-online-business/FIREBASE_SECRET_MANAGER_SETUP.md)
- Use `firebase functions:secrets:set` for all sensitive keys.
- Update `functions/index.js` to use `process.env` and declare secrets in `runWith`.

#### [Build-time Injection (Flutter)](file:///C:/Projects/fufaji-online-business/lib/config/app_config.dart)
- Remove any remaining secret logic from the client.
- Ensure all public config is read via `String.fromEnvironment`.

---

### [Deployment Guides]

#### [NEW] [DEPLOY_PROD.md](file:///C:/Projects/fufaji-online-business/DEPLOY_PROD.md)
A comprehensive guide for the user to:
1. Set secrets in Firebase.
2. Deploy Firebase Functions.
3. Deploy the Web frontend.
4. Build the final signed APK.

#### [UPDATED] [BUILD_APK_PRODUCTION.ps1](file:///C:/Projects/fufaji-online-business/BUILD_APK_PRODUCTION.ps1)
Update the script to use `--dart-define` for all necessary production values instead of relying on a `.env` asset.

---

## Verification Plan

### Automated Tests
- `firebase functions:secrets:list` to verify secret storage.
- `flutter build apk --analyze-size` to check if `.env` is removed from assets.

### Manual Verification
- **Secret Access**: Verify that Cloud Functions can access the new secrets (I will add a health check function).
- **APK Inspection**: Verify that the generated APK does not contain sensitive `.env` files using `apktool` or similar (conceptual check).
- **Webhook Test**: Trigger a test webhook from Razorpay to verify the `RAZORPAY_WEBHOOK_SECRET` is working.
