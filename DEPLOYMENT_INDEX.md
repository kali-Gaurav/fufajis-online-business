# DEPLOYMENT INDEX: Tasks #19, #20, #21

## Quick Navigation

**Just getting started?** → Start with [QUICK_REFERENCE_TASKS_19_20_21.md](QUICK_REFERENCE_TASKS_19_20_21.md)

**Need detailed steps?** → Read [DEPLOYMENT_TASKS_19_20_21.md](DEPLOYMENT_TASKS_19_20_21.md)

**Executive summary?** → See [TASKS_19_20_21_SUMMARY.txt](TASKS_19_20_21_SUMMARY.txt)

**Ready to verify?** → Run [verify-deployment-19-20-21.sql](verify-deployment-19-20-21.sql)

---

## Deployment Documents

### 📋 QUICK_REFERENCE_TASKS_19_20_21.md
**Best for:** Quick lookup, one-liner commands, troubleshooting
- One-line summary of each task
- Quick deploy commands
- Environment variables reference
- Bucket details table
- Quick testing procedures
- File locations

**Read this if:** You've deployed before or just need a refresher

### 📘 DEPLOYMENT_TASKS_19_20_21.md
**Best for:** Complete walkthrough, first-time deployment, detailed verification
- Full background on each task
- Step-by-step deployment (1-7 steps per task)
- Detailed verification queries
- SQL examples with expected output
- Troubleshooting with solutions
- Rollback procedures
- Post-deployment checklist

**Read this if:** This is your first deployment or you want detailed explanations

### 📄 TASKS_19_20_21_SUMMARY.txt
**Best for:** Project overview, architecture diagram, stakeholder updates
- Executive summary
- What was changed in code
- Prerequisites checklist
- Architecture diagram
- Performance notes
- Next tasks (22-26)
- Deployment checklist

**Read this if:** You need to brief others or understand the full scope

### 🔍 verify-deployment-19-20-21.sql
**Best for:** Testing and verification after deployment
- SQL queries organized by task
- Expected output documented
- Pre/post deployment verification
- Cleanup queries (rollback only)

**Run this if:** You need to verify deployment succeeded

---

## Deployment Scripts

### deploy-tasks-19-20-21.ps1 (PowerShell)
```bash
# Run from C:\Projects\fufaji-online-business\
.\deploy-tasks-19-20-21.ps1 `
  -FirebaseServiceAccountPath "C:\path\to\serviceAccount.json" `
  -RazorpayWebhookSecret "your-secret"
```

**What it does:**
- Checks prerequisites
- Validates files exist
- Provides manual command instructions
- Shows deployment summary

### deploy-tasks-19-20-21.sh (Bash)
```bash
# Run from project directory
./deploy-tasks-19-20-21.sh \
  --firebase-path ~/fufaji-service-account.json \
  --razorpay-secret your-secret
```

**What it does:** Same as PowerShell version, for Linux/Mac

---

## Code Changes

### Files Modified (Code-Only)
1. **supabase/functions/_shared/firebase-bridge.ts**
   - Added `syncPaymentToFirestore(paymentId, data)` 
   - Added `syncOrderToFirestore(orderId, data)`
   - Added default export
   - Returns boolean instead of throwing

2. **supabase/functions/razorpay-webhook-dual-write/index.ts**
   - Fixed import: `import firebaseBridge from "../_shared/firebase-bridge.ts"`
   - No other changes needed

### Files Already Ready (No Changes)
- `supabase/migrations/04_storage_buckets_firestore_sync.sql` ✅
- `supabase/functions/_shared/firebase-bridge.ts` ✅
- `supabase/functions/razorpay-webhook-dual-write/index.ts` ✅

---

## Deployment Flow

```
                    ┌─────────────────────┐
                    │   GET CREDENTIALS   │
                    │ Firebase SA + RPay  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   TASK #19: Deploy  │
        ┌──────────▶│  Firebase Bridge    │
        │          └──────────┬──────────┘
        │                     │
    Task #21            ┌─────▼──────────┐
    depends on          │  TASK #20: Deploy
    Task #19           │  Storage Buckets│
                       └──────────┬──────┘
                                  │
                       ┌──────────▼──────────┐
                       │   TASK #21: Deploy  │
                       │  Razorpay Webhook  │
                       └──────────┬──────────┘
                                  │
                       ┌──────────▼──────────┐
                       │    VERIFICATION    │
                       │  Run SQL Queries   │
                       │  Test Webhook      │
                       └────────────────────┘
```

---

## Deployment Sequence

### Phase 1: Setup (5 minutes)
1. Get Firebase service account JSON from Firebase Console
2. Get Razorpay webhook secret from Razorpay Dashboard
3. Ensure Supabase CLI is installed: `supabase --version`
4. Login to Supabase: `supabase login`

### Phase 2: Task #19 (5 minutes)
```bash
# Set Firebase secret
supabase secrets set FIREBASE_SERVICE_ACCOUNT $(cat ~/fufaji-service-account.json)

# Verify
supabase secrets list

# Deploy
supabase functions deploy _shared/firebase-bridge

# Check logs
# Console → Edge Functions → _shared/firebase-bridge → Logs
```

### Phase 3: Task #20 (5 minutes)
```bash
# Deploy migration
cd supabase
supabase db push

# Verify
# Run verify-deployment-19-20-21.sql queries
```

### Phase 4: Task #21 (5 minutes)
```bash
# Set Razorpay secret
supabase secrets set RAZORPAY_WEBHOOK_SECRET "your-secret"

# Deploy
supabase functions deploy razorpay-webhook-dual-write

# Configure in Razorpay (manual, 2 minutes)
# Dashboard → Settings → Webhooks → Add Webhook
```

### Phase 5: Verification (5 minutes)
```bash
# Run SQL verification queries
# Test storage bucket upload
# Test payment webhook with sample payment
```

**Total Time: ~25 minutes**

---

## Task Details

### Task #19: Firebase Bridge
| Aspect | Details |
|--------|---------|
| What | Shared library for Firebase operations |
| Where | `supabase/functions/_shared/firebase-bridge.ts` |
| Exports | `verifyFirebaseToken()`, `syncToFirestore()`, `syncPaymentToFirestore()`, `syncOrderToFirestore()` |
| Used by | Task #21 webhook |
| Status | ✅ Ready |

### Task #20: Storage Buckets
| Aspect | Details |
|--------|---------|
| What | PostgreSQL migration creating storage buckets |
| Where | `supabase/migrations/04_storage_buckets_firestore_sync.sql` |
| Creates | 4 buckets, 6 RLS policies, 3 functions, 1 table, 1 view |
| Buckets | product-images (public), customer-documents, order-receipts, delivery-proofs (private) |
| Status | ✅ Ready |

### Task #21: Razorpay Webhook
| Aspect | Details |
|--------|---------|
| What | Edge Function handling Razorpay payment webhooks |
| Where | `supabase/functions/razorpay-webhook-dual-write/index.ts` |
| Endpoint | `https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/razorpay-webhook-dual-write` |
| Method | POST (webhook receiver, not REST API) |
| Auth | HMAC-SHA256 signature verification |
| Events | payment.authorized, payment.failed, payment.completed |
| Dual-Write | PostgreSQL (source of truth) + Firestore (real-time app) |
| Status | ✅ Ready |

---

## Environment Setup

### Secrets to Set (in Supabase Dashboard)
```
Settings → Secrets

FIREBASE_SERVICE_ACCOUNT = {full JSON from Firebase Console}
RAZORPAY_WEBHOOK_SECRET = "webhook-secret-from-razorpay"
SUPABASE_URL = (already set)
SUPABASE_SECRET_KEY = (already set)
```

### Credentials Needed
- **Firebase:** Service Account private key (JSON)
  - Get from: Firebase Console → Project Settings → Service Accounts → Generate Key
  - Keep secure: Only DevOps/Infrastructure should have access

- **Razorpay:** Webhook Secret
  - Get from: Razorpay Dashboard → Settings → Webhooks
  - Used for HMAC signature verification
  - Not the same as API key or secret

---

## Verification Steps

### Quick Check (2 min)
1. Supabase Console → Edge Functions → Both functions deployed
2. Supabase Console → Secrets → Both secrets set
3. Supabase Console → Storage → 4 buckets visible

### SQL Verification (5 min)
Run queries from `verify-deployment-19-20-21.sql`:
- Check storage buckets exist
- Check RLS policies created
- Check storage_references table exists
- Check helper functions exist

### Functional Test (5 min)
1. Upload test image to product-images bucket
2. Verify public read access (no auth needed)
3. Create test order and test payment
4. Verify payment_transactions record created
5. Verify order status updated to "confirmed"

---

## Troubleshooting Quick Links

| Problem | Solution |
|---------|----------|
| Firebase initialization fails | See DEPLOYMENT_TASKS_19_20_21.md → Troubleshooting → Firebase Admin SDK |
| Storage bucket already exists | Normal (idempotent) - migration skips existing buckets |
| Webhook signature fails | Verify RAZORPAY_WEBHOOK_SECRET matches Razorpay dashboard |
| Firestore sync shows error | Non-fatal (PostgreSQL is source of truth) - check Firebase credentials |
| Functions not deploying | Check Supabase CLI version: `supabase --version` |
| Secrets not found | Verify set in Supabase Console Settings → Secrets |

---

## Next Steps (After Deployment)

After all 3 tasks deployed and verified:

1. **Task #22:** Test end-to-end order flow
2. **Task #23:** Test end-to-end delivery flow  
3. **Task #24:** Implement storage bucket upload functions
4. **Task #25:** Update mobile app with Firestore listeners
5. **Task #26:** Setup monitoring and observability

---

## Files at a Glance

```
C:\Projects\fufaji-online-business\

📂 supabase/
  ├── functions/
  │   ├── _shared/
  │   │   └── firebase-bridge.ts ✏️ (modified)
  │   └── razorpay-webhook-dual-write/
  │       └── index.ts ✏️ (modified import)
  └── migrations/
      └── 04_storage_buckets_firestore_sync.sql ✅ (ready)

📄 Deployment Documents:
  ├── DEPLOYMENT_TASKS_19_20_21.md (detailed guide, 380 lines)
  ├── QUICK_REFERENCE_TASKS_19_20_21.md (quick lookup, 320 lines)
  ├── TASKS_19_20_21_SUMMARY.txt (executive summary, 500 lines)
  └── DEPLOYMENT_INDEX.md (this file)

🔧 Scripts:
  ├── deploy-tasks-19-20-21.ps1 (PowerShell automation)
  ├── deploy-tasks-19-20-21.sh (Bash automation)
  └── verify-deployment-19-20-21.sql (SQL verification queries)

Legend:
  ✅ = Ready, no changes needed
  ✏️ = Modified, code ready
  📄 = Documentation
  🔧 = Automation scripts
```

---

## Success Criteria

Deployment is successful when:

- ✅ All 3 Edge Functions deployed without errors
- ✅ All secrets set in Supabase
- ✅ 4 storage buckets created
- ✅ 6 RLS policies active
- ✅ Razorpay webhook configured and receiving events
- ✅ Test payment webhook processed successfully
- ✅ Payment recorded in both PostgreSQL and Firestore
- ✅ Order status updated automatically
- ✅ Inventory deducted on payment
- ✅ No errors in Edge Function logs

---

## Estimated Timeline

| Phase | Time | Tasks |
|-------|------|-------|
| Setup | 5 min | Get credentials, verify CLI |
| Task #19 | 5 min | Set secret, deploy, verify logs |
| Task #20 | 5 min | Deploy migration, verify buckets |
| Task #21 | 5 min | Set secret, deploy, configure webhook |
| Testing | 10 min | Run SQL checks, test webhook |
| **Total** | **~30 min** | |

*Times are estimates for experienced deployer. First-time may take 1-2 hours.*

---

## Support Resources

### Supabase
- Docs: https://supabase.com/docs
- CLI: https://supabase.com/docs/guides/cli
- Support: https://supabase.com/support

### Firebase
- Docs: https://firebase.google.com/docs
- Console: https://console.firebase.google.com
- Support: https://firebase.google.com/support

### Razorpay
- Docs: https://razorpay.com/docs
- Webhooks: https://razorpay.com/docs/webhooks
- Dashboard: https://dashboard.razorpay.com

---

## Questions?

Refer to the appropriate guide:
- **How do I deploy?** → DEPLOYMENT_TASKS_19_20_21.md
- **What's the quick version?** → QUICK_REFERENCE_TASKS_19_20_21.md
- **What's the overview?** → TASKS_19_20_21_SUMMARY.txt
- **How do I verify?** → verify-deployment-19-20-21.sql
- **Need specific command?** → deploy-tasks-19-20-21.ps1 or .sh

---

**Status:** ✅ Ready for Deployment  
**Date:** 2026-06-28  
**Project:** Fufaji Online Business  
**Supabase:** mxjtgpunctckovtuyfmz.supabase.co
