'use strict';

const { Pool } = require('pg');

let pool = null;

function getPool() {
  if (!pool) {
    pool = new Pool({
      connectionString: process.env.DATABASE_URL,
      max: 5,
      ssl: { rejectUnauthorized: false },
    });
  }
  return pool;
}

/**
 * Upserts a single row into `table`, keyed on `conflictColumn`
 * (typically `firestore_id` or `firebase_uid`). Returns the row's
 * `id` (uuid).
 *
 * `row` is a plain object of column -> value. `undefined` values
 * are skipped entirely (column not included in the statement);
 * `null` values are written as SQL NULL.
 *
 * On conflict, every column EXCEPT the conflict column and `id`
 * is updated (COALESCE-free — migration data wins, since it
 * represents the historical source of truth being backfilled).
 */
async function upsert(client, table, conflictColumn, row) {
  // Keys prefixed with "__" are internal scratch data (e.g. embedded
  // sub-arrays) passed through to `afterUpsert` — never written as columns.
  const columns = Object.keys(row).filter((k) => row[k] !== undefined && !k.startsWith('__'));
  if (!columns.includes(conflictColumn)) {
    throw new Error(`upsert(${table}): row is missing conflict column "${conflictColumn}"`);
  }

  const values = columns.map((c) => row[c]);
  const placeholders = columns.map((_, i) => `$${i + 1}`);

  const updateAssignments = columns
    .filter((c) => c !== conflictColumn && c !== 'id')
    .map((c) => `"${c}" = excluded."${c}"`)
    .join(', ');

  const sql = `
    insert into "${table}" (${columns.map((c) => `"${c}"`).join(', ')})
    values (${placeholders.join(', ')})
    on conflict ("${conflictColumn}")
    do update set ${updateAssignments || `"${conflictColumn}" = excluded."${conflictColumn}"`}
    returning id
  `;

  const res = await client.query(sql, values);
  return res.rows[0].id;
}

/** Looks up an existing row's id by a unique column, without inserting. */
async function lookupId(client, table, column, value) {
  if (value === null || value === undefined) return null;
  const res = await client.query(`select id from "${table}" where "${column}" = $1 limit 1`, [value]);
  return res.rows.length ? res.rows[0].id : null;
}

async function startRun(client, collection) {
  const res = await client.query(
    `insert into migration_runs (collection, status) values ($1, 'running') returning id`,
    [collection]
  );
  return res.rows[0].id;
}

async function finishRun(client, runId, { status, documentsSeen, documentsWritten, documentsSkipped, lastDocId, error }) {
  await client.query(
    `update migration_runs set status = $2, documents_seen = $3, documents_written = $4,
       documents_skipped = $5, last_doc_id = $6, error = $7, finished_at = now()
     where id = $1`,
    [runId, status, documentsSeen, documentsWritten, documentsSkipped, lastDocId || null, error || null]
  );
}

module.exports = { getPool, upsert, lookupId, startRun, finishRun };
