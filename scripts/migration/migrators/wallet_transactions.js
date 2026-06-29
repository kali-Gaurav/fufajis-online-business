'use strict';

const { pick, num, ts, jsonb } = require('../lib/transform');

const VALID_TYPES = new Set(['credit', 'debit', 'referralBonus', 'refund', 'adjustment', 'topup']);

/** Firestore `wallet_transactions/{id}` (or `users/{uid}/wallet_transactions/{id}`) -> Postgres `wallet_transactions`. */
module.exports = {
  name: 'wallet_transactions',
  table: 'wallet_transactions',
  collection: 'wallet_transactions',
  collectionGroup: true,
  conflictColumn: 'firestore_id',

  async map(doc, idmap, client) {
    const d = doc.data();

    const userFsId = pick(d, ['userId', 'user_id'])
      || (doc.ref.parent.path.startsWith('users/') ? doc.ref.parent.parent.id : undefined);
    const userId = await idmap.resolve(client, 'users', String(userFsId || ''));

    if (!userId) {
      return null; // user_id is NOT NULL — skip unresolvable rows
    }

    const orderFsId = pick(d, ['orderId', 'order_id']);
    const orderId = orderFsId ? await idmap.resolve(client, 'orders', String(orderFsId)) : null;

    let type = pick(d, ['type'], 'adjustment');
    if (!VALID_TYPES.has(type)) type = 'adjustment';

    return {
      firestore_id: doc.id,
      user_id: userId,
      order_id: orderId,
      type,
      amount: num(pick(d, ['amount'], 0)),
      balance_after: num(pick(d, ['balanceAfter', 'balance_after'], 0)),
      description: pick(d, ['description']) || null,
      metadata: jsonb(pick(d, ['metadata']), {}),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
    };
  },
};
