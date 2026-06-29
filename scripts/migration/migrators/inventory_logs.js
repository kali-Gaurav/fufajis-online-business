'use strict';

const { pick, num, ts } = require('../lib/transform');

const VALID_CHANGE_TYPES = new Set(['restock', 'sale', 'adjustment', 'return', 'damage']);

/** Firestore `inventory_logs/{id}` (or `products/{id}/inventory_logs/{id}`) -> Postgres `inventory_logs`. */
module.exports = {
  name: 'inventory_logs',
  table: 'inventory_logs',
  collection: 'inventory_logs',
  collectionGroup: true,
  conflictColumn: 'firestore_id',

  async map(doc, idmap, client) {
    const d = doc.data();

    const productFsId = pick(d, ['productId', 'product_id'])
      || (doc.ref.parent.path.startsWith('products/') ? doc.ref.parent.parent.id : undefined);
    const productId = await idmap.resolve(client, 'products', String(productFsId || ''));

    if (!productId) {
      return null; // product_id is NOT NULL — skip unresolvable rows
    }

    const changedByFsId = pick(d, ['changedBy', 'changed_by']);
    const changedBy = changedByFsId ? await idmap.resolve(client, 'users', String(changedByFsId)) : null;

    let changeType = String(pick(d, ['changeType', 'change_type'], 'adjustment')).toLowerCase();
    if (!VALID_CHANGE_TYPES.has(changeType)) changeType = 'adjustment';

    return {
      firestore_id: doc.id,
      product_id: productId,
      changed_by: changedBy,
      change_type: changeType,
      quantity_change: Math.trunc(num(pick(d, ['quantityChange', 'quantity_change'], 0))),
      stock_after: Math.trunc(num(pick(d, ['stockAfter', 'stock_after'], 0))),
      reason: pick(d, ['reason']) || null,
      reference_id: null, // no stable Firestore->uuid mapping for arbitrary references
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
    };
  },
};
