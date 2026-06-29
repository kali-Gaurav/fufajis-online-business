'use strict';

/**
 * Restore-test for the Postgres logical backups produced by
 * `functions/pg_backup.js` (dailyPostgresBackup / runPostgresBackupNow).
 *
 * Two modes:
 *
 *   node restore_test.js                 — integrity check only (default)
 *     Downloads the manifest + every table's .json.gz, decompresses,
 *     parses every row as JSON, and verifies:
 *       - the file decompresses and parses cleanly
 *       - the row count matches manifest.tables[table].rowCount
 *       - every row has a non-null `id` and ids are unique
 *     Does NOT touch any database. Safe to run anywhere with S3 read access.
 *
 *   node restore_test.js --full          — full restore-into-scratch-schema
 *     In addition to the integrity check above, loads every row into
 *     `backup_verify.<table>` (JSONB-per-row tables) in the Postgres
 *     database pointed to by DATABASE_URL, then drops the schema again
 *     unless --keep is also passed. This proves the backup data is
 *     loadable, without touching the real application tables.
 *
 * Usage:
 *   cd scripts/pg-backup-restore-test && npm install
 *   AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_REGION=ap-south-1 \
 *   S3_BUCKET=bucket-ofqh8w \
 *   [BACKUP_PREFIX=2026-06-13T20-30-00-000Z] \
 *   [DATABASE_URL=postgres://...]   (required for --full) \
 *     node restore_test.js [--full] [--keep]
 *
 * If BACKUP_PREFIX is omitted, the script lists `backups/postgres/` and
 * picks the lexicographically-latest timestamp prefix (ISO timestamps with
 * `:`/`.` replaced by `-`, so lexicographic order == chronological order).
 *
 * Exit code is non-zero if any table fails its integrity check, so this
 * script can be wired into a scheduled CI job / Cloud Scheduler-triggered
 * Cloud Run job for ongoing restore-test verification (see
 * docs/POSTGRES_BACKUP_RESTORE.md).
 */

require('dotenv').config();
const zlib = require('zlib');
const { S3Client, ListObjectsV2Command, GetObjectCommand } = require('@aws-sdk/client-s3');

const FULL = process.argv.includes('--full');
const KEEP = process.argv.includes('--keep');

const BUCKET = process.env.S3_BUCKET || 'bucket-ofqh8w';
const REGION = process.env.AWS_REGION || process.env.S3_REGION || 'ap-south-1';

function s3Client() {
  return new S3Client({ region: REGION });
}

async function streamToBuffer(stream) {
  const chunks = [];
  for await (const chunk of stream) chunks.push(chunk);
  return Buffer.concat(chunks);
}

async function getObjectBuffer(client, key) {
  const res = await client.send(new GetObjectCommand({ Bucket: BUCKET, Key: key }));
  return streamToBuffer(res.Body);
}

async function findLatestPrefix(client) {
  const res = await client.send(
    new ListObjectsV2Command({ Bucket: BUCKET, Prefix: 'backups/postgres/', Delimiter: '/' })
  );
  const prefixes = (res.CommonPrefixes || [])
    .map((p) => p.Prefix)
    .filter(Boolean)
    .sort();
  if (prefixes.length === 0) {
    throw new Error(`No backups found under s3://${BUCKET}/backups/postgres/`);
  }
  // backups/postgres/<timestamp>/ -> <timestamp>
  const latest = prefixes[prefixes.length - 1];
  return latest.replace(/^backups\/postgres\//, '').replace(/\/$/, '');
}

async function main() {
  const client = s3Client();
  const prefix = process.env.BACKUP_PREFIX || (await findLatestPrefix(client));
  const basePrefix = `backups/postgres/${prefix}`;

  console.log(`[RestoreTest] Verifying backup s3://${BUCKET}/${basePrefix}`);

  const manifestBuf = await getObjectBuffer(client, `${basePrefix}/manifest.json`);
  const manifest = JSON.parse(manifestBuf.toString('utf8'));

  console.log(`[RestoreTest] Manifest: schemaVersion=${manifest.schemaVersion}, ` +
    `tables=${Object.keys(manifest.tables).length}, started=${manifest.startedAt}`);

  let pool = null;
  if (FULL) {
    if (!process.env.DATABASE_URL) {
      throw new Error('--full requires DATABASE_URL to point at a scratch-safe Postgres database');
    }
    const { Pool } = require('pg');
    pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 2, ssl: { rejectUnauthorized: false } });
    await pool.query('create schema if not exists backup_verify');
  }

  const failures = [];
  const summary = [];

  for (const [table, info] of Object.entries(manifest.tables)) {
    if (info.status !== 'ok') {
      summary.push({ table, status: 'skipped (backup failed)', error: info.error });
      continue;
    }

    try {
      const gz = await getObjectBuffer(client, info.key);
      const ndjson = zlib.gunzipSync(gz).toString('utf8');
      const lines = ndjson.length ? ndjson.split('\n') : [];

      const rows = lines.map((line, i) => {
        try {
          return JSON.parse(line);
        } catch (e) {
          throw new Error(`row ${i} is not valid JSON: ${e.message}`);
        }
      });

      if (rows.length !== info.rowCount) {
        throw new Error(`row count mismatch: manifest says ${info.rowCount}, decompressed file has ${rows.length}`);
      }

      const ids = rows.map((r) => r.id).filter((id) => id !== undefined && id !== null);
      if (ids.length !== rows.length) {
        throw new Error(`${rows.length - ids.length} row(s) missing an "id" column`);
      }
      const uniqueIds = new Set(ids);
      if (uniqueIds.size !== ids.length) {
        throw new Error(`duplicate ids found (${ids.length - uniqueIds.size} duplicates)`);
      }

      if (FULL && pool) {
        await pool.query(`drop table if exists backup_verify."${table}"`);
        await pool.query(`create table backup_verify."${table}" (id text primary key, data jsonb not null)`);
        // Batch insert in chunks to avoid one giant statement on large tables.
        const CHUNK = 500;
        for (let i = 0; i < rows.length; i += CHUNK) {
          const chunk = rows.slice(i, i + CHUNK);
          const values = [];
          const params = [];
          chunk.forEach((row, idx) => {
            values.push(`($${idx * 2 + 1}, $${idx * 2 + 2}::jsonb)`);
            params.push(String(row.id), JSON.stringify(row));
          });
          await pool.query(
            `insert into backup_verify."${table}" (id, data) values ${values.join(', ')} on conflict (id) do nothing`,
            params
          );
        }
      }

      summary.push({ table, status: 'ok', rows: rows.length, bytes: info.bytes });
      console.log(`[RestoreTest] ${table}: OK (${rows.length} rows, ${info.bytes} bytes gzipped)`);
    } catch (error) {
      failures.push({ table, error: error.message });
      summary.push({ table, status: 'FAILED', error: error.message });
      console.error(`[RestoreTest] ${table}: FAILED — ${error.message}`);
    }
  }

  if (FULL && pool) {
    if (!KEEP) {
      await pool.query('drop schema if exists backup_verify cascade');
      console.log('[RestoreTest] Dropped scratch schema backup_verify (pass --keep to retain it).');
    } else {
      console.log('[RestoreTest] Kept scratch schema backup_verify for inspection.');
    }
    await pool.end();
  }

  console.log('\n[RestoreTest] Summary:');
  for (const row of summary) console.log(`  - ${row.table}: ${row.status}`);

  if (failures.length > 0) {
    console.error(`\n[RestoreTest] FAILED — ${failures.length} table(s) failed integrity check.`);
    process.exit(1);
  }

  console.log(`\n[RestoreTest] PASSED — all ${summary.length} tables verified.`);
}

main().catch((err) => {
  console.error('[RestoreTest] Fatal error:', err);
  process.exit(1);
});
