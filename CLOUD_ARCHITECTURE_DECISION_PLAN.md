# Fufaji — Cloud Architecture Decision Plan

**Goal:** one clear, free (no-card-where-possible) cloud stack so the app is fully functional and the APK can be built and released — with no duplicate services causing bugs.

**Date:** 2026-06-21
**Method:** audited from `pubspec.yaml`, `.env.example`, `lib/services/`, `functions/`, `supabase/`, `infra/`. Free-tier facts web-verified June 2026.

---

## 1. The headline problem: you have 3 databases

| Database | Wired into | State |
|---|---|---|
| **Firestore** | **303 lib files** | LIVE — real source of truth |
| Supabase Postgres | 9 lib files + 17 SQL migrations | Full parallel schema, barely used |
| AWS RDS (Lightsail Postgres) | 19 lib files (via Functions proxy) | Accessed through `aws_services.js`, costs money |

Three databases holding overlapping data (orders, inventory, payments, delivery) is the structural reason your audits keep finding "competing order engines," "unreconciled stock surfaces," and "5 order engines." **The single most valuable decision is to pick ONE database and delete the other two from the code path.**

Recommendation: **keep Firestore, drop Supabase and AWS RDS as databases.** Firestore is where 303 files and all live data already are; migrating off it is months of risky rewrite for no functional gain. Supabase's relational schema is elegant but unused; AWS RDS Lightsail also costs money every month.

---

## 2. Recommended target stack (the short version)

| Capability | Use this | Free? | Drop these |
|---|---|---|---|
| Database | **Firestore** (Spark) | ✅ no card | Supabase, AWS RDS |
| Auth | **Firebase Auth** | ✅ no card | Supabase Auth tables |
| Files / media | **AWS S3** | ✅ free tier* | Firebase Storage (now needs Blaze) |
| Backend compute | **AWS Lambda + Function URLs** | ✅ perpetual free | Firebase Functions (needs Blaze) |
| Secrets | **AWS SSM Parameter Store** | ✅ free | `.env` in APK, Firebase Secret Mgr |
| Push notifications | **FCM** | ✅ no card | — |
| WhatsApp | **Meta WhatsApp Business API** | ✅ free convos tier | — |
| SMS (optional) | **Twilio** | 💲 pay-per-msg | use only for OTP/critical |
| Email (invoices) | **SendGrid** | ✅ 100/day free | — |
| AI / LLM | **Gemini** (free) | ✅ free tier | AWS Bedrock (keep only if needed) |
| On-device scan/OCR | **Google ML Kit** | ✅ on-device free | — |
| Payments | **Razorpay** (+UPI) | 💲 per-txn | **Stripe (remove)** |
| Maps | **flutter_map + OpenStreetMap** | ✅ no card | Google Maps (needs billing) |
| Caching | **Upstash Redis** | ✅ no card | keep only if actually used |
| Ads | **AdMob** | ✅ | — |
| Analytics | **Firebase Analytics** | ✅ no card | — |
| Remote config | **Firebase Remote Config** | ✅ no card | — |
| App integrity | **Firebase App Check** | ✅ no card | — |
| Crash + OTA | **Sentry + Shorebird** | ✅ free tiers | — |

\* S3 free tier is 5 GB for 12 months, then ~$0.02/GB/month — pennies. Your AWS account already exists, so no new signup.

**Net effect:** Firebase stays for everything that's free without a card (data, auth, push, config, analytics). AWS is used *only* for the compute + storage + secrets layer that Firebase wanted to charge for. Three databases collapse to one. Two payment gateways collapse to one.

---

## 3. Capability-by-capability detail

### Database — Firestore
- **Have:** Firestore (live), Supabase Postgres (idle schema), AWS RDS (proxy).
- **Choose:** Firestore. **Required:** rip Supabase + RDS calls out of the 28 files that reference them; route those reads/writes to Firestore. Keep the Supabase `.sql` migrations as documentation only.
- **Ceiling:** Spark gives 20,000 writes + 50,000 reads/day free. Fine for launch; watch as you grow. This is the one limit that could later force Blaze — but on *usage*, not as a wall.

### Authentication — Firebase Auth
- **Have:** Firebase Auth + Google/Apple sign-in + local biometric + TOTP. Live.
- **Choose:** Firebase Auth. Free on Spark, unlimited. **Required:** nothing — keep as is. The Lambda backend will verify Firebase ID tokens with `firebase-admin`, so auth stays unified.

### File / media storage — AWS S3
- **Have:** Firebase Storage (live today) + AWS S3 (`bucket-ofqh8w`, via proxy).
- **Problem:** Firebase Storage requires Blaze from **Feb 3, 2026** — on Spark, all bucket calls fail with 402/403.
- **Choose:** AWS S3 for all bill photos, delivery proofs, invoices, KYC. **Required:** move uploads to presigned-URL flow (already designed in `s3_storage_service.dart`); migrate any existing Firebase Storage objects to S3.

### Backend compute — AWS Lambda
- **Have:** 34 Firebase Functions (15 callable, 2 webhooks, 9 scheduled, 11 Firestore triggers) — **undeployable without Blaze.**
- **Choose:** one Express app on AWS Lambda behind a **Function URL** (free; avoids API Gateway's 12-month limit). Scheduled jobs → **EventBridge** (free). **The 11 Firestore triggers get folded into the callable endpoints that cause them** (e.g. `POST /orders` writes the order *and* deducts stock *and* queues the notification in one transaction) — this also fixes the multi-engine/stock bugs. **Required:** build `backend/`, port logic, deploy.

### Secrets — AWS SSM Parameter Store
- **Have:** secrets in `.env`, shipped inside the APK, leaked publicly. 🔴
- **Choose:** SSM Parameter Store (free), loaded by Lambda at cold start. **Required:** rotate every leaked key, store in SSM, stop bundling `.env` in `pubspec.yaml`, move public config to `--dart-define`.

### Push / SMS / WhatsApp / Email
- **Push — FCM:** keep, free, unlimited. No change.
- **WhatsApp — Meta Business API:** keep as the primary customer channel (cheapest in India). Service code exists (`meta_whatsapp_service.dart`).
- **SMS — Twilio:** keep only for OTP / critical alerts (SMS costs money everywhere). For everything else prefer WhatsApp + push.
- **Email — SendGrid:** keep for invoices/reports; free tier 100 emails/day.

### AI / LLM
- **Have:** Gemini (primary), AWS Bedrock Claude (fallback), `firebase_ai`, ML Kit.
- **Choose:** **Gemini** as the single cloud LLM (generous free tier). **ML Kit** stays for on-device barcode/text/image (free, offline). **Bedrock:** keep only if Gemini proves insufficient for Hindi/Hinglish OCR — otherwise drop it to remove an AWS cost + dependency.

### Payments — Razorpay only
- **Have:** Razorpay (live primary, with UPI), Stripe (fallback).
- **Choose:** **Razorpay.** **Remove Stripe** — it's unused, violates your own no-Stripe rule, and `key_secret == webhook_secret` is currently breaking verification. **Required:** delete `stripe_service.dart` + `flutter_stripe` dep; fix the Razorpay webhook secret in SSM.

### Maps — OpenStreetMap to stay card-free
- **Have:** Google Maps (`google_maps_flutter`) + `flutter_map` (OSM) + geolocator.
- **Choose:** **flutter_map + OpenStreetMap** — Google Maps Platform requires a billing account (a card). You already have `flutter_map`. **Required:** route map screens through flutter_map; drop `google_maps_flutter` unless you accept Google billing.

### Caching, Ads, Analytics, Remote Config, App Check, Crash/OTA
- **Upstash Redis:** free, no card — keep *only if* lightning-deals caching is actually used; otherwise remove to cut a moving part.
- **AdMob, Firebase Analytics, Remote Config, App Check:** all free, no card — keep.
- **Sentry + Shorebird:** free tiers — keep for crash reporting + over-the-air updates.

---

## 4. What gets deleted (the consolidation list)

1. **Supabase** — as a runtime database (keep SQL as design docs).
2. **AWS RDS / Lightsail Postgres** — redundant + paid.
3. **Firebase Functions** — replaced by Lambda.
4. **Firebase Storage** — replaced by S3 (Blaze-gated now anyway).
5. **Stripe** — unused, rule-violating, broken secret.
6. **Google Maps SDK** — swap to OSM to avoid a billing account.
7. **AWS Bedrock** — optional; drop unless Gemini falls short.
8. **`.env` in the APK** — the security hole.

---

## 5. Build order (each step independently shippable)

1. **Security lockdown** — stop bundling `.env`, move public config to `--dart-define`, rotate all leaked keys into SSM, make GitHub repo private. *(blocks a safe release)*
2. **Database consolidation** — route the 28 Supabase/RDS call sites to Firestore.
3. **AWS Lambda backend** — Express on Lambda + Function URL, secrets from SSM, schedules on EventBridge.
4. **Fold triggers** into endpoints (order/payment/stock first).
5. **Rewire the app** — swap ~25 `httpsCallable` calls to HTTP-to-Lambda with the Firebase ID token.
6. **Trim** — remove Stripe, Google Maps, Bedrock, Firebase Storage, Supabase/RDS deps.
7. **Build + release APK.**

**Division of labour:** I write all code and exact commands. You run anything that touches a live console — key rotation, AWS deploy, GitHub settings — because secrets shouldn't pass through me and git history can't be safely rewritten from here.

---

## 6. Cost reality check

- **No card needed:** Firebase (Spark), Gemini, Upstash, OSM, AdMob, Sentry, Shorebird.
- **Card already on file (your existing AWS account):** Lambda, S3, SSM, EventBridge — all within perpetual/12-month free tiers ≈ **$0/month** at your scale.
- **Pay-per-use (no upfront barrier):** Razorpay (per txn), Twilio (per SMS), SendGrid (free under 100/day).

The only thing that could ever generate a bill is **usage growth** — Firestore past 50K reads/day, S3 past 5 GB, Lambda past 1M calls/month — not the act of setting any of this up.
