'use strict';

const functions = require('firebase-functions');
const { getPgPool } = require('./aws_services');
const { pick, num, ts, bool, strArray, jsonb, pgUpsert, pgDelete } = require('./sync_transform');

/**
 * ═══════════════════════════════════════════════════════════════════════
 * STREAMING FIRESTORE -> POSTGRES SYNC
 * ═══════════════════════════════════════════════════════════════════════
 * Mirrors the field-mapping conventions of scripts/migration/migrators/*.js
 * (the one-time historical backfill), but runs continuously: every write to
 * a tracked Firestore collection upserts the corresponding Postgres row via
 * `ON CONFLICT (firestore_id | firebase_uid) DO UPDATE`, keeping Supabase/RDS
 * in near-real-time sync with Firestore.
 *
 * See docs/FIRESTORE_POSTGRES_SYNC.md for the full design write-up
 * (collection -> table map, ordering/idempotency guarantees, error
 * handling, and how this relates to the one-time `migrate.js` backfill).
 *
 * IMPORTANT — this module NEVER writes inventory/stock changes. Product
 * `stock_quantity` sync here mirrors whatever Firestore has (which itself is
 * only mutated through the approved inventory flows — see
 * docs/RBAC.md "Escalation Path: Inventory Change Requests"). This module is
 * a passive mirror, not a write path.
 */

const VALID_ORDER_STATUS = new Set([
  'pending', 'confirmed', 'preparing', 'ready_for_pickup',
  'out_for_delivery', 'delivered', 'cancelled', 'refunded',
]);
const VALID_PAYMENT_STATUS = new Set(['pending', 'paid', 'failed', 'refunded', 'partial_refund']);

function normalizeStatus(value, allowed, fallback) {
  const v = String(value || '').toLowerCase().replace(/[\s-]+/g, '_');
  return allowed.has(v) ? v : fallback;
}

/** Resolves a Postgres uuid for a Firestore doc id via the matching unique column. Returns null on miss (no insert). */
async function resolveId(pool, table, column, firestoreId) {
  if (!firestoreId) return null;
  const res = await pool.query(`select id from "${table}" where "${column}" = $1 limit 1`, [String(firestoreId)]);
  return res.rows.length ? res.rows[0].id : null;
}

const RDS_SECRETS = ['RDS_CONNECTION_STRING', 'RDS_HOST', 'RDS_PORT', 'RDS_USER', 'RDS_PASSWORD', 'RDS_DATABASE'];

// ───────────────────────────────────────────────────────────────────────
// users  (users/{firebaseUid})
// ───────────────────────────────────────────────────────────────────────
exports.syncUserToPostgres = functions.runWith({ secrets: RDS_SECRETS }).firestore
  .document('users/{uid}')
  .onWrite(async (change, context) => {
    const pool = getPgPool();
    const uid = context.params.uid;

    if (!change.after.exists) {
      // Soft-delete: keep the row (FKs from orders/products/etc. reference
      // it) but mark inactive.
      await pgDelete(pool, 'users', 'firebase_uid', uid, { hardDelete: false, softColumn: 'is_active' });
      return null;
    }

    const d = change.after.data();
    const rawRole = pick(d, ['role', 'userRole'], 'customer');
    let cleanRole = 'customer';
    if (rawRole) {
      const r = String(rawRole).replace('UserRole.', '').toLowerCase().trim();
      if (r === 'admin' || r === 'superadmin') {
        cleanRole = 'admin';
      } else if (r === 'shopowner' || r === 'owner' || r === 'franchiseowner') {
        cleanRole = 'shop_owner';
      } else if (r === 'rider') {
        cleanRole = 'rider';
      } else if (r === 'customer') {
        cleanRole = 'customer';
      } else {
        // employee, branchmanager, dispatcher, etc.
        cleanRole = 'employee';
      }
    }

    const row = {
      firebase_uid: uid,
      phone: pick(d, ['phone', 'phoneNumber']) || null,
      email: pick(d, ['email']) || null,
      name: pick(d, ['name', 'displayName', 'fullName']) || null,
      role: cleanRole,
      wallet_balance: num(pick(d, ['walletBalance', 'wallet_balance']), 0),
      cod_limit: num(pick(d, ['codLimit', 'cod_limit']), 0),
      loyalty_points: Math.trunc(num(pick(d, ['loyaltyPoints', 'loyalty_points']), 0)),
      referral_code: pick(d, ['referralCode', 'referral_code']) || null,
      referred_by: pick(d, ['referredBy', 'referred_by']) || null,
      is_active: bool(pick(d, ['isActive', 'is_active']), true),
      is_verified: bool(pick(d, ['isVerified', 'is_verified']), false),
      metadata: jsonb(pick(d, ['metadata']), {}),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'lastLogin', 'updated_at'])) || new Date().toISOString(),
    };

    await pgUpsert(pool, 'users', 'firebase_uid', row);
    return null;
  });

// ───────────────────────────────────────────────────────────────────────
// categories  (categories/{id})
// ───────────────────────────────────────────────────────────────────────
exports.syncCategoryToPostgres = functions.runWith({ secrets: RDS_SECRETS }).firestore
  .document('categories/{id}')
  .onWrite(async (change, context) => {
    const pool = getPgPool();
    const fsId = context.params.id;

    if (!change.after.exists) {
      await pgDelete(pool, 'categories', 'firestore_id', fsId, { hardDelete: false, softColumn: 'is_active' });
      return null;
    }

    const d = change.after.data();
    const parentFsId = pick(d, ['parentId', 'parent_id']);
    const parentId = parentFsId ? await resolveId(pool, 'categories', 'firestore_id', String(parentFsId)) : null;

    const row = {
      firestore_id: fsId,
      name: pick(d, ['name'], fsId),
      name_hi: pick(d, ['nameHi', 'name_hi']) || null,
      slug: pick(d, ['slug', 'id'], fsId),
      parent_id: parentId,
      icon_url: pick(d, ['iconUrl', 'icon_url']) || null,
      display_order: Math.trunc(Number(pick(d, ['displayOrder', 'display_order'], 0)) || 0),
      is_active: bool(pick(d, ['isActive', 'is_active']), true),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || new Date().toISOString(),
    };

    await pgUpsert(pool, 'categories', 'firestore_id', row);
    return null;
  });

// ───────────────────────────────────────────────────────────────────────
// products  (products/{id})
// ───────────────────────────────────────────────────────────────────────
exports.syncProductToPostgres = functions.runWith({ secrets: RDS_SECRETS }).firestore
  .document('products/{id}')
  .onWrite(async (change, context) => {
    const pool = getPgPool();
    const fsId = context.params.id;

    if (!change.after.exists) {
      await pgDelete(pool, 'products', 'firestore_id', fsId, { hardDelete: false, softColumn: 'active' });
      return null;
    }

    const d = change.after.data();
    const vendorFsId = pick(d, ['vendorId', 'vendor_id', 'ownerId', 'shopOwnerId']);
    const categoryFsId = pick(d, ['categoryId', 'category_id']);

    const vendorId = vendorFsId ? await resolveId(pool, 'users', 'firebase_uid', String(vendorFsId)) : null;
    const categoryId = categoryFsId ? await resolveId(pool, 'categories', 'firestore_id', String(categoryFsId)) : null;

    const row = {
      firestore_id: fsId,
      vendor_id: vendorId,
      category_id: categoryId,
      name: pick(d, ['name', 'title'], ''),
      name_hi: pick(d, ['nameHi', 'name_hi']) || null,
      description: pick(d, ['description', 'desc']) || null,
      sku: pick(d, ['sku']) || null,
      barcode: pick(d, ['barcode']) || null,
      unit_type: pick(d, ['unitType', 'unit', 'unit_type']) || null,
      price: num(pick(d, ['price', 'sellingPrice'], 0)),
      mrp: num(pick(d, ['mrp', 'maxRetailPrice'], 0)),
      cost_price: pick(d, ['costPrice', 'cost_price']) != null ? num(pick(d, ['costPrice', 'cost_price'])) : null,
      stock_quantity: Math.trunc(num(pick(d, ['stockQuantity', 'stock', 'stock_quantity']), 0)),
      low_stock_threshold: Math.trunc(num(pick(d, ['lowStockThreshold', 'low_stock_threshold']), 5)),
      image_urls: strArray(pick(d, ['imageUrls', 'images', 'image_urls'])) || [],
      tags: strArray(pick(d, ['tags'])) || [],
      brand: pick(d, ['brand']) || null,
      tax_code: pick(d, ['taxCode', 'tax_code']) || null,
      is_active: bool(pick(d, ['isActive', 'is_active']), true),
      active: bool(pick(d, ['isActive', 'is_active']), true),
      is_featured: bool(pick(d, ['isFeatured', 'is_featured']), false),
      rating: pick(d, ['rating']) != null ? num(pick(d, ['rating'])) : null,
      rating_count: Math.trunc(num(pick(d, ['ratingCount', 'rating_count']), 0)),
      metadata: jsonb(pick(d, ['metadata']), {}),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || new Date().toISOString(),
    };

    await pgUpsert(pool, 'products', 'firestore_id', row);
    return null;
  });

// ───────────────────────────────────────────────────────────────────────
// users/{uid}/addresses/{id}  (collection group)
// ───────────────────────────────────────────────────────────────────────
exports.syncAddressToPostgres = functions.runWith({ secrets: RDS_SECRETS }).firestore
  .document('users/{uid}/addresses/{addressId}')
  .onWrite(async (change, context) => {
    const pool = getPgPool();
    const fsId = context.params.addressId;
    const firebaseUid = context.params.uid;

    if (!change.after.exists) {
      await pgDelete(pool, 'addresses', 'firestore_id', fsId, { hardDelete: true });
      return null;
    }

    const d = change.after.data();
    const userId = await resolveId(pool, 'users', 'firebase_uid', String(firebaseUid));
    if (!userId) {
      // Parent user hasn't synced yet (rare race on first signup). The
      // user-sync trigger will fire moments later; this address write will
      // be retried on its own next edit, or can be backfilled by
      // scripts/migration/migrate.js --only=addresses.
      console.warn(`[syncAddressToPostgres] user ${firebaseUid} not yet in Postgres, skipping address ${fsId}`);
      return null;
    }

    const row = {
      firestore_id: fsId,
      user_id: userId,
      label: pick(d, ['label']) || null,
      line1: pick(d, ['line1', 'addressLine1', 'address'], ''),
      line2: pick(d, ['line2', 'addressLine2']) || null,
      landmark: pick(d, ['landmark']) || null,
      city: pick(d, ['city']) || null,
      state: pick(d, ['state']) || null,
      pincode: pick(d, ['pincode', 'pinCode', 'zip']) || null,
      latitude: pick(d, ['latitude', 'lat']) != null ? num(pick(d, ['latitude', 'lat'])) : null,
      longitude: pick(d, ['longitude', 'lng', 'lon']) != null ? num(pick(d, ['longitude', 'lng', 'lon'])) : null,
      is_default: bool(pick(d, ['isDefault', 'is_default']), false),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || new Date().toISOString(),
    };

    await pgUpsert(pool, 'addresses', 'firestore_id', row);
    return null;
  });

// ───────────────────────────────────────────────────────────────────────
// orders/{id}  (+ embedded order_items array, + status-history append)
// ───────────────────────────────────────────────────────────────────────
exports.syncOrderToPostgres = functions.runWith({ secrets: RDS_SECRETS }).firestore
  .document('orders/{id}')
  .onWrite(async (change, context) => {
    const pool = getPgPool();
    const fsId = context.params.id;

    if (!change.after.exists) {
      // Orders are never hard-deleted from the analytical store — a
      // Firestore delete here is unusual (orders are normally
      // cancelled, not removed). Leave the Postgres row as the last
      // known state for audit purposes.
      console.warn(`[syncOrderToPostgres] order ${fsId} deleted in Firestore — Postgres row retained as-is`);
      return null;
    }

    const before = change.before.exists ? change.before.data() : null;
    const d = change.after.data();

    const userFsId = pick(d, ['userId', 'customerId', 'user_id']);
    const vendorFsId = pick(d, ['vendorId', 'vendor_id']);
    const driverFsId = pick(d, ['driverId', 'deliveryAgentId', 'driver_id']);
    const addressFsId = pick(d, ['addressId', 'address_id']);

    const userId = userFsId ? await resolveId(pool, 'users', 'firebase_uid', String(userFsId)) : null;
    const vendorId = vendorFsId ? await resolveId(pool, 'users', 'firebase_uid', String(vendorFsId)) : null;
    const driverId = driverFsId ? await resolveId(pool, 'users', 'firebase_uid', String(driverFsId)) : null;
    const addressId = addressFsId ? await resolveId(pool, 'addresses', 'firestore_id', String(addressFsId)) : null;

    const placedAt = ts(pick(d, ['createdAt', 'placedAt', 'created_at']));
    const newStatus = normalizeStatus(pick(d, ['orderStatus', 'status', 'order_status']), VALID_ORDER_STATUS, 'pending');
    const oldStatus = before
      ? normalizeStatus(pick(before, ['orderStatus', 'status', 'order_status']), VALID_ORDER_STATUS, null)
      : null;

    const row = {
      firestore_id: fsId,
      order_number: pick(d, ['orderNumber', 'order_number'], fsId),
      user_id: userId,
      vendor_id: vendorId,
      driver_id: driverId,
      address_id: addressId,
      order_status: newStatus,
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
      delivered_at: ts(pick(d, ['deliveredAt', 'delivered_at'])),
      created_at: placedAt || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || new Date().toISOString(),
    };

    const orderId = await pgUpsert(pool, 'orders', 'firestore_id', row);
    if (!orderId) return null;

    // --- order_items: replace-on-write. Firestore order documents embed
    // the full item list; rather than diffing, delete and re-insert the
    // snapshot for this order on every write. Cheap (orders have a small,
    // bounded item count) and avoids drift between Firestore and Postgres.
    const items = Array.isArray(d.items) ? d.items : (Array.isArray(d.orderItems) ? d.orderItems : []);
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('delete from order_items where order_id = $1', [orderId]);
      for (const item of items) {
        const productFsId = pick(item, ['productId', 'product_id']);
        const productId = productFsId ? await resolveId(pool, 'products', 'firestore_id', String(productFsId)) : null;
        const quantity = Math.trunc(num(pick(item, ['quantity', 'qty'], 1), 1));
        const unitPrice = num(pick(item, ['unitPrice', 'price', 'unit_price'], 0));
        const itemSubtotal = num(pick(item, ['subtotal'], unitPrice * quantity));

        await client.query(
          `insert into order_items
             (order_id, product_id, product_name, unit_price, quantity, subtotal, metadata)
           values ($1, $2, $3, $4, $5, $6, $7)`,
          [orderId, productId, pick(item, ['name', 'productName'], 'Item'), unitPrice, quantity, itemSubtotal, jsonb(item.metadata, {})]
        );
      }

      // --- order_status_history: append a row only when order_status
      // actually changed (or this is the first write).
      if (!before || oldStatus !== newStatus) {
        await client.query(
          `insert into order_status_history (order_id, from_status, to_status, reason, created_at)
           values ($1, $2, $3, $4, now())`,
          [orderId, oldStatus, newStatus, pick(d, ['statusChangeReason', 'cancelledReason'], null)]
        );
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      console.error(`[syncOrderToPostgres] order_items/status_history sync failed for ${fsId}:`, err.message);
    } finally {
      client.release();
    }

    return null;
  });
