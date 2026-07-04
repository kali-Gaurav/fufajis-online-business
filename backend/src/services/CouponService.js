const pool = require('../db/pool');
const { v4: uuidv4 } = require('uuid');

/**
 * Coupon Service - Manage discount codes and their application
 */
class CouponService {
  /**
   * Validate and apply coupon to order
   */
  static async validateAndApply({ couponCode, orderTotal, userId, items = [] }) {
    try {
      if (!couponCode) {
        return { valid: false, error: 'Coupon code required' };
      }

      if (!userId) {
        return { valid: false, error: 'User ID required for coupon validation' };
      }

      // Fetch coupon
      const coupon = await pool.query(
        `SELECT * FROM coupons WHERE code = $1 AND is_active = true`,
        [couponCode.toUpperCase()]
      );

      if (coupon.rows.length === 0) {
        return { valid: false, error: 'Coupon not found or inactive' };
      }

      const cpn = coupon.rows[0];

      // ✅ FIX: Use IST timezone for date comparisons (consistent with app)
      const nowUTC = new Date();
      const istOffset = 5.5 * 60 * 60 * 1000; // IST is UTC+5:30
      const now = new Date(nowUTC.getTime() + istOffset);

      if (cpn.valid_from && new Date(cpn.valid_from) > now) {
        return { valid: false, error: 'Coupon not yet valid' };
      }
      if (cpn.valid_to && new Date(cpn.valid_to) < now) {
        return { valid: false, error: 'Coupon expired' };
      }

      // ✅ FIX: Check global usage limit (race condition is handled at checkout level with atomic increment)
      if (cpn.max_usage && cpn.used_count >= cpn.max_usage) {
        return { valid: false, error: 'Coupon usage limit exceeded' };
      }

      // ✅ FIX: Check per-user usage limit (prevent abuse)
      const userUsageRes = await pool.query(
        `SELECT COUNT(*) as count FROM orders
         WHERE customer_id = $1 AND coupon_id = $2
         AND created_at > NOW() - INTERVAL '30 days'`,
        [userId, cpn.id]
      );

      const userUsageCount = parseInt(userUsageRes.rows[0].count);
      const maxPerUser = 5; // Max 5 uses per customer per 30 days

      if (userUsageCount >= maxPerUser) {
        return {
          valid: false,
          error: `You have already used this coupon ${userUsageCount} times in the last 30 days`,
        };
      }

      // Check minimum order value
      if (cpn.min_order_value && orderTotal < cpn.min_order_value) {
        return {
          valid: false,
          error: `Minimum order value: ₹${cpn.min_order_value}`,
        };
      }

      // Check applicable categories
      if (cpn.applicable_categories && cpn.applicable_categories.length > 0) {
        // Get product categories for items
        const productIds = items.map((item) => item.product_id);
        if (productIds.length > 0) {
          const products = await pool.query(
            `SELECT id, category FROM products WHERE id = ANY($1)`,
            [productIds]
          );

          const itemCategories = products.rows.map((p) => p.category);
          const isApplicable = itemCategories.some((cat) =>
            cpn.applicable_categories.includes(cat)
          );

          if (!isApplicable) {
            return {
              valid: false,
              error: 'Coupon not applicable to these items',
            };
          }
        }
      }

      // ✅ FIX: Validate discount_value before calculation
      if (typeof cpn.discount_value !== 'number' || cpn.discount_value < 0) {
        throw new Error(`INVALID_COUPON_CONFIG: discount_value is invalid (${cpn.discount_value})`);
      }

      // ✅ FIX: Validate coupon type
      if (!['percentage', 'fixed_amount'].includes(cpn.type)) {
        throw new Error(`INVALID_COUPON_CONFIG: type must be 'percentage' or 'fixed_amount'`);
      }

      // Calculate discount
      let discountAmount = 0;
      if (cpn.type === 'percentage') {
        if (cpn.discount_value > 100) {
          throw new Error('INVALID_COUPON_CONFIG: Percentage discount cannot exceed 100%');
        }
        discountAmount = (orderTotal * cpn.discount_value) / 100;
        if (cpn.max_discount && cpn.max_discount > 0) {
          discountAmount = Math.min(discountAmount, cpn.max_discount);
        }
      } else if (cpn.type === 'fixed_amount') {
        discountAmount = cpn.discount_value;
      }

      // Can't discount more than order total
      discountAmount = Math.min(discountAmount, orderTotal);

      // ✅ FIX: Ensure discount is non-negative
      discountAmount = Math.max(0, discountAmount);

      return {
        valid: true,
        couponId: cpn.id,
        discount: discountAmount,
        finalTotal: Math.max(0, orderTotal - discountAmount),
        message: `Discount of ₹${discountAmount.toFixed(2)} applied`,
      };
    } catch (error) {
      console.error('[Coupon] Validation failed:', error.message);
      throw error;
    }
  }

  /**
   * Create a new coupon (admin only)
   */
  static async createCoupon({
    code,
    type,
    discountValue,
    maxUsage = null,
    validFrom = null,
    validTo = null,
    minOrderValue = null,
    maxDiscount = null,
    applicableCategories = null,
    createdBy = null,
  }) {
    try {
      const couponId = uuidv4();

      const coupon = await pool.query(
        `INSERT INTO coupons (
          id, code, type, discount_value, max_usage, valid_from, valid_to,
          min_order_value, max_discount, applicable_categories, created_by, is_active
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, true)
        RETURNING *`,
        [
          couponId,
          code.toUpperCase(),
          type,
          discountValue,
          maxUsage,
          validFrom,
          validTo,
          minOrderValue,
          maxDiscount,
          applicableCategories,
          createdBy,
        ]
      );

      console.log(`[Coupon] Created coupon: ${code}`);
      return coupon.rows[0];
    } catch (error) {
      console.error('[Coupon] Create failed:', error.message);
      throw error;
    }
  }

  /**
   * Get all active coupons
   */
  static async getActiveCoupons() {
    try {
      const coupons = await pool.query(
        `SELECT * FROM coupons WHERE is_active = true AND (valid_to IS NULL OR valid_to > NOW())
         ORDER BY created_at DESC`
      );

      return coupons.rows;
    } catch (error) {
      console.error('[Coupon] Get active failed:', error.message);
      throw error;
    }
  }

  /**
   * Mark coupon as used (increment used_count)
   */
  static async markAsUsed(couponId) {
    try {
      const coupon = await pool.query(
        `UPDATE coupons SET used_count = used_count + 1, updated_at = NOW()
         WHERE id = $1
         RETURNING *`,
        [couponId]
      );

      if (coupon.rows.length > 0 && coupon.rows[0].max_usage) {
        if (coupon.rows[0].used_count >= coupon.rows[0].max_usage) {
          // Auto-disable if limit reached
          await pool.query(
            `UPDATE coupons SET is_active = false WHERE id = $1`,
            [couponId]
          );
        }
      }

      return coupon.rows[0];
    } catch (error) {
      console.error('[Coupon] Mark as used failed:', error.message);
      throw error;
    }
  }

  /**
   * Disable a coupon
   */
  static async disableCoupon(couponId) {
    try {
      const coupon = await pool.query(
        `UPDATE coupons SET is_active = false, updated_at = NOW()
         WHERE id = $1
         RETURNING *`,
        [couponId]
      );

      return coupon.rows[0];
    } catch (error) {
      console.error('[Coupon] Disable failed:', error.message);
      throw error;
    }
  }
}

module.exports = CouponService;
