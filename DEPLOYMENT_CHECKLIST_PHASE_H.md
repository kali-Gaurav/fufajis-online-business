# Phase H Deployment Checklist

**Phase**: Production Launch Readiness  
**Date**: 2026-07-04  
**Status**: Pre-Deployment

---

## ✅ PRE-DEPLOYMENT VERIFICATION

### Database
- [ ] Run migration: `psql $DATABASE_URL < supabase/migrations/phase_h_critical_fixes_20260704.sql`
- [ ] Verify all tables created: `SELECT * FROM information_schema.tables WHERE table_schema = 'public';`
- [ ] Verify order_status ENUM exists: `SELECT typname FROM pg_type WHERE typname = 'order_status_enum';`
- [ ] Verify indexes exist: `SELECT * FROM pg_indexes WHERE tablename = 'orders';`
- [ ] Backup database before migration: `pg_dump $DATABASE_URL > backup_pre_phase_h.sql`

### Edge Function
- [ ] Deploy: `supabase functions deploy order-lifecycle`
- [ ] Verify deployment: `curl https://<supabase-url>/functions/v1/order-lifecycle/health`
- [ ] Expected response: `{ "status": "healthy" }`

### Environment Variables
- [ ] Set in Supabase Edge Function secrets:
  - `SUPABASE_URL` ✓ (auto-set)
  - `SUPABASE_SERVICE_ROLE_KEY` ✓ (auto-set)

### Flutter App
- [ ] Merge PR: `refactor: order lifecycle → Supabase Edge Functions`
- [ ] Bump version: `pubspec.yaml` (e.g., 1.2.3 → 1.2.4)
- [ ] Run tests: `flutter test`
- [ ] Build APK: `flutter build apk --release`
- [ ] Upload to Play Store internal testing

### Firestore Webhook
- [ ] Verify `sync-to-firestore` webhook is active in Supabase
- [ ] Test webhook: Create order in PostgreSQL, check Firestore syncs within 2s
- [ ] Monitor logs: `supabase functions logs sync-to-firestore`

---

## 🚀 DEPLOYMENT STEPS

### Step 1: Database Migration (5 min)
```bash
# 1a. Connect to Supabase
export DATABASE_URL="postgresql://..."

# 1b. Backup
pg_dump $DATABASE_URL > backups/before_phase_h.sql

# 1c. Run migration
psql $DATABASE_URL < supabase/migrations/phase_h_critical_fixes_20260704.sql

# 1d. Verify
psql $DATABASE_URL -c "SELECT COUNT(*) FROM order_audit_logs;"
```

### Step 2: Deploy Edge Function (3 min)
```bash
# 2a. Navigate to repo
cd /path/to/fufaji-online-business

# 2b. Deploy
supabase functions deploy order-lifecycle

# 2c. Test health endpoint
curl -H "Authorization: Bearer $JWT_TOKEN" \
  https://<your-supabase-url>/functions/v1/order-lifecycle/health
```

### Step 3: Deploy Flutter App (15 min)
```bash
# 3a. Build release APK
flutter build apk --release

# 3b. Sign APK (if not already signed)
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 \
  -keystore <keystore-file> \
  build/app/outputs/apk/release/app-release.apk <key-alias>

# 3c. Upload to Play Store Console
# Internal Testing Track → Choose APK

# 3d. Announce testing to QA team
```

### Step 4: Smoke Tests (10 min)
```bash
# 4a. Test health endpoint
curl https://<supabase-url>/functions/v1/order-lifecycle/health

# 4b. Test /process-checkout (use test JWT)
curl -X POST https://<supabase-url>/functions/v1/order-lifecycle \
  -H "Authorization: Bearer $TEST_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "path": "/process-checkout",
    "idempotencyKey": "smoke-test-1",
    "shopId": "primary",
    "items": [{"productId": "test-1", "quantity": 1}],
    "deliveryAddress": {"latitude": 28.6, "longitude": 77.2},
    "deliveryType": "sameDay",
    "paymentMethod": "upi"
  }'

# 4c. Monitor logs
supabase functions logs order-lifecycle --limit 20
```

### Step 5: Monitor & Validate (Ongoing)
```bash
# 5a. Watch Edge Function logs (live)
supabase functions logs order-lifecycle --follow

# 5b. Check Firestore syncs
# Supabase Dashboard → Database → Webhooks → Verify execution logs

# 5c. Alert on errors
# Set up Sentry / Datadog to catch Edge Function errors
```

---

## ⚠️ ROLLBACK PLAN

If critical issues arise in first 2 hours:

### Immediate Rollback (5 min)
```bash
# 1. Disable Edge Function (stop routing from app)
# Edit lib/services/order_service.dart:
#   Revert to using FirebaseFunctions.instance instead of SupabaseConfig

# 2. Revert Flutter app
# Push hotfix: git checkout main lib/services/order_service.dart
# Rebuild & release to internal testers

# 3. Restore Firebase functions (if needed)
cd functions/
git checkout src/processCheckout.js src/changeOrderStatus.js # etc
firebase deploy --only functions
```

### Database Rollback (if migration fails)
```bash
# Restore from backup
psql $DATABASE_URL < backups/before_phase_h.sql
```

---

## 📊 MONITORING & ALERTS

### Set up Supabase Monitoring
1. **Logs**: Supabase Dashboard → Logs → Filter by `order-lifecycle`
2. **Query Performance**: Check slow queries on `orders` table
3. **Webhook Status**: Dashboard → Database → Webhooks → Check execution status

### Key Metrics to Watch
| Metric | Threshold | Alert |
|--------|-----------|-------|
| Edge Function latency (p95) | < 500ms | Slack alert if > 1000ms |
| Error rate | < 0.1% | Slack alert if > 1% |
| Firestore sync delay | < 2s | Slack alert if > 5s |
| OTP verification success | > 99% | Slack alert if < 95% |
| Checkout success rate | > 98% | Slack alert if < 95% |

### Sentry Integration (Optional)
```typescript
// Add to order-lifecycle/index.ts
import * as Sentry from 'https://deno.land/x/sentry/index.ts';

Sentry.init({
  dsn: Deno.env.get('SENTRY_DSN'),
  environment: Deno.env.get('ENVIRONMENT') || 'production',
});
```

---

## ✅ POST-DEPLOYMENT (After 24h of monitoring)

- [ ] Zero critical errors logged
- [ ] Firestore syncs working (100% success)
- [ ] OTP verification pass rate > 99%
- [ ] Order creation latency p95 < 500ms
- [ ] All tests passing in staging
- [ ] QA sign-off from team
- [ ] Delete old Firebase Cloud Functions:
  ```bash
  rm functions/src/{changeOrderStatus,dispatchCluster,verifyDeliveryOtp,cancelOrder,failOrderDelivery,resolveDeliveryException}.js
  firebase deploy --only functions
  ```

---

## 📞 SUPPORT CONTACTS

| Role | Contact | Escalation Path |
|------|---------|-----------------|
| Database Issues | DBA | Escalate to Supabase support |
| Edge Function Errors | Backend Lead | Check logs, restart function |
| Flutter App Crashes | Mobile Lead | Revert to last working build |
| Payment Failures | Payments Lead | Check Razorpay webhook logs |

---

## 🔔 COMMUNICATION PLAN

### During Deployment
1. **T-0:30**: Notify QA: "Deploying Phase H in 30 minutes"
2. **T-0:00**: Disable new orders (optional maintenance window)
3. **T+0:15**: Database migration complete
4. **T+0:20**: Edge Function deployed
5. **T+0:30**: Flutter app released to testers
6. **T+1:00**: Reopen orders, monitor

### If Issues Arise
1. **Slack alert** to #fufaji-alerts
2. **Page on-call engineer** if error rate > 5%
3. **Initiate rollback** if p99 latency > 3s

---

## ✨ SUCCESS CRITERIA

Phase H is complete when:

✅ All 3 critical issues fixed  
✅ processCheckout migrated to Supabase  
✅ releaseExpiredReservations implemented  
✅ Database schema hardened (ENUM, CHECK, audit)  
✅ Webhook reliability improved (outbox events)  
✅ Zero Firebase Cloud Functions for transactions  
✅ Tests pass (unit + E2E)  
✅ Deployment completed with zero rollbacks  
✅ 24h monitoring shows green metrics  

---

**Last Updated**: 2026-07-04  
**Next Phase**: H.2 — Ray Optimization & Query Performance
