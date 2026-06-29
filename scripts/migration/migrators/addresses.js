'use strict';

const { pick, num, bool, ts } = require('../lib/transform');

/**
 * Firestore `users/{firebaseUid}/addresses/{id}` -> Postgres `addresses`.
 *
 * Uses a collectionGroup scan, so it picks up addresses regardless
 * of which user document they're nested under. Rows whose parent
 * user hasn't been migrated yet (or doesn't resolve) are skipped —
 * run the `users` migrator first.
 */
module.exports = {
  name: 'addresses',
  table: 'addresses',
  collection: 'addresses',
  collectionGroup: true,
  conflictColumn: 'firestore_id',

  async map(doc, idmap, client) {
    const d = doc.data();

    const parentRef = doc.ref.parent.parent; // users/{firebaseUid}
    const firebaseUid = parentRef ? parentRef.id : pick(d, ['userId', 'user_id']);
    const userId = await idmap.resolve(client, 'users', String(firebaseUid || ''));

    if (!userId) {
      return null; // skip — parent user not migrated/resolvable
    }

    return {
      firestore_id: doc.id,
      user_id: userId,
      label: pick(d, ['label']) || null,
      line1: pick(d, ['line1', 'addressLine1', 'address'], ''),
      line2: pick(d, ['line2', 'addressLine2']) || null,
      landmark: pick(d, ['landmark']) || null,
      city: pick(d, ['city']) || null,
      state: pick(d, ['state']) || null,
      pincode: pick(d, ['pincode', 'pinCode', 'zip']) || null,
      latitude: pick(d, ['latitude', 'lat']) != null ? num(pick(d, ['latitude', 'lat'])) : null,
      longitude: pick(d, ['longitude', 'lng', 'lon']) != null ? num(pick(d, ['longitude', 'lng', 'lon'])) : null,
      is_default: bool(pick(d, ['isDefault', 'is_default']), false),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || undefined,
    };
  },

  async afterUpsert(client, doc, row, pgId, idmap) {
    idmap.set('addresses', doc.id, pgId);
  },
};
