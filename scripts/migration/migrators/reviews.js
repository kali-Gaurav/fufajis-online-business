'use strict';

const { pick, bool, ts, strArray } = require('../lib/transform');

/** Firestore `reviews/{id}` (or `products/{id}/reviews/{id}`) -> Postgres `reviews`. */
module.exports = {
  name: 'reviews',
  table: 'reviews',
  collection: 'reviews',
  collectionGroup: true,
  conflictColumn: 'firestore_id',

  async map(doc, idmap, client) {
    const d = doc.data();

    const productFsId = pick(d, ['productId', 'product_id'])
      || (doc.ref.parent.path.startsWith('products/') ? doc.ref.parent.parent.id : undefined);
    const userFsId = pick(d, ['userId', 'user_id']);
    const orderFsId = pick(d, ['orderId', 'order_id']);

    const productId = await idmap.resolve(client, 'products', String(productFsId || ''));
    const userId = await idmap.resolve(client, 'users', String(userFsId || ''));

    if (!productId || !userId) {
      return null; // product_id and user_id are NOT NULL — skip unresolvable rows
    }

    const orderId = orderFsId ? await idmap.resolve(client, 'orders', String(orderFsId)) : null;

    let rating = Math.trunc(Number(pick(d, ['rating'], 5)) || 5);
    if (rating < 1) rating = 1;
    if (rating > 5) rating = 5;

    return {
      firestore_id: doc.id,
      product_id: productId,
      user_id: userId,
      order_id: orderId,
      rating,
      comment: pick(d, ['comment', 'review']) || null,
      image_urls: strArray(pick(d, ['imageUrls', 'image_urls'])),
      is_verified_purchase: bool(pick(d, ['isVerifiedPurchase', 'is_verified_purchase']), false),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
    };
  },
};
