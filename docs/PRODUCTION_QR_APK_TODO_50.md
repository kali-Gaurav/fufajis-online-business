# Production QR/APK Deployment TODO - 50 Tasks

Goal: build one production Android APK that can be downloaded through a QR code, installed directly by nearby customers, and used with Firebase Auth/OTP, internet data, Razorpay/UPI/COD payments, WhatsApp communication, and delivery-radius protection.

## Phase 1 - Production Configuration

- [x] 1. Create central app config for shop coordinates, delivery radius, Razorpay Key ID, APK URL, and WhatsApp number.
- [x] 2. Remove hard-coded Razorpay live key from checkout code and read it from build-time config.
- [x] 3. Add `scripts/build_release_apk.ps1` so release APK builds are repeatable.
- [x] 4. Add `.gitignore` entries for secrets, keystores, APK/AAB outputs, and Firebase config files.
- [x] 5. Add Android `network_security_config.xml` so release builds have a valid manifest reference.
- [x] 6. Add production signing template file `android/key.properties.example`.
- [ ] 7. Generate real Android upload keystore and create local `android/key.properties`.
- [ ] 8. Replace debug release signing fallback with strict release signing after keystore is created.
- [x] 9. Confirm final app package name `com.fufajis.online`.
- [ ] 10. Update app version in `pubspec.yaml` before final APK.

## Phase 2 - Firebase and Auth Readiness

- [ ] 11. Add real `android/app/google-services.json` from Firebase Android app.
- [ ] 12. Confirm Firebase project has Android package `com.fufajis.online`.
- [ ] 13. Enable Firebase Phone Authentication.
- [ ] 14. Add owner/test phone numbers in Firebase Auth for free OTP testing.
- [ ] 15. Enable Google Sign-In only if needed for launch.
- [ ] 16. Publish production Firestore rules.
- [x] 17. Review Firestore rules for customer/owner/delivery separation.
- [x] 18. Verify orders cannot be written by unauthenticated users.
- [x] 19. Verify users cannot edit other users' profiles or addresses.
- [ ] 20. Enable Firebase Analytics and Crashlytics-ready release monitoring.

## Phase 3 - Nearby Customer Restriction

- [x] 21. Add delivery radius calculation from shop GPS coordinates.
- [x] 22. Show delivery eligibility message on checkout address.
- [x] 23. Block order placement when selected address is outside delivery radius.
- [x] 24. Add current GPS capture while saving addresses.
- [ ] 25. Add map pin/manual coordinate correction for addresses.
- [ ] 26. Add owner-editable delivery radius settings in Firestore.
- [ ] 27. Add pincode allowlist as a backup to GPS radius.
- [ ] 28. Add a friendly out-of-area screen with WhatsApp contact.
- [ ] 29. Add server-side delivery-radius validation before order creation.
- [ ] 30. Test addresses at 1 km, 8 km, 15 km, and 30 km from shop.

## Phase 4 - Payments and Order Safety

- [ ] 31. Switch Razorpay to Test Mode for full test cycle.
- [ ] 32. Add backend order creation for Razorpay orders.
- [ ] 33. Add backend Razorpay signature verification.
- [ ] 34. Store Razorpay payment ID/order ID/signature in Firestore.
- [ ] 35. Prevent duplicate payment callback/order completion.
- [x] 36. Keep COD available for local launch.
- [ ] 37. Test UPI intent on real Android phone.
- [ ] 38. Add payment failed/cancelled state to order records.
- [ ] 39. Add owner payment status view.
- [ ] 40. Rotate exposed Razorpay secret before going live.

## Phase 5 - WhatsApp, QR, and APK Delivery

- [ ] 41. Decide APK hosting location: Firebase Hosting, GitHub Release, Google Drive, or website server.
- [ ] 42. Create stable APK download URL.
- [ ] 43. Generate QR code pointing to the stable APK download page.
- [x] 44. Create simple download page with install instructions.
- [x] 45. Add WhatsApp support/contact link inside app.
- [ ] 46. Add WhatsApp order notification plan: manual link first, API/webhook later.
- [ ] 47. Test APK download and install from QR on Android phone.
- [ ] 48. Test app update flow by installing a newer APK over older APK.
- [ ] 49. Prepare final launch checklist for shop staff.
- [ ] 50. Build final signed release APK and archive it with version/date.
