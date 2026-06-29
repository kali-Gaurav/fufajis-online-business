'use strict';

const { pick, bool, ts, jsonb } = require('../lib/transform');

/** Firestore `notifications/{id}` (or `users/{uid}/notifications/{id}`) -> Postgres `notifications`. */
module.exports = {
  name: 'notifications',
  table: 'notifications',
  collection: 'notifications',
  collectionGroup: true,
  conflictColumn: 'firestore_id',

  async map(doc, idmap, client) {
    const d = doc.data();

    const userFsId = pick(d, ['userId', 'user_id'])
      || (doc.ref.parent.path.startsWith('users/') ? doc.ref.parent.parent.id : undefined);
    const userId = userFsId ? await idmap.resolve(client, 'users', String(userFsId)) : null;

    return {
      firestore_id: doc.id,
      user_id: userId,
      title: pick(d, ['title'], '(no title)'),
      body: pick(d, ['body', 'message']) || null,
      type: pick(d, ['type']) || null,
      data: jsonb(pick(d, ['data']), {}),
      is_read: bool(pick(d, ['isRead', 'read', 'is_read']), false),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
    };
  },
};
