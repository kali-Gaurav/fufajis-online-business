'use strict';

const { pick, bool, ts } = require('../lib/transform');

/** Firestore `categories/{id}` -> Postgres `categories`. */
module.exports = {
  name: 'categories',
  table: 'categories',
  collection: 'categories',
  conflictColumn: 'firestore_id',

  async map(doc, idmap, client) {
    const d = doc.data();

    // Parent category may not have been migrated yet if Firestore
    // ordering puts a child before its parent — resolve what we
    // can now; a second pass (run the script twice) will fill in
    // any still-null parent_id values once all categories exist.
    const parentFirestoreId = pick(d, ['parentId', 'parent_id']);
    const parentId = parentFirestoreId
      ? await idmap.resolve(client, 'categories', String(parentFirestoreId))
      : null;

    return {
      firestore_id: doc.id,
      name: pick(d, ['name'], doc.id),
      name_hi: pick(d, ['nameHi', 'name_hi']) || null,
      slug: pick(d, ['slug', 'id'], doc.id),
      parent_id: parentId,
      icon_url: pick(d, ['iconUrl', 'icon_url']) || null,
      display_order: Math.trunc(Number(pick(d, ['displayOrder', 'display_order'], 0)) || 0),
      is_active: bool(pick(d, ['isActive', 'is_active']), true),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || undefined,
    };
  },

  async afterUpsert(client, doc, row, pgId, idmap) {
    idmap.set('categories', doc.id, pgId);
  },
};
