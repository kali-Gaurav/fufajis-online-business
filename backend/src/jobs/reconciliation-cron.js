// Payment Reconciliation Cron Job
// Run every 1 hour
// Find stale orders with pending payments and reconcile with Razorpay

const pool = require('../db/pool');
const razorpay = require('../lib/razorpay');
const InventoryService = require('../services/inventory-service');

class ReconciliationCron {
  /**
   * Execute reconciliation (called by node-cron scheduler)
   * Finds orders stuck in payment_pending state and checks Razorpay API
   */
  static async execute() {
    console.log(`[ReconciliationCron] Running reconciliation job...`);

    try {
      // Find stale payment orders (> 30 minutes in payment_pending)
      const staleRes = await pool.query(
        `SELECT o.id, o.payment_order_id, r.id as reservation_id
         FROM orders o
         LEFT JOIN reservations r ON o.reservation_id = r.id
         WHERE o.status = 'payment_pending'
           AND o.created_at < CURRENT_TIMESTAMP - INTERVAL '30 minutes'`
      );

      if (staleRes.rows.length === 0) {
        console.log(`[ReconciliationCron] No stale payments found`);
        return { reconciled: 0 };
      }

      let reconciledCount = 0;

      // Check each stale order with Razorpay API
      for (const order of staleRes.rows) {
        try {
          console.log(
            `[ReconciliationCron] ⏰ Checking stale order ${order.id} (payment: ${order.payment_order_id})`
          );

          // Query Razorpay API for order status
          const razorpayResponse = await razorpay.createOrder({
            amount: 0,  // Dummy, only used to make API call
            currency: 'INR'
          }).catch(err => {
            // Try to fetch order status via fetch
            return fetch(`https://api.razorpay.com/v1/orders/${order.payment_order_id}`, {
              method: 'GET',
              headers: {
                'Authorization': `Basic ${Buffer.from(`${process.env.RAZORPAY_KEY_ID}:${process.env.RAZORPAY_KEY_SECRET}`).toString('base64')}`,
              },
            }).then(res => res.json());
          });

          const paymentStatus = razorpayResponse?.status || razorpayResponse?.data?.status;

          if (paymentStatus === 'paid' || paymentStatus === 'captured') {
            // Payment succeeded but webhook didn't arrive → confirm reservation manually
            console.log(
              `[ReconciliationCron] ✅ Payment confirmed via API for order ${order.id}. Confirming reservation.`
            );

            await pool.query(
              `UPDATE reservations
               SET status = 'confirmed', confirmed_at = CURRENT_TIMESTAMP
               WHERE id = $1`,
              [order.reservation_id]
            );

            await pool.query(
              `UPDATE orders
               SET status = 'confirmed'
               WHERE id = $1`,
              [order.id]
            );

            reconciledCount++;
          } else if (paymentStatus === 'expired' || paymentStatus === 'failed' || !paymentStatus) {
            // Payment failed or absent → release reservation and refund if needed
            console.log(
              `[ReconciliationCron] ❌ Payment failed/expired for order ${order.id}. Releasing reservation.`
            );

            await InventoryService.releaseReservation(order.reservation_id);

            await pool.query(
              `UPDATE orders
               SET status = 'cancelled'
               WHERE id = $1`,
              [order.id]
            );

            reconciledCount++;
          }
        } catch (err) {
          console.error(
            `[ReconciliationCron] Failed to reconcile ${order.id}:`,
            err.message
          );
        }
      }

      console.log(`[ReconciliationCron] ✅ Reconciled ${reconciledCount} stale orders`);

      return { reconciled: reconciledCount };
    } catch (err) {
      console.error(`[ReconciliationCron] ❌ Reconciliation failed:`, err.message);
      throw err;
    }
  }
}

module.exports = ReconciliationCron;
