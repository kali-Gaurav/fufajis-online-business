# 🚀 Fufaji Online v1.1.0 — Production Readiness Release

**Released:** June 2026 | **Version Code:** 3 | **Build:** Stable

## 🔧 Bug Fixes & Improvements
- **🔴 Fixed Redis Cache:** Upstash REST API endpoints corrected (`/ping`, `/get/{key}`, `/set/{key}`) — resolves known Redis authentication failure
- **🔔 FCM Deep-Link Navigation:** Tapping push notifications now routes directly to the relevant order detail screen
- **🛒 Dynamic Coupons:** Coupon validation now fetches from Firestore `coupons` collection (with offline fallback)
- **📊 Sentry Error Reporting:** Crash reporting now properly wired via `--dart-define=SENTRY_DSN` in CI build
- **⚡ Faster CI Builds:** Flutter 3.32.0 pinned, analyzer step added, JVM heap increased to 6GB
- **⚠️ Email OTP Documented:** Security limitations of client-side OTP generation clearly documented for future server-side upgrade

## ✅ Verified Production Features (25/25)
- Firebase Auth (phone + email OTP), role-based access, cart & checkout
- Razorpay live payments, order state machine, OTP delivery verification
- FCM + WhatsApp real-time notifications, offline sync, Hive caching
- GST PDF invoicing, Shorebird OTA, Multi-language (Hindi/English), Accessibility

---

# 🚀 Fufaji Online v1.0.0 "District Connect" - Release Notes

We are thrilled to announce the official launch of **Fufaji Online**, the hyperlocal digital transformation for the Fufaji Family shop ecosystem! This release brings a fully integrated, three-sided marketplace for Customers, Shop Owners, and Delivery Agents.

---

## 🌟 Key Highlights

### 🛍️ For Customers: The "Trust & Ease" Experience
- **📍 Pinpoint Delivery:** No more confusing addresses. Use our **Interactive Map-Picker** to drop a pin exactly at your door.
- **🎙️ Voice Landmarks:** Record voice directions (e.g., "Behind the Big Banyan Tree") directly during checkout for the rider.
- **🛡️ Secure Handoffs:** Every delivery is protected by a 4-digit security OTP sent via WhatsApp and SMS.
- **💳 Payment Choice:** Pay with Razorpay, UPI, or Cash on Delivery.

### 🚚 For Delivery Agents: The "Logistics Brain"
- **🛣️ Route Optimization:** Our system automatically organizes your multi-stop deliveries for the shortest, fastest path.
- **🗺️ Live Navigation:** One-tap integration with Google Maps for turn-by-turn navigation to customer pins.
- **💰 Instant Earnings:** Track your daily earnings and COD settlements in real-time.

### 🏪 For Shop Owners: The "Control Tower"
- **📊 Revenue Dashboard:** Interactive district heatmaps showing where your sales are coming from.
- **🤖 Automated Inventory:** Smart stock alerts and voice-powered product seeding.
- **📱 WhatsApp Sync:** Automated order status updates sent directly to customers' WhatsApp.

---

## 🛠️ Technical Hardening (v1.0.0)
- **🔐 Secure Webhooks:** Server-side Razorpay verification via Firebase Cloud Functions.
- **⚡ Idempotency:** Smart order processing to prevent duplicate charges on slow networks.
- **📦 CI/CD Pipeline:** Automated production builds via GitHub Actions.
- **🌍 Geo-Fencing:** Automatic delivery radius validation (8km radius from shop).

---

## 📥 How to Install
1. **Scan the QR Code** displayed at the Fufaji Online Shop.
2. **Download the APK** directly to your Android device.
3. **Login with Phone OTP** and start shopping fresh!

---

*Built with ❤️ by the Fufaji Digital Team (Aarav, Dev, Priya, Ishaan).*
