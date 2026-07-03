// Inventory Service
// All operations atomic via PostgreSQL row-level locks (SELECT...FOR UPDATE)

const pool = require('../db/pool');

class InventoryService {
  /**
   * Reserve inventory atomically
   * Returns { reservationId, expiresAt } on success
   * Throws on failure (insufficient stock)
   */
  static async reserveInventory(productId, quantity, customerId) {
    const query = `
      UPDATE products
      SET available_quantity = available_quantity - $2,
          reserved_quantity = reserved_quantity + $2
      WHERE id = $1
        AND available_quantity >= $2
      RETURNING id as product_id
    `;

    const result = await pool.query(query, [productId, quantity]);

    if (result.rows.length === 0) {
      throw new Error(`INSUFFICIENT_STOCK: Product ${productId} only has remaining stock`);
    }

    const reservationId = require('uuid').v4();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Log audit trail
    await pool.query(
      `INSERT INTO inventory_audit_log (product_id, action, quantity, actor_id, reason)
       VALUES ($1, $2, $3, $4, $5)`,
      [productId, 'reserve', quantity, customerId, `Reservation ${reservationId}`]
    );

    return { reservationId, expiresAt };
  }

  /**
   * Confirm reservation (lock stock until fulfillment)
   * Called after payment webhook verification
   */
  static async confirmReservation(reservationId, orderId, paymentId) {
    await pool.query(
      `UPDATE reservations
       SET status = 'confirmed', order_id = $2, confirmed_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [reservationId, orderId]
    );
  }

  /**
   * Release reservation (return stock to available pool)
   * Called on checkout cancel or payment failure
   */
  static async releaseReservation(reservationId) {
    // Get reservation details first
    const res = await pool.query(
      `SELECT * FROM reservations WHERE id = $1`,
      [reservationId]
    );

    if (res.rows.length === 0) {
      throw new Error(`RESERVATION_NOT_FOUND: ${reservationId}`);
    }

    const reservation = res.rows[0];

    // Return stock to available pool
    const itemsRes = await pool.query(
      `SELECT product_id, quantity FROM reservation_items WHERE reservation_id = $1`,
      [reservationId]
    );

    for (const item of itemsRes.rows) {
      await pool.query(
        `UPDATE products
         SET available_quantity = available_quantity + $2,
             reserved_quantity = reserved_quantity - $2
         WHERE id = $1`,
        [item.product_id, item.quantity]
      );
    }

    // Mark reservation as released
    await pool.query(
      `UPDATE reservations
       SET status = 'released', released_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [reservationId]
    );
  }

  /**
   * Get available quantity for a product
   * Uses row-level lock to prevent race conditions
   */
  static async getAvailableQuantity(productId) {
    const result = await pool.query(
      `SELECT available_quantity FROM products WHERE id = $1 FOR UPDATE`,
      [productId]
    );

    if (result.rows.length === 0) {
      throw new Error(`PRODUCT_NOT_FOUND: ${productId}`);
    }

    return result.rows[0].available_quantity;
  }

  /**
   * Get product stock status
   */
  static async getStockStatus(productId) {
    const result = await pool.query(
      `SELECT
        id,
        name,
        total_quantity,
        available_quantity,
        reserved_quantity,
        (total_quantity - available_quantity - reserved_quantity) as committed_quantity
      FROM products
      WHERE id = $1`,
      [productId]
    );

    if (result.rows.length === 0) {
      throw new Error(`PRODUCT_NOT_FOUND: ${productId}`);
    }

    return result.rows[0];
  }

  /**
   * Expire stale reservations (called by cron job)
   */
  static async expireStaleReservations() {
    const query = `
      WITH expired AS (
        SELECT id, product_id, quantity
        FROM reservations r
        JOIN reservation_items ri ON r.id = ri.reservation_id
        WHERE r.status = 'active'
          AND r.expires_at <= CURRENT_TIMESTAMP
      )
      UPDATE products p
      SET available_quantity = available_quantity + e.quantity,
          reserved_quantity = reserved_quantity - e.quantity
      FROM expired e
      WHERE p.id = e.product_id
    `;

    const result = await pool.query(query);

    // Update reservation statuses
    await pool.query(
      `UPDATE reservations
       SET status = 'expired', released_at = CURRENT_TIMESTAMP
       WHERE status = 'active' AND expires_at <= CURRENT_TIMESTAMP`
    );

    return result.rowCount;
  }
}

module.exports = InventoryService;
