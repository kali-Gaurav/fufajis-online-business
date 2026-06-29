'use strict';

const admin = require('firebase-admin');

let app = null;

/**
 * Initializes (once) and returns a Firestore instance using the
 * service account credentials pointed to by
 * GOOGLE_APPLICATION_CREDENTIALS.
 */
function getFirestore() {
  if (!app) {
    app = admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  }
  return admin.firestore();
}

/**
 * Iterates every document in `collectionName`, in pages of
 * `pageSize`, calling `onPage(docs)` for each page. Uses
 * document-id ordering so pagination is stable even if the
 * collection is being written to concurrently.
 *
 * `onPage` may return a promise; pages are processed
 * sequentially (never in parallel) to keep Postgres load
 * predictable.
 */
async function forEachDocPage(collectionName, pageSize, onPage) {
  const db = getFirestore();
  let lastDoc = null;
  let total = 0;

  // eslint-disable-next-line no-constant-condition
  while (true) {
    let query = db.collection(collectionName).orderBy('__name__').limit(pageSize);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    await onPage(snap.docs);

    total += snap.docs.length;
    lastDoc = snap.docs[snap.docs.length - 1];

    if (snap.docs.length < pageSize) break;
  }

  return total;
}

/**
 * Iterates every document in a subcollection across ALL parent
 * documents (e.g. orders/{id}/items). Less efficient than a
 * top-level collection scan but Firestore doesn't support
 * cross-document subcollection queries without the v8+
 * `collectionGroup` API, which IS used here.
 */
async function forEachCollectionGroupPage(collectionGroupId, pageSize, onPage) {
  const db = getFirestore();
  let lastDoc = null;
  let total = 0;

  // eslint-disable-next-line no-constant-condition
  while (true) {
    let query = db.collectionGroup(collectionGroupId).orderBy('__name__').limit(pageSize);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    await onPage(snap.docs);

    total += snap.docs.length;
    lastDoc = snap.docs[snap.docs.length - 1];

    if (snap.docs.length < pageSize) break;
  }

  return total;
}

/** Converts Firestore Timestamps / Dates / strings to ISO 8601, else returns input. */
function toIso(value) {
  if (value === null || value === undefined) return null;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'string') return value;
  return null;
}

module.exports = { getFirestore, forEachDocPage, forEachCollectionGroupPage, toIso };
