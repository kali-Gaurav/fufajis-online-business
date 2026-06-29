# S3 Storage Lifecycle Policy

Defines automatic storage-class transitions and expirations for the
Fufaji Store S3 bucket (`bucket-ofqh8w`, region `ap-south-1`), so
object storage costs stay proportional to how often each kind of file
is actually accessed — without any manual cleanup.

The policy lives at `infra/s3/lifecycle-policy.json` and is applied
with `infra/s3/apply_lifecycle_policy.js`. Prefixes match the
key layout defined by `S3Paths` in
`lib/services/s3_storage_service.dart`.

## Rules and rationale

| Rule ID | Prefix | What happens | Why |
|---|---|---|---|
| `abort-incomplete-multipart-uploads` | (whole bucket) | Incomplete multipart uploads are aborted after 7 days | Failed/abandoned uploads otherwise sit in the bucket forever, billed at full price with nothing to show for it |
| `backups-expire-and-tier` | `backups/` | → Standard-IA at 30 days, **deleted** at 90 days | Backups (`S3Paths.backup`) are a short-term safety net, not long-term archival (Postgres is the source of truth). 90 days is enough to recover from a bad migration without paying for indefinite storage |
| `user-docs-tier-to-ia` | `users/` | → Standard-IA at 180 days | Covers `users/{uid}/avatar/...` and `users/{uid}/kyc/...`. Most avatars/KYC docs are uploaded once and rarely re-read after onboarding; Standard-IA keeps them instantly retrievable (no restore step) at ~45% lower storage cost |
| `order-financial-docs-tier-to-ia` | `orders/` | → Standard-IA at 180 days | Covers `delivery-proof/`, `bills/`, `invoices/`. These must remain retrievable on demand (e.g. a customer re-downloading an invoice), so we use Standard-IA rather than Glacier (which requires a restore request before the object can be read) |
| `marketing-assets-expire-and-tier` | `marketing/` | → Standard-IA at 30 days, **deleted** at 365 days | Campaign assets (`S3Paths.marketingAsset`) are time-bound; after a year a campaign is over and its banners/creatives are no longer needed |
| `product-and-vendor-media-intelligent-tiering` | `products/` | → Intelligent-Tiering from day 0 | Product images (`S3Paths.productImage`) have very uneven access patterns — popular SKUs are hit constantly, discontinued ones almost never. Intelligent-Tiering automatically moves each object between frequent/infrequent access tiers with no retrieval latency penalty, so no manual age-based rule is needed |
| `vendor-media-intelligent-tiering` | `vendors/` | → Intelligent-Tiering from day 0 | Same reasoning as above for vendor banners/logos (`S3Paths.vendorBanner`, `S3Paths.vendorLogo`) |
| `orphaned-staging-uploads-expire` | `uploads/` | **deleted** at 45 days | Generic presigned uploads for non-admin users land under `uploads/{uid}/...` (see `S3StorageService.scopedKey`). Anything still sitting there after 45 days was never moved/referenced by the app and is safe to clean up |

None of the rules use the `GLACIER`/`DEEP_ARCHIVE` storage classes,
because every prefix in this bucket can be requested on demand via a
presigned URL (`getS3DownloadUrl`) — Glacier-class objects require an
explicit restore request before they're readable, which would break
those flows with a confusing delay/error.

## Applying the policy

```bash
cd infra/s3
npm install
cp .env.example .env   # fill in the same AWS creds used by functions/aws_services.js

npm run lifecycle:dry     # preview: prints current + proposed config, no changes
npm run lifecycle:apply    # apply lifecycle-policy.json to the bucket
npm run lifecycle:verify   # fetch and print the bucket's current lifecycle config
```

The script is idempotent — re-running `lifecycle:apply` after editing
`lifecycle-policy.json` simply replaces the bucket's lifecycle
configuration with the new version.

## Updating the policy

If a new `S3Paths` prefix is added to
`lib/services/s3_storage_service.dart`, consider whether it needs its
own rule here:

- **Ephemeral/staging data** → short expiration (like `uploads/` or `backups/`).
- **User-generated media that's actively browsed** (product/vendor images) → Intelligent-Tiering from day 0.
- **Documents retrieved occasionally on demand** (invoices, KYC, avatars) → Standard-IA after ~6 months, no expiration.
- **Campaign/marketing content** → Standard-IA + expiration tied to campaign lifetime.

Add the rule to `infra/s3/lifecycle-policy.json`, document it in the
table above, and re-run `npm run lifecycle:apply`.
