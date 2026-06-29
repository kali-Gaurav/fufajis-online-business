'use strict';

const { pick, num, ts, jsonb } = require('../lib/transform');
const { upsert } = require('../lib/pg');

const VALID_ORDER_STATUS = new Set([
  'pending', 'confirmed', 'preparing', 'ready_for_pickup',
  'out_for_delivery', 'delivered', 'cancelled', 'refunded',
]);
const VALID_PAYMENT_STATUS = new Set(['pending', 'paid', 'failed', 'refunded', 'partial_refund']);

function normalizeStatus(value, allowed, fallback) {
  const v = String(value || '').toLowerCase().replace(/[\s-]+/g, '_');
  return allowed.has(v) ? v : fallback;
}

/**
 * Firestore `orders/{id}` -> Postgres `orders`, plus embedded
 * `order_items` array -> `order_items` rows, and a seeded
 * `order_status_history` row reflecting the order's current status
 * (full historical transitions aren't available from Firestore).
 */
module.exports = {
  name: 'orders',
  table: 'orders',
  collection: 'orders',
  conflictColumn: 'firestore_id',

  async map(doc, idmap, client) {
    const d = doc.data();

    const userFsId = pick(d, ['userId', 'customerId', 'user_id']);
    const vendorFsId = pick(d, ['vendorId', 'vendor_id']);
    const driverFsId = pick(d, ['driverId', 'deliveryAgentId', 'driver_id']);
    const addressFsId = pick(d, ['addressId', 'address_id']);
    const shopFsId = pick(d, ['shopId', 'shop_id']);
    const branchFsId = pick(d, ['branchId', 'branch_id']);

    const userId = userFsId ? await idmap.resolve(client, 'users', String(userFsId)) : null;
    const vendorId = vendorFsId ? await idmap.resolve(client, 'users', String(vendorFsId)) : null;
    const driverId = driverFsId ? await idmap.resolve(client, 'users', String(driverFsId)) : null;
    const addressId = addressFsId ? await idmap.resolve(client, 'addresses', String(addressFsId)) : null;
    const shopId = shopFsId ? await idmap.resolve(client, 'shops', String(shopFsId)) : null;
    const branchId = branchFsId ? await idmap.resolve(client, 'branches', String(branchFsId)) : null;

    const placedAt = ts(pick(d, ['createdAt', 'placedAt', 'created_at']));
    const deliveredAt = ts(pick(d, ['deliveredAt', 'delivered_at']));

    return {
      firestore_id: doc.id,
      order_number: pick(d, ['orderNumber', 'order_number'], doc.id),
      user_id: userId,
      vendor_id: vendorId,
      driver_id: driverId,
      address_id: addressId,
      shop_id: shopId,
      branch_id: branchId,
      order_status: normalizeStatus(pick(d, ['orderStatus', 'status', 'order_status']), VALID_ORDER_STATUS, 'pending'),
      payment_status: normalizeStatus(pick(d, ['paymentStatus', 'payment_status']), VALID_PAYMENT_STATUS, 'pending'),
      payment_method: pick(d, ['paymentMethod', 'payment_method']) || null,
      subtotal: num(pick(d, ['subtotal'], 0)),
      discount: num(pick(d, ['discount'], 0)),
      delivery_fee: num(pick(d, ['deliveryFee', 'delivery_fee'], 0)),
      tax: num(pick(d, ['tax'], 0)),
      total: num(pick(d, ['total', 'totalAmount', 'grandTotal'], 0)),
      coupon_code: pick(d, ['couponCode', 'coupon_code']) || null,
      notes: pick(d, ['notes']) || null,
      cancelled_reason: pick(d, ['cancelledReason', 'cancelled_reason']) || null,
      placed_at: placedAt || undefined,
      delivered_at: deliveredAt,
      created_at: placedAt || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || undefined,
      // not a column on `orders` — used by afterUpsert only:
      __items: Array.isArray(d.items) ? d.items : (Array.isArray(d.orderItems) ? d.orderItems : []),
    };
  },

  async afterUpsert(client, doc, row, pgId, idmap) {
    idmap.set('orders', doc.id, pgId);

    // --- order_items (embedded array on the order document) ---
    const items = row.__items || [];
    for (const item of items) {
      const productFsId = pick(item, ['productId', 'product_id']);
      const productId = productFsId ? await idmap.resolve(client, 'products', String(productFsId)) : null;

      const quantity = Math.trunc(num(pick(item, ['quantity', 'qty'], 1), 1));
      const unitPrice = num(pick(item, ['unitPrice', 'price', 'unit_price'], 0));
      const itemSubtotal = num(pick(item, ['subtotal'], unitPrice * quantity));

      // order_items has no unique constraint to upsert against safely
      // across reruns without a firestore-level item id, so dedupe by
      // (order_id, product_id, product_name) via a manual check.
      const existing = await client.query(
        `select id from order_items
           where order_id = $1
             and product_name = $2
             and coalesce(product_id::text, '') = coalesce($3::text, '')
           limit 1`,
        [pgId, pick(item, ['name', 'productName'], 'Item'), productId]
      );

      if (existing.rows.length > 0) {
        await client.query(
          `update order_items
             set unit_price = $1, quantity = $2, subtotal = $3, metadata = $4
             where id = $5`,
          [unitPrice, quantity, itemSubtotal, jsonb(item.metadata, {}), existing.rows[0].id]
        );
      } else {
        await client.query(
          `insert into order_items
             (order_id, product_id, product_name, unit_price, quantity, subtotal, metadata)
           values ($1, $2, $3, $4, $5, $6, $7)`,
          [pgId, productId, pick(item, ['name', 'productName'], 'Item'), unitPrice, quantity, itemSubtotal, jsonb(item.metadata, {})]
        );
      }
    }

    // --- order_status_history (seed a single row for the current status) ---
    const historyExists = await client.query(
      `select 1 from order_status_history where order_id = $1 limit 1`,
      [pgId]
    );
    if (historyExists.rows.length === 0) {
      await client.query(
        `insert into order_status_history (order_id, from_status, to_status, reason, created_at)
         values ($1, null, $2, 'Migrated from Firestore (history not available)', coalesce($3, now()))`,
        [pgId, row.order_status, row.updated_at || row.placed_at || null]
      );
    }
  },
};
