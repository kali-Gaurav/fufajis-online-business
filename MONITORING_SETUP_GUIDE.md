# Fufaji Monitoring & Observability Setup Guide

**Date:** June 23, 2026  
**Status:** CRITICAL - Complete before production launch

---

## EXECUTIVE SUMMARY

This guide sets up comprehensive monitoring across:
1. **CloudWatch** - Lambda performance, errors, costs
2. **Sentry** - Frontend + Backend exception tracking
3. **Firestore Monitoring** - Database performance, quota usage
4. **Custom Dashboards** - Business metrics (orders, payments, delivery)

**Setup Time:** 2-3 hours  
**Cost:** Free tier sufficient for initial launch

---

## PART 1: AWS CloudWatch Setup

### 1.1 Lambda Function Monitoring

CloudWatch automatically monitors Lambda. Verify it's enabled:

```bash
AWS_REGION=ap-south-1
FUNCTION_NAME=fufaji-backend

# Check current Lambda metrics
aws cloudwatch list-metrics \
  --namespace AWS/Lambda \
  --dimensions Name=FunctionName,Value=$FUNCTION_NAME \
  --region $AWS_REGION
```

**Key metrics to watch:**
- Invocations
- Errors
- Duration
- Throttles
- ConcurrentExecutions

### 1.2 Create CloudWatch Dashboard

```bash
# Save this as create_dashboard.sh

AWS_REGION=ap-south-1
DASHBOARD_NAME="Fufaji-Production"

aws cloudwatch put-dashboard \
  --dashboard-name "$DASHBOARD_NAME" \
  --dashboard-body '{
    "widgets": [
      {
        "type": "metric",
        "properties": {
          "metrics": [
            [ "AWS/Lambda", "Invocations", { "stat": "Sum" } ],
            [ ".", "Errors", { "stat": "Sum" } ],
            [ ".", "Duration", { "stat": "Average" } ],
            [ ".", "Throttles", { "stat": "Sum" } ]
          ],
          "period": 300,
          "stat": "Average",
          "region": "'$AWS_REGION'",
          "title": "Lambda Performance"
        }
      },
      {
        "type": "metric",
        "properties": {
          "metrics": [
            [ "AWS/Lambda", "Errors", { "stat": "Sum", "dimensions": { "FunctionName": "fufaji-backend" } } ]
          ],
          "period": 60,
          "stat": "Sum",
          "region": "'$AWS_REGION'",
          "title": "Lambda Error Rate (1-min)"
        }
      }
    ]
  }' \
  --region $AWS_REGION
```

### 1.3 Create CloudWatch Alarms

```bash
# Alarm 1: High error rate
aws cloudwatch put-metric-alarm \
  --alarm-name fufaji-lambda-high-error-rate \
  --alarm-description "Alert when Lambda error rate > 5%" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:ap-south-1:YOUR_ACCOUNT_ID:fufaji-alerts \
  --dimensions Name=FunctionName,Value=fufaji-backend \
  --region ap-south-1

# Alarm 2: High duration (latency)
aws cloudwatch put-metric-alarm \
  --alarm-name fufaji-lambda-high-duration \
  --alarm-description "Alert when Lambda average duration > 5 seconds" \
  --metric-name Duration \
  --namespace AWS/Lambda \
  --statistic Average \
  --period 300 \
  --threshold 5000 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:ap-south-1:YOUR_ACCOUNT_ID:fufaji-alerts \
  --dimensions Name=FunctionName,Value=fufaji-backend \
  --region ap-south-1

# Alarm 3: Throttling
aws cloudwatch put-metric-alarm \
  --alarm-name fufaji-lambda-throttles \
  --alarm-description "Alert when Lambda is throttled" \
  --metric-name Throttles \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 60 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:ap-south-1:YOUR_ACCOUNT_ID:fufaji-alerts \
  --dimensions Name=FunctionName,Value=fufaji-backend \
  --region ap-south-1
```

### 1.4 Set Up SNS Notifications

```bash
# Create SNS topic
aws sns create-topic \
  --name fufaji-alerts \
  --region ap-south-1

# Subscribe your email
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-south-1:YOUR_ACCOUNT_ID:fufaji-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com \
  --region ap-south-1
```

---

## PART 2: Sentry Error Tracking Setup

### 2.1 Configure Sentry in Backend

Already partially configured in main.dart. Add to backend:

```javascript
// backend/src/sentry.js
const Sentry = require("@sentry/node");

const SENTRY_DSN = process.env.SENTRY_DSN;

if (SENTRY_DSN) {
  Sentry.init({
    dsn: SENTRY_DSN,
    environment: process.env.NODE_ENV || 'production',
    integrations: [
      new Sentry.Integrations.Http({ tracing: true }),
      new Sentry.Integrations.OnUncaughtException(),
      new Sentry.Integrations.OnUnhandledRejection(),
    ],
    tracesSampleRate: 0.1, // 10% sampling
    beforeSend(event, hint) {
      // Filter out health checks
      if (event.request && event.request.url.includes('/health')) {
        return null;
      }
      return event;
    },
  });
}

module.exports = Sentry;
```

### 2.2 Integrate Sentry into Express

```javascript
// backend/src/app.js
const Sentry = require('./sentry');

// After route definitions, add error handler:
app.use(Sentry.Handlers.errorHandler());

// Final fallback error handler
app.use((err, req, res, next) => {
  console.error('[Error]', err);
  res.status(500).json({
    success: false,
    error: 'internal_server_error',
    requestId: req.headers['x-request-id'] || 'unknown',
  });
});
```

### 2.3 Get Sentry DSN

1. Go to https://sentry.io
2. Create project (select Node.js)
3. Copy DSN
4. Add to AWS SSM: `/fufaji/sentry/dsn`

---

## PART 3: Firestore Monitoring

### 3.1 Enable Firestore Monitoring in Firebase Console

1. Go to Firebase Console → Fufaji project
2. Click Firestore Database
3. Navigate to "Monitoring" tab
4. Enable collection-level metrics

### 3.2 Set Up Custom Firestore Alerts

```bash
# Monitor Firestore quota usage via Cloud Functions
# Create alert if read ops > 10M/month or write ops > 1M/month

cat > firestore-quota-monitor.js << 'EOF'
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.monitorFirestoreQuota = functions.pubsub
  .schedule('every 6 hours')
  .onRun(async (context) => {
    const firestoreClient = admin.firestore();
    
    try {
      // Get collection statistics
      const stats = await firestoreClient.collection('__stats__/metadata/collections').get();
      
      console.log('Firestore Statistics:');
      stats.docs.forEach(doc => {
        const data = doc.data();
        console.log(`${doc.id}: ${data.size} documents`);
      });
      
      return null;
    } catch (error) {
      console.error('Error monitoring Firestore:', error);
      // Send alert via Sentry
      Sentry.captureException(error);
    }
  });
EOF
```

---

## PART 4: Business Metrics Dashboard

### 4.1 Track Key Metrics

Create custom Firestore collection for metrics:

```javascript
// backend/src/services/MetricsService.js
const { admin, db } = require('../firestore');

class MetricsService {
  async recordOrder(orderId, amount, status) {
    const date = new Date().toISOString().split('T')[0];
    const docRef = db().collection('metrics').doc(`orders_${date}`);
    
    await docRef.set({
      totalOrders: admin.firestore.FieldValue.increment(1),
      totalRevenue: admin.firestore.FieldValue.increment(amount),
      statusCounts: {
        [status]: admin.firestore.FieldValue.increment(1),
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  async recordPayment(paymentId, amount, status) {
    const date = new Date().toISOString().split('T')[0];
    const docRef = db().collection('metrics').doc(`payments_${date}`);
    
    await docRef.set({
      totalPayments: admin.firestore.FieldValue.increment(1),
      totalAmount: admin.firestore.FieldValue.increment(amount),
      [status]: admin.firestore.FieldValue.increment(1),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  async recordDelivery(deliveryId, distanceKm, timeMinutes) {
    const docRef = db().collection('metrics').doc('deliveries_aggregate');
    
    await docRef.set({
      totalDeliveries: admin.firestore.FieldValue.increment(1),
      avgDistanceKm: admin.firestore.FieldValue.increment(distanceKm),
      avgTimeMinutes: admin.firestore.FieldValue.increment(timeMinutes),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
}

module.exports = MetricsService;
```

### 4.2 Display in Admin Dashboard

Create a simple metrics view in admin:

```dart
// lib/screens/admin/metrics_screen.dart
// Displays:
// - Daily revenue trend
// - Payment success rate
// - Average order value
// - Delivery completion rate
// - Top products
// - Busy hours
```

---

## PART 5: Production SLOs (Service Level Objectives)

### 5.1 Define SLOs

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| API Availability | 99.9% | < 99.5% |
| API Latency (p99) | 500ms | > 750ms |
| Payment Success Rate | 99% | < 97% |
| Order Fulfillment Rate | 98% | < 95% |
| Delivery On-Time Rate | 95% | < 90% |

### 5.2 Error Budget

- **99.9% availability** = 43.2 seconds downtime/month allowed
- **99% payment success** = 1 failure per 100 transactions allowed

---

## PART 6: Monitoring Checklist

### Before Launch

- [ ] CloudWatch dashboard created and displaying metrics
- [ ] 3+ CloudWatch alarms configured (errors, latency, throttles)
- [ ] SNS topic created and email subscribed
- [ ] Sentry project created and DSN added to AWS SSM
- [ ] Sentry integrated into backend (app.js)
- [ ] Frontend Sentry DSN configured (already done in main.dart)
- [ ] Firestore monitoring enabled in Firebase Console
- [ ] Custom metrics collection created (orders, payments, deliveries)
- [ ] Admin dashboard showing real-time metrics
- [ ] SLOs documented and baseline metrics recorded

### Post-Launch (48-hour monitoring)

- [ ] Review all error logs (Sentry)
- [ ] Check Lambda duration trends (should be < 1 second)
- [ ] Verify payment success rate (target 99%+)
- [ ] Check delivery tracking accuracy
- [ ] Review customer feedback (support tickets)
- [ ] Check cost usage (Lambda, Firestore, Storage)

---

## MONITORING STACK SUMMARY

```
┌─────────────────────────────────────────────────────────────┐
│                   FUFAJI MONITORING STACK                    │
└─────────────────────────────────────────────────────────────┘

Frontend (Flutter)
├─ Sentry.captureException() [Errors]
├─ Performance metrics [Page load time, frame rate]
└─ User analytics [DAU, feature usage]
    ↓
Backend (Express/Lambda)
├─ CloudWatch [Invocations, errors, duration]
├─ Sentry [Unhandled exceptions, performance]
├─ Custom Metrics [Orders, payments, deliveries]
└─ Structured Logging [All HTTP requests, business events]
    ↓
Database (Firestore)
├─ Firebase Console [Read/write counts, latency]
├─ Firestore Rules Logging [Denied operations]
└─ Custom Metrics [Collection sizes, growth rates]
    ↓
External Services
├─ Razorpay Dashboards [Payment success rate]
├─ SendGrid Analytics [Email delivery rate]
├─ Twilio Logs [SMS delivery status]
└─ Genkit Logs [AI model responses, latency]
    ↓
Dashboard (Main Visibility)
├─ AWS CloudWatch [Infrastructure health]
├─ Sentry Dashboard [Error tracking, trends]
├─ Firebase Console [Database health]
└─ Custom Admin Dashboard [Business metrics]
```

---

## ALERTING MATRIX

| Issue | Detection Method | Alert Channel | Action |
|-------|------------------|----------------|--------|
| Lambda Errors > 5% | CloudWatch | Email + Slack | Page on-call |
| Lambda Latency > 5s | CloudWatch | Email + Slack | Check database queries |
| Payment Failure > 5% | Sentry + Metrics | Slack + Email | Check Razorpay status |
| Firestore Quota Warning | Firebase Console | Email | Scale up if needed |
| Unhandled Exception | Sentry | Email + Slack | Create incident ticket |
| API 5xx Errors | Sentry | Email + Slack | Check logs immediately |

---

## Quick Start Commands

```bash
# Deploy monitoring
cd scripts
chmod +x *.sh

# 1. Setup AWS SSM parameters
./setup_aws_ssm_parameters.sh

# 2. Create CloudWatch alarms (update SNS ARN first)
aws cloudwatch put-metric-alarm \
  --alarm-name fufaji-lambda-errors \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --region ap-south-1

# 3. Get Sentry DSN from Sentry Console
# https://sentry.io/auth/login/

# 4. Verify all systems connected
curl https://<lambda-url>/health
echo "✅ Lambda is responding"
```

---

## Success Criteria

✅ You'll know monitoring is working when:
1. CloudWatch dashboard shows Lambda metrics in real-time
2. First error in Sentry (test via: `throw new Error('test')` in backend)
3. Email received when Lambda errors spike
4. Admin dashboard shows order/payment metrics
5. Mobile app shows errors in Sentry dashboard

---

**Setup Time:** 2-3 hours  
**Cost:** Essentially free (CloudWatch Free Tier + Sentry Free Plan)  
**Maintenance:** 30 mins/week to review alerts and metrics  

**Status:** Ready for production launch once completed ✅
