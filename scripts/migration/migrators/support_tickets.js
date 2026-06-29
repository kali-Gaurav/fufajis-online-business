'use strict';

const { pick, ts } = require('../lib/transform');

const VALID_STATUS = new Set(['open', 'in_progress', 'resolved', 'closed']);
const VALID_PRIORITY = new Set(['low', 'normal', 'high', 'urgent']);

/** Firestore `support_tickets/{id}` -> Postgres `support_tickets`. */
module.exports = {
  name: 'support_tickets',
  table: 'support_tickets',
  collection: 'support_tickets',
  conflictColumn: 'firestore_id',

  async map(doc, idmap, client) {
    const d = doc.data();

    const userFsId = pick(d, ['userId', 'user_id']);
    const userId = await idmap.resolve(client, 'users', String(userFsId || ''));

    if (!userId) {
      return null; // user_id is NOT NULL — skip unresolvable rows
    }

    const orderFsId = pick(d, ['orderId', 'order_id']);
    const orderId = orderFsId ? await idmap.resolve(client, 'orders', String(orderFsId)) : null;

    const assignedFsId = pick(d, ['assignedTo', 'assigned_to']);
    const assignedTo = assignedFsId ? await idmap.resolve(client, 'users', String(assignedFsId)) : null;

    let status = String(pick(d, ['status'], 'open')).toLowerCase().replace(/[\s-]+/g, '_');
    if (!VALID_STATUS.has(status)) status = 'open';

    let priority = String(pick(d, ['priority'], 'normal')).toLowerCase();
    if (!VALID_PRIORITY.has(priority)) priority = 'normal';

    return {
      firestore_id: doc.id,
      user_id: userId,
      order_id: orderId,
      subject: pick(d, ['subject', 'title'], '(no subject)'),
      description: pick(d, ['description', 'message']) || null,
      status,
      priority,
      assigned_to: assignedTo,
      resolution: pick(d, ['resolution']) || null,
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || undefined,
    };
  },
};
