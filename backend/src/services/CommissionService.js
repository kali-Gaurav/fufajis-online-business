/**
 * ============================================================================
 * CommissionService - Vendor Commission Calculation
 * ============================================================================
 * Handles:
 * - Commission rate calculation per vendor/product
 * - Deduction tracking (platform fees, payment processing, etc.)
 * - Payout scheduling
 * - Commission ledger (audit trail)
 *
 * Flow:
 * Order Paid → Calculate Commission → Log to Ledger → Track for Payout
 * ============================================================================
 */

const pool = require('../db/pool');
const { v4: uuidv4 } = require('uuid');

class CommissionService {
  /**
   * Calculate commission for an order
   * CRITICAL: Must be called AFTER payment is confirmed
   */
  static async calculateOrderCommission({
    orderId,
    vendorId,
    customerId,
    orderTotal,
    items,              // [{ productId, quantity, price }, ...]
    paymentMethodId,
    platformFeePercent = 5,  // Default 5% platform fee
    paymentGatewayFeePercent = 2.5, // Razorpay ~2.5%
  }) {
    console.log(`[CommissionService] Calculating commission for order ${orderId}`);

    if (!orderId || !vendorId || !orderTotal || !items) {
      throw new Error('INVALID_REQUEST: orderId, vendorId, orderTotal, and items are required');
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Fetch vendor details
      const vendorRes = await client.query(
        `SELECT id, commission_rate FROM vendors WHERE id = $1`,
        [vendorId]
      );

      if (vendorRes.rows.length === 0) {
        throw new Error('VENDOR_NOT_FOUND');
      }

      const vendor = vendorRes.rows[0];
      const vendorCommissionRate = vendor.commission_rate || 15; // Default 15%

      // Calculate base amounts
      const subtotal = orderTotal;
      const platformFee = (subtotal * platformFeePercent) / 100;
      const paymentGatewayFee = (subtotal * paymentGatewayFeePercent) / 100;

      // Calculate vendor commission (payout to vendor)
      // Vendor gets: Order Total - Platform Fee - Payment Gateway Fee
      const vendorPayout = subtotal - platformFee - paymentGatewayFee;

      // Calculate shop earnings (or deduct shop commission if needed)
      const shopEarnings = platformFee + paymentGatewayFee;

      // Validate payout is positive
      if (vendorPayout <= 0) {
        throw new Error('PAYOUT_CALCULATION_FAILED: Vendor payout would be non-positive');
      }

      // Create commission record
      const commissionId = uuidv4();
      const commissionRes = await client.query(
        `INSERT INTO vendor_commissions (
          id, order_id, vendor_id, customer_id,
          order_total, platform_fee, payment_gateway_fee,
          vendor_payout, shop_earnings,
          commission_rate, status,
          created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'pending',
          CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        RETURNING *`,
        [
          commissionId, orderId, vendorId, customerId,
          subtotal, platformFee, paymentGatewayFee,
          vendorPayout, shopEarnings,
          vendorCommissionRate
        ]
      );

      const commission = commissionRes.rows[0];

      // Create ledger entry for audit trail
      await client.query(
        `INSERT INTO commission_ledger (
          id, vendor_id, order_id, commission_id,
          amount, direction, transaction_type,
          description, created_at
        ) VALUES ($1, $2, $3, $4, $5, 'debit', 'order_commission',
          $6, CURRENT_TIMESTAMP)`,
        [
          uuidv4(), vendorId, orderId, commissionId,
          vendorPayout,
          `Commission for order ${orderId.substring(0, 8)}`
        ]
      );

      // Update vendor balance (add to due amount)
      await client.query(
        `UPDATE vendors
         SET balance = balance + $2,
             balance_updated = CURRENT_TIMESTAMP,
             total_commissions_due = total_commissions_due + $2
         WHERE id = $1`,
        [vendorId, vendorPayout]
      );

      await client.query('COMMIT');
      console.log(`[CommissionService] ✅ Commission calculated: ${commissionId}`);

      return {
        commissionId,
        orderId,
        vendorId,
        subtotal,
        platformFee,
        paymentGatewayFee,
        vendorPayout,
        shopEarnings,
        status: 'pending'
      };
    } catch (err) {
      await client.query('ROLLBACK');
      console.error(`[CommissionService] ❌ Failed:`, err.message);
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Get pending commissions for a vendor
   */
  static async getPendingCommissions(vendorId, limit = 50) {
    console.log(`[CommissionService] Fetching pending commissions for vendor ${vendorId}`);

    const result = await pool.query(
      `SELECT * FROM vendor_commissions
       WHERE vendor_id = $1 AND status = 'pending'
       ORDER BY created_at DESC
       LIMIT $2`,
      [vendorId, limit]
    );

    const total = result.rows.reduce((sum, row) => sum + row.vendor_payout, 0);

    return {
      commissions: result.rows,
      totalPending: total,
      count: result.rows.length
    };
  }

  /**
   * Get commission ledger for vendor (audit trail)
   */
  static async getCommissionLedger(vendorId, limit = 100, offset = 0) {
    console.log(`[CommissionService] Fetching ledger for vendor ${vendorId}`);

    const result = await pool.query(
      `SELECT * FROM commission_ledger
       WHERE vendor_id = $1
       ORDER BY created_at DESC
       LIMIT $2 OFFSET $3`,
      [vendorId, limit, offset]
    );

    return result.rows;
  }

  /**
   * Mark commissions as paid (after payout)
   */
  static async markCommissionsAsPaid(vendorId, commissionIds = []) {
    console.log(`[CommissionService] Marking ${commissionIds.length} commissions as paid`);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // If specific IDs provided, update those; otherwise update all pending
      let result;
      if (commissionIds && commissionIds.length > 0) {
        result = await client.query(
          `UPDATE vendor_commissions
           SET status = 'paid', updated_at = CURRENT_TIMESTAMP
           WHERE id = ANY($1) AND vendor_id = $2 AND status = 'pending'
           RETURNING *`,
          [commissionIds, vendorId]
        );
      } else {
        result = await client.query(
          `UPDATE vendor_commissions
           SET status = 'paid', updated_at = CURRENT_TIMESTAMP
           WHERE vendor_id = $1 AND status = 'pending'
           RETURNING *`,
          [vendorId]
        );
      }

      // Calculate total paid
      const totalPaid = result.rows.reduce((sum, row) => sum + row.vendor_payout, 0);

      // Update vendor ledger
      for (const commission of result.rows) {
        await client.query(
          `INSERT INTO commission_ledger (
            id, vendor_id, order_id, commission_id,
            amount, direction, transaction_type,
            description, created_at
          ) VALUES ($1, $2, $3, $4, $5, 'credit', 'payout_processed',
            $6, CURRENT_TIMESTAMP)`,
          [
            uuidv4(), vendorId, commission.order_id, commission.id,
            commission.vendor_payout,
            `Payout processed for commission ${commission.id.substring(0, 8)}`
          ]
        );
      }

      // Update vendor balance_updated
      await client.query(
        `UPDATE vendors
         SET balance_updated = CURRENT_TIMESTAMP
         WHERE id = $1`,
        [vendorId]
      );

      await client.query('COMMIT');
      console.log(`[CommissionService] ✅ Marked ${result.rows.length} as paid`);

      return {
        paid: result.rows.length,
        totalPaid: totalPaid,
        commissions: result.rows
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Get commission statistics for vendor (dashboard)
   */
  static async getCommissionStats(vendorId) {
    console.log(`[CommissionService] Fetching stats for vendor ${vendorId}`);

    // Pending commissions
    const pendingRes = await pool.query(
      `SELECT COUNT(*) as count, COALESCE(SUM(vendor_payout), 0) as total
       FROM vendor_commissions
       WHERE vendor_id = $1 AND status = 'pending'`,
      [vendorId]
    );

    // Paid commissions (this month)
    const paidThisMonthRes = await pool.query(
      `SELECT COUNT(*) as count, COALESCE(SUM(vendor_payout), 0) as total
       FROM vendor_commissions
       WHERE vendor_id = $1 AND status = 'paid'
       AND updated_at >= CURRENT_DATE - INTERVAL '30 days'`,
      [vendorId]
    );

    // Total all-time paid
    const totalPaidRes = await pool.query(
      `SELECT COALESCE(SUM(vendor_payout), 0) as total
       FROM vendor_commissions
       WHERE vendor_id = $1 AND status = 'paid'`,
      [vendorId]
    );

    // Average commission rate
    const avgRateRes = await pool.query(
      `SELECT AVG(commission_rate) as avg_rate
       FROM vendor_commissions
       WHERE vendor_id = $1`,
      [vendorId]
    );

    return {
      pending: {
        count: parseInt(pendingRes.rows[0].count || 0),
        totalAmount: parseFloat(pendingRes.rows[0].total || 0)
      },
      paidThisMonth: {
        count: parseInt(paidThisMonthRes.rows[0].count || 0),
        totalAmount: parseFloat(paidThisMonthRes.rows[0].total || 0)
      },
      totalAllTime: {
        totalAmount: parseFloat(totalPaidRes.rows[0].total || 0)
      },
      averageCommissionRate: parseFloat(avgRateRes.rows[0].avg_rate || 0)
    };
  }

  /**
   * Calculate commissions for all orders from yesterday (daily cron)
   */
  static async calculateDailyCommissions() {
    console.log('[CommissionService] Calculating commissions for orders from yesterday...');

    const ordersRes = await pool.query(
      `SELECT id, vendor_id, customer_id, total_amount
       FROM orders
       WHERE DATE(created_at) = CURRENT_DATE - INTERVAL '1 day'
       AND payment_status = 'completed'
       AND commission_status IS NULL
       LIMIT 500`
    );

    const results = [];
    for (const order of ordersRes.rows) {
      try {
        // Fetch order items
        const itemsRes = await pool.query(
          `SELECT product_id, quantity, price FROM order_items WHERE order_id = $1`,
          [order.id]
        );

        const result = await this.calculateOrderCommission({
          orderId: order.id,
          vendorId: order.vendor_id,
          customerId: order.customer_id,
          orderTotal: order.total_amount,
          items: itemsRes.rows
        });

        results.push({ orderId: order.id, success: true, commissionId: result.commissionId });
      } catch (err) {
        console.error(`[CommissionService] Failed for order ${order.id}:`, err.message);
        results.push({ orderId: order.id, success: false, error: err.message });
      }
    }

    console.log(`[CommissionService] ✅ Calculated commissions for ${results.filter(r => r.success).length} orders`);
    return results;
  }
}

module.exports = CommissionService;
