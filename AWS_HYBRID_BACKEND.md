# AWS Hybrid Backend — Firebase Functions Proxy

## Architecture

The app never holds AWS credentials. All RDS/S3/Bedrock access goes through
Firebase Cloud Functions (`functions/aws_services.js`), which the Flutter app
calls via `cloud_functions`.

```
Flutter App ──httpsCallable──▶ Cloud Functions ──AWS SDK / pg──▶ AWS (RDS, S3, Bedrock)
                                     │
                                     └─▶ Firebase Auth + App Check enforce
                                         who can call what
```

## One-time server setup

Run these once (replace placeholders with the real values currently in
`.env`'s removed AWS section), then redeploy:

```bash
firebase functions:config:set \
  rds.host="ls-6ce03c479b031df8b611864eeacf9883a6f70f04.c1uuq48mk4lv.ap-south-1.rds.amazonaws.com" \
  rds.port="5432" \
  rds.user="dbmasteruser" \
  rds.password="<RDS_PASSWORD>" \
  rds.database="postgres"

firebase functions:config:set \
  aws.s3_access_key="<AWS_S3_ACCESS_KEY>" \
  aws.s3_secret_key="<AWS_S3_SECRET_KEY>" \
  aws.s3_bucket="bucket-ofqh8w" \
  aws.s3_region="ap-south-1" \
  aws.s3_endpoint="s3.ap-south-1.amazonaws.com"

firebase functions:config:set \
  aws.bedrock_token="<AWS_BEARER_TOKEN_BEDROCK>" \
  aws.bedrock_region="us-east-1" \
  aws.bedrock_model="anthropic.claude-3-sonnet-20240229-v1:0"

cd functions && npm install
firebase deploy --only functions
```

**Strongly recommended**: rotate the RDS password and the AWS S3 access
key/secret before setting them server-side, since they were previously
shipped inside the APK and may already be exposed.

## New callable functions (`functions/aws_services.js`)

- `rdsQuery({ sql, params, allowWrite })` — admin/owner only. Parameterized
  Postgres queries (`$1`, `$2`, ...). Write queries (`INSERT/UPDATE/DELETE/
  DDL`) require `allowWrite: true`.
- `getS3UploadUrl({ key, contentType, expiresIn })` — any signed-in user;
  non-admins restricted to `uploads/{uid}/...`. Returns a presigned PUT URL.
- `getS3DownloadUrl({ key, expiresIn })` — same scoping; returns a presigned
  GET URL.
- `deleteS3Object({ key })` — admin/owner only.
- `bedrockGenerate({ prompt, maxTokens })` — any signed-in user. Proxies to
  Claude 3 Sonnet via Bedrock's bearer-token API.
- `verifyBackendHealth()` — admin/owner only. Live reachability + latency
  for RDS, S3, and Bedrock. Powers the new **Backend Diagnostics** screen at
  `/owner/backend-diagnostics`.

## Client services (rewritten)

- `lib/services/rds_database_service.dart` → `RDSDatabaseService().query(sql, params: [...])`
- `lib/services/s3_storage_service.dart` → `uploadBytes`, `uploadFile`,
  `getPresignedUrl`, `deleteFile`, plus `scopedKey(path)` helper for
  per-user upload paths
- `lib/services/aws_bedrock_service.dart` → `generateComplexReasoning(prompt)`,
  `parseComplexBill(imageBytes)`
- `lib/services/workflow_verification_service.dart` → `verifyWorkflow(includeBackendHealth: true)`
  merges client + server health into one report

## What else this hybrid backend enables

1. **RDS analytics warehouse** — mirror Firestore order/inventory data into
   Postgres (via a scheduled function) and run heavy SQL aggregations
   (cohort analysis, multi-month sales trends, vendor performance) that are
   awkward in Firestore. Surface results in `bi_analytics_hub_screen.dart`.

2. **S3 as the document/media vault** — route bill photos, delivery proofs,
   invoices, and KYC documents to S3 via `scopedKey('bills/...')` instead of
   Firebase Storage, cutting Firebase Storage costs at scale. Presigned URLs
   keep access time-limited.

3. **Bedrock as Gemini's fallback/escalation model** — when `GeminiService`
   fails or returns low-confidence results (e.g. complex multilingual bill
   OCR, long-form customer support replies), call
   `AWSBedrockService().generateComplexReasoning(...)` as a second opinion.

4. **Bedrock for regional language generation** — Claude 3 handles Hindi/
   Hinglish well; use it for WhatsApp broadcast copy, review-reply drafts,
   and product descriptions in regional languages.

5. **RDS-backed loyalty/points ledger** — a relational ledger table is a
   natural fit for double-entry style points/cashback accounting, with
   `rdsQuery(..., allowWrite: true)` from admin-only Cloud Functions
   (not directly from the client) for writes.

6. **Cross-checking financial reconciliation** — periodically run an RDS
   query that diffs Razorpay settlement totals (already synced via
   `settlements_management.dart`) against Firestore order totals, flagging
   mismatches in `audit_log_screen.dart`.

7. **Cold storage / backups** — point `dailyFirestoreBackup` (already in
   `functions/index.js`) at the S3 bucket via `@aws-sdk/client-s3` for
   cheaper long-term backup retention alongside the existing Firestore
   export.

## Diagnostics

Owners can open **Backend Diagnostics** (`/owner/backend-diagnostics`) to
see config status for every service, and tap refresh to run a live
RDS/S3/Bedrock connectivity check via `verifyBackendHealth`.
