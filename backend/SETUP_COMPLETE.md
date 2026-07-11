# 🚀 Backend Setup Complete - Production Ready

This document guides you through setting up the complete backend infrastructure with Supabase, Render, and Firestore integration.

## 📋 Checklist

### Phase 1: Database Schema (Supabase)

- [ ] **Step 1**: Go to [Supabase Dashboard](https://app.supabase.com)
- [ ] **Step 2**: Select your project `fufajis-online-business`
- [ ] **Step 3**: Open **SQL Editor** → **New Query**
- [ ] **Step 4**: Copy & run these migrations in order:

```sql
-- Run each migration in Supabase SQL Editor
-- 1. Copy contents of backend/migrations/001_create_subscriptions_schema.sql
-- 2. Copy contents of backend/migrations/002_create_commissions_schema.sql
-- 3. Copy contents of backend/migrations/003_create_delivery_schema.sql
-- 4. Copy contents of backend/migrations/004_create_cron_functions.sql
```

✅ **Verification**:
```sql
-- Check tables created
\dt subscriptions
\dt vendor_commissions
\dt delivery_tracking
\dt riders
```

---

### Phase 2: Cron Jobs (Supabase)

- [ ] **Step 1**: Verify `pg_cron` extension is installed
  ```sql
  SELECT * FROM pg_extension WHERE extname = 'pg_cron';
  ```

- [ ] **Step 2**: In **SQL Editor**, run `backend/setup-supabase-cron.sql`

- [ ] **Step 3**: Verify cron jobs
  ```sql
  SELECT * FROM cron.job;
  ```

**Cron Jobs Scheduled**:
- ✅ `process_due_subscriptions` - Daily 00:00 UTC
- ✅ `calculate_daily_commissions` - Daily 01:00 UTC
- ✅ `cleanup_expired_reservations` - Every 30 minutes
- ✅ `reconcile_stale_payments` - Every hour

---

### Phase 3: Database Webhooks (Supabase)

- [ ] **Step 1**: In **SQL Editor**, run `backend/setup-supabase-webhooks.sql`

- [ ] **Step 2**: Verify triggers created
  ```sql
  SELECT trigger_name FROM information_schema.triggers
  WHERE table_name IN ('orders', 'subscriptions', 'delivery_tracking');
  ```

**Webhooks Configured**:
- ✅ `order_sync_trigger` → Firestore sync
- ✅ `subscription_sync_trigger` → Firestore sync
- ✅ `delivery_tracking_sync_trigger` → Real-time tracking
- ✅ `product_inventory_sync_trigger` → Stock updates
- ✅ `vendor_commission_sync_trigger` → Commission tracking

---

### Phase 4: Render Environment Variables

- [ ] **Step 1**: Go to [Render Dashboard](https://dashboard.render.com)

- [ ] **Step 2**: Select service `fufajis-online-business-backend`

- [ ] **Step 3**: Click **Environment** tab

- [ ] **Step 4**: Copy all variables from `backend/.env.render` and paste into Render

```bash
# Key variables to set:
NODE_ENV=production
PORT=3001
API_BASE_URL=https://fufajis-online-business.onrender.com

# Database
DATABASE_URL=postgresql://...
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=...

# Payment
RAZORPAY_KEY_ID=rzp_live_...
RAZORPAY_KEY_SECRET=...

# Firebase
FIREBASE_SERVICE_ACCOUNT={...}

# Communications
WHATSAPP_TOKEN=...
TWILIO_ACCOUNT_SID=...
```

✅ **Verification**: Test endpoint
```bash
curl https://fufajis-online-business.onrender.com/health
```

Expected response:
```json
{"success": true, "status": "ok", "ts": 1657891234567}
```

---

### Phase 5: Test Endpoints

- [ ] **Step 1**: Install dependencies
  ```bash
  cd backend
  npm install
  ```

- [ ] **Step 2**: Run test suite (local)
  ```bash
  node test-endpoints.js --base-url=http://localhost:3001
  ```

- [ ] **Step 3**: Run against Render
  ```bash
  node test-endpoints.js --base-url=https://fufajis-online-business.onrender.com
  ```

**Tests Include**:
- ✅ Health check
- ✅ Configuration endpoint
- ✅ Subscription lifecycle (create, list, pause, resume, cancel)
- ✅ Commission queries (pending, ledger, stats)
- ✅ Delivery dispatch (find riders, assign, track, complete)

---

## 🔌 API Endpoints Summary

### Subscriptions
```
POST   /subscriptions/create           → Create recurring subscription
GET    /subscriptions                  → List customer subscriptions
GET    /subscriptions/:id              → Get subscription details
POST   /subscriptions/:id/pause        → Pause subscription
POST   /subscriptions/:id/resume       → Resume subscription
POST   /subscriptions/:id/cancel       → Cancel subscription
POST   /subscriptions/process          → Process due (cron job)
```

### Commissions
```
GET    /commissions/pending            → Get pending commissions
GET    /commissions/ledger             → Commission history
GET    /commissions/stats              → Dashboard stats
POST   /commissions/mark-paid          → Mark as paid (admin)
```

### Delivery
```
POST   /dispatch/find-riders           → Find nearby riders
POST   /dispatch/assign                → Assign order to rider
POST   /dispatch/unassign              → Unassign order
GET    /dispatch/optimize-route        → Get best route
POST   /dispatch/update-location       → Update rider location
POST   /dispatch/verify-otp            → Verify delivery OTP
POST   /dispatch/complete              → Complete delivery
GET    /dispatch/track/:orderId        → Track delivery (customer)
```

### Configuration
```
GET    /health                         → Server health check
GET    /config/app-config              → App configuration
```

---

## 🔐 Security Configuration

### Row-Level Security (RLS)

All tables have RLS enabled:
- ✅ Customers can only view their own data
- ✅ Vendors can only view their commissions
- ✅ Riders can only view their deliveries

### Secrets Management

Use **Supabase Vault** for sensitive data:
```sql
-- Store in Vault
INSERT INTO vault.secrets (name, secret)
VALUES 
  ('razorpay_key_secret', 'your-secret'),
  ('firebase_service_account', '{...}'),
  ('whatsapp_token', '...');

-- Retrieve in code
SELECT decrypted_secret FROM vault.decrypted_secrets
WHERE name = 'razorpay_key_secret';
```

### Environment Variables

**Production** (Render):
- Set in Render Dashboard → Environment tab
- Never commit `.env` file with secrets

**Development** (Local):
- Copy `.env.render` to `.env`
- Add your test values
- Never commit to git

---

## 📊 Monitoring & Logging

### Check Cron Job Execution

```sql
-- View cron job logs
SELECT 
  jobid, 
  jobname, 
  command,
  last_successful_run,
  last_run,
  last_run_success
FROM cron.job_run_details
ORDER BY last_run DESC;
```

### Monitor Firestore Sync Queue

```sql
-- Check pending sync events
SELECT 
  id, table_name, operation, status, retry_count, created_at
FROM firestore_sync_queue
WHERE status IN ('pending', 'failed')
ORDER BY created_at DESC;

-- Retry failed syncs
UPDATE firestore_sync_queue
SET status = 'pending', retry_count = 0
WHERE status = 'failed' AND retry_count < 3;
```

### View Logs

```bash
# Render logs
render logs --service=fufajis-online-business-backend --tail

# Or via dashboard
# https://dashboard.render.com → Your Service → Logs
```

---

## 🚨 Troubleshooting

### "Cron jobs not executing"

**Check**:
```sql
-- Verify pg_cron is installed
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Check cron job status
SELECT * FROM cron.job WHERE jobname = 'process_due_subscriptions';
```

### "Firestore sync not working"

**Check**:
1. Verify webhook triggers exist:
   ```sql
   SELECT * FROM pg_trigger WHERE tgname LIKE '%sync%';
   ```

2. Check sync queue:
   ```sql
   SELECT COUNT(*) FROM firestore_sync_queue WHERE status = 'failed';
   ```

3. Verify backend endpoint is reachable:
   ```bash
   curl https://fufajis-online-business.onrender.com/health
   ```

### "Commission calculation missing"

**Check**:
1. Verify function exists:
   ```sql
   \df calculate_daily_commissions
   ```

2. Test function:
   ```sql
   SELECT * FROM calculate_daily_commissions();
   ```

3. Check if orders have `commission_status`:
   ```sql
   SELECT COUNT(*) FROM orders WHERE commission_status IS NULL;
   ```

---

## 📈 Next Steps

1. **Connect Flutter App**
   - Update API base URL in `lib/config/app_config.dart`
   - Initialize subscription stream in app startup
   - Test checkout flow end-to-end

2. **Enable Analytics**
   - Set up Firebase Analytics
   - Track subscription events
   - Monitor commission calculations

3. **Set Up Monitoring**
   - Configure Sentry for error tracking
   - Set up alerts for failed payments
   - Monitor Render uptime

4. **Production Deployment**
   - Run security audit
   - Load test endpoints
   - Set up backup strategy
   - Configure disaster recovery

---

## 📞 Support

For issues or questions:
1. Check troubleshooting section above
2. Review Supabase docs: https://supabase.com/docs
3. Review Render docs: https://render.com/docs
4. Check backend logs: `render logs --service=...`

---

**Status**: ✅ Production Ready  
**Last Updated**: 2026-07-11  
**Version**: 1.0.0
