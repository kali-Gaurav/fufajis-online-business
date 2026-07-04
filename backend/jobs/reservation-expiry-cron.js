/**
 * Cron Job: Expire Stale Reservations
 * Runs every 2 minutes
 *
 * FIX #4: Implements stale reservation cleanup
 * Finds reservations that are 10+ minutes old and marks them as expired
 * Then releases the inventory that was reserved
 */

const pool = require('../src/db/pool');
const logger = require('../src/utils/logger');

/**
 * Expire stale active reservations
 * Updates status to 'expired' and releases inventory
 */
async function expireStaleReservations() {
  const startTime = Date.now();
  let expiredCount = 0;

  try {
    // Step 1: Find and expire stale reservations
    // Stale = active status AND created more than 10 minutes ago
    const expireResult = await pool.query(`
      UPDATE reservations
      SET status = 'expired',
          expired_at = CURRENT_TIMESTAMP
      WHERE status = 'active'
        AND created_at <= NOW() - INTERVAL '10 minutes'
      RETURNING id, order_id, customer_id;
    `);

    expiredCount = expireResult.rowCount || 0;

    if (expiredCount > 0) {
      logger.info('[ExpirationCron] Expired stale reservations', { count: expiredCount });

      // Step 2: Release inventory for each expired reservation
      for (const reservation of expireResult.rows) {
        try {
          await releaseInventoryForReservation(reservation.id);
        } catch (err) {
          logger.error('[ExpirationCron] Failed to release inventory', {
            reservationId: reservation.id,
            error: err.message
          });
          // Continue with next reservation even if one fails
        }
      }

      logger.info('[ExpirationCron] Inventory released', { count: expiredCount });
    } else {
      logger.debug('[ExpirationCron] No stale reservations found');
    }

    const duration = Date.now() - startTime;
    logger.debug('[ExpirationCron] Job completed', {
      durationMs: duration,
      expiredCount
    });

  } catch (err) {
    logger.error('[ExpirationCron] Job failed', {
      error: err.message,
      stack: err.stack
    });

    // Alert operations team
    try {
      await alertOps('Reservation expiry cron job failed: ' + err.message);
    } catch (alertErr) {
      logger.error('[ExpirationCron] Failed to alert ops', { error: alertErr.message });
    }
  }
}

/**
 * Release inventory for expired reservation
 * Subtracts reserved quantities back to available
 */
async function releaseInventoryForReservation(reservationId) {
  try {
    // Get all items in this reservation
    const items = await pool.query(
      `SELECT product_id, shop_id, quantity
       FROM reservation_items
       WHERE reservation_id = $1`,
      [reservationId]
    );

    logger.debug('[ExpirationCron] Releasing inventory', {
      reservationId,
      itemCount: items.rows.length
    });

    // Release each item back to available
    for (const item of items.rows) {
      await pool.query(`
        UPDATE products
        SET reserved_quantity = GREATEST(0, reserved_quantity - $1),
            available_quantity = available_quantity + $1,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = $2
      `, [item.quantity, item.product_id]);

      logger.debug('[ExpirationCron] Released inventory', {
        productId: item.product_id,
        quantity: item.quantity
      });
    }

    logger.info('[ExpirationCron] Inventory released for reservation', {
      reservationId,
      itemsReleased: items.rows.length
    });

  } catch (err) {
    logger.error('[ExpirationCron] Release failed', {
      reservationId,
      error: err.message
    });
    throw err;
  }
}

/**
 * Alert operations team that cron job failed
 */
async function alertOps(message) {
  try {
    // In production, this would send to Slack, PagerDuty, etc.
    logger.error('[ExpirationCron] ALERT OPS', { message });

    // TODO: Implement alerting mechanism
    // Example: await slack.send('#ops', message)
  } catch (err) {
    logger.error('[ExpirationCron] Alert failed', { error: err.message });
  }
}

module.exports = { expireStaleReservations };
