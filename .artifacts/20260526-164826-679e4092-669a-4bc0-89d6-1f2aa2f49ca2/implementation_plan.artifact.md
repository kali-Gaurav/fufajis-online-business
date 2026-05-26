# Next-Gen Infrastructure: 24/7 Reliability & Automated Updates

This plan outlines the transition to a fully automated deployment system with Over-The-Air (OTA) updates, continuous integration, and real-time environment management.

## User Review Required
> [!IMPORTANT]
> - **GitHub Setup:** This plan assumes the project will be pushed to a Private GitHub repository.
> - **Shorebird Account:** You will need a Shorebird.dev account for the OTA (Code Push) functionality to work.
> - **Secrets Management:** Sensitive keys (Razorpay Secret, Firebase Admin Key) will move to GitHub Secrets and Google Cloud Secret Manager.

## Proposed Changes

### 1. Automated Updates (Over-The-Air)
Enabling the app to update itself without requiring a Play Store download for logic changes.

#### [NEW] [Shorebird Integration](file:///C:/Projects/fufaji-online-business/pubspec.yaml)
- Integrate `shorebird_code_push` to allow pushing bug fixes and UI changes instantly to all users.
- Configure `shorebird.yaml` for release track management.

#### [UpdateService](file:///C:/Projects/fufaji-online-business/lib/services/update_service.dart)
- Refactor to check for Shorebird patches on app resume.
- Implement a "Force Update" UI if a critical version is set in Firebase Remote Config.

---

### 2. CI/CD Pipeline (GitHub Actions)
Automating the build and deployment process.

#### [NEW] [main.yml](file:///C:/Projects/fufaji-online-business/.github/workflows/main.yml)
- **Automatic Testing:** Run `flutter test` on every push.
- **Automatic Build:** Build APK/AppBundle on every tag creation.
- **Firebase Deploy:** Automatically deploy Cloud Functions and Security Rules when code in the `functions/` or `firestore.rules` changes.

---

### 3. Environment & Secret Management
Removing all hardcoded `.env` values and moving to a secure, dynamic system.

#### [RemoteConfigService](file:///C:/Projects/fufaji-online-business/lib/services/remote_config_service.dart)
- Use Firebase Remote Config to manage:
    - `API_BASE_URL`
    - `MAINTENANCE_MODE` (to take the app offline 24/7 if needed)
    - `MIN_REQUIRED_VERSION`

#### [Cloud Functions Security](file:///C:/Projects/fufaji-online-business/functions/index.js)
- Migrate Twilio and Razorpay secrets from `functions.config()` (deprecated) to **Google Cloud Secret Manager**.

---

### 4. 24/7 Operational Monitoring
Ensuring the team is notified before users notice a crash.

#### [Sentry Integration](file:///C:/Projects/fufaji-online-business/lib/main.dart)
- Connect Sentry to the CI/CD pipeline to upload debug symbols (source maps).
- Implement custom alerts for "Payment Failure Rate > 5%".

## Verification Plan

### Automated Tests
- `gh workflow run build.yml`: Trigger a manual build on GitHub Actions.
- `shorebird patch android`: Verify that a small UI change is reflected on a test device without a reinstall.

### Manual Verification
1. **Force Update Test:** Increase `min_version` in Firebase Console -> App should show a non-dismissible "Update Required" dialog.
2. **Secret Rotation:** Delete local `.env` -> App should fetch necessary non-sensitive config from Remote Config.
