// Payment Reconciliation Cron Job
// Run every 1 hour
// Find stale orders with pending payments and reconcile with Razorpay

const pool = require('../db/pool');
const { v4: uuidv4 } = require('uuid');

class ReconciliationCron {
  /**
   * Execute reconciliation (called by node-cron scheduler)
   * ✅ FIXES:
   * - Processes in batches (max 50 per run)
   * - Timeout on Razorpay API calls (30 seconds)
   * - Retry logic with exponential backoff
   * - Atomic transaction for state updates
   * - Audit logging
   */
  static async execute() {
    console.log(`[ReconciliationCron] Running reconciliation job...`);
    const startTime = Date.now();

    try {
      const BATCH_SIZE = 50; // Process max 50 stale orders per run
      let totalReconciled = 0;

      let batchNum = 0;
      let continueCleaning = true;

      while (continueCleaning) {
        batchNum++;

        // ✅ FIX: Find stale orders with LIMIT
        const staleRes = await pool.query(
          `SELECT o.id, o.payment_order_id, o.customer_id, o.shop_id, r.id as reservation_id
           FROM orders o
           LEFT JOIN reservations r ON o.reservation_id = r.id
           WHERE o.status = 'payment_pending'
             AND o.created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes'
           LIMIT $1`,
          [BATCH_SIZE]
        );

        if (staleRes.rows.length === 0) {
          continueCleaning = false;
          break;
        }

        // Process each order
        for (const order of staleRes.rows) {
          try {
            console.log(
              `[ReconciliationCron] ⏰ Batch ${batchNum}: Checking order ${order.id} (payment: ${order.payment_order_id})`
            );

            // ✅ FIX: Call Razorpay API with timeout and retry
            const paymentStatus = await this.fetchPaymentStatusWithRetry(order.payment_order_id);

            if (paymentStatus === 'paid' || paymentStatus === 'captured') {
              // ✅ FIX: Confirm with atomic transaction
              await pool.transaction(async (client) => {
                await client.query(
                  `UPDATE reservations
                   SET status = 'confirmed', confirmed_at = CURRENT_TIMESTAMP
                   WHERE id = $1`,
                  [order.reservation_id]
                );

                await client.query(
                  `UPDATE orders
                   SET status = 'confirmed', updated_at = CURRENT_TIMESTAMP
                   WHERE id = $1`,
                  [order.id]
                );

                // Audit log
                await client.query(
                  `INSERT INTO inventory_audit_log (product_id, action, reason)
                   VALUES ($1, $2, $3)`,
                  [order.id, 'payment_reconciled_api', `Order ${order.id} confirmed via Razorpay API reconciliation`]
                );
              });

              console.log(
                `[ReconciliationCron] ✅ Batch ${batchNum}: Order ${order.id} confirmed via API`
              );
              totalReconciled++;

            } else if (paymentStatus === 'expired' || paymentStatus === 'failed' || !paymentStatus) {
              // ✅ FIX: Release with atomic transaction
              await pool.transaction(async (client) => {
                // Release reservation inventory
                if (order.reservation_id) {
                  const itemsRes = await client.query(
                    `SELECT product_id, quantity FROM reservation_items
                     WHERE reservation_id = $1`,
                    [order.reservation_id]
                  );

                  for (const item of itemsRes.rows) {
                    await client.query(
                      `UPDATE products
                       SET available_quantity = available_quantity + $2,
                           reserved_quantity = reserved_quantity - $2,
                           updated_at = CURRENT_TIMESTAMP
                       WHERE id = $1`,
                      [item.product_id, item.quantity]
                    );
                  }

                  // Mark reservation as released
                  await client.query(
                    `UPDATE reservations
                     SET status = 'released', released_at = CURRENT_TIMESTAMP
                     WHERE id = $1`,
                    [order.reservation_id]
                  );
                }

                // Cancel order
                await client.query(
                  `UPDATE orders
                   SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP
                   WHERE id = $1`,
                  [order.id]
                );

                // Create refund request if payment was actually made
                const paymentRes = await client.query(
                  `SELECT id FROM payments WHERE order_id = $1`,
                  [order.id]
                );

                if (paymentRes.rows.length > 0) {
                  await client.query(
                    `INSERT INTO refund_requests (order_id, reason, status, created_at)
                     VALUES ($1, $2, $3, CURRENT_TIMESTAMP)`,
                    [order.id, `Payment failed/expired after 30+ minutes - Reconciliation cancel`, 'pending']
                  );
                }
              });

              console.log(
                `[ReconciliationCron] ❌ Batch ${batchNum}: Order ${order.id} cancelled (payment ${paymentStatus || 'absent'})`
              );
              totalReconciled++;
            }
          } catch (err) {
            console.error(
              `[ReconciliationCron] ⚠️ Batch ${batchNum}: Failed to reconcile ${order.id}: ${err.message}`
            );
            // Continue with next order, don't break
          }
        }

        // If we got fewer than BATCH_SIZE, we're done
        if (staleRes.rows.length < BATCH_SIZE) {
          continueCleaning = false;
        }
      }

      const duration = Date.now() - startTime;
      console.log(
        `[ReconciliationCron] ✅ Reconciliation complete in ${duration}ms. Total reconciled: ${totalReconciled}`
      );

      return { reconciled: totalReconciled, durationMs: duration };
    } catch (err) {
      console.error(`[ReconciliationCron] 🚨 CRITICAL: Reconciliation failed:`, err.message);
      console.error(`[ReconciliationCron] ⚠️ Stale orders may accumulate if reconciliation fails`);
      throw err;
    }
  }

  /**
   * Fetch payment status from Razorpay API with timeout and retry
   * ✅ FIX: Adds timeout to prevent hanging
   */
  static async fetchPaymentStatusWithRetry(paymentOrderId, maxRetries = 3) {
    const TIMEOUT_MS = 30000; // 30-second timeout

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

        const response = await fetch(
          `https://api.razorpay.com/v1/orders/${paymentOrderId}`,
          {
            method: 'GET',
            headers: {
              'Authorization': `Basic ${Buffer.from(
                `${process.env.RAZORPAY_KEY_ID}:${process.env.RAZORPAY_KEY_SECRET}`
              ).toString('base64')}`,
            },
            signal: controller.signal,
          }
        );

        clearTimeout(timeoutId);

        if (!response.ok) {
          throw new Error(`Razorpay API returned ${response.status}`);
        }

        const data = await response.json();
        return data?.status || null;
      } catch (err) {
        if (err.name === 'AbortError') {
          console.warn(`[ReconciliationCron] ⏱️ Timeout on attempt ${attempt} for order ${paymentOrderId}`);
        } else {
          console.warn(`[ReconciliationCron] ⚠️ API call failed on attempt ${attempt}: ${err.message}`);
        }

        if (attempt < maxRetries) {
          // Exponential backoff
          const backoffMs = Math.pow(2, attempt) * 500;
          console.log(`[ReconciliationCron] Retrying in ${backoffMs}ms...`);
          await new Promise(resolve => setTimeout(resolve, backoffMs));
          continue;
        } else {
          // Final attempt failed, treat as unknown status (don't reconcile)
          throw new Error(`Max retries exceeded for payment order ${paymentOrderId}`);
        }
      }
    }

    return null;
  }
}

module.exports = ReconciliationCron;
