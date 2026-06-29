'use strict';

/**
 * Small, self-contained transform helpers for the streaming
 * Firestore -> Postgres sync (functions/firestore_sync.js).
 *
 * Deliberately duplicated (not shared via require) from
 * scripts/migration/lib/transform.js so that `functions/` can be
 * deployed as a standalone Cloud Functions package without reaching
 * outside its own directory. Keep the two in sync if the mapping
 * conventions change.
 */

function pick(data, keys, fallback = undefined) {
  for (const k of keys) {
    if (data[k] !== undefined && data[k] !== null) return data[k];
  }
  return fallback;
}

function num(value, fallback = 0) {
  if (value === null || value === undefined) return fallback;
  if (typeof value === 'number') return value;
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function toIso(value) {
  if (value === null || value === undefined) return null;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'string') return value;
  return null;
}

function ts(value) {
  return toIso(value);
}

function bool(value, fallback = false) {
  if (typeof value === 'boolean') return value;
  if (value === undefined || value === null) return fallback;
  return Boolean(value);
}

function strArray(value) {
  if (!Array.isArray(value)) return null;
  return value.map((v) => String(v));
}

function jsonb(value, fallback = {}) {
  if (value === null || value === undefined) return fallback;
  if (typeof value === 'object') return value;
  return fallback;
}

/**
 * Upserts a single row into `table`, keyed on `conflictColumn`
 * (typically `firestore_id` or `firebase_uid`).
 *
 * Same semantics as scripts/migration/lib/pg.js#upsert: undefined
 * values are skipped (column omitted), null values are written as
 * SQL NULL, and on conflict every column except the conflict column
 * and `id` is overwritten with the incoming value (last-write-wins —
 * acceptable because Firestore is the system of record for these
 * fields and the trigger fires on every write).
 *
 * Returns the row's `id` (uuid), or null if the upsert was skipped
 * because `row` was null (caller should treat this as "nothing to
 * sync for this document").
 */
async function pgUpsert(pool, table, conflictColumn, row) {
  if (!row) return null;

  const columns = Object.keys(row).filter((k) => row[k] !== undefined && !k.startsWith('__'));
  if (!columns.includes(conflictColumn)) {
    throw new Error(`pgUpsert(${table}): row is missing conflict column "${conflictColumn}"`);
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

  const res = await pool.query(sql, values);
  return res.rows[0]?.id || null;
}

/** Looks up an existing row's id by a unique column, without inserting. */
async function pgLookupId(pool, table, column, value) {
  if (value === null || value === undefined) return null;
  const res = await pool.query(`select id from "${table}" where "${column}" = $1 limit 1`, [value]);
  return res.rows.length ? res.rows[0].id : null;
}

/** Soft-deletes (or hard-deletes, if `hardDelete` true) a row by its conflict column. */
async function pgDelete(pool, table, conflictColumn, firestoreId, { hardDelete = false, softColumn = 'is_active' } = {}) {
  if (hardDelete) {
    await pool.query(`delete from "${table}" where "${conflictColumn}" = $1`, [firestoreId]);
  } else {
    await pool.query(`update "${table}" set "${softColumn}" = false where "${conflictColumn}" = $1`, [firestoreId]);
  }
}

module.exports = { pick, num, ts, toIso, bool, strArray, jsonb, pgUpsert, pgLookupId, pgDelete };
