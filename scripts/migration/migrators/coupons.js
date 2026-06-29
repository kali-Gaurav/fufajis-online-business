'use strict';

const { pick, num, bool, ts } = require('../lib/transform');

/** Firestore `coupons/{id}` -> Postgres `coupons`. No FK resolution needed. */
module.exports = {
  name: 'coupons',
  table: 'coupons',
  collection: 'coupons',
  conflictColumn: 'code',

  async map(doc, idmap, client) {
    const d = doc.data();

    const code = pick(d, ['code'], doc.id);
    let discountType = String(pick(d, ['discountType', 'discount_type'], 'flat')).toLowerCase();
    if (discountType !== 'percentage' && discountType !== 'flat') discountType = 'flat';

    return {
      firestore_id: doc.id,
      code,
      description: pick(d, ['description']) || null,
      discount_type: discountType,
      discount_value: num(pick(d, ['discountValue', 'discount_value'], 0)),
      min_order_value: num(pick(d, ['minOrderValue', 'min_order_value'], 0)),
      max_discount: pick(d, ['maxDiscount', 'max_discount']) != null ? num(pick(d, ['maxDiscount', 'max_discount'])) : null,
      usage_limit: pick(d, ['usageLimit', 'usage_limit']) != null ? Math.trunc(num(pick(d, ['usageLimit', 'usage_limit']))) : null,
      usage_count: Math.trunc(num(pick(d, ['usageCount', 'usage_count'], 0))),
      per_user_limit: pick(d, ['perUserLimit', 'per_user_limit']) != null ? Math.trunc(num(pick(d, ['perUserLimit', 'per_user_limit']))) : 1,
      valid_from: ts(pick(d, ['validFrom', 'valid_from'])),
      valid_until: ts(pick(d, ['validUntil', 'valid_until'])),
      is_active: bool(pick(d, ['isActive', 'is_active']), true),
      created_at: ts(pick(d, ['createdAt', 'created_at'])) || undefined,
      updated_at: ts(pick(d, ['updatedAt', 'updated_at'])) || undefined,
    };
  },
};
