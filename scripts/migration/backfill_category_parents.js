#!/usr/bin/env node
'use strict';

require('dotenv').config();

const { getPool } = require('./lib/pg');
const { forEachDocPage } = require('./lib/firestore');
const { pick } = require('./lib/transform');

/**
 * Second-pass fixup for `categories.parent_id`.
 *
 * `migrators/categories.js` resolves `parent_id` during the main migration
 * by looking up the parent's Postgres row via `firestore_id`. If Firestore
 * returns a child category before its parent has been migrated/synced yet,
 * `parent_id` is left `null` for that row (documented in
 * scripts/migration/README.md "Known gaps / follow-up passes").
 *
 * Re-running `node migrate.js --only=categories` fixes this (every
 * category now exists in Postgres, so the second pass's lookups succeed),
 * but it re-maps and re-upserts every category column. This script is a
 * lighter-weight, targeted alternative: it only touches rows where
 * `parent_id is null` but the Firestore source document has a parent
 * reference, updating just `categories.parent_id`.
 *
 * Usage:
 *   cd scripts/migration && npm install   (if not already)
 *   node backfill_category_parents.js [--dry-run]
 *
 * Safe to re-run — only updates rows that still need it, and is a no-op
 * once every category's parent has been resolved.
 */

async function main() {
  const dryRun = process.argv.includes('--dry-run') || process.argv.includes('--dry');

  if (!process.env.DATABASE_URL) {
    console.error('DATABASE_URL is not set. Copy .env.example to .env and fill it in.');
    process.exit(1);
  }

  const pool = getPool();

  // Find categories currently missing a parent link.
  const { rows: orphans } = await pool.query(
    `select id, firestore_id, name from categories where parent_id is null`
  );

  if (orphans.length === 0) {
    console.log('[backfill_category_parents] No categories with parent_id = null. Nothing to do.');
    await pool.end();
    return;
  }

  console.log(`[backfill_category_parents] ${orphans.length} categories with parent_id = null. Checking Firestore for parent references...`);

  const orphanByFirestoreId = new Map(orphans.map((r) => [r.firestore_id, r]));
  let resolved = 0;
  let stillMissingParentDoc = 0;
  let noParentInSource = 0;

  // Walk the categories collection once, looking only at docs that
  // correspond to an orphaned Postgres row.
  await forEachDocPage('categories', 200, async (docs) => {
    for (const doc of docs) {
      const orphan = orphanByFirestoreId.get(doc.id);
      if (!orphan) continue;

      const d = doc.data();
      const parentFirestoreId = pick(d, ['parentId', 'parent_id']);
      if (!parentFirestoreId) {
        noParentInSource += 1;
        continue; // top-level category — parent_id null is correct, not a gap.
      }

      const { rows: parentRows } = await pool.query(
        `select id from categories where firestore_id = $1 limit 1`,
        [String(parentFirestoreId)]
      );

      if (parentRows.length === 0) {
        stillMissingParentDoc += 1;
        console.warn(
          `  [skip] "${orphan.name}" (${doc.id}) references parent "${parentFirestoreId}" which has not been migrated yet.`
        );
        continue;
      }

      const parentPgId = parentRows[0].id;

      if (dryRun) {
        console.log(`  [dry-run] would set categories.parent_id for "${orphan.name}" (${doc.id}) -> ${parentPgId}`);
      } else {
        await pool.query(`update categories set parent_id = $1, updated_at = now() where id = $2`, [
          parentPgId,
          orphan.id,
        ]);
        console.log(`  [fixed] "${orphan.name}" (${doc.id}) -> parent ${parentPgId}`);
      }
      resolved += 1;
    }
  });

  console.log('\n[backfill_category_parents] Summary:');
  console.log(`  resolved:               ${resolved}${dryRun ? ' (dry-run, not written)' : ''}`);
  console.log(`  no parent in source:    ${noParentInSource} (top-level categories — expected)`);
  console.log(`  parent not migrated yet: ${stillMissingParentDoc} (re-run after that category exists)`);

  await pool.end();
}

main().catch((err) => {
  console.error('[backfill_category_parents] Fatal error:', err);
  process.exit(1);
});
