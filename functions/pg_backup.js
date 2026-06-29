'use strict';

/**
 * ═══════════════════════════════════════════════════════════════════════
 * POSTGRES (RDS/Supabase) LOGICAL BACKUP — scheduled export to S3
 * ═══════════════════════════════════════════════════════════════════════
 *
 * Companion to `dailyFirestoreBackup` (functions/index.js), which exports
 * Firestore to GCS. This module performs an analogous *logical* backup of
 * the Postgres database that `firestore_sync.js` and the Phase 13 inventory
 * services write to.
 *
 * Cloud Functions' managed Node runtime does not ship `pg_dump`, so this
 * uses a `SELECT * FROM <table>` + JSON + gzip export per table via the
 * shared `getPgPool()` connection, uploaded to S3 under
 * `backups/postgres/<timestamp>/`. A `manifest.json` records the table list,
 * row counts, and schema version so a restore can verify completeness.
 *
 * This is a *logical* backup (data + structure-agnostic JSON rows), meant
 * as an application-level safety net and restore-test target. It does not
 * replace AWS RDS automated snapshots / point-in-time recovery, which should
 * also be enabled at the infrastructure level (see
 * docs/POSTGRES_BACKUP_RESTORE.md for the full picture).
 *
 * See docs/POSTGRES_BACKUP_RESTORE.md for the restore-test procedure
 * (functions/scripts/pg_restore_test.js).
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const zlib = require('zlib');
const { PutObjectCommand } = require('@aws-sdk/client-s3');
const { getPgPool, getS3Client } = require('./aws_services');

// Tables backed up, in an order that's convenient (but not required) for
// restore — parents before children. Keep in sync with
// docs/POSTGRES_SCHEMA.md. `migration_runs` and `saved_queries` are
// operational/metadata tables and are included for completeness.
const BACKUP_TABLES = [
  'users',
  'categories',
  'products',
  'addresses',
  'inventory',
  'inventory_logs',
  'inventory_events',
  'inventory_versions',
  'change_requests',
  'automation_rules',
  'bulk_operations',
  'saved_queries',
  'package_processing',
  'orders',
  'order_items',
  'order_status_history',
  'delivery_tracking',
  'coupons',
  'reviews',
  'wallet_transactions',
  'notifications',
  'support_tickets',
  'kyc_documents',
  'audit_logs',
  'migration_runs',
];

const SCHEMA_VERSION = 'phase16'; // bump when supabase/migrations adds/removes backed-up tables

const BACKUP_SECRETS = [
  'RDS_CONNECTION_STRING', 'RDS_HOST', 'RDS_PORT', 'RDS_USER', 'RDS_PASSWORD', 'RDS_DATABASE',
  'SUPABASE_S3_ACCESS_KEY', 'SUPABASE_S3_SECRET_KEY', 'SUPABASE_S3_ENDPOINT', 'SUPABASE_S3_BUCKET'
];

function s3Bucket() {
  return process.env.SUPABASE_S3_BUCKET || 'uploads';
}

function s3Region() {
  return 'ap-south-1';
}

async function putObject(client, bucket, key, buffer, contentType) {
  await client.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: buffer,
      ContentType: contentType,
      ContentEncoding: contentType === 'application/json' ? undefined : 'gzip',
    })
  );
}

/**
 * Exports every table in BACKUP_TABLES to `<prefix>/<table>.json.gz`
 * (newline-delimited JSON rows, gzip-compressed) and writes a
 * `<prefix>/manifest.json` summarizing row counts and any per-table errors.
 *
 * Returns the manifest object.
 */
async function runPostgresBackup({ prefix, logger = console } = {}) {
  const pool = getPgPool();
  const s3 = getS3Client();
  const bucket = s3Bucket();

  const timestamp = prefix || new Date().toISOString().replace(/[:.]/g, '-');
  const basePrefix = `backups/postgres/${timestamp}`;

  const manifest = {
    schemaVersion: SCHEMA_VERSION,
    startedAt: new Date().toISOString(),
    bucket,
    prefix: basePrefix,
    tables: {},
  };

  for (const table of BACKUP_TABLES) {
    try {
      const res = await pool.query(`select * from "${table}"`);
      const ndjson = res.rows.map((row) => JSON.stringify(row)).join('\n');
      const gz = zlib.gzipSync(Buffer.from(ndjson, 'utf8'));
      const key = `${basePrefix}/${table}.json.gz`;

      await putObject(s3, bucket, key, gz, 'application/gzip');

      manifest.tables[table] = {
        rowCount: res.rowCount,
        key,
        bytes: gz.length,
        status: 'ok',
      };
      logger.log(`[PgBackup] ${table}: ${res.rowCount} rows -> s3://${bucket}/${key} (${gz.length} bytes)`);
    } catch (error) {
      // A missing/renamed table shouldn't abort the whole backup — record
      // the error and continue, so newer/older schema versions still
      // produce a usable (partial) backup.
      manifest.tables[table] = { status: 'error', error: error.message };
      logger.error(`[PgBackup] ${table}: FAILED — ${error.message}`);
    }
  }

  manifest.finishedAt = new Date().toISOString();

  const manifestKey = `${basePrefix}/manifest.json`;
  await putObject(s3, bucket, manifestKey, Buffer.from(JSON.stringify(manifest, null, 2), 'utf8'), 'application/json');
  manifest.manifestKey = manifestKey;

  return manifest;
}

/**
 * Scheduled: Daily Postgres logical backup (8:30 PM IST — 1 hour after the
 * Firestore export at 8:00 PM, to avoid overlapping load on the same
 * instance during cold starts).
 *
 * Logs status to the same Firestore `system_backups` collection used by
 * `dailyFirestoreBackup`, with `type: 'postgres_backup'`.
 */
exports.dailyPostgresBackup = functions.runWith({ secrets: BACKUP_SECRETS }).pubsub
  .schedule('30 20 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    console.log(`[PgBackup] Starting daily Postgres backup: ${timestamp}`);

    try {
      const manifest = await runPostgresBackup({ prefix: timestamp });

      const failedTables = Object.entries(manifest.tables)
        .filter(([, t]) => t.status === 'error')
        .map(([name]) => name);

      await admin.firestore().collection('system_backups').add({
        type: 'postgres_backup',
        status: failedTables.length === 0 ? 'completed' : 'completed_with_errors',
        outputUri: `s3://${manifest.bucket}/${manifest.prefix}`,
        manifestKey: manifest.manifestKey,
        tableCount: Object.keys(manifest.tables).length,
        failedTables,
        totalRows: Object.values(manifest.tables).reduce((sum, t) => sum + (t.rowCount || 0), 0),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        scheduledBy: 'dailyPostgresBackup',
      });

      console.log(`[PgBackup] Done. ${Object.keys(manifest.tables).length} tables, ${failedTables.length} failed.`);
      return null;
    } catch (error) {
      console.error('[PgBackup] Fatal error:', error);
      await admin.firestore().collection('system_backups').add({
        type: 'postgres_backup',
        status: 'failed',
        error: error.message,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        scheduledBy: 'dailyPostgresBackup',
      }).catch(() => {});
      return null;
    }
  });

/**
 * Callable: lets an admin/owner trigger an on-demand Postgres backup from
 * the app (e.g. before a risky bulk inventory approval), without waiting
 * for the nightly schedule.
 */
exports.runPostgresBackupNow = functions.runWith({ secrets: BACKUP_SECRETS }).https.onCall(async (data, context) => {
  const { requireAdmin } = require('./aws_services');
  await requireAdmin(context);

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const manifest = await runPostgresBackup({ prefix: `manual-${timestamp}` });

  await admin.firestore().collection('system_backups').add({
    type: 'postgres_backup',
    status: 'completed',
    outputUri: `s3://${manifest.bucket}/${manifest.prefix}`,
    manifestKey: manifest.manifestKey,
    tableCount: Object.keys(manifest.tables).length,
    totalRows: Object.values(manifest.tables).reduce((sum, t) => sum + (t.rowCount || 0), 0),
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    scheduledBy: `manual:${context.auth.uid}`,
  });

  return { success: true, manifest };
});

module.exports.runPostgresBackup = runPostgresBackup;
module.exports.BACKUP_TABLES = BACKUP_TABLES;
module.exports.s3Bucket = s3Bucket;
module.exports.s3Region = s3Region;
