# Razorpay Webhook Deployment Checklist

Quick reference for deploying the payment webhook system to production.

## Pre-Deployment (Preparation)

- [ ] Review `PAYMENT_WEBHOOK_SETUP.md` completely
- [ ] Review `WEBHOOK_IMPLEMENTATION_SUMMARY.md`
- [ ] Backup current Firebase configuration
- [ ] Backup current Firestore data
- [ ] Test in development/staging first
- [ ] Have Razorpay credentials ready
- [ ] Have Firebase project access ready

## Development Setup

- [ ] Clone/pull latest code
- [ ] Verify all files present:
  - [ ] `functions/src/webhooks/razorpay_webhook.ts`
  - [ ] `functions/src/tasks/process_payment_retries.ts`
  - [ ] `functions/src/types/webhook.types.ts`
  - [ ] `functions/src/utils/webhook_utils.ts`
  - [ ] `functions/firestore.rules`
  - [ ] `functions/test/webhooks/razorpay_webhook.test.ts`
  - [ ] `functions/.env.example`
  - [ ] `functions/src/index.ts` (updated)

- [ ] Install dependencies: `cd functions && npm install`
- [ ] Create `.env` file: `cp .env.example .env`
- [ ] Edit `.env` with your credentials:
  - [ ] `RAZORPAY_API_KEY`
  - [ ] `RAZORPAY_API_SECRET`
  - [ ] `RAZORPAY_WEBHOOK_SECRET`
  - [ ] `NODE_ENV=development` (for testing)

- [ ] Run tests: `npm test`
- [ ] Verify all tests pass
- [ ] Build TypeScript: `npm run build` (if configured)

## Staging Deployment

- [ ] Set `NODE_ENV=staging` in `.env`
- [ ] Deploy functions: `firebase deploy --only functions --project staging-project`
- [ ] Deploy rules: `firebase deploy --only firestore:rules --project staging-project`
- [ ] Get staging webhook URL from Firebase Console
- [ ] Add webhook in Razorpay **Test Mode**:
  - [ ] URL: Your staging function URL
  - [ ] Events: payment.authorized, payment.captured, payment.failed
  - [ ] Copy webhook secret to `.env`
  - [ ] Test webhook delivery

- [ ] Test payment flow:
  - [ ] Create test order
  - [ ] Initiate Razorpay payment (test mode)
  - [ ] Complete payment
  - [ ] Verify webhook received: `firebase functions:log --filter="razorpay_webhook"`
  - [ ] Verify order status updated in Firestore
  - [ ] Check webhook_logs collection for entry
  
- [ ] Test failure flow:
  - [ ] Initiate payment with test card that fails
  - [ ] Verify payment.failed webhook received
  - [ ] Verify retry entry created in payment_retry_queue
  - [ ] Wait 5 minutes for Cloud Scheduler to process
  - [ ] Verify retry logged in payment_retry_audit

- [ ] Monitor for 24 hours
- [ ] Check logs regularly: `firebase functions:log`
- [ ] Verify Firestore collections growing correctly

## Production Deployment

### Pre-Flight Checks

- [ ] All staging tests passed
- [ ] Logs reviewed and clean
- [ ] No errors in function logs
- [ ] Team approval obtained
- [ ] Backup created

### Deploy to Production

- [ ] Set `NODE_ENV=production` in `.env`
- [ ] Update `.env` with production credentials (if different)
  - [ ] Production `RAZORPAY_API_KEY`
  - [ ] Production `RAZORPAY_API_SECRET`
  - [ ] Production `RAZORPAY_WEBHOOK_SECRET`

- [ ] Deploy functions:
  ```bash
  firebase deploy --only functions --project fufaji-store
  ```
  - [ ] Verify deployment successful
  - [ ] No errors in deploy log

- [ ] Deploy Firestore rules:
  ```bash
  firebase deploy --only firestore:rules --project fufaji-store
  ```
  - [ ] Verify rules deployed
  - [ ] Rules take effect immediately

- [ ] Get production webhook URL from Firebase Console

### Razorpay Configuration

- [ ] Go to [Razorpay Dashboard](https://dashboard.razorpay.com)
- [ ] Navigate to Settings > Webhooks
- [ ] Click "Add New Webhook"
- [ ] Enter webhook URL from Firebase
- [ ] Select events:
  - [ ] payment.authorized
  - [ ] payment.captured
  - [ ] payment.failed
- [ ] Copy webhook signing secret
- [ ] Update `RAZORPAY_WEBHOOK_SECRET` in production `.env`
- [ ] Save webhook configuration
- [ ] Test webhook in Razorpay (send test event)
- [ ] Verify webhook received in logs: `firebase functions:log --filter="razorpay_webhook"`

### Cloud Scheduler Verification

- [ ] Go to [Google Cloud Console](https://console.cloud.google.com)
- [ ] Navigate to Cloud Scheduler
- [ ] Find `processPaymentRetries` job
- [ ] Verify job is enabled
- [ ] Check schedule: "every 5 minutes"
- [ ] Verify target is correct function

### Dart App Updates

- [ ] Update `lib/models/order_model.dart`:
  - [ ] Add `paymentStatus` field
  - [ ] Add `paymentConfirmed` field
  - [ ] Add `razorpayPaymentId` field
  - [ ] Add `paymentAmount` field
  - [ ] Add `paymentConfirmedAt` field

- [ ] Update `lib/services/payment_router_service.dart`:
  - [ ] Webhook endpoint ready
  - [ ] Payment flow updated
  - [ ] Error handling updated

- [ ] Test payment flow in app
- [ ] Deploy app update to Play Store/App Store

### Production Verification

- [ ] Create test order in production
- [ ] Initiate test payment with Razorpay
- [ ] Monitor webhook logs: `firebase functions:log --filter="razorpay_webhook" --tail`
- [ ] Verify order updated with payment status
- [ ] Check webhook_logs collection
- [ ] Verify signatures valid: `signatureValid == true`

### Error Scenarios (Test in Production)

- [ ] Failed payment:
  - [ ] Create order
  - [ ] Initiate payment with failing card
  - [ ] Verify payment.failed webhook received
  - [ ] Verify retry entry created
  - [ ] Wait for retry processor to run (next 5-minute mark)
  - [ ] Check retry logs in payment_retry_audit

- [ ] Duplicate webhook:
  - [ ] Send same webhook twice (simulate network retry)
  - [ ] Verify second webhook skipped (duplicate)
  - [ ] Check logs show idempotency check

- [ ] Invalid signature:
  - [ ] Send webhook with wrong signature
  - [ ] Verify logged but not processed
  - [ ] Check webhook_logs shows `signatureValid: false`

### Monitoring Setup

- [ ] Set up log alerts in Firebase Console
- [ ] Monitor for errors: `ERROR` in logs
- [ ] Monitor payment failures: `payment.failed` events
- [ ] Monitor retry queue: `SELECT * FROM payment_retry_queue WHERE status='pending'`

- [ ] Set up Firestore triggers (optional):
  - [ ] Alert if payment_retry_queue grows too large
  - [ ] Alert if webhook_logs has many failures

- [ ] Daily checks:
  - [ ] Review webhook logs
  - [ ] Check retry queue emptiness
  - [ ] Verify no errors in function logs

### Post-Deployment

- [ ] Enable payment option in app for users
- [ ] Announce payment integration to users
- [ ] Monitor for 7 days continuously
- [ ] Check logs every 6 hours during first week
- [ ] Verify no payment failures
- [ ] Verify retry processor running

### Documentation

- [ ] Update README with webhook info
- [ ] Document webhook URL in team wiki
- [ ] Add Razorpay config to team documentation
- [ ] Create runbook for troubleshooting
- [ ] Share checklist with team

### Rollback Plan (If Needed)

- [ ] Firebase has automatic backups
- [ ] Delete webhook from Razorpay to stop new events
- [ ] Disable functions if critical issues:
  ```bash
  firebase functions:delete razorpayWebhook
  firebase functions:delete processPaymentRetries
  ```
- [ ] Revert Firestore rules to previous version
- [ ] Revert Dart app deployment if app-side changes broke

## Daily Monitoring

After deployment, check daily for first week:

```bash
# Check for errors
firebase functions:log --filter="ERROR" --tail

# Check webhook processing
firebase functions:log --filter="razorpay_webhook" --limit 50

# Check retry processor
firebase functions:log --filter="process_payment_retries" --limit 50

# Firestore queries
# Pending retries
db.collection('payment_retry_queue')
  .where('status', '==', 'pending')
  .get()

# Failed webhooks
db.collection('webhook_logs')
  .where('processed', '==', false)
  .get()

# Wallet fallbacks
db.collection('payment_retry_audit')
  .where('status', '==', 'wallet_deduction')
  .get()
```

## Weekly Review (First Month)

- [ ] Review webhook logs for patterns
- [ ] Check if any retries failed permanently
- [ ] Verify retry processor running consistently
- [ ] Review error logs for recurring issues
- [ ] Verify no data integrity issues
- [ ] Check performance metrics

## Success Criteria

- [ ] ✅ All webhooks received and processed
- [ ] ✅ Signature validation passing
- [ ] ✅ Orders updating with payment status
- [ ] ✅ Retries processing correctly
- [ ] ✅ No duplicate payments
- [ ] ✅ No errors in logs
- [ ] ✅ All tests passing
- [ ] ✅ Firestore rules protecting data

## Emergency Contacts

- [ ] Firebase Support: [Firebase Support](https://firebase.google.com/support)
- [ ] Razorpay Support: [Razorpay Support](https://razorpay.com/support)
- [ ] Team Lead: [Your Name/Contact]

## Sign-Off

- [ ] Deployment Date: _______________
- [ ] Deployed By: _______________
- [ ] Verified By: _______________
- [ ] Status: _____ READY / _____ PENDING / _____ ROLLED BACK

---

**Note:** Keep this checklist for future reference. Update it as you learn from production deployment.
