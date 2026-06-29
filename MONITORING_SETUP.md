# Fufaji Monitoring & Analytics Stack

Complete monitoring setup for production tracking, crash reporting, and quota management. Timeline: Deployed Phase 2.

## Overview

This document describes the complete monitoring infrastructure for Fufaji across Flutter frontend and Firebase backend.

### Components
1. **Crashlytics** - Real-time crash reporting with context
2. **Firebase Analytics** - Event tracking for business metrics
3. **Backend Logging** - Structured logging service
4. **Firestore Quota Monitoring** - Usage tracking and alerts
5. **Health Check Endpoint** - System status monitoring

---

## 1. CRASHLYTICS SETUP (Flutter App)

### Implementation

**File:** `lib/services/crashlytics_service.dart`

Crashlytics is integrated with Sentry for enhanced error context.

### Usage in App

#### Initialize in main.dart

```dart
import 'services/crashlytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Crashlytics
  await CrashlyticsService().initialize();
  
  // ... rest of initialization
  runApp(const FufajiApp());
}
```

#### Set User Context Before Sensitive Operations

```dart
// After successful login
await CrashlyticsService().setUserProperties(
  userId: user.id,
  userRole: user.role,
  shopId: user.shopId,
  phoneNumber: user.phone,
);
```

#### Record Order Context Before Payment

```dart
// Before starting payment flow
await CrashlyticsService().recordOrderContext(
  orderId: orderId,
  userId: currentUser.id,
  amount: totalAmount,
  itemCount: cartItems.length,
  shopId: shopId,
);
```

#### Record Payment Context

```dart
// When starting Razorpay checkout
await CrashlyticsService().recordPaymentContext(
  paymentId: paymentId,
  orderId: orderId,
  amount: amount,
  paymentMethod: 'razorpay',
);
```

#### Log Breadcrumbs for Important Events

```dart
// Important event before potential crash
await CrashlyticsService().logBreadcrumb(
  message: 'Payment verification started',
  category: 'payment',
  data: {'paymentId': paymentId, 'orderId': orderId},
);
```

#### Record Errors Manually

```dart
try {
  // risky operation
} catch (e, stackTrace) {
  await CrashlyticsService().recordError(
    error: e,
    stackTrace: stackTrace,
    reason: 'Payment verification failed',
    context: {'orderId': orderId, 'amount': amount},
  );
}
```

#### Clear User Data on Logout

```dart
// During logout
await CrashlyticsService().clearUserData();
```

### Viewing Crashes

**Dashboard:** https://console.firebase.google.com/project/YOUR_PROJECT/crashlytics

- Click "Crashlytics" in left sidebar
- View crash trends, affected users, stack traces
- Filter by app version, date range, user properties
- Set up alerts in Firebase Console

### Key Metrics

- **Crash-Free Users %** - Percentage of users not experiencing crashes
- **Crash-Free Sessions %** - Percentage of sessions without crashes
- **Top Issues** - Most frequent crashes
- **Affected Users** - Count of affected users by issue
- **Severity Score** - Risk-weighted crash importance

---

## 2. FIREBASE ANALYTICS EVENTS

### Implementation

**File:** `lib/services/analytics_service.dart`

All major user events are tracked for business intelligence.

### Event Tracking Checklist

#### Authentication Events
- [x] `app_launch` - App opened
- [x] `login_success` - User logged in
- [x] `logout` - User logged out

#### Order Events
- [x] `order_created` - New order placed
- [x] `order_confirmed` - Order confirmed for packing
- [x] `order_cancelled` - Order cancelled
- [x] `order_delivered` - Order completed
- [x] `refund_processed` - Refund initiated

#### Payment Events
- [x] `payment_initiated` - Razorpay checkout opened
- [x] `payment_verified` - Payment successful
- [x] `payment_failed` - Payment failed (not yet tracked)

#### Fulfillment Events
- [x] `packing_completed` - Order packed
- [x] `delivery_assigned` - Rider assigned

#### Technical Events
- [x] `error_occurred` - App error with context

### Usage Examples

#### Log Order Creation

```dart
import 'services/analytics_service.dart';

// When user creates order
await AnalyticsService().logOrderCreated(
  orderId: orderId,
  userId: userId,
  amount: totalAmount,
  itemCount: cartItems.length,
  shopId: shopId,
);
```

#### Log Payment Flow

```dart
// When opening Razorpay
await AnalyticsService().logPaymentInitiated(
  orderId: orderId,
  userId: userId,
  amount: amount,
  paymentMethod: 'razorpay',
);

// After successful payment verification
await AnalyticsService().logPaymentVerified(
  orderId: orderId,
  userId: userId,
  amount: amount,
  paymentId: paymentId,
  duration: elapsedTime, // in milliseconds
);
```

#### Log Errors with Context

```dart
await AnalyticsService().logErrorOccurred(
  errorType: 'PaymentVerificationError',
  errorMessage: error.toString(),
  userId: userId,
  orderId: orderId,
  paymentId: paymentId,
  additionalContext: {
    'retryCount': retryAttempts,
    'errorCode': errorCode,
  },
);
```

### Viewing Analytics

**Dashboard:** https://console.firebase.google.com/project/YOUR_PROJECT/analytics/overview

- View real-time user activity
- Click "Events" to see all tracked events
- Filter by date, user segment, platform
- Create custom reports and dashboards

### Key Metrics to Monitor

- **Daily Active Users** - Users launching app daily
- **Login Success Rate** - % of login attempts successful
- **Order Conversion Rate** - Users who create orders
- **Payment Success Rate** - Successful payment vs initiated
- **Delivery Completion Rate** - Orders completed vs created
- **Refund Rate** - Refunds vs successful orders
- **Error Rate** - Errors vs total sessions

---

## 3. BACKEND STRUCTURED LOGGING

### Implementation

**Files:**
- `functions/LoggerService.js` - Centralized logging
- `functions/requestLogger.js` - Request middleware
- `functions/health.js` - Health check endpoint

### Usage in Firebase Functions

#### Basic Logging

```javascript
const logger = require('./LoggerService');

// Info log
logger.info('Payment processing started', {
  paymentId: 'pay_xxx',
  orderId: 'ord_yyy',
  amount: 10000,
});

// Warning
logger.warning('High response time', {
  endpoint: '/api/payment/verify',
  duration: '850ms',
});

// Error
logger.error('Payment verification failed', error, {
  paymentId: 'pay_xxx',
  attemptCount: 3,
});
```

#### Wrap HTTP Handlers

```javascript
const { requestLogger } = require('./requestLogger');

// Automatically logs request/response with metrics
exports.myFunction = functions.https.onRequest(
  requestLogger(async (req, res) => {
    // Your handler code
    res.json({ status: 'ok' });
  })
);
```

#### Log Database Operations

```javascript
const startTime = Date.now();
try {
  await db.collection('orders').doc(orderId).set(orderData);
  const duration = Date.now() - startTime;
  await logger.logDatabaseOp('write', 'orders', orderId, duration, true);
} catch (error) {
  const duration = Date.now() - startTime;
  await logger.logDatabaseOp('write', 'orders', orderId, duration, false);
}
```

#### Log Payment Transactions

```javascript
await logger.logPaymentTransaction({
  paymentId: 'pay_xxx',
  orderId: 'ord_yyy',
  amount: 10000,
  status: 'verified',
  method: 'razorpay',
  userId: 'user_123',
  duration: 245, // milliseconds
});
```

#### Log Inventory Changes

```javascript
await logger.logInventoryChange({
  productId: 'prod_123',
  operation: 'deduct', // or 'add', 'reserve'
  quantity: 5,
  before: 100,
  after: 95,
  orderId: 'ord_yyy',
  userId: 'user_123',
});
```

#### Log Order State Changes

```javascript
await logger.logOrderStateChange({
  orderId: 'ord_yyy',
  fromState: 'payment_verified',
  toState: 'packing',
  userId: 'user_123',
  reason: 'Payment confirmed',
  duration: 120,
});
```

#### Log Security Events

```javascript
await logger.logSecurityEvent({
  eventType: 'invalid_payment_signature',
  severity: 'high',
  userId: 'unknown',
  action: 'webhook_rejected',
  details: { signature: '...' },
});
```

### Firestore Log Collection

Logs are stored in `backend_logs` collection:

```
backend_logs/
├── doc1: {
│   timestamp: "2026-06-22T10:30:45Z",
│   level: "INFO",
│   message: "Payment verified",
│   context: {
│     paymentId: "pay_xxx",
│     orderId: "ord_yyy",
│     amount: 10000,
│     duration: "245ms",
│     userId: "user_123"
│   }
│ }
└── ... more logs
```

### Querying Logs

```javascript
// Get all errors from today
const today = new Date().toISOString().split('T')[0];
const logs = await db
  .collection('backend_logs')
  .where('level', '==', 'ERROR')
  .where('timestamp', '>=', today)
  .orderBy('timestamp', 'desc')
  .limit(100)
  .get();
```

---

## 4. FIRESTORE QUOTA MONITORING

### Implementation

**File:** `functions/FirestoreQuotaService.js`

Automatic tracking of Firestore usage against free tier limits.

### Free Tier Limits

| Operation | Daily Limit |
|-----------|------------|
| Reads | 50,000 |
| Writes | 20,000 |
| Deletes | 20,000 |
| Storage | 1 GB |

### Alert Thresholds

- **80-90%** - Warning level
- **90-95%** - Critical level
- **95%+** - Exceeded

### Usage in Code

#### Initialize at Startup

```javascript
const quotaService = require('./FirestoreQuotaService');

// Call in a setup function
async function setupMonitoring() {
  await quotaService.initialize();
}
```

#### Track Operations

```javascript
// After a read operation
const snapshot = await db.collection('orders').get();
await quotaService.trackRead(snapshot.docs.length);

// After a write operation
await db.collection('orders').doc(orderId).set(data);
await quotaService.trackWrite(1);

// After a delete operation
await db.collection('orders').doc(orderId).delete();
await quotaService.trackDelete(1);
```

#### Get Current Usage

```javascript
// Get today's quota usage
const usage = await quotaService.getDayQuotaUsage();
console.log(`Reads: ${usage.reads} / 50000`);
console.log(`Writes: ${usage.writes} / 20000`);

// Get percentages
const percentages = await quotaService.getQuotaPercentages();
console.log(`Reads: ${percentages.reads.percent}%`);
console.log(`Writes: ${percentages.writes.percent}%`);
```

#### Generate Report

```javascript
// Get 7-day quota report
const report = await quotaService.getQuotaReport(
  new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
  new Date()
);

console.log('7-day totals:');
console.log(`Reads: ${report.totals.reads}`);
console.log(`Writes: ${report.totals.writes}`);
console.log(`Alerts: ${report.totals.alerts}`);
```

### Firestore Quota Collection

Usage is stored in `firestore_quota_metrics` collection:

```
firestore_quota_metrics/
├── quota_2026-06-22: {
│   date: "2026-06-22",
│   reads: 12543,
│   writes: 8234,
│   deletes: 452,
│   alerts: [
│     { operation: "reads", current: 40000, limit: 50000, usagePercent: 80 }
│   ],
│   createdAt: timestamp
│ }
└── quota_2026-06-23: { ... }
```

---

## 5. HEALTH CHECK ENDPOINT

### Implementation

**File:** `functions/health.js`

Provides system health status and quota metrics.

### Endpoints

#### GET /health

Returns overall system health and current quota usage.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-06-22T10:30:45Z",
  "uptime": 3600.5,
  "environment": "production",
  "firebase": {
    "project": "fufaji-online-business"
  },
  "quota": {
    "reads": {
      "used": 12543,
      "limit": 50000,
      "usage": 25,
      "status": "ok"
    },
    "writes": {
      "used": 8234,
      "limit": 20000,
      "usage": 41,
      "status": "ok"
    },
    "deletes": {
      "used": 452,
      "limit": 20000,
      "usage": 2,
      "status": "ok"
    },
    "alerts": 0
  },
  "sessionStats": {
    "reads": 1243,
    "writes": 834,
    "deletes": 23,
    "total": 2100
  },
  "checks": {
    "firestore": "ok",
    "timestamp": "ok"
  }
}
```

**Usage:**
```bash
curl https://YOUR_FIREBASE_REGION-fufaji-online-business.cloudfunctions.net/health
```

**Quota Status Legend:**
- `ok` - 0-50%
- `warning` - 50-80%
- `critical` - 80-95%
- `exceeded` - 95%+

#### GET /quota-report?days=7

Returns detailed quota usage report for specified days.

**Response:**
```json
{
  "summary": {
    "period": {
      "start": "2026-06-15",
      "end": "2026-06-22"
    },
    "days": 7,
    "totals": {
      "reads": 87802,
      "writes": 57638,
      "deletes": 3164,
      "alerts": 2
    },
    "dailyAverage": {
      "reads": 12543,
      "writes": 8234,
      "deletes": 452
    },
    "projectedDaily": {
      "reads": 627150000,
      "writes": 164680000,
      "deletes": 9040000
    },
    "alertCount": 2
  },
  "daily": [
    {
      "date": "2026-06-15",
      "reads": 11234,
      "writes": 7856,
      "deletes": 412,
      "alerts": []
    },
    // ... more days
  ]
}
```

---

## 6. ALERTS & NOTIFICATIONS

### Setting Up Alerts in Firebase Console

1. Go to **Crashlytics** dashboard
2. Click **Create Alert Policy**
3. Set thresholds:
   - Crash-free users < 95%
   - New issue type appears
   - Issue spike (>10 crashes in 1 hour)
4. Configure notification channels (Email, Slack, PagerDuty)

### Setting Up Alerts for Quota

Monitor `/quota-report` endpoint:
- If writes > 16,000/day (80%), send alert
- If reads > 40,000/day (80%), send alert
- If any alert occurs, review usage patterns

### Monitoring Via Health Endpoint

```javascript
// Check health periodically
async function monitorHealth() {
  const response = await fetch('https://YOUR_FUNCTION_URL/health');
  const health = await response.json();
  
  if (health.quota.writes.status === 'critical') {
    sendAlert('Write quota critical: ' + health.quota.writes.usage + '%');
  }
}

// Run every 6 hours
setInterval(monitorHealth, 6 * 60 * 60 * 1000);
```

---

## 7. INTEGRATION CHECKLIST

### Flutter App
- [ ] Import `analytics_service.dart` and `crashlytics_service.dart`
- [ ] Initialize Crashlytics in main.dart
- [ ] Add analytics tracking to key screens:
  - [ ] Login screen - `logLoginSuccess()`
  - [ ] Cart checkout - `logOrderCreated()`
  - [ ] Payment flow - `logPaymentInitiated()`, `logPaymentVerified()`
  - [ ] Order confirmation - `logOrderConfirmed()`
  - [ ] Packing screen - `logPackingCompleted()`
  - [ ] Delivery flow - `logDeliveryAssigned()`, `logOrderDelivered()`
  - [ ] Cancellation screen - `logOrderCancelled()`
  - [ ] Error screens - `logErrorOccurred()`
- [ ] Set user context after login
- [ ] Clear user context on logout
- [ ] Record order/payment context before sensitive operations
- [ ] Test crash reporting in debug mode

### Backend Functions
- [ ] Integrate `LoggerService` into all endpoints
- [ ] Wrap HTTP handlers with `requestLogger`
- [ ] Import `FirestoreQuotaService` and call `initialize()`
- [ ] Track reads/writes/deletes throughout code
- [ ] Export `health` endpoint
- [ ] Export `quotaReport` endpoint
- [ ] Set up monitoring dashboards
- [ ] Configure alerts
- [ ] Test health endpoint: `GET /health`
- [ ] Test quota report: `GET /quota-report?days=7`

### Dashboards to Bookmark
1. **Crashlytics:** https://console.firebase.google.com/project/YOUR_PROJECT/crashlytics
2. **Analytics:** https://console.firebase.google.com/project/YOUR_PROJECT/analytics/overview
3. **Firestore:** https://console.firebase.google.com/project/YOUR_PROJECT/firestore/data
4. **Cloud Functions:** https://console.cloud.google.com/functions

---

## 8. COMMON ISSUES & TROUBLESHOOTING

### Crash Not Reporting
- Ensure Crashlytics initialized before runApp()
- Disable collection must be false in release mode
- Check internet connectivity
- Wait 5 minutes for dashboard update

### Analytics Event Not Showing
- Firebase Analytics has up to 24-hour delay
- Check event name (must match exactly)
- Ensure user has granted analytics permission
- View in real-time via Analytics dashboard

### High Quota Usage
- Check for unnecessary reads in loops
- Batch write operations
- Use composite indexes only when needed
- Archive old data periodically
- Consider upgrading to paid plan

### Health Endpoint Not Responding
- Check Firebase project is configured
- Ensure `health.js` is deployed
- Check Cloud Logs for function errors
- Verify Firestore is accessible

---

## 9. MONITORING BEST PRACTICES

### For Frontend
1. **Never log sensitive data** - Don't track payment tokens, PINs
2. **Set context early** - Set user properties immediately after login
3. **Use breadcrumbs** - Log important milestones before errors
4. **Custom errors** - Always include order/payment IDs in errors
5. **Test in staging** - Verify monitoring works before production

### For Backend
1. **Request IDs** - Always propagate for tracing
2. **Batch operations** - Combine multiple Firestore ops
3. **Cache reads** - Don't re-read same data
4. **Log transitions** - Track state changes with duration
5. **Security events** - Log all auth failures and violations

### For Production
1. **Monitor health hourly** - Use cron job to check `/health`
2. **Review crashes daily** - Check Crashlytics dashboard
3. **Watch analytics trends** - Monitor KPIs for regressions
4. **Alert on thresholds** - Set up automated alerts for quotas
5. **Quarterly review** - Analyze monitoring data for improvements

---

## 10. NEXT STEPS

1. **Deploy monitoring services** - Push code to Firebase
2. **Add analytics tracking** - Instrument key user flows
3. **Set up dashboards** - Create custom reports
4. **Configure alerts** - Set notification channels
5. **Test thoroughly** - Verify all tracking in staging
6. **Monitor production** - Daily dashboard reviews for first 2 weeks
7. **Adjust sampling rates** - Fine-tune based on traffic patterns
8. **Document runbooks** - Create incident response procedures

---

**Last Updated:** 2026-06-22  
**Status:** Phase 2 Complete  
**Next Phase:** Incident Response & Alerting (Phase 3)
