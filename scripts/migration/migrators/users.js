'use strict';

const { pick, num, ts, bool, jsonb } = require('../lib/transform');

/**
 * Firestore `users/{firebaseUid}` -> Postgres `users`.
 *
 * The Firestore document id IS the Firebase Auth uid, which is
 * also the natural conflict key (`firebase_uid` is unique).
 */
module.exports = {
  name: 'users',
  table: 'users',
  collection: 'users',
  conflictColumn: 'firebase_uid',

  async map(doc, idmap, client) {
    const d = doc.data();

    const role = pick(d, ['role', 'userRole'], 'customer');

    const shopFsId = pick(d, ['shopId', 'shop_id']);
    const branchFsId = pick(d, ['branchId', 'branch_id']);
    const shopId = shopFsId ? await idmap.resolve(client, 'shops', String(shopFsId)) : null;
    const branchId = branchFsId ? await idmap.resolve(client, 'branches', String(branchFsId)) : null;

    const row = {
      firebase_uid: doc.id,
      phone: pick(d, ['phone', 'phoneNumber']) || null,
      email: pick(d, ['email']) || null,
      name: pick(d, ['name', 'displayName', 'fullName']) || null,
      role: String(role),
      wallet_balance: num(pick(d, ['walletBalance', 'wallet_balance']), 0),
      cod_limit: num(pick(d, ['codLimit', 'cod_limit']), 0),
      loyalty_points: Math.trunc(num(pick(d, ['loyaltyPoints', 'loyalty_points']), 0)),
      referral_code: pick(d, ['referralCode', 'referral_code']) || null,
      referred_by: pick(d, ['referredBy', 'referred_by']) || null,
      is_active: bool(pick(d, ['isActive', 'is_active']), true),
      is_verified: bool(pick(d, ['isVerified', 'is_verified']), false),
      shop_id: shopId,
      branch_id: branchId,
      metadata: jsonb(pick(d, ['metadata']), {}),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'lastLogin', 'updated_at'])) || undefined,
    };

    // shop_id / branch_id: resolved above via idmap against the new
    // `shops` / `branches` tables (migration 008_shops_branches.sql).
    // Requires the `shops` and `branches` migrators to have run first
    // (enforced by ordering in migrators/index.js). If the user doc has
    // no shopId/branchId field, or the referenced shop/branch hasn't
    // been migrated, these remain null — backfill_shops_branches.js
    // assigns the seeded default shop/branch in that case.
    return row;
  },

  /** Cache the mapping so dependent collections (orders, products, ...) can resolve user_id. */
  async afterUpsert(client, doc, row, pgId, idmap) {
    idmap.set('users', doc.id, pgId);
  },
};
