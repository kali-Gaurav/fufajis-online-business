// Cleanup Cron Job
// Run every 5 minutes
// Expire stale reservations and return stock to available pool

const pool = require('../db/pool');

class CleanupCron {
  /**
   * Execute cleanup (called by node-cron scheduler)
   * ✅ FIXES:
   * - Processes in batches (max 100 per run)
   * - Uses transactions for atomicity
   * - Retry logic for deadlocks
   * - Audit logging for transparency
   */
  static async execute() {
    console.log(`[CleanupCron] Running cleanup job...`);
    const startTime = Date.now();

    try {
      // ✅ FIX: Process in BATCHES to avoid locking too many rows
      const BATCH_SIZE = 100;
      let totalExpired = 0;

      let batchNum = 0;
      let continueCleaning = true;

      while (continueCleaning) {
        batchNum++;

        // ✅ FIX: Find expired reservations with LIMIT
        const expiredRes = await pool.query(
          `SELECT id FROM reservations
           WHERE status = 'active' AND expires_at <= CURRENT_TIMESTAMP
           LIMIT $1`,
          [BATCH_SIZE]
        );

        if (expiredRes.rows.length === 0) {
          continueCleaning = false;
          break;
        }

        // ✅ FIX: Process batch atomically with TRANSACTION + RETRY for deadlocks
        const expiredIds = expiredRes.rows.map(r => r.id);
        const batchExpiredCount = await this.processBatchWithRetry(expiredIds);
        totalExpired += batchExpiredCount;

        console.log(`[CleanupCron] Batch ${batchNum}: Processed ${batchExpiredCount} reservations`);

        // If we got fewer than BATCH_SIZE, we're done
        if (expiredRes.rows.length < BATCH_SIZE) {
          continueCleaning = false;
        }
      }

      console.log(`[CleanupCron] ✅ Total expired reservations: ${totalExpired}`);

      // Clean up old idempotency keys
      const deletedKeysRes = await pool.query(
        `DELETE FROM idempotency_keys WHERE expires_at < CURRENT_TIMESTAMP`
      );

      console.log(`[CleanupCron] ✅ Deleted ${deletedKeysRes.rowCount} expired idempotency keys`);

      const duration = Date.now() - startTime;
      console.log(`[CleanupCron] ✅ Cleanup complete in ${duration}ms. Expired: ${totalExpired}, Keys deleted: ${deletedKeysRes.rowCount}`);

      return { expired: totalExpired, deletedKeys: deletedKeysRes.rowCount, durationMs: duration };
    } catch (err) {
      console.error(`[CleanupCron] 🚨 CRITICAL: Cleanup failed:`, err.message);
      // Alert ops - this is a critical background job
      console.error(`[CleanupCron] ⚠️ Stale reservations may accumulate if cleanup continues to fail`);
      throw err;
    }
  }

  /**
   * Process a batch of expired reservations with deadlock retry
   * ✅ FIX: Atomic transaction + deadlock retry logic
   */
  static async processBatchWithRetry(reservationIds, maxRetries = 3) {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await pool.transaction(async (client) => {
          // ✅ FIX: Get all items for batch in single query (not N+1)
          const itemsRes = await client.query(
            `SELECT reservation_id, product_id, quantity
             FROM reservation_items
             WHERE reservation_id = ANY($1)`,
            [reservationIds]
          );

          // ✅ FIX: Batch update products (not individual updates)
          const productUpdates = {};
          for (const item of itemsRes.rows) {
            if (!productUpdates[item.product_id]) {
              productUpdates[item.product_id] = 0;
            }
            productUpdates[item.product_id] += item.quantity;
          }

          for (const [productId, quantity] of Object.entries(productUpdates)) {
            await client.query(
              `UPDATE products
               SET available_quantity = available_quantity + $2,
                   reserved_quantity = reserved_quantity - $2,
                   updated_at = CURRENT_TIMESTAMP
               WHERE id = $1`,
              [productId, quantity]
            );

            // ✅ FIX: Audit logging
            await client.query(
              `INSERT INTO inventory_audit_log (product_id, action, quantity, reason)
               VALUES ($1, $2, $3, $4)`,
              [productId, 'release_from_expiry', quantity, `Batch cleanup attempt ${attempt}`]
            );
          }

          // Mark reservations as expired
          await client.query(
            `UPDATE reservations
             SET status = 'expired', released_at = CURRENT_TIMESTAMP
             WHERE id = ANY($1)`,
            [reservationIds]
          );

          return reservationIds.length;
        });
      } catch (err) {
        if (err.code === '40P01' && attempt < maxRetries) {
          // Deadlock detected, retry with backoff
          const backoffMs = Math.pow(2, attempt) * 100;
          console.warn(`[CleanupCron] ⚠️ Deadlock on attempt ${attempt}, retrying in ${backoffMs}ms...`);
          await new Promise(resolve => setTimeout(resolve, backoffMs));
          continue;
        } else {
          throw err;
        }
      }
    }

    throw new Error('Max retries exceeded for cleanup batch');
  }
}

module.exports = CleanupCron;
