# Fufaji Backend (AWS Lambda)

Replaces Firebase Cloud Functions (which require the paid Blaze plan). One
Lambda, exposed by a free **Function URL**, secrets in **SSM Parameter Store**.
Auth model is unchanged: the app sends its Firebase ID token; the Lambda
verifies it with `firebase-admin`.

## Status (this slice)

Ported and wired with your real logic:

| Old Firebase function | New endpoint | Auth |
|---|---|---|
| `createRazorpayOrder` | `POST /payments/razorpay/order` | signed-in user |
| `verifyRazorpayPayment` | `POST /payments/razorpay/verify` | signed-in user |
| `initiateRazorpayRefund` | `POST /payments/razorpay/refund` | admin / shop owner |
| `razorpayWebhook` | `POST /webhooks/razorpay` | HMAC signature |
| `setRole` | `POST /admin/roles/set` | admin |
| `syncUserClaims` | `POST /admin/claims/sync` | signed-in user |
| `getS3UploadUrl` | `POST /storage/upload-url` | signed-in user |
| `getS3DownloadUrl` | `POST /storage/download-url` | signed-in user |
| `deleteS3Object` | `POST /storage/delete` | admin / shop owner |
| `generateAndSendInvoice` | `POST /invoices/generate` | signed-in user |
| (basic health) | `GET /health` | none |

Response field names match the old callables exactly, so the Flutter clients
(`razorpay_service.dart`, `refund_processing_screen.dart`, `s3_storage_service.dart`,
`auth_provider.dart`) work unchanged once their base URL is switched (Phase 5).

**Notes on this slice**
- S3 presign now targets **real AWS S3** (`bucket-ofqh8w`); the old code pointed
  at Supabase Storage's S3 endpoint, which we're dropping. Presigning uses the
  **Lambda execution role** — so there are NO S3 access keys to store or rotate.
- `generateAndSendInvoice` sends a WhatsApp text invoice via the Meta Graph API
  (uses `/fufaji/whatsapp/*`).

Still to port (next slices): rider payouts, the 9 scheduled jobs (→ EventBridge),
and the folded order/stock/notification triggers (`POST /orders`).

## Required SSM parameters (you create these, with ROTATED values)

```
/fufaji/firebase/service_account   # full service-account JSON (SecureString)
/fufaji/razorpay/key_id
/fufaji/razorpay/key_secret
/fufaji/razorpay/webhook_secret     # MUST differ from key_secret
/fufaji/whatsapp/token              # for invoice WhatsApp send
/fufaji/whatsapp/phone_id
```
No S3 keys needed — presigning uses the Lambda role. Later slices also use:
`/fufaji/twilio/*`, `/fufaji/gemini/api_key`, `/fufaji/sendgrid/api_key`.

Create one like this (never commit the value):
```
aws ssm put-parameter --name /fufaji/razorpay/key_secret \
  --type SecureString --value "<ROTATED_VALUE>" --region ap-south-1
```

The Firebase service account: Firebase console → Project settings → Service
accounts → Generate new private key → paste the whole JSON as the value of
`/fufaji/firebase/service_account`.

## Deploy

Prereqs: AWS CLI v2 + AWS SAM CLI installed, `aws configure` done (region
`ap-south-1`).

```
cd backend
npm install
sam build
sam deploy --guided     # first time: accept defaults, region ap-south-1
```
SAM prints `FunctionUrl` — that's your `API_BASE_URL` for the app build.

## Razorpay webhook

In the Razorpay dashboard set the webhook URL to `<FunctionUrl>webhooks/razorpay`
and the signing secret to the same value stored in
`/fufaji/razorpay/webhook_secret`.

## Smoke test (before touching the app)

```
curl <FunctionUrl>health
# -> {"success":true,"status":"ok",...}
```
A full Postman collection for the authed endpoints comes with Phase 6.
