'use strict';

const { pick, num, ts } = require('../lib/transform');

const VALID_STATUS = new Set([
  'assigned', 'accepted', 'arrived_pickup', 'picked_up',
  'arrived_dropoff', 'delivered', 'failed', 'cancelled',
]);

/** Firestore `delivery_tracking/{id}` (or `orders/{id}/tracking/{id}`) -> Postgres `delivery_tracking`. */
module.exports = {
  name: 'delivery_tracking',
  table: 'delivery_tracking',
  collection: 'delivery_tracking',
  collectionGroup: true,
  conflictColumn: 'firestore_id',

  async map(doc, idmap, client) {
    const d = doc.data();

    const orderFsId = pick(d, ['orderId', 'order_id'])
      || (doc.ref.parent.path.startsWith('orders/') ? doc.ref.parent.parent.id : undefined);
    const orderId = await idmap.resolve(client, 'orders', String(orderFsId || ''));

    if (!orderId) {
      return null; // order_id is NOT NULL — skip unresolvable rows
    }

    const driverFsId = pick(d, ['driverId', 'driver_id']);
    const driverId = driverFsId ? await idmap.resolve(client, 'users', String(driverFsId)) : null;

    let status = String(pick(d, ['status'], 'assigned')).toLowerCase().replace(/[\s-]+/g, '_');
    if (!VALID_STATUS.has(status)) status = 'assigned';

    const lat = pick(d, ['latitude', 'lat']);
    const lng = pick(d, ['longitude', 'lng', 'lon']);

    return {
      firestore_id: doc.id,
      order_id: orderId,
      driver_id: driverId,
      status,
      latitude: lat != null ? num(lat) : null,
      longitude: lng != null ? num(lng) : null,
      proof_image_url: pick(d, ['proofImageUrl', 'proof_image_url']) || null,
      notes: pick(d, ['notes']) || null,
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || undefined,
    };
  },
};
