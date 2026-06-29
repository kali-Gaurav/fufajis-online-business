# Monitoring Integration Guide

Quick reference for integrating the monitoring stack into the Fufaji app.

## Files Created (Phase 2)

### Flutter Services
```
lib/services/
├── analytics_service.dart          (NEW - Firebase Analytics tracking)
├── crashlytics_service.dart        (NEW - Enhanced crash reporting)
└── [existing services...]
```

### Backend Services
```
functions/
├── LoggerService.js                (NEW - Centralized logging)
├── FirestoreQuotaService.js        (NEW - Quota monitoring)
├── requestLogger.js                (NEW - Request middleware)
├── health.js                       (NEW - Health check endpoint)
└── [existing functions...]
```

### Configuration & Documentation
```
.github/workflows/
├── monitoring-setup.yml            (NEW - Health check automation)

root/
├── MONITORING_SETUP.md             (NEW - Complete monitoring guide)
├── MONITORING_INTEGRATION_GUIDE.md (NEW - This file)
└── alerts-config.json              (NEW - Alert configuration)
```

## Integration Checklist

### 1. Add Analytics Service Imports to main.dart

```dart
// Add to imports section (around line 44)
import 'services/analytics_service.dart';
import 'services/crashlytics_service.dart';
```

### 2. Initialize Crashlytics in main.dart

In `_initializeApp()` function, add after Firebase initialization:

```dart
// Initialize Crashlytics
await CrashlyticsService().initialize();
LoggingService().info('Crashlytics initialized');
```

### 3. Track Login Success

In `auth_provider.dart` after successful login:

```dart
await AnalyticsService().logLoginSuccess(
  userId: user.id,
  userRole: user.role,
  loginMethod: 'email', // or 'google', 'phone', etc
);

// Set Crashlytics context
await CrashlyticsService().setUserProperties(
  userId: user.id,
  userRole: user.role.toString(),
  shopId: user.shopId,
  phoneNumber: user.phone,
);
```

### 4. Track Order Creation

In `order_provider.dart` or order creation handler:

```dart
await AnalyticsService().logOrderCreated(
  orderId: order.id,
  userId: currentUser.id,
  amount: order.totalAmount,
  itemCount: order.items.length,
  shopId: order.shopId,
);

await CrashlyticsService().recordOrderContext(
  orderId: order.id,
  userId: currentUser.id,
  amount: order.totalAmount,
  itemCount: order.items.length,
  shopId: order.shopId,
);
```

### 5. Track Payment Flow

Before Razorpay checkout:

```dart
await AnalyticsService().logPaymentInitiated(
  orderId: orderId,
  userId: currentUser.id,
  amount: amount,
  paymentMethod: 'razorpay',
);

await CrashlyticsService().recordPaymentContext(
  paymentId: paymentId,
  orderId: orderId,
  amount: amount,
  paymentMethod: 'razorpay',
);
```

After successful payment verification:

```dart
final startTime = DateTime.now();
// ... payment verification logic
final duration = DateTime.now().difference(startTime).inMilliseconds;

await AnalyticsService().logPaymentVerified(
  orderId: orderId,
  userId: currentUser.id,
  amount: amount,
  paymentId: paymentId,
  duration: duration,
);
```

### 6. Track Order Confirmations

When order moves to packing:

```dart
await AnalyticsService().logOrderConfirmed(
  orderId: orderId,
  userId: currentUser.id,
);

await CrashlyticsService().logBreadcrumb(
  message: 'Order confirmed and sent to packing',
  category: 'order',
  data: {'orderId': orderId, 'userId': currentUser.id},
);
```

### 7. Track Delivery Events

Delivery assigned:

```dart
await AnalyticsService().logDeliveryAssigned(
  orderId: orderId,
  userId: customerId,
  riderId: riderId,
);
```

Order delivered:

```dart
await AnalyticsService().logOrderDelivered(
  orderId: orderId,
  userId: customerId,
  riderId: riderId,
  deliveryDuration: deliveryTimeMs,
);
```

### 8. Track Packing

When packing completes:

```dart
await AnalyticsService().logPackingCompleted(
  orderId: orderId,
  userId: packerId,
  duration: packingTimeMs,
);
```

### 9. Track Cancellations

When order is cancelled:

```dart
await AnalyticsService().logOrderCancelled(
  orderId: orderId,
  userId: currentUser.id,
  reason: cancellationReason,
);
```

### 10. Track Refunds

When refund is processed:

```dart
await AnalyticsService().logRefundProcessed(
  orderId: orderId,
  userId: currentUser.id,
  refundAmount: amount,
  status: 'completed',
);
```

### 11. Track Errors

In error handlers:

```dart
try {
  // risky operation
} catch (e, stackTrace) {
  await AnalyticsService().logErrorOccurred(
    errorType: 'PaymentVerificationError',
    errorMessage: e.toString(),
    userId: currentUser?.id,
    orderId: orderId,
    paymentId: paymentId,
  );

  await CrashlyticsService().recordError(
    error: e,
    stackTrace: stackTrace,
    reason: 'Payment verification failed',
    context: {
      'orderId': orderId,
      'amount': amount,
      'paymentId': paymentId,
    },
  );
}
```

### 12. Clear User Data on Logout

In logout handler:

```dart
await AnalyticsService().clearUserData();
await CrashlyticsService().clearUserData();
```

## Backend Integration

### Update functions/index.js

Add at top of file:

```javascript
const logger = require('./LoggerService');
const quotaService = require('./FirestoreQuotaService');
const { requestLogger } = require('./requestLogger');

// Initialize quota monitoring
quotaService.initialize().catch(err => {
  console.error('Quota service initialization failed:', err);
});
```

### Wrap Existing Functions

```javascript
// Before:
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
  // ... handler
});

// After:
exports.razorpayWebhook = functions.https.onRequest(
  requestLogger(async (req, res) => {
    try {
      // ... handler
      const startTime = Date.now();
      
      // Log operations
      await quotaService.trackRead(1);
      await logger.info('Processing payment webhook', {
        paymentId: payment.id,
        orderId: orderId,
      });
      
      // ... rest of logic
      
    } catch (error) {
      await logger.error('Payment webhook failed', error, {
        paymentId: payment.id,
      });
      throw error;
    }
  })
);
```

### Export Health Endpoints

Add to functions/index.js exports:

```javascript
// Import health endpoints
const { health, quotaReport } = require('./health');
exports.health = health;
exports.quotaReport = quotaReport;
```

## Testing Checklist

### Flutter App
- [ ] App launches without errors
- [ ] Crashlytics initializes successfully
- [ ] User can login (analytics event triggered)
- [ ] Order can be created (analytics event + crashlytics context)
- [ ] Payment flow works (analytics events for initiation + verification)
- [ ] Errors are captured in Crashlytics with full context
- [ ] User data is cleared on logout

### Backend Functions
- [ ] `GET /health` returns 200 with quota metrics
- [ ] `GET /quota-report?days=7` returns quota report
- [ ] Logs appear in Firestore `backend_logs` collection
- [ ] Request IDs are generated and logged
- [ ] Response times are tracked

### Firebase Console
- [ ] Crashlytics dashboard shows crashes (if any)
- [ ] Analytics dashboard shows events
- [ ] Event parameters include expected data
- [ ] User properties are set correctly

## Deployment Steps

1. **Deploy Backend First**
   ```bash
   cd functions
   firebase deploy --only functions:health,functions:quotaReport
   firebase deploy --only functions:razorpayWebhook  # Update existing
   ```

2. **Update Flutter App**
   - Add imports from integration guide
   - Add analytics tracking calls
   - Add crashlytics initialization
   - Test in staging environment

3. **Verify Monitoring**
   - Run health check: `curl https://YOUR_URL/health`
   - Check Firebase console for events
   - Simulate error and verify Crashlytics report

4. **Set Up Alerts**
   - Configure email alerts in Firebase Console
   - Set up Slack webhook if using Slack
   - Configure PagerDuty if using on-call rotation

## Common Issues

### Crashlytics not reporting
- Ensure `CrashlyticsService().initialize()` is called BEFORE `runApp()`
- Check that `kDebugMode` is false in release mode
- Wait 5 minutes for events to appear
- Verify Sentry DSN is configured

### Analytics events not showing
- Events have 24-hour delay in Firebase console
- Check real-time data in Analytics dashboard
- Verify event names match exactly
- Ensure user has granted analytics permission

### Quota alerts not firing
- Check Firestore quota metrics collection exists
- Verify alerting rules in alerts-config.json
- Check Cloud Logs for quota service errors
- Ensure health endpoint is accessible

## Monitoring Dashboards

### Essential Links
1. **Crashlytics:** https://console.firebase.google.com/project/YOUR_PROJECT/crashlytics
2. **Analytics:** https://console.firebase.google.com/project/YOUR_PROJECT/analytics/overview
3. **Firestore:** https://console.firebase.google.com/project/YOUR_PROJECT/firestore/data
4. **Cloud Functions:** https://console.cloud.google.com/functions
5. **Health Check:** https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/health
6. **Quota Report:** https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/quota-report?days=7

### Daily Monitoring Routine
- Check Crashlytics for new crashes
- Review Analytics KPIs (DAU, conversion rate, payment success)
- Monitor health check every 6 hours (via GitHub Actions)
- Review quota usage if >70%
- Check backend logs for errors

## Next Steps

1. Add tracking to all key screens
2. Set up alert notifications
3. Create monitoring dashboards
4. Document runbooks for common alerts
5. Train ops team on monitoring tools
6. Quarterly review of metrics and SLOs

---

**Last Updated:** 2026-06-22  
**Reference:** MONITORING_SETUP.md for detailed documentation
