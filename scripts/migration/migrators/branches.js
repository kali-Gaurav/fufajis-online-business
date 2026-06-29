'use strict';

const { pick, bool, ts, jsonb } = require('../lib/transform');

/**
 * Firestore `shops/{shopId}/branches/{branchId}` -> Postgres `branches`.
 *
 * Read via `collectionGroup('branches')` so it's picked up regardless of
 * which shop it's nested under. `shop_id` is resolved from the parent
 * document's id (`doc.ref.parent.parent.id` is the `shops/{shopId}` doc),
 * which must already exist in `idmap` — i.e. the `shops` migrator must run
 * before this one (enforced by ordering in migrators/index.js).
 */
module.exports = {
  name: 'branches',
  table: 'branches',
  collection: 'branches',
  collectionGroup: true,
  conflictColumn: 'firestore_id',

  async map(doc, idmap, client) {
    const d = doc.data();

    const parentShopDoc = doc.ref.parent && doc.ref.parent.parent;
    const shopFirestoreId = parentShopDoc ? parentShopDoc.id : pick(d, ['shopId', 'shop_id']);
    const shopId = shopFirestoreId ? await idmap.resolve(client, 'shops', String(shopFirestoreId)) : null;

    if (!shopId) {
      // Branch references a shop that hasn't been migrated yet (or has
      // no parent doc, e.g. a stray top-level "branches" collection) —
      // skip rather than insert with a null shop_id that we can't later
      // distinguish from "intentionally unassigned".
      return null;
    }

    const managerFsId = pick(d, ['managerId', 'manager_id', 'branchManagerId']);
    const managerId = managerFsId ? await idmap.resolve(client, 'users', String(managerFsId)) : null;

    return {
      firestore_id: doc.id,
      shop_id: shopId,
      name: pick(d, ['name', 'branchName'], doc.id),
      branch_code: pick(d, ['branchCode', 'branch_code', 'code']) || null,
      manager_id: managerId,
      phone: pick(d, ['phone', 'phoneNumber']) || null,
      address: pick(d, ['address', 'addressLine']) || null,
      city: pick(d, ['city']) || null,
      state: pick(d, ['state']) || null,
      pincode: pick(d, ['pincode', 'zip']) || null,
      latitude: pick(d, ['latitude', 'lat']) != null ? Number(pick(d, ['latitude', 'lat'])) : null,
      longitude: pick(d, ['longitude', 'lng', 'long']) != null ? Number(pick(d, ['longitude', 'lng', 'long'])) : null,
      is_active: bool(pick(d, ['isActive', 'is_active']), true),
      metadata: jsonb(pick(d, ['metadata']), {}),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || undefined,
    };
  },

  async afterUpsert(client, doc, row, pgId, idmap) {
    idmap.set('branches', doc.id, pgId);
  },
};
