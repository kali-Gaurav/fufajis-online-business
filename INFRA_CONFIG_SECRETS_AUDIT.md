# Fufaji — Infrastructure, Config & Secrets Audit + Migration Runbook

**Date:** 2026-06-21
**Scope:** Full stack — Flutter app, Firebase Functions, Firebase rules, infra (AWS S3 / pgbouncer), CI/CD, all secrets.
**Method:** Grounded entirely in the real repo (not the assumed variable names from the brief). Every secret value in this document is **masked**; the real values live only in your files and the providers' dashboards.

---

## 0. Executive summary

> **Production-readiness score: 28 / 100 — RED. Do not ship until the P0 items below are closed.**

The single biggest finding is not "configs are scattered" — it's that **live production secrets are currently published on the public internet.** Your GitHub repo `kali-Gaurav/fufajis-online-business` is **Public**, and it contains committed files with real, working credentials. Separately, your Flutter `.env` (with storage and cache credentials) is **bundled inside every APK** you distribute.

Centralising config is the right goal, but it is step 2. **Step 1 is to treat every secret listed here as compromised, rotate it, and remove it from the public surface.** No amount of "single source of truth" architecture helps while the old values are still valid and still public.

What's actually wired (corrected from the brief): **Supabase** (Postgres + Supabase S3) **and** a parallel **AWS** path (S3 `bucket-ofqh8w` ap-south-1 + Bedrock + `pg`), **Upstash Redis**, **Razorpay**, **Gemini**, **Twilio**, **WhatsApp Business**, **SendGrid**, **Stripe**, **Sentry**, **Firebase**.

---

## 1. Score breakdown

| Dimension | Score | Why |
|---|---|---|
| Secret confidentiality | 0 / 25 | Live secrets public on GitHub + `.env` shipped in APK + signing keystore public |
| Single source of truth | 5 / 15 | Same secret defined in 4+ files with **conflicting** values |
| Secret-management backend | 3 / 15 | Uses deprecated `functions.config()`; no Secret Manager; no Firebase Secrets |
| Config correctness | 5 / 15 | `key_secret == webhook_secret` bug; conflicting webhook secrets across files |
| Deployment automation | 8 / 15 | CI exists, but mixes `.ps1`/`.bat`/`.sh` and bakes secrets into committed scripts |
| Verification / observability | 7 / 15 | Sentry present, e2e test exists; no config/secret validation step |
| **Total** | **28 / 100** | |

---

## 2. Issues — classified

### 🔴 P0 — Launch blockers (secret exposure / breakage)

| # | Issue | Evidence | Exposure |
|---|---|---|---|
| P0-1 | **`functions/.runtimeconfig.json` committed to a PUBLIC repo** with live Twilio + Razorpay secrets | tracked since commit `b64604f` "Initial Production Ready Release" | Twilio `AC33d2…` + auth token `e1a6…`, Razorpay `key_secret`/`webhook_secret` `ieGG…` |
| P0-2 | **`scripts/setup_functions_config.bat` committed** with live WhatsApp + Twilio + Razorpay secrets | tracked, commit `37662bf` | WhatsApp token `EAASZ…` (full), Twilio auth token, Razorpay key_secret |
| P0-3 | **`LIVE_SETUP_GUIDE.md` + `firebase-deploy.sh` committed** with the same live secrets in plaintext | 7 + 3 secret-like hits | same as above |
| P0-4 | **`keystore_base64.txt` committed** — your Android release signing keystore, base64-encoded | tracked, 3726 bytes, `MIIK5AIBAz…` (PKCS#12) | Anyone can sign APKs that impersonate your app. `*.jks` is gitignored but the `.txt` bypassed it. |
| P0-5 | **Flutter `.env` is bundled into the APK** (`- .env` in `pubspec.yaml` assets, lines 6 **and** 145) and loaded via `dotenv.load(fileName: ".env")` | confirmed | Every APK leaks: `SUPABASE_S3_ACCESS_KEY`/`SECRET`, `UPSTASH_REDIS_REST_TOKEN` (full Redis access), `GEMINI_API_KEY`. Your own `.env.example` warns against exactly this. |
| P0-6 | **Razorpay `key_secret == webhook_secret`** (both `ieGG9Gcx…`) | `functions/.runtimeconfig.json` | The webhook secret was pasted into the key_secret slot. Payment capture/verification/refunds are almost certainly using the **wrong** secret → silent payment failures. |

### 🟠 P1 — Serious

| # | Issue | Evidence |
|---|---|---|
| P1-1 | **Conflicting webhook-secret values** across files: `ieGG…` (runtimeconfig) vs `Fufaji@Webhook2026!` (LIVE_SETUP_GUIDE line 162) vs placeholder (.bat). No single truth. |
| P1-2 | **Deprecated `functions.config()` everywhere** (`razorpay`, `twilio`, `whatsapp`, `aws`, `rds`). Google is removing runtime config; this will break a future deploy. Your chosen target (Firebase Secrets) requires migrating off it. |
| P1-3 | **Duplicate variable names for the same secret**: functions read both `functions.config().razorpay.*` **and** `process.env.RAZORPAY_API_KEY / RAZORPAY_API_SECRET / RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET / RAZORPAY_WEBHOOK_SECRET`. Five names, one credential. |
| P1-4 | **True secrets sitting client-side**: app reads `UPSTASH_REDIS_REST_TOKEN`, `SUPABASE_S3_SECRET_KEY`, `WHATSAPP_TOKEN` via dotenv. These must never be in a mobile client — they belong behind Cloud Functions. |
| P1-5 | **Twilio phone number is the demo value** `+15017122661` (Twilio's magic test number) — Twilio is not really configured. |

### 🟡 P2 — Improvements

| # | Issue |
|---|---|
| P2-1 | **Two storage stacks**: Supabase S3 (`.env`) and AWS S3 (`infra/s3`, `aws_services.js`, `bucket-ofqh8w`). Decide on one; the other is dead config/cost. |
| P2-2 | **Stripe present** (`stripe` dep, `StripePublishableKey`, server `stripe.secret_key`) — violates the project's no-Stripe rule (see memory). Remove or formally adopt. |
| P2-3 | **Two email paths**: SendGrid (`@sendgrid/mail`) and Twilio. Pick one. |
| P2-4 | `REDIS_REST_URL`/`REDIS_REST_TOKEN` **and** `UPSTASH_REDIS_REST_URL`/`UPSTASH_REDIS_REST_TOKEN` both defined — duplicate Redis config. |

### ⚪ P3 — Cleanup

| # | Issue |
|---|---|
| P3-1 | `build.log`, `build_failure.log`, `build_final.log` committed to the repo. |
| P3-2 | `.env` listed twice in `pubspec.yaml` assets. |
| P3-3 | `firebase-deploy.sh`, `*.ps1`, `*.bat` overlap — three deploy mechanisms doing similar things. |

---

## 3. Single source of truth — target architecture

```
LOCAL DEV          .env  (gitignored, NEVER an APK asset)  ── flutter run --dart-define-from-file
                   functions/.env.local (gitignored)        ── functions local emulator only

CI / CD            GitHub Secrets  ──► used by .github/workflows for build + firebase deploy

RUNTIME (server)   Firebase Secret Manager (firebase functions:secrets:set)
                   read in code via defineSecret()  ── Razorpay secret, Twilio, WhatsApp,
                                                        Gemini, RDS, AWS, SendGrid, webhook secret

RUNTIME (client)   ONLY public-by-design values reach the app, injected at build time via
                   --dart-define (RAZORPAY_KEY_ID, SENTRY_DSN, SUPABASE_URL, SUPABASE_ANON_KEY).
                   No server secret, no storage key, no Redis token ever ships in the APK.
```

Rule of thumb: **if leaking a value lets someone spend your money or read/write your data, it is a Firebase Secret + GitHub Secret — never a `--dart-define` and never a bundled asset.**

---

## 4. 🔴 P0 EMERGENCY RUNBOOK — rotate + purge (run one at a time)

> Do this **first**, before any architecture work. The exposed values are burned — rotation is mandatory, not optional. Commands are PowerShell-friendly for your Windows machine.

### 4a. Rotate every exposed credential at its source (manual, in each dashboard)

Rotate these **now** (old values are public). After rotating you'll set the *new* values in Steps 5–6.

1. **Razorpay** → Dashboard ▸ Settings ▸ API Keys ▸ **Regenerate** key. Then Settings ▸ Webhooks ▸ regenerate the **webhook secret**. (Exposed: `key_secret` + `webhook_secret`.)
2. **Twilio** → Console ▸ Account ▸ **Auth Token** ▸ rotate. (Exposed: `AC33d2…` + auth token.)
3. **WhatsApp / Meta** → revoke the leaked permanent token `EAASZ…` and issue a new System User token.
4. **Gemini** → Google AI Studio ▸ delete the leaked API key, create a new one.
5. **Supabase** → rotate the S3 access/secret keys; if the `anon` key was treated as secret, rotate and confirm RLS is on.
6. **Upstash** → rotate the Redis REST token.
7. **AWS** (if the AWS path is live) → rotate the IAM access key used by `aws_services.js`.
8. **Android signing key** → because the keystore is public, anyone can sign as you. If the app is **not yet on Play Store**, generate a brand-new keystore. If it **is** live and you used Play App Signing, contact Google Play support about an upload-key reset. Treat the public keystore as compromised.

### 4b. Stop the bleeding in git (purge from working tree + ignore)

```powershell
git rm --cached functions/.runtimeconfig.json
```
```powershell
git rm --cached scripts/setup_functions_config.bat
```
```powershell
git rm --cached LIVE_SETUP_GUIDE.md
```
```powershell
git rm --cached firebase-deploy.sh
```
```powershell
git rm --cached keystore_base64.txt
```
```powershell
git rm --cached build.log build_failure.log build_final.log
```

Add them to `.gitignore` (append these lines):
```
functions/.runtimeconfig.json
keystore_base64.txt
LIVE_SETUP_GUIDE.md
firebase-deploy.sh
scripts/setup_functions_config.bat
*.log
```

Commit:
```powershell
git commit -m "security: remove leaked secrets and signing key from repo"
```

### 4c. Remove the `.env` from the APK (P0-5)

Edit `pubspec.yaml` — delete **both** `- .env` lines (line 6 and line 145). The app must stop bundling it. (See Step 7 for how the app reads public config instead.)

### 4d. Purge from git **history** (the values stay public until you do this)

`git rm` only removes them going forward — they remain in every past commit on GitHub. Use `git filter-repo` (preferred):

```powershell
pip install git-filter-repo
```
```powershell
git filter-repo --invert-paths --path functions/.runtimeconfig.json --path scripts/setup_functions_config.bat --path LIVE_SETUP_GUIDE.md --path firebase-deploy.sh --path keystore_base64.txt
```
```powershell
git push origin --force --all
```
```powershell
git push origin --force --tags
```

> Even after history rewrite, assume the secrets were scraped. Rotation (4a) is what actually protects you. Consider making the repo **Private** (GitHub ▸ Settings ▸ Danger Zone) regardless.

---

## 5. Migrate server secrets → Firebase Secret Manager (run one at a time)

> Each command prompts you to paste the value interactively, so secrets never touch your shell history or this document. Enter the **newly rotated** values from Step 4a. Run from the repo root.

```powershell
firebase functions:secrets:set RAZORPAY_KEY_ID
```
```powershell
firebase functions:secrets:set RAZORPAY_KEY_SECRET
```
```powershell
firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
```
```powershell
firebase functions:secrets:set TWILIO_ACCOUNT_SID
```
```powershell
firebase functions:secrets:set TWILIO_AUTH_TOKEN
```
```powershell
firebase functions:secrets:set TWILIO_PHONE_NUMBER
```
```powershell
firebase functions:secrets:set WHATSAPP_TOKEN
```
```powershell
firebase functions:secrets:set WHATSAPP_PHONE_ID
```
```powershell
firebase functions:secrets:set WHATSAPP_VERIFY_TOKEN
```
```powershell
firebase functions:secrets:set GEMINI_API_KEY
```
```powershell
firebase functions:secrets:set RDS_CONNECTION_STRING
```
```powershell
firebase functions:secrets:set AWS_S3_ACCESS_KEY
```
```powershell
firebase functions:secrets:set AWS_S3_SECRET_KEY
```
```powershell
firebase functions:secrets:set SENDGRID_API_KEY
```

Confirm what's stored (names only, never values):
```powershell
firebase functions:secrets:get RAZORPAY_KEY_SECRET
```
```powershell
gcloud secrets list --project=fufaji-online-business
```

> ⚠️ **Code change required (P1-2).** Firebase Secrets are **not** readable via `functions.config()`. Each function that uses a secret must declare it with `defineSecret('NAME')` and attach it (`runWith({ secrets: [...] })` v1, or `{ secrets: [...] }` in the v2 options) and read it from `process.env.NAME`. This is the one remaining code task — your 115 KB `functions/index.js` plus `aws_services.js` reference `functions.config().{razorpay,twilio,whatsapp,aws,rds}`. Want me to do that wiring as a follow-up? It's the only thing standing between these secrets and a working deploy.

---

## 6. Set CI/CD secrets → GitHub Secrets (run one at a time)

> Requires the GitHub CLI (`gh auth login` once). Each command prompts for the value. Run from the repo root.

```powershell
gh secret set FIREBASE_TOKEN
```
```powershell
gh secret set RAZORPAY_KEY_ID
```
```powershell
gh secret set RAZORPAY_KEY_SECRET
```
```powershell
gh secret set RAZORPAY_WEBHOOK_SECRET
```
```powershell
gh secret set SENTRY_DSN
```
```powershell
gh secret set SUPABASE_URL
```
```powershell
gh secret set SUPABASE_ANON_KEY
```
```powershell
gh secret set ANDROID_KEYSTORE_BASE64
```
```powershell
gh secret set ANDROID_KEYSTORE_PASSWORD
```
```powershell
gh secret set ANDROID_KEY_ALIAS
```

List them back (names only):
```powershell
gh secret list
```

> Then update `.github/workflows/*.yml` to read these via `${{ secrets.NAME }}` and pass app-facing public values as `--dart-define` at build time. The CI must reconstruct the keystore from `ANDROID_KEYSTORE_BASE64` at build, never from a committed file.

---

## 7. Flutter app — public config only (no secrets in the APK)

Replace the `.env`-as-asset pattern. The app should receive only **public-by-design** values at build time:

```powershell
flutter build apk --release --dart-define=RAZORPAY_KEY_ID=rzp_live_xxx --dart-define=SENTRY_DSN=https://xxx --dart-define=SUPABASE_URL=https://xxx --dart-define=SUPABASE_ANON_KEY=xxx
```

For local dev, keep a gitignored `dart_defines.json` and run `flutter run --dart-define-from-file=dart_defines.json`.

Everything currently read in the app that is a **true secret** — `UPSTASH_REDIS_REST_TOKEN`, `SUPABASE_S3_SECRET_KEY`, `WHATSAPP_TOKEN`, `LIVE_KEY_SECRET` — must be removed from the client and accessed only through a Cloud Function that holds the secret server-side.

---

## 8. End-to-end verification (run one at a time, after Steps 4–7)

```powershell
firebase deploy --only functions
```
```powershell
firebase functions:log --only <yourPaymentWebhookFn> | Select-String "secret|razorpay|error"
```
Razorpay (sends a test event you can verify the signature against):
```
Razorpay Dashboard ▸ Webhooks ▸ Send test webhook  →  confirm 200 + signature OK in logs
```
```powershell
grep -rn "\.env" pubspec.yaml   # must return nothing
```
```powershell
git grep -nE "rzp_live_|EAASZ|AC[0-9a-f]{32}|-----BEGIN" $(git rev-parse HEAD)   # must return nothing
```
Integration smoke test already in the repo:
```powershell
node scripts/e2e_integration_test.js
```

Pass criteria: ✅ functions deploy with secrets, ✅ Razorpay test webhook verifies, ✅ no `.env` asset, ✅ no secret patterns anywhere in tracked files, ✅ e2e green.

---

## 9. Full config & secret inventory

Legend — **Where it should live:** `FBSecret` = Firebase Secret Manager, `GHSecret` = GitHub Secret, `dart-define` = public build-time value, `client?` = currently in client but shouldn't be.

| Variable | Used in | Real source today | Should live in | Status |
|---|---|---|---|---|
| RAZORPAY_KEY_ID / LIVE_API_KEY | app + functions | `.env`, runtimeconfig, process.env | dart-define + FBSecret | dup names (P1-3) |
| RAZORPAY_KEY_SECRET / LIVE_KEY_SECRET | functions (+app getter!) | runtimeconfig (WRONG value), process.env | FBSecret | 🔴 P0-6 wrong + exposed |
| RAZORPAY_WEBHOOK_SECRET | app + functions | runtimeconfig / guide / .bat | FBSecret | 🔴 conflicting values P1-1 |
| TWILIO_ACCOUNT_SID / AUTH_TOKEN | functions | runtimeconfig, .bat | FBSecret | 🔴 P0 exposed |
| TWILIO_PHONE_NUMBER | functions | runtimeconfig (`+15017122661` demo) | FBSecret | 🟠 P1-5 demo value |
| WHATSAPP_TOKEN / PHONE_ID / VERIFY_TOKEN | app + functions | .bat, functions.config | FBSecret (token); verify_token FBSecret | 🔴 P0 token exposed + client P1-4 |
| GEMINI_API_KEY | app + functions | `.env`, process.env | FBSecret | 🔴 P0 in APK |
| RDS_CONNECTION_STRING | functions | functions.config().rds / process.env | FBSecret | 🟠 dup access |
| AWS_S3_ACCESS_KEY / SECRET_KEY | functions + infra | functions.config().aws | FBSecret | 🟠 + dup with Supabase S3 (P2-1) |
| SUPABASE_URL / ANON_KEY | app | `.env` (in APK) | dart-define (public) | move off asset |
| SUPABASE_S3_ACCESS_KEY / SECRET_KEY | app(!) | `.env` (in APK) | FBSecret, server-only | 🔴 P0-5 |
| UPSTASH_REDIS_REST_URL / TOKEN | app(!) | `.env` (in APK) | FBSecret, server-only | 🔴 P0-5 |
| REDIS_REST_URL / TOKEN | app | `.env` | remove (dup of Upstash) | P2-4 |
| SENTRY_DSN | app | `.env` | dart-define (public) | ok once off asset |
| SENDGRID (api key) | functions | code (dep present) | FBSecret | P2-3 pick one email path |
| STRIPE_PUBLISHABLE_KEY / secret | app + functions | `.env` / functions.config | remove (policy) | P2-2 |
| WEBHOOK_RAZORPAY_URL, SHOP_LAT/LNG, DELIVERY_RADIUS_KM | app | `.env` | dart-define / Remote Config | non-secret, ok |
| Android keystore | CI/build | `keystore_base64.txt` (committed!) | GHSecret base64 | 🔴 P0-4 |

---

## 10. Recommended order of operations

1. **Step 4a** — rotate every exposed credential (today).
2. **Step 4b–4d** — purge from repo + history, make repo private, remove `.env` from APK.
3. **Step 5** — load rotated secrets into Firebase Secret Manager.
4. **Code wiring** — migrate `functions.config()` → `defineSecret()` (offer above).
5. **Step 6** — GitHub Secrets + workflow update.
6. **Step 7** — app reads public config via `--dart-define`; move client-side secrets behind functions.
7. **Step 8** — verify end-to-end; rebuild + redistribute APK (the old APK still leaks).
8. Then "Module 11: Production Deployment + CI/CD" as you planned.

> The architecture half of your brief (single source of truth, automated setup) is sound and reflected in Sections 3, 5, 6. But it only delivers value once the emergency in Section 4 is resolved — centralising secrets that are already public just organises a breach.
