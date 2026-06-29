#!/usr/bin/env node
'use strict';

require('dotenv').config();

const { getPool, upsert } = require('./lib/pg');
const { getFirestore, forEachDocPage, forEachCollectionGroupPage } = require('./lib/firestore');
const { pick } = require('./lib/transform');
const { IdMap } = require('./lib/idmap');
const shopsMigrator = require('./migrators/shops');
const branchesMigrator = require('./migrators/branches');

/**
 * Backfill `shops` / `branches` tables and the `shop_id` / `branch_id`
 * foreign keys on rows that were migrated BEFORE migration
 * 008_shops_branches.sql introduced those tables/columns.
 *
 * This is a second-pass companion to the `shops` and `branches`
 * migrators (now the first two entries in migrators/index.js, so any
 * FUTURE full run of `node migrate.js` already populates these
 * correctly). This script exists for databases that were migrated
 * before that change:
 *
 *   1. Runs the `shops` and `branches` migrators standalone, so the
 *      `shops` / `branches` tables are populated (and the default
 *      `__default__` shop/branch seeded by 008_shops_branches.sql
 *      already exists from running that SQL migration).
 *   2. For every `users` row with `shop_id is null` (or `branch_id is
 *      null`), re-fetches the corresponding `users/{firebase_uid}`
 *      Firestore doc, resolves `shopId`/`branchId` -> Postgres
 *      `shops.id`/`branches.id`, and updates the row. Same for
 *      `products` (shop_id only) and `orders` (shop_id + branch_id).
 *   3. Any row that still has no shop/branch reference after step 2
 *      (no `shopId`/`branchId` field in the source doc) is assigned
 *      the seeded `__default__` shop/branch, so every row ends up with
 *      a non-null `shop_id` (branch_id may remain null for
 *      shop-level-only references).
 *
 * Usage:
 *   cd scripts/migration && npm install   (if not already)
 *   node backfill_shops_branches.js [--dry-run]
 *
 * Safe to re-run — only updates rows that still need it.
 */

async function getDefaultIds(pool) {
  const { rows } = await pool.query(
    `select s.id as shop_id, b.id as branch_id
       from shops s
       left join branches b on b.shop_id = s.id and b.firestore_id = '__default__'
      where s.firestore_id = '__default__'
      limit 1`
  );
  if (rows.length === 0) {
    throw new Error(
      "No '__default__' shop found. Run the 008_shops_branches.sql migration before this script."
    );
  }
  return { shopId: rows[0].shop_id, branchId: rows[0].branch_id || null };
}

/** Step 1: run the shops/branches migrators standalone (upserts only, no migration_runs bookkeeping). */
async function runShopsAndBranchesMigrators(pool, idmap, dryRun) {
  let shopsSeen = 0;
  let shopsWritten = 0;

  await forEachDocPage(shopsMigrator.collection, 200, async (docs) => {
    for (const doc of docs) {
      shopsSeen += 1;
      const client = await pool.connect();
      try {
        const row = await shopsMigrator.map(doc, idmap, client);
        if (!row) continue;
        if (dryRun) {
          shopsWritten += 1;
          // Still populate idmap from existing DB row (if any) so branches
          // resolution works in dry-run mode too.
          const existingId = await idmap.resolve(client, 'shops', doc.id);
          if (existingId) idmap.set('shops', doc.id, existingId);
          continue;
        }
        const pgId = await upsert(client, shopsMigrator.table, shopsMigrator.conflictColumn, row);
        await shopsMigrator.afterUpsert(client, doc, row, pgId, idmap);
        shopsWritten += 1;
      } finally {
        client.release();
      }
    }
  });

  let branchesSeen = 0;
  let branchesWritten = 0;
  let branchesSkipped = 0;

  await forEachCollectionGroupPage(branchesMigrator.collection, 200, async (docs) => {
    for (const doc of docs) {
      branchesSeen += 1;
      const client = await pool.connect();
      try {
        const row = await branchesMigrator.map(doc, idmap, client);
        if (!row) {
          branchesSkipped += 1;
          continue;
        }
        if (dryRun) {
          branchesWritten += 1;
          const existingId = await idmap.resolve(client, 'branches', doc.id);
          if (existingId) idmap.set('branches', doc.id, existingId);
          continue;
        }
        const pgId = await upsert(client, branchesMigrator.table, branchesMigrator.conflictColumn, row);
        await branchesMigrator.afterUpsert(client, doc, row, pgId, idmap);
        branchesWritten += 1;
      } finally {
        client.release();
      }
    }
  });

  console.log(
    `[backfill_shops_branches] shops: seen=${shopsSeen} written=${shopsWritten}${dryRun ? ' (dry-run)' : ''}`
  );
  console.log(
    `[backfill_shops_branches] branches: seen=${branchesSeen} written=${branchesWritten} skipped=${branchesSkipped}${
      dryRun ? ' (dry-run)' : ''
    }`
  );
}

/**
 * Step 2+3 for a single table: find rows with null shop_id (and
 * optionally branch_id), re-fetch the Firestore doc by `firestoreKey`
 * (firestore_id or firebase_uid), resolve refs via idmap, and update.
 * Falls back to the default shop/branch when the source doc has no
 * shopId/branchId.
 */
async function backfillTable({
  pool,
  idmap,
  dryRun,
  table,
  conflictColumn, // 'firestore_id' or 'firebase_uid'
  collection, // Firestore collection to re-fetch docs from
  includeBranch, // whether this table has a branch_id column to backfill
  defaults,
}) {
  const whereCols = includeBranch
    ? `(shop_id is null or branch_id is null)`
    : `(shop_id is null)`;

  const { rows: candidates } = await pool.query(
    `select id, "${conflictColumn}" as fid from "${table}" where ${whereCols}`
  );

  if (candidates.length === 0) {
    console.log(`[backfill_shops_branches] ${table}: nothing to backfill.`);
    return;
  }

  console.log(`[backfill_shops_branches] ${table}: ${candidates.length} rows missing shop/branch refs.`);

  const byFid = new Map(candidates.map((r) => [r.fid, r]));
  let resolvedFromSource = 0;
  let assignedDefault = 0;
  let docNotFound = 0;

  await forEachDocPage(collection, 200, async (docs) => {
    for (const doc of docs) {
      const candidate = byFid.get(doc.id);
      if (!candidate) continue;
      byFid.delete(doc.id);

      const d = doc.data();
      const shopFsId = pick(d, ['shopId', 'shop_id']);
      const branchFsId = pick(d, ['branchId', 'branch_id']);

      const client = await pool.connect();
      try {
        let shopId = shopFsId ? await idmap.resolve(client, 'shops', String(shopFsId)) : null;
        let branchId = includeBranch && branchFsId ? await idmap.resolve(client, 'branches', String(branchFsId)) : null;

        if (shopId) resolvedFromSource += 1;

        if (!shopId) {
          shopId = defaults.shopId;
          assignedDefault += 1;
        }
        if (includeBranch && !branchId && shopId === defaults.shopId) {
          branchId = defaults.branchId;
        }

        if (dryRun) {
          console.log(
            `  [dry-run] ${table} ${doc.id}: shop_id -> ${shopId}` +
              (includeBranch ? `, branch_id -> ${branchId}` : '')
          );
        } else if (includeBranch) {
          await client.query(`update "${table}" set shop_id = $1, branch_id = $2 where id = $3`, [
            shopId,
            branchId,
            candidate.id,
          ]);
        } else {
          await client.query(`update "${table}" set shop_id = $1 where id = $2`, [shopId, candidate.id]);
        }
      } finally {
        client.release();
      }
    }
  });

  // Any candidates whose Firestore doc no longer exists: assign default shop/branch.
  for (const candidate of byFid.values()) {
    docNotFound += 1;
    if (dryRun) {
      console.log(`  [dry-run] ${table} ${candidate.fid}: source doc not found, would assign default shop`);
      continue;
    }
    const client = await pool.connect();
    try {
      if (includeBranch) {
        await client.query(`update "${table}" set shop_id = $1, branch_id = $2 where id = $3`, [
          defaults.shopId,
          defaults.branchId,
          candidate.id,
        ]);
      } else {
        await client.query(`update "${table}" set shop_id = $1 where id = $2`, [defaults.shopId, candidate.id]);
      }
    } finally {
      client.release();
    }
    assignedDefault += 1;
  }

  console.log(
    `[backfill_shops_branches] ${table}: resolved from source=${resolvedFromSource}, assigned default=${assignedDefault}, source doc missing=${docNotFound}${
      dryRun ? ' (dry-run, not written)' : ''
    }`
  );
}

async function main() {
  const dryRun = process.argv.includes('--dry-run') || process.argv.includes('--dry');

  if (!process.env.DATABASE_URL) {
    console.error('DATABASE_URL is not set. Copy .env.example to .env and fill it in.');
    process.exit(1);
  }

  // Touch Firestore so credential errors surface early.
  getFirestore();

  const pool = getPool();
  const idmap = new IdMap();

  console.log('[backfill_shops_branches] Step 1/3: syncing shops + branches from Firestore...');
  await runShopsAndBranchesMigrators(pool, idmap, dryRun);

  console.log('[backfill_shops_branches] Step 2/3: resolving default shop/branch...');
  const defaults = await getDefaultIds(pool);
  console.log(`[backfill_shops_branches]   default shop_id=${defaults.shopId} branch_id=${defaults.branchId}`);

  console.log('[backfill_shops_branches] Step 3/3: backfilling users / products / orders...');
  await backfillTable({
    pool,
    idmap,
    dryRun,
    table: 'users',
    conflictColumn: 'firebase_uid',
    collection: 'users',
    includeBranch: true,
    defaults,
  });
  await backfillTable({
    pool,
    idmap,
    dryRun,
    table: 'products',
    conflictColumn: 'firestore_id',
    collection: 'products',
    includeBranch: false,
    defaults,
  });
  await backfillTable({
    pool,
    idmap,
    dryRun,
    table: 'orders',
    conflictColumn: 'firestore_id',
    collection: 'orders',
    includeBranch: true,
    defaults,
  });

  console.log('[backfill_shops_branches] Done.');
  await pool.end();
}

main().catch((err) => {
  console.error('[backfill_shops_branches] Fatal error:', err);
  process.exit(1);
});
