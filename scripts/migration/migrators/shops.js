'use strict';

const { pick, bool, ts, jsonb } = require('../lib/transform');

/** Firestore `shops/{shopId}` -> Postgres `shops`. */
module.exports = {
  name: 'shops',
  table: 'shops',
  collection: 'shops',
  conflictColumn: 'firestore_id',

  async map(doc, idmap, client) {
    const d = doc.data();

    const ownerFsId = pick(d, ['ownerId', 'owner_id', 'shopOwnerId']);
    const ownerId = ownerFsId ? await idmap.resolve(client, 'users', String(ownerFsId)) : null;

    return {
      firestore_id: doc.id,
      name: pick(d, ['name', 'shopName'], doc.id),
      owner_id: ownerId,
      phone: pick(d, ['phone', 'phoneNumber']) || null,
      email: pick(d, ['email']) || null,
      address: pick(d, ['address', 'addressLine']) || null,
      city: pick(d, ['city']) || null,
      state: pick(d, ['state']) || null,
      pincode: pick(d, ['pincode', 'zip']) || null,
      latitude: pick(d, ['latitude', 'lat']) != null ? Number(pick(d, ['latitude', 'lat'])) : null,
      longitude: pick(d, ['longitude', 'lng', 'long']) != null ? Number(pick(d, ['longitude', 'lng', 'long'])) : null,
      is_active: bool(pick(d, ['isActive', 'is_active']), true),
      is_open: bool(pick(d, ['isOpen', 'is_open']), true),
      metadata: jsonb(pick(d, ['metadata']), {}),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || undefined,
    };
  },

  async afterUpsert(client, doc, row, pgId, idmap) {
    idmap.set('shops', doc.id, pgId);
  },
};
