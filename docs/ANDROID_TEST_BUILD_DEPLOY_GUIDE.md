# Fufaji's Online Android Test, Build, and Deploy Guide

This guide explains how to test the Flutter app, connect Firebase and Razorpay, build an Android APK/AAB, and deploy using mostly free resources.

## 1. What This Project Uses

- App framework: Flutter
- Android package name: `com.fufajis.online`
- Backend: Firebase Auth, Firestore, Storage, Messaging, Analytics
- Payments: Razorpay SDK and UPI intent
- Maps/location: Google Maps, Geolocator, Geocoding
- Local tests: Flutter unit/widget tests in `test/`

Important: never put a Razorpay Key Secret inside the APK or public repository. The APK can safely contain the Razorpay Key ID, but payment order creation and signature verification must happen on a backend such as Firebase Cloud Functions, Cloud Run, or another server.

## 2. Free Accounts and Tools to Use

### Development tools

- Flutter SDK: free
- Android Studio: free
- VS Code: free
- Git and GitHub: free for private and public repositories
- Firebase CLI: free
- FlutterFire CLI: free

### Firebase

Use the Firebase Spark plan while testing. It is the no-cost Firebase plan and is good for development, prototypes, and small testing. Firebase's official docs say to start with the no-cost Spark plan in the initial development stage.

Recommended Firebase products for this app:

- Firebase Authentication: phone login, Google login
- Cloud Firestore: users, products, carts, orders, delivery status
- Firebase Analytics: app usage
- Firebase Cloud Messaging: push notifications
- Firebase Hosting: optional, useful for admin web pages later

Be careful with:

- Phone OTP: free quotas can be limited; heavy testing may require billing.
- Firebase Storage: check current Firebase pricing before using it heavily.
- Cloud Functions: often requires upgrading to Blaze, even if free monthly quotas exist.

Official links:

- Firebase pricing plans: https://firebase.google.com/docs/projects/billing/firebase-pricing-plans
- Firebase console: https://console.firebase.google.com

### Razorpay

Use Razorpay Test Mode first. Razorpay is good for Indian payments and supports cards, UPI, net banking, wallets, and payment links.

Use these safely:

- Razorpay Test Key ID in local development
- Razorpay Live Key ID in production APK
- Razorpay Key Secret only on backend

Do not store this in the app:

- Razorpay Key Secret
- Webhook secret
- Any private Firebase service account key

Official links:

- Razorpay pricing: https://razorpay.com/pricing/
- Razorpay docs: https://razorpay.com/docs/
- Razorpay dashboard: https://dashboard.razorpay.com/

### Google Play

Google Play Console is not free. It normally requires a one-time registration fee. You can still test and share APK files directly without Play Store during development.

Official link:

- Google Play Console setup: https://support.google.com/googleplay/android-developer/answer/6112435

## 3. One-Time Local Setup

Install Flutter and Android Studio, then confirm everything works:

```powershell
flutter doctor
flutter --version
```

Install project dependencies:

```powershell
flutter pub get
```

If `flutter doctor` shows Android license issues:

```powershell
flutter doctor --android-licenses
```

## 4. Firebase Setup

1. Open Firebase Console.
2. Create a Firebase project.
3. Add an Android app with package name:

```text
com.fufajis.online
```

4. Download `google-services.json`.
5. Place it here:

```text
android/app/google-services.json
```

6. Enable Authentication providers:

- Phone
- Google

7. Create Cloud Firestore.
8. Publish the rules from this repo:

```powershell
firebase deploy --only firestore:rules
```

9. If Firebase CLI is not logged in:

```powershell
firebase login
firebase init firestore
```

For FlutterFire configuration, run:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

This updates `lib/firebase_options.dart`.

## 5. Razorpay Setup

Use Test Mode first:

1. Open Razorpay Dashboard.
2. Switch to Test Mode.
3. Copy the Test Key ID.
4. Use only the Key ID in the Flutter app.
5. Keep the Key Secret on a backend.

Recommended production payment flow:

1. App sends cart/order amount to backend.
2. Backend creates a Razorpay order using Key ID and Key Secret.
3. Backend returns Razorpay order ID to the app.
4. App opens Razorpay checkout.
5. Razorpay returns payment ID, order ID, and signature.
6. App sends those values to backend.
7. Backend verifies signature.
8. Backend marks order as paid in Firestore.

Security note: if a Razorpay Key Secret was ever committed or shared, rotate it in the Razorpay Dashboard before going live.

## 6. Google Maps Setup

The Android manifest currently has this placeholder:

```text
YOUR_GOOGLE_MAPS_API_KEY
```

Before testing map screens:

1. Create a Google Cloud project.
2. Enable Maps SDK for Android.
3. Create an Android-restricted API key.
4. Restrict it to package `com.fufajis.online` and your app signing SHA-1.
5. Replace the placeholder in `android/app/src/main/AndroidManifest.xml`.

For early testing, you can skip map screens and test shopping, cart, orders, and owner screens first.

## 7. Testing Plan

Run static checks:

```powershell
flutter analyze
```

Run automated tests:

```powershell
flutter test
```

Run the app on emulator or phone:

```powershell
flutter run
```

Run release mode on a connected phone:

```powershell
flutter run --release
```

Manual test checklist:

- App opens without crash
- Splash screen routes correctly
- Role selection works
- Customer login works with test OTP
- Customer home loads products/categories
- Search works
- Voice search permission flow works
- Barcode scanner permission flow works
- Product detail opens
- Cart add/remove/quantity works
- Checkout creates an order
- COD order can be placed
- UPI intent opens installed UPI app
- Razorpay Test Mode payment succeeds
- Razorpay failed payment shows useful error
- Owner dashboard opens
- Owner can add/edit inventory
- Owner can update order status
- Delivery dashboard opens
- Delivery agent can view assigned orders
- Delivery OTP/proof flow works
- Push notification permission flow works
- App works after closing and reopening
- App handles no internet state
- Firestore rules block unauthorized writes

Recommended test users:

- One customer phone number
- One shop owner account
- One delivery agent account

Keep test data separate from production data. A simple approach is to use a separate Firebase project for testing.

## 8. Build Debug APK for Testing

Use this when you want to install on your own phone or share with a tester:

```powershell
flutter clean
flutter pub get
flutter build apk --debug
```

Output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Install on connected Android phone:

```powershell
flutter install
```

Or:

```powershell
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## 9. Build Release APK

Use this for direct APK sharing outside Play Store:

```powershell
flutter clean
flutter pub get
flutter build apk --release --dart-define=RAZORPAY_KEY_ID=rzp_test_or_live_key_id --dart-define=SHOP_LATITUDE=26.9124 --dart-define=SHOP_LONGITUDE=75.7873 --dart-define=DELIVERY_RADIUS_KM=8
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Or use the included script:

```powershell
.\scripts\build_release_apk.ps1 -RazorpayKeyId rzp_test_or_live_key_id -ShopLatitude 26.9124 -ShopLongitude 75.7873 -DeliveryRadiusKm 8
```

To enable in-app WhatsApp support, pass your WhatsApp number in international format without `+`:

```powershell
.\scripts\build_release_apk.ps1 -RazorpayKeyId rzp_test_or_live_key_id -ShopLatitude 26.9124 -ShopLongitude 75.7873 -DeliveryRadiusKm 8 -SupportWhatsappNumber 919999999999
```

Smaller APKs per CPU architecture:

```powershell
flutter build apk --release --split-per-abi
```

Output examples:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

## 10. Build App Bundle for Play Store

For Google Play, prefer AAB:

```powershell
flutter build appbundle --release
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

Official Flutter Android release guide:

https://docs.flutter.dev/deployment/android

## 11. Proper Release Signing

The current Gradle config signs release builds with the debug signing config. That is okay only for quick local testing, not production.

For production:

1. Create a keystore.
2. Store it safely outside public Git.
3. Create `android/key.properties`.
4. Update `android/app/build.gradle` to use release signing.
5. Back up the keystore securely.

Example keystore generation:

```powershell
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Never lose this file. If you use Google Play App Signing, this becomes your upload key.

## 12. Deployment Options

### Free or nearly free testing

- Install APK directly using USB.
- Share APK using Google Drive.
- Host `distribution/download.html` plus the APK and generate one QR code for that page.
- Use Firebase App Distribution. Check current Firebase limits before depending on it for many testers.
- Use GitHub Releases for internal APK delivery.

### Production deployment

- Google Play Store: best long-term option, but requires Play Console registration.
- Direct APK distribution: possible, but users must allow install from unknown sources.
- Website download page: possible, but less trusted than Play Store.

For real customers, Google Play is recommended because updates, trust, device compatibility, and signing are easier.

## 13. Before Going Live

Complete this checklist:

- Rotate any exposed Razorpay secrets.
- Use Razorpay Live Mode only after full Test Mode success.
- Verify Razorpay signature on backend.
- Use production Firebase project.
- Lock Firestore security rules.
- Add real Google Maps API key with Android restrictions.
- Disable unnecessary cleartext traffic if not needed.
- Replace placeholder icons with production icons.
- Add privacy policy.
- Add terms and refund/cancellation policy.
- Test release APK on at least 3 Android devices.
- Test slow internet and offline cases.
- Increase version in `pubspec.yaml`, for example `version: 1.0.1+2`.
- Build signed release APK or AAB.

## 14. Useful Commands

```powershell
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter run
flutter run --release
flutter build apk --debug
flutter build apk --release
flutter build apk --release --split-per-abi
flutter build appbundle --release
firebase login
firebase deploy --only firestore:rules
```

## 15. Recommended First Testing Order

1. Run `flutter analyze`.
2. Run `flutter test`.
3. Run app on emulator.
4. Run app on a real phone.
5. Test Firebase login and Firestore reads/writes.
6. Test COD order flow.
7. Test UPI intent.
8. Test Razorpay Test Mode.
9. Build debug APK and install it manually.
10. Build release APK.
11. Add production signing.
12. Build AAB for Play Store.
