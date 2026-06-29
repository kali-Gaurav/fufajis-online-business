# Fufaji — Master Migration Task List

Single source of truth for moving to the free cloud stack (Firestore + AWS Lambda
+ S3 + SSM) and shipping the APK. Work top to bottom; check off as you go.

**Companion docs:** `CLOUD_ARCHITECTURE_DECISION_PLAN.md` (what & why) ·
`CLOUD_IMPLEMENTATION_RUNBOOK.md` (how) · `backend/README.md` (deploy).

### Legend

- `[ ]` todo · `[x]` done
- 🤖 = Claude writes code/commands · 🧑 = you run console/deploy/secret steps
- 🔴 P0 (blocks release) · 🟠 P1 (needed for full function) · 🟢 P2 (polish)

### Progress

| Phase | Done / Total |
|---|---|
| 0 Security lockdown | 0 / 13 |
| 1 AWS prep | 0 / 12 |
| 2 Secrets → SSM | 0 / 14 |
| 3 DB consolidation | 0 / 16 |
| 4 Lambda backend | 11 / 38 |
| 5 Client rewiring | 0 / 22 |
| 6 Build & release | 0 / 16 |
| 7 Cleanup & hardening | 0 / 12 |
| **Total** | **11 / 143** |

---

## Phase 0 — Security lockdown 🔴

- [ ] P0.1 🤖 Remove `.env` from `flutter_dotenv` assets list in `pubspec.yaml`
- [ ] P0.2 🤖 Replace in-app secret reads with `--dart-define` public values only
- [ ] P0.3 🤖 Delete committed `.env` from repo working tree
- [ ] P0.4 🤖 Delete `functions/.env` / `.runtimeconfig.json` if present
- [ ] P0.5 🤖 Delete `setup_functions_config.bat` (contains secret-set commands)
- [ ] P0.6 🧑 Make the GitHub repo **Private** (Settings → Danger Zone)
- [ ] P0.7 🧑 Rotate Razorpay key secret + set a NEW webhook secret (different value)
- [ ] P0.8 🧑 Rotate AWS S3 access/secret key (then delete old key)
- [ ] P0.9 🧑 Rotate Twilio auth token / API key
- [ ] P0.10 🧑 Rotate Meta WhatsApp permanent token
- [ ] P0.11 🧑 Rotate Gemini API key + SendGrid API key
- [ ] P0.12 🧑 Decide on Android signing keystore (regen only if not yet on Play Store)
- [ ] P0.13 🧑 Purge secrets from git history (`git filter-repo`) + force-push

## Phase 1 — AWS account prep 🔴

- [ ] P1.1 🧑 Install AWS CLI v2; run `aws configure` (region `ap-south-1`)
- [ ] P1.2 🧑 Install AWS SAM CLI; verify `sam --version`
- [ ] P1.3 🤖 Provide least-privilege IAM policy JSON for the Lambda role
- [ ] P1.4 🧑 Confirm/create deploy IAM user with Lambda/SSM/S3/EventBridge perms
- [ ] P1.5 🤖 Provide S3 CORS JSON for app uploads
- [ ] P1.6 🧑 Apply S3 CORS to `bucket-ofqh8w`
- [ ] P1.7 🧑 Apply S3 lifecycle policy (`infra/s3/lifecycle-policy.json`)
- [ ] P1.8 🧑 Confirm S3 bucket is **private** (block public access ON)
- [ ] P1.9 🧑 Verify AWS account region consistency (`ap-south-1` everywhere)
- [ ] P1.10 🧑 Generate Firebase service-account JSON (console → service accounts)
- [ ] P1.11 🤖 Document EventBridge schedule expressions for the 9 cron jobs
- [ ] P1.12 🧑 Confirm CloudWatch Logs retention (e.g. 14 days) to stay free

## Phase 2 — Secrets → SSM 🔴

- [ ] P2.1 🤖 Generate the exact `aws ssm put-parameter` command list from `.env` keys
- [ ] P2.2 🧑 Put `/fufaji/firebase/service_account` (full JSON)
- [ ] P2.3 🧑 Put `/fufaji/razorpay/key_id`
- [ ] P2.4 🧑 Put `/fufaji/razorpay/key_secret` (rotated)
- [ ] P2.5 🧑 Put `/fufaji/razorpay/webhook_secret` (rotated, distinct)
- [ ] P2.6 🧑 Put `/fufaji/whatsapp/token` + `/fufaji/whatsapp/phone_id`
- [ ] P2.7 🧑 Put `/fufaji/twilio/account_sid` + `auth_token` + `phone_number`
- [ ] P2.8 🧑 Put `/fufaji/gemini/api_key`
- [ ] P2.9 🧑 Put `/fufaji/sendgrid/api_key`
- [ ] P2.10 🧑 (none for S3 — uses Lambda role)
- [ ] P2.11 🧑 Verify all params are type `SecureString`
- [ ] P2.12 🧑 `aws ssm get-parameters-by-path --path /fufaji/ --with-decryption` sanity check
- [ ] P2.13 🤖 Confirm `secrets.js` key names match every param exactly
- [ ] P2.14 🧑 Restrict SSM param KMS key access to the Lambda role only

## Phase 3 — Database consolidation (→ Firestore) 🟠

- [ ] P3.1 🤖 Inventory all 9 Supabase call sites in `lib/`
- [ ] P3.2 🤖 Inventory all 19 RDS call sites in `lib/`
- [ ] P3.3 🤖 Classify each: migrate-to-Firestore vs dead-code-remove
- [ ] P3.4 🤖 Rewrite `supabase_database_service.dart` callers → Firestore
- [ ] P3.5 🤖 Rewrite `rds_database_service.dart` callers → Firestore
- [ ] P3.6 🤖 Remove `supabase_flutter` from `pubspec.yaml`
- [ ] P3.7 🤖 Remove `Supabase.initialize` from `main.dart`
- [ ] P3.8 🤖 Remove `pg`/RDS code paths from `functions/` (being retired)
- [ ] P3.9 🤖 Drop `rdsQuery`/`getContacts`/`addContact`/`deleteContact` (RDS-only)
- [ ] P3.10 🤖 Verify no screen reads from a removed source
- [ ] P3.11 🤖 Keep `supabase/migrations/*.sql` as design docs (do not delete)
- [ ] P3.12 🤖 Add Firestore composite indexes for any new query patterns
- [ ] P3.13 🤖 `flutter analyze` clean after removals
- [ ] P3.14 🧑 Decommission AWS RDS / Lightsail Postgres instance (stop billing)
- [ ] P3.15 🧑 Pause/delete the Supabase project (or leave free, unused)
- [ ] P3.16 🤖 Update docs to state Firestore is the single source of truth

## Phase 4 — Lambda backend 🟠

### 4A Scaffold & foundation

- [x] P4.1 🤖 Scaffold `backend/` (package.json, template.yaml, .gitignore)
- [x] P4.2 🤖 `secrets.js` — SSM loader with cache
- [x] P4.3 🤖 `firestore.js` — firebase-admin init from SSM service account
- [x] P4.4 🤖 `auth.js` — verify Firebase ID token + `requireRole`
- [x] P4.5 🤖 `app.js` + `lambda.js` — Express + serverless-http wrapper
- [x] P4.6 🤖 SAM `template.yaml` — Lambda + free Function URL + IAM

### 4B Payments & webhook

- [x] P4.7 🤖 `POST /payments/razorpay/order` (createRazorpayOrder)
- [x] P4.8 🤖 `POST /payments/razorpay/verify` (verifyRazorpayPayment)
- [x] P4.9 🤖 `POST /payments/razorpay/refund` (initiateRazorpayRefund + ledger)
- [x] P4.10 🤖 `POST /webhooks/razorpay` (full webhook, HMAC + idempotency)

### 4C Roles, storage, invoice

- [x] P4.11 🤖 `POST /admin/roles/set` + `POST /admin/claims/sync`
- [ ] P4.12 🤖 `POST /storage/upload-url` / `download-url` / `delete` (AWS S3) — *code done, deploy pending*
- [ ] P4.13 🤖 `POST /invoices/generate` (WhatsApp invoice) — *code done, deploy pending*

### 4D Remaining endpoints

- [ ] P4.14 🤖 `POST /payouts/rider` (initiateRiderPayout)
- [ ] P4.15 🤖 `POST /webhooks/whatsapp` (whatsappWebhook)
- [ ] P4.16 🤖 `POST /ai/gemini` (bedrockGenerate — actually Gemini)
- [ ] P4.17 🤖 `GET /health` deep check (RDS removed; S3 + Gemini ping)
- [ ] P4.18 🤖 Audit/port `verifyOrderOTP` (referenced by client)
- [ ] P4.19 🤖 Audit/port `processRefundWithStockRestore` (referenced by client)
- [ ] P4.20 🤖 Audit/port `initiateBankTransferRefund` (referenced by client)
- [ ] P4.21 🤖 Audit/port `sendOrderConfirmationEmail` / `sendOrderReceiptEmail`

### 4E SMS / notification helpers (internal modules)

- [ ] P4.22 🤖 `sms.js` — Twilio helper + `formatPhoneNumber`
- [ ] P4.23 🤖 Port sendOrderConfirmationSMS / StatusUpdate / Cancellation
- [ ] P4.24 🤖 Port sendDeliveryAgentAssignmentSMS / sendDeliveryOTPSMS
- [ ] P4.25 🤖 Port sendPromotionalSMS (admin-gated)
- [ ] P4.26 🤖 Port sendLowStockWhatsAppAlert helper

### 4F Scheduled jobs → EventBridge

- [ ] P4.27 🤖 `jobs/` handlers + EventBridge rules in template.yaml
- [ ] P4.28 🤖 checkInventoryAlerts (hourly)
- [ ] P4.29 🤖 processExpiries + checkExpiryAlerts
- [ ] P4.30 🤖 updateDynamicPricing
- [ ] P4.31 🤖 processNotificationQueue + cleanupNotificationQueue
- [ ] P4.32 🤖 sendDailyOwnerReport
- [ ] P4.33 🤖 dailyFirestoreBackup (→ S3)
- [ ] P4.34 🤖 reconcileOrphanedPayments
- [ ] P4.35 🤖 clusterDeliveryOrders

### 4G Folded triggers (correctness fixes) 🔴

- [ ] P4.36 🤖 `POST /orders` — create order + deduct stock + notify in one txn (folds onOrderCreate)
- [ ] P4.37 🤖 `POST /orders/{id}/status` — status change + SMS + delivery (folds onOrderUpdate)
- [ ] P4.38 🤖 Fold onUserCreate / onEmployeeWrite / onOwnerWrite / notifyNewDevice into endpoints

## Phase 4H — Deploy backend 🟠

- [ ] P4H.1 🧑 `cd backend && npm install`
- [ ] P4H.2 🧑 `sam build`
- [ ] P4H.3 🧑 `sam deploy --guided` (capture Function URL)
- [ ] P4H.4 🧑 Set Razorpay dashboard webhook → `<FunctionUrl>webhooks/razorpay`
- [ ] P4H.5 🧑 Set Meta WhatsApp webhook → `<FunctionUrl>webhooks/whatsapp`
- [ ] P4H.6 🧑 `curl <FunctionUrl>health` returns ok

## Phase 5 — Client rewiring 🟠

- [ ] P5.1 🤖 `api_client.dart` — base URL + auto Firebase ID token header
- [ ] P5.2 🤖 Add `--dart-define=API_BASE_URL` plumbing
- [ ] P5.3 🤖 Rewire `razorpay_service.dart` (order + verify)
- [ ] P5.4 🤖 Rewire `refund_processing_screen.dart` (refund)
- [ ] P5.5 🤖 Rewire `auth_provider.dart` (setRole)
- [ ] P5.6 🤖 Rewire claims sync call (syncUserClaims)
- [ ] P5.7 🤖 Rewire `s3_storage_service.dart` (upload/download/delete)
- [ ] P5.8 🤖 Rewire invoice trigger (generateAndSendInvoice)
- [ ] P5.9 🤖 Rewire `sms_service.dart` (3 SMS calls)
- [ ] P5.10 🤖 Rewire `smart_route_screen.dart` (clusterDeliveryOrders)
- [ ] P5.11 🤖 Rewire order create/status to `POST /orders` endpoints
- [ ] P5.12 🤖 Rewire `email_service.dart` (confirmation/receipt)
- [ ] P5.13 🤖 Rewire `order_business_logic.dart` (processOrderRefund)
- [ ] P5.14 🤖 Rewire POS refund (`processRefundWithStockRestore`)
- [ ] P5.15 🤖 Rewire OTP verify (`verifyOrderOTP`)
- [ ] P5.16 🤖 Remove all remaining `cloud_functions` / `httpsCallable` usage
- [ ] P5.17 🤖 Storage: route media uploads through S3 service (off Firebase Storage)
- [ ] P5.18 🤖 Maps: switch screens to `flutter_map` + OpenStreetMap
- [ ] P5.19 🤖 Drop `google_maps_flutter` (or keep if Google billing accepted)
- [ ] P5.20 🤖 Payments: disable/remove Stripe (`stripe_service.dart`, `flutter_stripe`)
- [ ] P5.21 🤖 Remove `flutter_dotenv` secret reads
- [ ] P5.22 🤖 `flutter analyze` clean

## Phase 6 — Build, test, release 🔴

- [ ] P6.1 🤖 Provide Postman collection for all Lambda endpoints
- [ ] P6.2 🧑 Test each endpoint via Postman (with a real ID token)
- [ ] P6.3 🧑 `flutter clean && flutter pub get`
- [ ] P6.4 🧑 `flutter build apk --release` with all `--dart-define`s
- [ ] P6.5 🧑 Smoke: sign in (Google/phone)
- [ ] P6.6 🧑 Smoke: browse + search products
- [ ] P6.7 🧑 Smoke: add to cart → place order (stock deducts **once**)
- [ ] P6.8 🧑 Smoke: pay via Razorpay → order confirmed
- [ ] P6.9 🧑 Smoke: webhook reconciles payment (check Firestore)
- [ ] P6.10 🧑 Smoke: order status update → SMS/WhatsApp received
- [ ] P6.11 🧑 Smoke: invoice WhatsApp received
- [ ] P6.12 🧑 Smoke: refund from owner panel → wallet/refund correct
- [ ] P6.13 🧑 Smoke: image upload → appears (S3 presigned)
- [ ] P6.14 🧑 Smoke: admin sets a role → takes effect
- [ ] P6.15 🧑 Verify no secret strings inside the built APK (`unzip`/grep)
- [ ] P6.16 🧑 Release APK

## Phase 7 — Cleanup & hardening 🟢

- [ ] P7.1 🤖 Delete `functions/` folder (after Lambda verified live)
- [ ] P7.2 🤖 Remove Firebase Functions config from `firebase.json`
- [ ] P7.3 🤖 Remove Firebase Storage rules/usage (Blaze-gated, replaced by S3)
- [ ] P7.4 🧑 Set CloudWatch billing alarm at $1 (early warning)
- [ ] P7.5 🤖 Add request rate limiting / abuse guard on Function URL
- [ ] P7.6 🤖 Tighten S3 presign to per-user key scoping
- [ ] P7.7 🤖 Add structured logging + error capture (Sentry DSN server-side)
- [ ] P7.8 🤖 Document the final architecture in `README.md`
- [ ] P7.9 🧑 Rotate Firebase service-account key on a schedule
- [ ] P7.10 🤖 Add a `/health` dashboard screen wiring
- [ ] P7.11 🧑 Enable Firebase App Check enforcement
- [ ] P7.12 🤖 Archive obsolete `.md` planning docs into `docs/archive/`

---

## How we proceed

We work one checkbox at a time (or one sub-group per session). After each, I mark
it `[x]` here and update the Progress table. The 🧑 items are batched so you can run
several console steps in one sitting. Order of attack:
**Phase 0 → finish Phase 4 code → Phase 3 → Phase 5 → deploy (1/2/4H) → Phase 6.**
