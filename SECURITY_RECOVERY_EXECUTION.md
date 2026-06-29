# Fufaji — Security Recovery + Secret Migration: Execution Plan

**Date:** 2026-06-21
**Mode:** Incident response (not deployment hardening).
**Companion doc:** `INFRA_CONFIG_SECRETS_AUDIT.md` (full findings + masked inventory + command runbook).
**Stack decision (Gaurav, 2026-06-21):** keep **both** Supabase and AWS for now — so every secret below is migrated as-is; consolidation deferred.

Ownership legend: **[G]** = Gaurav runs it (dashboards / native Windows terminal). **[C]** = Claude can do it in-repo. Git *writes* are always **[G]** — running them from the agent sandbox corrupts the index on this Windows mount.

---

## Step 0 — Recover the git index (do this first, [G])

My earlier `git rm --cached` from the sandbox corrupted `.git/index` and left a stale `.git/index.lock`. **No commits, history, or files were lost** — only the index needs rebuilding. In your Windows terminal at the repo root:

```powershell
del .git\index.lock
```
```powershell
del .git\index
```
```powershell
git reset
```
```powershell
git status
```

`git status` should show a clean tree plus two new untracked files (`INFRA_CONFIG_SECRETS_AUDIT.md`, `SECURITY_RECOVERY_EXECUTION.md`). If so, you're recovered.

---

## Module A — Emergency lockdown (TODAY, mostly [G])

### A1. Make the repo private [G]
GitHub ▸ repo ▸ Settings ▸ General ▸ Danger Zone ▸ **Change visibility → Private**.

### A2. Rotate every exposed credential at its source [G]
All of these are public-burned. Regenerate, then you'll load the new values in Module B.

| Provider | What to rotate | Where |
|---|---|---|
| Razorpay | API key **secret** + **webhook secret** (set as two *different* values — see A5) | Dashboard ▸ Settings ▸ API Keys / Webhooks |
| Twilio | Auth token | Console ▸ Account |
| Meta / WhatsApp | Revoke leaked token `EAASZ…`, issue new System User token | developers.facebook.com |
| Gemini | Delete + recreate API key | aistudio.google.com |
| Supabase | S3 access/secret keys (+ confirm RLS on) | supabase.com/dashboard |
| Upstash | Redis REST token | console.upstash.com |
| AWS | IAM access key used by `aws_services.js` | console.aws.amazon.com |

### A3. Untrack the leaked files [G] (native Windows terminal — NOT the agent)
```powershell
git rm --cached functions/.runtimeconfig.json scripts/setup_functions_config.bat LIVE_SETUP_GUIDE.md firebase-deploy.sh keystore_base64.txt build.log build_failure.log build_final.log
```

### A4. Add them to `.gitignore` [C or G]
Append:
```
functions/.runtimeconfig.json
keystore_base64.txt
LIVE_SETUP_GUIDE.md
firebase-deploy.sh
scripts/setup_functions_config.bat
*.log
```
Then commit: `git commit -m "security: stop tracking leaked secret files"`

### A5. Fix the Razorpay payment bug (config, not code) [G]
**Confirmed in code** (`functions/index.js`): the design is correct — webhook verification (line 32) uses `webhook_secret`; payment-signature verification (line 254) and order/refund API auth (lines 952/2297/2385) use `key_secret`. The breakage is that stored `key_secret` currently holds the *webhook* secret value, so payment verification rejects valid payments and order/refund API calls 401. When you regenerate in A2, set the **real key secret** distinctly from the webhook secret.

### A6. Purge git history + force-push [G] (native terminal)
```powershell
pip install git-filter-repo
git filter-repo --invert-paths --path functions/.runtimeconfig.json --path scripts/setup_functions_config.bat --path LIVE_SETUP_GUIDE.md --path firebase-deploy.sh --path keystore_base64.txt
git push origin --force --all
git push origin --force --tags
```

### A7. Regenerate the Android signing key [G]
The keystore was public → compromised. If not yet on Play Store, create a fresh keystore. If live with Play App Signing, contact Google Play about an upload-key reset. Store the new keystore base64 only in GitHub Secrets (Module B), never in the repo.

---

## Module B — Secret migration (after A2 rotation, [G] runs, [C] preps)

Full one-command-at-a-time lists are in `INFRA_CONFIG_SECRETS_AUDIT.md` §5 (Firebase) and §6 (GitHub). Because we're keeping both stacks, the Firebase Secret set includes **both** Supabase-server and AWS secrets:

Server (Firebase Secret Manager): `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`, `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_ID`, `WHATSAPP_VERIFY_TOKEN`, `GEMINI_API_KEY`, `RDS_CONNECTION_STRING`, `AWS_S3_ACCESS_KEY`, `AWS_S3_SECRET_KEY`, `SUPABASE_S3_ACCESS_KEY`, `SUPABASE_S3_SECRET_KEY`, `UPSTASH_REDIS_REST_TOKEN`, `SENDGRID_API_KEY`.

CI (GitHub Secrets): `FIREBASE_TOKEN`, app-public values, `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`.

App (public, via `--dart-define` only): `RAZORPAY_KEY_ID`, `SENTRY_DSN`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `FIREBASE_*`.

---

## Module C — Code refactor (mostly [C], after B)

> Sequenced **after** secrets exist in Secret Manager, because the wiring reads them. This is the one large code task. I (Claude) can do it on request.

### C1. Functions: `functions.config()` → `defineSecret()` [C]
Every function that uses `functions.config().{razorpay,twilio,whatsapp,aws,rds}` (across `functions/index.js` ~115 KB and `aws_services.js`) must declare and attach its secrets:
```js
const { defineSecret } = require('firebase-functions/params');
const razorpayKeySecret    = defineSecret('RAZORPAY_KEY_SECRET');
const razorpayWebhookSecret = defineSecret('RAZORPAY_WEBHOOK_SECRET');

exports.verifyPaymentSignature = onCall(
  { secrets: [razorpayKeySecret] },
  async (req) => { const secret = process.env.RAZORPAY_KEY_SECRET; /* ... */ }
);
```
Also collapse the duplicate name set (`process.env.RAZORPAY_API_KEY/API_SECRET/KEY_ID/KEY_SECRET/WEBHOOK_SECRET` + `functions.config().razorpay.*`) down to one canonical name per credential.

### C2. App: stop shipping `.env` in the APK [C]
- Remove the two `- .env` lines from `pubspec.yaml` (lines 6 and 145).
- Replace `dotenv.load(fileName: ".env")` in `lib/main.dart:69` with `--dart-define` reads (`String.fromEnvironment`) for the public values only.
- Remove all client reads of true secrets (`UPSTASH_REDIS_REST_TOKEN`, `SUPABASE_S3_SECRET_KEY`, `WHATSAPP_TOKEN`, `LIVE_KEY_SECRET`) and route those operations through Cloud Functions that hold the secrets.

> ⚠️ Do C2's pubspec/main.dart edits together — removing the asset without the code change breaks `dotenv.load()` and the build.

### C3. Update CI workflows [C]
`.github/workflows/*.yml` read secrets via `${{ secrets.* }}`, reconstruct the keystore from `ANDROID_KEYSTORE_BASE64` at build, and inject app-public values as `--dart-define`. No secret in any committed file.

---

## Verification (after C, [G] runs)
See `INFRA_CONFIG_SECRETS_AUDIT.md` §8. Pass = functions deploy with secrets ✅, Razorpay test webhook verifies ✅, a real test payment verifies + refunds ✅, `.env` not an asset ✅, `git grep` finds no secret patterns ✅, e2e green ✅. Then rebuild + redistribute the APK (old APKs still leak).

---

## Ownership at a glance
| Module | Who | Blocking dependency |
|---|---|---|
| Step 0 index recovery | [G] | none — do first |
| A1 private / A2 rotate / A3,A6 git / A7 keystore | [G] | Step 0 for git parts |
| A4 .gitignore / A5 payment secret note | [C]/[G] | A2 for the real key secret |
| B Firebase + GitHub secrets | [G] (Claude preps lists) | A2 rotation |
| C1 functions wiring / C2 app / C3 CI | [C] | B (secrets must exist) |
| Verification | [G] | C complete |

**Recommended next action:** run Step 0, then start Module A. Tell me when secrets are loaded (Module B done) and I'll execute Module C.
