# Fufaji — Cloud Implementation Runbook

**Goal:** move every backend service to the free target stack, keep 100% of features, end with an APK you can build and release.

**Companion doc:** `CLOUD_ARCHITECTURE_DECISION_PLAN.md` (the "what & why"). This doc is the "how", step by step.

**Legend:** 🤖 = I do it (write code/commands) · 🧑 = you do it (console/deploy/secrets) · ⏱ = rough effort

**Two ground rules**
- No feature is removed. Only providers/plumbing change.
- No leaked secret is reused. Every secret is **rotated by you** and pasted into AWS SSM. Secrets never go through me or into any committed file.

---

## Phase 0 — Security lockdown (do first; blocks safe release)

### 0.1 Stop shipping secrets in the APK 🤖 ⏱15m
- Remove `.env` from `flutter_dotenv` assets in `pubspec.yaml`.
- Replace in-app secret reads with **public** config via `--dart-define` (only public values: Razorpay *key id*, Supabase URL if still referenced, FCM sender id). No secret keys in the app — ever.
- Delete committed plaintext: `.env`, `.runtimeconfig.json`, `setup_functions_config.bat`.

### 0.2 Make the repo private right now 🧑 ⏱2m
GitHub → repo → Settings → General → Danger Zone → **Change visibility → Private**. Stops further exposure while we rotate.

### 0.3 Rotate every leaked credential 🧑 ⏱45m
Generate NEW values in each console; revoke the old. Order by blast radius:

| Secret | Console | Action |
|---|---|---|
| Razorpay key secret + **webhook secret** | dashboard.razorpay.com → Settings → API Keys / Webhooks | Regenerate; set webhook secret **different** from key secret |
| AWS S3 access/secret key | IAM → the S3 user | Create new access key, delete old |
| AWS Bedrock bearer token | Bedrock console | Regenerate (skip if dropping Bedrock) |
| Twilio auth token | console.twilio.com | Roll auth token / API key |
| Meta WhatsApp token | developers.facebook.com | Regenerate permanent token |
| Gemini API key | aistudio.google.com | Create new key, delete old |
| SendGrid API key | app.sendgrid.com | Create new key, delete old |
| Android signing keystore | local `keytool` | Regenerate **only if not yet on Play Store**; if published, keep & treat as sensitive |

> RDS password is intentionally omitted — we're dropping RDS (Phase 3).

### 0.4 Purge secrets from git history 🧑 ⏱15m
After rotation (so it's belt-and-suspenders), run on your Windows terminal (NOT from here — this sandbox must not write git):
```
git filter-repo --path .env --path functions/.env --path .runtimeconfig.json --invert-paths
git push --force --all
```
(If `git filter-repo` isn't installed: `pip install git-filter-repo`.)

**Phase 0 exit:** no secret in the repo, no secret in the APK, all live keys rotated.

---

## Phase 1 — AWS account prep 🧑 (I give exact values/commands) ⏱30m

Region everywhere: **ap-south-1** (Mumbai), to match your S3 bucket and users.

1. **IAM role for Lambda** — least privilege: read SSM params under `/fufaji/*`, read/write your S3 bucket, write CloudWatch logs. (I provide the JSON policy + `aws iam` commands.)
2. **IAM user for deploy** (or use existing) with Lambda/SSM/S3/EventBridge admin for setup only.
3. **S3 bucket** `bucket-ofqh8w` — apply CORS (app uploads) + lifecycle (you already have `infra/s3/lifecycle-policy.json`). I provide the CORS JSON.
4. **Install tooling** on your machine: AWS CLI v2 + AWS SAM CLI. (I provide the install + `aws configure` steps.)

---

## Phase 2 — Store secrets in SSM 🧑 ⏱15m

Paste **rotated** values (placeholders shown — never the old ones):
```
aws ssm put-parameter --name /fufaji/razorpay/key_secret   --type SecureString --value "<NEW_RAZORPAY_SECRET>"
aws ssm put-parameter --name /fufaji/razorpay/webhook_secret --type SecureString --value "<NEW_WEBHOOK_SECRET>"
aws ssm put-parameter --name /fufaji/twilio/auth_token      --type SecureString --value "<NEW_TWILIO_TOKEN>"
aws ssm put-parameter --name /fufaji/whatsapp/token         --type SecureString --value "<NEW_WA_TOKEN>"
aws ssm put-parameter --name /fufaji/gemini/api_key         --type SecureString --value "<NEW_GEMINI_KEY>"
aws ssm put-parameter --name /fufaji/sendgrid/api_key       --type SecureString --value "<NEW_SENDGRID_KEY>"
aws ssm put-parameter --name /fufaji/s3/access_key          --type SecureString --value "<NEW_S3_ACCESS>"
aws ssm put-parameter --name /fufaji/s3/secret_key          --type SecureString --value "<NEW_S3_SECRET>"
```
(I generate this list from your actual `.env` keys so nothing is missed.)

---

## Phase 3 — Database consolidation to Firestore 🤖 ⏱half-day

Drop the two duplicate databases so there's one source of truth.

1. Map the **28 call sites** that use Supabase/RDS:
   - `supabase_database_service.dart` + 8 callers → Firestore equivalents.
   - `rds_database_service.dart` + 18 callers → Firestore (or remove if analytics-only/dead).
2. Remove deps: `supabase_flutter` from `pubspec.yaml`; `pg` usage from backend.
3. Keep `supabase/migrations/*.sql` as **design documentation only** (don't delete the design knowledge).
4. Verify no screen reads from a now-removed source (compile + smoke test).

**Exit:** every order/inventory/payment read-write goes to Firestore only — kills the "competing engines" class of bugs.

---

## Phase 4 — Backend on AWS Lambda 🤖 build · 🧑 deploy ⏱1–2 days

### 4.1 Structure (I scaffold)
```
backend/
  src/app.js          # Express app
  src/secrets.js      # loads /fufaji/* from SSM at cold start, caches
  src/auth.js         # firebase-admin: verify Firebase ID token on every request
  src/firestore.js    # firebase-admin Firestore handle
  src/routes/...       # ported endpoints
  src/jobs/...         # scheduled handlers
  template.yaml        # AWS SAM: one Lambda + Function URL + EventBridge rules
```
One Lambda, exposed by a **Function URL** (free; no API Gateway). Auth model unchanged: the app sends its Firebase ID token; the Lambda verifies it with `firebase-admin`, so all your existing roles/claims still apply.

### 4.2 Port the 34 functions

**Callable → REST endpoints** (app calls these directly):
| Old function | New endpoint |
|---|---|
| createRazorpayOrder | POST /payments/razorpay/order |
| verifyRazorpayPayment | POST /payments/razorpay/verify |
| initiateRazorpayRefund | POST /payments/razorpay/refund |
| initiateRiderPayout | POST /payouts/rider |
| setRole / syncUserClaims | POST /admin/roles (admin only) |
| generateAndSendInvoice | POST /invoices/generate |
| onReportTriggerRequest | POST /reports/trigger |
| getS3UploadUrl / DownloadUrl / deleteS3Object | POST /storage/* (presigned) |
| bedrockGenerate | POST /ai/bedrock *(optional — keep only if used)* |
| verifyBackendHealth | GET /health |
| rdsQuery | **removed** (RDS dropped) |

**Webhooks → public routes** (HMAC-verified, no Firebase token):
- razorpayWebhook → POST /webhooks/razorpay (verify with rotated webhook secret)
- whatsappWebhook → POST /webhooks/whatsapp

**Scheduled → EventBridge rules** (cron in `template.yaml`, free):
checkInventoryAlerts, processExpiries, updateDynamicPricing, checkExpiryAlerts, processNotificationQueue, cleanupNotificationQueue, sendDailyOwnerReport, dailyFirestoreBackup, reconcileOrphanedPayments, clusterDeliveryOrders, sendLowStockWhatsAppAlert.

**Triggers → folded into endpoints** (the key correctness fix). Each trigger's logic moves into the action that causes it, run transactionally:
| Old trigger | Folded into |
|---|---|
| onOrderCreate (stock deduct, notify) | POST /orders create endpoint |
| onOrderUpdate (status SMS, delivery) | POST /orders/{id}/status |
| onUserCreate (claims, welcome) | POST /auth/onboard (called post-signup) |
| onEmployeeWrite / onOwnerWrite | the admin write endpoints |
| notifyNewDevice | POST /devices/register |

SMS senders (sendOrder*SMS, sendDelivery*SMS, sendPromotionalSMS) become internal helpers called by the endpoints above.

### 4.3 Deploy 🧑
```
cd backend && npm install
sam build && sam deploy --guided      # first time; pick ap-south-1
```
SAM prints the **Function URL** — copy it for Phase 5.

**Exit:** every backend behavior works, callable + webhook + scheduled + (folded) triggers, all on free Lambda.

---

## Phase 5 — Rewire the Flutter app 🤖 ⏱half-day

1. **API client** — new `lib/services/api_client.dart`: base URL = Function URL (via `--dart-define=API_BASE_URL=...`), attaches `Authorization: Bearer <firebase id token>` automatically.
2. **Swap the ~25 `httpsCallable(...)` calls** to `apiClient.post('/...')`. Same inputs/outputs, so screens don't change.
3. **Storage** → route uploads through `s3_storage_service.dart` presigned flow (off Firebase Storage).
4. **Provider swaps (no feature loss):**
   - Maps: render via `flutter_map` + OpenStreetMap tiles (keeps the map feature, no Google billing). Keep `google_maps_flutter` only if you choose to enable Google billing.
   - Payments: Razorpay stays primary. **Stripe:** your call — keep `flutter_stripe` as a disabled fallback, or remove it. (It's currently broken + unused; I recommend disabling, not deleting the idea.)
5. Remove `flutter_dotenv` reads of secrets; keep only `--dart-define` public values.

---

## Phase 6 — Build, test, release 🧑 runs · 🤖 provides checklist ⏱2h

```
flutter clean && flutter pub get
flutter build apk --release \
  --dart-define=API_BASE_URL=<function-url> \
  --dart-define=RAZORPAY_KEY_ID=<public-key-id> \
  --dart-define=FCM_SENDER_ID=<id>
```
Smoke test: sign in → browse → add to cart → place order (stock deducts once) → pay (Razorpay) → status update SMS/WhatsApp → invoice → owner report. I provide the full checklist + a Postman collection to hit each Lambda endpoint before APK testing.

---

## Ownership summary

| Phase | 🤖 Me | 🧑 You |
|---|---|---|
| 0 Security | pubspec/dart-define, delete plaintext | repo private, rotate keys, purge history |
| 1 AWS prep | IAM policy JSON, CORS, commands | run commands, install CLI/SAM |
| 2 Secrets | generate the SSM key list | paste rotated values |
| 3 DB consolidation | all code | review |
| 4 Backend | all code + SAM template | `sam deploy` |
| 5 App rewiring | all code | review |
| 6 Release | checklist + Postman | build + test APK |

---

## What I need from you to start building (Phase 3–5 code)

1. Confirm: **drop Supabase + AWS RDS as databases** (keep SQL as docs)? 
2. **Stripe** — disable as dormant fallback (recommended) or fully remove?
3. **Bedrock** — keep `/ai/bedrock` endpoint or drop (Gemini-only)?
4. Confirm region **ap-south-1** and S3 bucket **bucket-ofqh8w**.

You do NOT need to finish Phase 0 rotations before I start — I can build all the code (Phases 3–5) in parallel; rotations + deploy (Phases 0–2, 4.3, 6) are yours and can happen when you're ready.
