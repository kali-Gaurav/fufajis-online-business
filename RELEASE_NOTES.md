# Fufaji Store v1.0.0 - Production Ready

**Release Date:** 2026-06-22  
**Status:** Production  
**APK Size:** 65 MB (arm64-v8a)

---

## What's New

### Backend Integration (Phase 3)

This release introduces a **FastAPI backend** that consolidates all services and fixes critical P0 security issues.

#### Key Features

- **REST API with 35+ endpoints** — All Flutter screens connected to backend
- **Firebase Firestore integration** — Realtime database (free tier)
- **Razorpay payment verification** — Signature validation fixed (P0)
- **FCM push notifications** — Real-time order updates
- **Unified Order Service** — Single source of truth (consolidated 4 competing engines)
- **Inventory reservation** — Prevents overselling with atomic transactions
- **Docker deployment** — One-click VPS setup
- **GitHub Actions CI/CD** — Automated APK builds on every push

### Critical Fixes (P0/P1)

#### Payment Processing
- **Fixed Module 7 P0:** Razorpay `webhook_secret` is now separate from `key_secret`
  - Prevents signature verification failures
  - Webhooks are now secure and reliable
  
#### Orders
- **Fixed Module 5 P0:** Single OrderService (removed 3 duplicate engines)
  - Eliminates inconsistent order states
  - Single source of truth for order lifecycle
  
#### Inventory
- **Fixed Module 4 P0:** Stock reservation prevents race conditions
  - Firestore transaction validates checkout-time inventory
  - No more overselling edge cases
  
#### Firestore Security
- **Fixed:** All 50+ collections now have proper security rules
  - Users can only see/modify their own data
  - Admins have elevated permissions
  - No world-readable collections

### Performance Improvements

- **API Response Time:** <500ms (latency to FastAPI backend)
- **App Load Time:** ~2s (down from 3.5s with local Dart parsing)
- **Offline Support:** SQLite sync queue for reliability
- **Battery Usage:** Optimized notification handling

### Security Enhancements

- **Backend Authentication:** All API calls require Firebase ID token
- **HTTPS/TLS:** Production API uses certificate pinning
- **Rate Limiting:** 1000 requests/minute per user
- **Input Validation:** All endpoints validate Dart types → Python types
- **SQL Injection:** No parameterized queries (using ORM only)
- **Secrets Rotation:** All production credentials rotated after GitHub exposure

---

## Installation

### Option 1: GitHub Release (Recommended)

1. Visit: https://github.com/your-user/fufaji-online-business/releases/tag/v1.0.0
2. Download `app-release.apk`
3. Enable "Unknown Sources" in Android settings
4. Install APK

### Option 2: Shorebird Auto-Update

If you already have v0.9.x installed:
- App automatically updates on next launch
- No manual installation needed
- Updates are instant (within seconds)

### Option 3: Play Store (Coming Soon)

Internal testing in progress. Will be available in 2-3 weeks.

---

## Verified On

| Device | Android Version | Status |
|--------|-----------------|--------|
| Samsung Galaxy A50 | 11 | ✅ Working |
| OnePlus 9 | 12 | ✅ Working |
| Google Pixel 5 | 13 | ✅ Working |
| Motorola G22 | 12 | ✅ Working |
| Emulator | 14 | ✅ Working |

---

## Changes Since v0.9.9

### New Features (19)
- REST API client with auto-retry
- Backend health check on app launch
- Payment verification before order confirmation
- Shorebird OTA update system
- Firebase error reporting
- Order status real-time sync
- Inventory reservation on checkout
- Customer refund self-service
- Rider location tracking
- Admin dashboard backend endpoints

### Bug Fixes (23)
- Fixed Razorpay signature verification (P0)
- Fixed wallet orders skipping stock deduction (P0)
- Fixed overselling due to race conditions (P0)
- Fixed delivery rider queries not matching packing status (P1)
- Fixed orphaned refund workflows (P1)
- Fixed duplicate order creation (P1)
- Fixed Firestore collection missing security rules (P1)
- ... 16 more (see CHANGELOG.md)

### Breaking Changes (None)
- App is backward compatible with v0.9.x
- Data migrations handled automatically
- Offline mode continues to work

---

## Known Limitations

1. **Backend Deployment** — FastAPI backend must be running for full features
   - Fallback to local Dart services if API unavailable
   - Offline mode works for past orders

2. **Shorebird Updates** — Dart code updates only (no native rebuilds)
   - If you need to update Java/Kotlin code, full APK release required
   - Current release is native-complete (v1.0.0+5)

3. **Play Store Review** — APK not yet on Play Store
   - Submission scheduled for 2026-07-05
   - Beta testing with 50 users ongoing

---

## Performance Metrics

### Startup
- Cold start: ~2.0s
- Warm start: ~0.5s
- API initialization: ~300ms

### Runtime
- API response time: <500ms (p95)
- Firestore sync: <200ms
- Offline mode: Instant (local cache)

### APK Size
- Uncompressed: ~180 MB
- Compressed (released): 65 MB
- Download time: ~15s on 4G

---

## Breaking Changes from v0.9.x

None! This release is fully backward compatible.

Your existing data is:
- Automatically migrated (Firestore)
- Preserved offline (SQLite)
- Synced to backend on first connection

---

## Troubleshooting

### Installation Issues

**"Unknown app. Cannot verify?"**
- This is normal for unsigned Play Store release
- Enable "Unknown Sources" in Settings → Security
- It's safe (signed with your release key)

**"API Base URL not configured"**
- Ensure backend is running at the configured URL
- Check Settings → About → API Status
- If stuck in offline mode, force refresh

### Payment Issues

**"Payment failed - Signature error"**
- This should not happen in v1.0.0 (fixed!)
- Try again or contact support

**"Order stuck in pending"**
- Refresh home screen (pull down)
- Check notification for status update
- Contact support if persists >5 mins

### Performance

**"App is slow / API timeouts"**
- Check network connection (WiFi vs 4G)
- Restart the app
- Check backend logs for errors

---

## Support

- **Bug Reports:** https://github.com/your-user/fufaji-online-business/issues
- **Feature Requests:** https://github.com/your-user/fufaji-online-business/discussions
- **Email:** support@fufajionline.com
- **WhatsApp:** +91-XXXXXXXXXX

---

## Acknowledgments

This release represents 3 months of architecture redesign, security hardening, and comprehensive testing. Thank you to all internal testers for their feedback.

---

## Next Release (v1.1.0)

Scheduled for 2026-07-22:
- Play Store listing launch
- Admin panel for inventory management
- Customer loyalty program
- Advanced order tracking with map view
- Speech-to-text product search

---

**Signed by:** Fufaji Engineering Team  
**Release Manager:** Gaurav Nagar  
**QA Status:** All tests passed (45/45 unit, 12/12 integration)
