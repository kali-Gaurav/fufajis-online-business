# Postgres Backup & Restore Testing

This document describes the automated logical backup of the Supabase/RDS
Postgres database (`functions/pg_backup.js`) and how to verify a backup is
restorable (`scripts/pg-backup-restore-test/`).

It is the Postgres-side counterpart to `dailyFirestoreBackup`
(`functions/index.js`), which exports Firestore to GCS.

## What gets backed up

`dailyPostgresBackup` (Cloud Scheduler, `30 20 * * *` Asia/Kolkata — 30
minutes after the Firestore export) runs `SELECT * FROM <table>` for every
table in `BACKUP_TABLES` (see `functions/pg_backup.js`), writes each table as
newline-delimited JSON, gzips it, and uploads to:

```
s3://<aws.s3_bucket>/backups/postgres/<timestamp>/<table>.json.gz
s3://<aws.s3_bucket>/backups/postgres/<timestamp>/manifest.json
```

`manifest.json` records, per table: row count, S3 key, gzipped size, and
status (`ok` or `error` — a single table failing, e.g. due to a renamed
column after a migration, does not abort the rest of the backup).

Backed-up tables (kept in sync with `docs/POSTGRES_SCHEMA.md`):

`users`, `categories`, `products`, `addresses`, `inventory`,
`inventory_logs`, `inventory_events`, `inventory_versions`,
`change_requests`, `automation_rules`, `bulk_operations`, `saved_queries`,
`package_processing`, `orders`, `order_items`, `order_status_history`,
`delivery_tracking`, `coupons`, `reviews`, `wallet_transactions`,
`notifications`, `support_tickets`, `kyc_documents`, `audit_logs`,
`migration_runs`.

## Why JSON export instead of `pg_dump`?

Cloud Functions' managed Node runtime does not include the `pg_dump`/`psql`
binaries, and shelling out to arbitrary binaries isn't supported in the
default Node 18/20 runtime. A per-table `SELECT * FROM` export via the
existing `getPgPool()` connection:

- requires no extra runtime dependencies beyond `pg` (already a dependency),
- is naturally per-table, so one table's schema drift doesn't break the
  whole backup,
- produces a format (`ndjson.gz`) that's trivial to inspect, diff, or
  selectively restore.

This is a **logical, application-level backup** — a safety net for "oops we
deleted/corrupted data" and a restore-test target. It is **not** a
replacement for AWS RDS automated snapshots / point-in-time recovery (PITR),
which should be enabled separately at the infrastructure level (see
"Infrastructure-level backups" below) for full disaster recovery (e.g.
"restore the whole instance to 14:32 yesterday").

## Status logging

Every run (success, partial failure, or fatal error) writes a document to
the Firestore `system_backups` collection with `type: 'postgres_backup'`,
mirroring the `type: 'firestore_export'` documents written by
`dailyFirestoreBackup`. Fields: `status` (`completed` |
`completed_with_errors` | `failed`), `outputUri`, `manifestKey`,
`tableCount`, `failedTables`, `totalRows`, `timestamp`, `scheduledBy`.

An admin/owner can also trigger an on-demand backup via the callable
`runPostgresBackupNow` (e.g. from the app, before approving a large bulk
inventory change request — see `docs/RBAC.md` for the approval flow this
protects).

## Restore-testing a backup

`scripts/pg-backup-restore-test/restore_test.js` verifies a backup is
actually restorable, without touching production data:

```bash
cd scripts/pg-backup-restore-test
npm install

# Integrity check only (no DB connection needed):
AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_REGION=ap-south-1 \
S3_BUCKET=bucket-ofqh8w \
node restore_test.js
```

This downloads the latest `backups/postgres/<timestamp>/` (or a specific one
via `BACKUP_PREFIX=2026-06-13T20-30-00-000Z`), decompresses every table,
parses every row as JSON, and checks:

1. the file decompresses and every line parses as JSON,
2. the row count matches `manifest.json`,
3. every row has a non-null, unique `id`.

Exit code is `0` if all tables pass, `1` otherwise — suitable for a
scheduled job (Cloud Scheduler → Cloud Run/Cloud Function, or a cron on any
host with network access to S3) that pages on failure.

### Full restore test (loads data into a scratch schema)

```bash
DATABASE_URL=postgres://user:pass@host:5432/postgres \
AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_REGION=ap-south-1 \
S3_BUCKET=bucket-ofqh8w \
node restore_test.js --full
```

In addition to the integrity check, this creates a `backup_verify` schema in
the target database and loads each table's rows as `(id, data jsonb)` pairs,
proving the backup data can actually be re-inserted into Postgres. The
schema is dropped at the end unless `--keep` is passed.

**Always point `DATABASE_URL` at a non-production database** (a scratch
Supabase project, a local Postgres, or an RDS read-replica/snapshot-restore
instance) — never at the live application database, even though this script
only writes to its own `backup_verify` schema.

### Full structural restore (disaster-recovery drill)

For a true "rebuild the database from scratch" drill (e.g. quarterly DR
exercise):

1. Provision a fresh scratch Postgres instance (new Supabase project or RDS
   instance).
2. Run `supabase/migrations/001_core_schema.sql` through the latest
   migration to recreate the schema (tables, indexes, RLS policies).
3. For each table in the backup manifest, decompress
   `<table>.json.gz` and `COPY`/bulk-insert the rows into the matching
   typed table (the JSON keys match the column names used by
   `sync_transform.js#pgUpsert` and `scripts/migration/lib/transform.js`,
   so the same upsert helpers can be reused for this).
4. Run `scripts/migration/migrate.js --dry-run` against the restored
   database to confirm referential integrity (no dangling
   `vendor_id`/`category_id`/etc.) before treating the drill as successful.

This is a manual/scripted runbook rather than a single command because it
depends on which migration version the backup corresponds to
(`manifest.schemaVersion`).

## Infrastructure-level backups (recommended complement)

In addition to this application-level export, enable on the RDS/Supabase
side:

- **AWS RDS automated backups** with a retention window (e.g. 7 days) and
  **point-in-time recovery (PITR)**, so the whole instance can be restored
  to any second within the retention window — covers scenarios this logical
  export doesn't (e.g. restoring mid-transaction state, or a table this
  export's `BACKUP_TABLES` list hasn't been updated to include yet).
- If using Supabase-managed Postgres, enable Supabase's daily backups (Pro
  plan+) or PITR add-on as the infrastructure-level equivalent.

## Adding/removing a backed-up table

1. Add or remove the table name in `BACKUP_TABLES` in `functions/pg_backup.js`.
2. Bump `SCHEMA_VERSION` if the change reflects a `supabase/migrations/*.sql`
   schema change.
3. No changes needed to `restore_test.js` — it iterates whatever tables are
   listed in the manifest.
