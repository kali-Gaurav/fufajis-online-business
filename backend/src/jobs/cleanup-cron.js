// Cleanup Cron Job
// Run every 5 minutes
// Expire stale reservations and return stock to available pool

const pool = require('../db/pool');

class CleanupCron {
  /**
   * Execute cleanup (called by node-cron scheduler)
   */
  static async execute() {
    console.log(`[CleanupCron] Running cleanup job...`);

    try {
      // Find expired reservations (just IDs, then get items per reservation)
      const expiredRes = await pool.query(
        `SELECT id
         FROM reservations
         WHERE status = 'active' AND expires_at <= CURRENT_TIMESTAMP`
      );

      if (expiredRes.rows.length === 0) {
        console.log(`[CleanupCron] No expired reservations found`);
        return { expired: 0 };
      }

      let expiredCount = 0;

      // Return stock for each expired reservation
      for (const reservation of expiredRes.rows) {
        const itemsRes = await pool.query(
          `SELECT product_id, quantity FROM reservation_items WHERE reservation_id = $1`,
          [reservation.id]
        );

        // Update products
        for (const item of itemsRes.rows) {
          await pool.query(
            `UPDATE products
             SET available_quantity = available_quantity + $2,
                 reserved_quantity = reserved_quantity - $2
             WHERE id = $1`,
            [item.product_id, item.quantity]
          );
        }

        // Mark reservation as expired
        await pool.query(
          `UPDATE reservations
           SET status = 'expired', released_at = CURRENT_TIMESTAMP
           WHERE id = $1`,
          [reservation.id]
        );

        expiredCount++;
      }

      console.log(`[CleanupCron] ✅ Expired ${expiredCount} reservations, returned stock`);

      // Clean up old idempotency keys (older than TTL)
      const deletedKeysRes = await pool.query(
        `DELETE FROM idempotency_keys WHERE expires_at < CURRENT_TIMESTAMP`
      );

      console.log(
        `[CleanupCron] ✅ Deleted ${deletedKeysRes.rowCount} expired idempotency keys`
      );

      return { expired: expiredCount, deletedKeys: deletedKeysRes.rowCount };
    } catch (err) {
      console.error(`[CleanupCron] ❌ Cleanup failed:`, err.message);
      throw err;
    }
  }
}

module.exports = CleanupCron;
