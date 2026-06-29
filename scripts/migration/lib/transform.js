'use strict';

const { toIso } = require('./firestore');

/** Returns the first defined (non-undefined, non-null) value among `data[keys[i]]`. */
function pick(data, keys, fallback = undefined) {
  for (const k of keys) {
    if (data[k] !== undefined && data[k] !== null) return data[k];
  }
  return fallback;
}

/** Coerces to number, returning `fallback` if not numeric. */
function num(value, fallback = 0) {
  if (value === null || value === undefined) return fallback;
  if (typeof value === 'number') return value;
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

/** Coerces to a Postgres-friendly ISO timestamp string, or null. */
function ts(value) {
  return toIso(value);
}

/** Coerces to boolean. */
function bool(value, fallback = false) {
  if (typeof value === 'boolean') return value;
  if (value === undefined || value === null) return fallback;
  return Boolean(value);
}

/** Coerces to a string array, or null. */
function strArray(value) {
  if (!Array.isArray(value)) return null;
  return value.map((v) => String(v));
}

/** Safely JSON-stringifies an object for jsonb columns (pg accepts objects directly for jsonb, but arrays of primitives need care). */
function jsonb(value, fallback = {}) {
  if (value === null || value === undefined) return fallback;
  if (typeof value === 'object') return value;
  return fallback;
}

module.exports = { pick, num, ts, bool, strArray, jsonb };
