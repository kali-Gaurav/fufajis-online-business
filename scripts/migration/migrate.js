#!/usr/bin/env node
'use strict';

require('dotenv').config();

const { forEachDocPage, forEachCollectionGroupPage } = require('./lib/firestore');
const { getPool, upsert, startRun, finishRun } = require('./lib/pg');
const { IdMap } = require('./lib/idmap');
const allMigrators = require('./migrators');

/**
 * Firestore -> Postgres historical data backfill.
 *
 * Usage:
 *   node migrate.js                  Run every migrator
 *   node migrate.js --dry-run        Read & map, but never write to Postgres
 *   node migrate.js --only=users,products   Run a subset (comma-separated names)
 *   node migrate.js --limit=500      Stop each migrator after N source documents
 *
 * Safe to re-run: every table is upserted on a stable key
 * (`firestore_id`, or `firebase_uid` for users, or `code` for
 * coupons), so reruns update existing rows instead of duplicating.
 */

function parseArgs(argv) {
  const args = { dryRun: false, only: null, limit: null };
  for (const arg of argv.slice(2)) {
    if (arg === '--dry-run' || arg === '--dry') {
      args.dryRun = true;
    } else if (arg.startsWith('--only=')) {
      args.only = arg.slice('--only='.length).split(',').map((s) => s.trim()).filter(Boolean);
    } else if (arg.startsWith('--limit=')) {
      args.limit = Number(arg.slice('--limit='.length)) || null;
    } else {
      console.warn(`Unknown argument: ${arg}`);
    }
  }
  return args;
}

const PAGE_SIZE = Number(process.env.MIGRATION_BATCH_SIZE) || 200;

async function runMigrator(migrator, idmap, { dryRun, limit }) {
  const pool = getPool();
  const adminClient = await pool.connect();

  let runId = null;
  let documentsSeen = 0;
  let documentsWritten = 0;
  let documentsSkipped = 0;
  let lastDocId = null;
  let runError = null;

  try {
    if (!dryRun) {
      runId = await startRun(adminClient, migrator.name);
    }

    console.log(`\n=== ${migrator.name} ===`);

    const pageFn = migrator.collectionGroup ? forEachCollectionGroupPage : forEachDocPage;

    await pageFn(migrator.collection, PAGE_SIZE, async (docs) => {
      for (const doc of docs) {
        if (limit !== null && documentsSeen >= limit) return;

        documentsSeen += 1;
        lastDocId = doc.id;

        const client = await pool.connect();
        try {
          await client.query('BEGIN');

          let row;
          try {
            row = await migrator.map(doc, idmap, client);
          } catch (mapErr) {
            console.error(`  [${migrator.name}] map() failed for doc ${doc.id}:`, mapErr.message);
            documentsSkipped += 1;
            await client.query('ROLLBACK');
            continue;
          }

          if (row === null || row === undefined) {
            documentsSkipped += 1;
            await client.query('ROLLBACK');
            continue;
          }

          if (dryRun) {
            documentsWritten += 1;
            await client.query('ROLLBACK');
            continue;
          }

          const pgId = await upsert(client, migrator.table, migrator.conflictColumn, row);

          if (typeof migrator.afterUpsert === 'function') {
            await migrator.afterUpsert(client, doc, row, pgId, idmap);
          }

          await client.query('COMMIT');
          documentsWritten += 1;
        } catch (docErr) {
          await client.query('ROLLBACK').catch(() => {});
          console.error(`  [${migrator.name}] failed for doc ${doc.id}:`, docErr.message);
          documentsSkipped += 1;
        } finally {
          client.release();
        }
      }

      if (limit !== null && documentsSeen >= limit) {
        // Signal pagination to stop by throwing a sentinel — caught below.
        throw new STOP_PAGINATION();
      }
    }).catch((err) => {
      if (!(err instanceof STOP_PAGINATION)) throw err;
    });

    console.log(
      `  seen=${documentsSeen} written=${documentsWritten} skipped=${documentsSkipped}`
    );

    if (!dryRun) {
      await finishRun(adminClient, runId, {
        status: 'completed',
        documentsSeen,
        documentsWritten,
        documentsSkipped,
        lastDocId,
      });
    }
  } catch (err) {
    runError = err;
    console.error(`  [${migrator.name}] migrator failed:`, err.message);
    if (!dryRun && runId) {
      await finishRun(adminClient, runId, {
        status: 'failed',
        documentsSeen,
        documentsWritten,
        documentsSkipped,
        lastDocId,
        error: err.message,
      });
    }
  } finally {
    adminClient.release();
  }

  return { name: migrator.name, documentsSeen, documentsWritten, documentsSkipped, error: runError };
}

// Sentinel class used to break out of the page-iteration loop once --limit is hit.
class STOP_PAGINATION extends Error {}

async function main() {
  const args = parseArgs(process.argv);

  if (!process.env.DATABASE_URL) {
    console.error('DATABASE_URL is not set. Copy .env.example to .env and fill it in.');
    process.exit(1);
  }

  const migrators = args.only
    ? allMigrators.filter((m) => args.only.includes(m.name))
    : allMigrators;

  if (migrators.length === 0) {
    console.error(`No migrators matched --only=${(args.only || []).join(',')}`);
    console.error(`Available: ${allMigrators.map((m) => m.name).join(', ')}`);
    process.exit(1);
  }

  console.log(`Fufaji Firestore -> Postgres migration`);
  console.log(`mode: ${args.dryRun ? 'DRY RUN (no writes)' : 'LIVE'}`);
  console.log(`migrators: ${migrators.map((m) => m.name).join(', ')}`);
  if (args.limit !== null) console.log(`limit: ${args.limit} docs per migrator`);

  const idmap = new IdMap();
  const results = [];

  for (const migrator of migrators) {
    results.push(await runMigrator(migrator, idmap, args));
  }

  console.log('\n=== Summary ===');
  let hadError = false;
  for (const r of results) {
    const status = r.error ? `FAILED (${r.error.message})` : 'ok';
    console.log(
      `  ${r.name.padEnd(20)} seen=${r.documentsSeen} written=${r.documentsWritten} skipped=${r.documentsSkipped} ${status}`
    );
    if (r.error) hadError = true;
  }

  await getPool().end();
  process.exit(hadError ? 1 : 0);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
