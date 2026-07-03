/**
 * Orders API Routes (v2)
 *
 * CRITICAL: All order state changes are transactional.
 *
 * Architecture:
 * 1. Order creation reserves inventory (eventual consumption at packing)
 * 2. Order packing atomically reserves AND consumes inventory
 * 3. Order cancellation releases reserved inventory
 * 4. Refunds reverse payment + inventory
 *
 * PREVENTS:
 * - Overselling
 * - Double-packing
 * - Refund fraud
 * - Data inconsistency
 */

const express = require('express');
const router = express.Router();
const { db } = require('../db');
const { firestore } = require('../firebase');
const { verifyAuth, requireRole } = require('../middleware/auth');
const { logAudit } = require('../middleware/audit');

/**
 * GET /orders
 * Fetch orders with filters and pagination
 *
 * Query params:
 * - page: int (default 1)
 * - limit: int (default 20)
 * - status: 'pending' | 'confirmed' | 'packed' | 'shipped' | 'delivered' | 'cancelled'
 * - shopId?: string (for multi-shop filtering)
 *
 * Response:
 * {
 *   orders: [{id, shopId, customerId, totalAmount, status, createdAt, items}],
 *   total: int,
 *   page: int,
 *   limit: int
 * }
 */
router.get('/', verifyAuth, requireRole('admin', 'employee'), async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const status = req.query.status;
    const shopId = req.query.shopId;

    const offset = (page - 1) * limit;
    const params = [];

    let whereClause = 'WHERE 1=1';

    if (status) {
      whereClause += ' AND orders.status = $' + (params.length + 1);
      params.push(status);
    }

    if (shopId) {
      whereClause += ' AND orders.shop_id = $' + (params.length + 1);
      params.push(shopId);
    }

    // Count total
    const countQuery = `SELECT COUNT(*) as total FROM orders ${whereClause}`;
    const countResult = await db.query(countQuery, params);
    const total = parseInt(countResult.rows[0].total);

    // Fetch paginated orders
    const query = `
      SELECT
        id,
        shop_id as shopId,
        customer_id as customerId,
        total_amount as totalAmount,
        status,
        payment_status as paymentStatus,
        created_at as createdAt,
        updated_at as updatedAt
      FROM orders
      ${whereClause}
      ORDER BY created_at DESC
      LIMIT $${params.length + 1} OFFSET $${params.length + 2}
    `;

    params.push(limit);
    params.push(offset);

    const result = await db.query(query, params);

    // Fetch items for each order
    const ordersWithItems = await Promise.all(
      result.rows.map(async order => {
        const itemsQuery = `
          SELECT product_id as productId, quantity, price
          FROM order_items
          WHERE order_id = $1
        `;
        const itemsResult = await db.query(itemsQuery, [order.id]);
        return { ...order, items: itemsResult.rows };
      })
    );

    res.json({
      orders: ordersWithItems,
      total,
      page,
      limit,
    });
  } catch (error) {
    console.error('GET /orders error:', error);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
});

/**
 * POST /orders/:orderId/pack
 * Pack an order (consume inventory + update status)
 *
 * CRITICAL: This is the most dangerous operation.
 * Must be 100% atomic to prevent overselling.
 *
 * Body:
 * {
 *   items: [{productId: string, quantity: int}],
 *   employeeId: string,
 *   notes?: string
 * }
 *
 * Response:
 * {
 *   orderId: string,
 *   status: 'packed',
 *   packedAt: ISO8601,
 *   inventoryAdjustments: [{productId, oldStock, newStock}]
 * }
 */
router.post('/:orderId/pack', verifyAuth, requireRole('admin', 'employee'), logAudit('order_pack'), async (req, res) => {
  const client = await db.connect();

  try {
    const { orderId } = req.params;
    const { items, employeeId, notes } = req.body;
    const userId = req.user.uid;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'items[] is required' });
    }

    // BEGIN TRANSACTION
    await client.query('BEGIN');

    try {
      // STEP 1: Verify order exists and is in packable state
      const orderQuery = `
        SELECT id, status, total_amount, shop_id
        FROM orders
        WHERE id = $1
        FOR UPDATE
      `;
      const orderResult = await client.query(orderQuery, [orderId]);

      if (orderResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Order not found' });
      }

      const order = orderResult.rows[0];

      // Verify order is in packing state (pending, confirmed)
      if (!['pending', 'confirmed'].includes(order.status)) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          error: 'Order cannot be packed',
          details: { currentStatus: order.status },
        });
      }

      // STEP 2: Lock all inventory rows for update
      const productIds = items.map(i => i.productId);
      const lockQuery = `
        SELECT product_id, quantity, min_stock, max_stock
        FROM inventory
        WHERE product_id = ANY($1)
        FOR UPDATE
      `;
      const lockResult = await client.query(lockQuery, [productIds]);
      const inventoryMap = {};
      lockResult.rows.forEach(row => {
        inventoryMap[row.product_id] = row;
      });

      // STEP 3: Validate all items have sufficient stock
      const adjustments = [];

      for (const item of items) {
        const inv = inventoryMap[item.productId];

        if (!inv) {
          await client.query('ROLLBACK');
          return res.status(404).json({ error: `Product ${item.productId} not in inventory` });
        }

        const newStock = inv.quantity - item.quantity;

        if (newStock < 0) {
          await client.query('ROLLBACK');
          return res.status(400).json({
            error: 'Insufficient inventory for packing',
            details: {
              productId: item.productId,
              currentStock: inv.quantity,
              requestedQuantity: item.quantity,
              shortfall: item.quantity - inv.quantity,
            },
          });
        }

        adjustments.push({
          productId: item.productId,
          oldStock: inv.quantity,
          newStock,
          quantityPacked: item.quantity,
        });
      }

      // STEP 4: Update all inventory rows
      for (const adj of adjustments) {
        const updateQuery = `
          UPDATE inventory
          SET quantity = $1, updated_at = NOW()
          WHERE product_id = $2
        `;
        await client.query(updateQuery, [adj.newStock, adj.productId]);

        // Create inventory transaction record
        const transactionQuery = `
          INSERT INTO inventory_transactions (product_id, quantity_change, reason, old_quantity, new_quantity, order_id, employee_id, created_by_user_id, created_at)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
        `;
        await client.query(transactionQuery, [
          adj.productId,
          -adj.quantityPacked,
          'order_packed',
          adj.oldStock,
          adj.newStock,
          orderId,
          employeeId,
          userId,
        ]);
      }

      // STEP 5: Update order status
      const updateOrderQuery = `
        UPDATE orders
        SET status = $1, updated_at = NOW()
        WHERE id = $2
        RETURNING id, status, updated_at
      `;
      const updateOrderResult = await client.query(updateOrderQuery, ['packed', orderId]);
      const packedAt = updateOrderResult.rows[0].updated_at;

      // STEP 6: Create packing log
      const packingLogQuery = `
        INSERT INTO order_packing_logs (order_id, employee_id, items, notes, packed_at, created_by_user_id, created_at)
        VALUES ($1, $2, $3, $4, NOW(), $5, NOW())
      `;
      await client.query(packingLogQuery, [
        orderId,
        employeeId,
        JSON.stringify(items),
        notes || null,
        userId,
      ]);

      // STEP 7: Create audit log
      const auditQuery = `
        INSERT INTO audit_logs (entity_type, entity_id, action, old_value, new_value, user_id, metadata, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
      `;
      await client.query(auditQuery, [
        'order',
        orderId,
        'pack',
        JSON.stringify({ status: order.status }),
        JSON.stringify({ status: 'packed' }),
        userId,
        JSON.stringify({ employeeId, itemsPacked: items.length }),
      ]);

      // STEP 8: COMMIT TRANSACTION
      await client.query('COMMIT');

      // STEP 9: Sync to Firestore (background)
      syncOrderToFirestore(orderId, 'packed').catch(err => {
        console.error('Firestore sync failed for order pack:', err);
      });

      // Return success
      res.json({
        success: true,
        orderId,
        status: 'packed',
        packedAt: packedAt.toISOString(),
        inventoryAdjustments: adjustments,
      });
    } catch (txError) {
      await client.query('ROLLBACK');
      throw txError;
    }
  } catch (error) {
    console.error('POST /orders/:orderId/pack error:', error);
    res.status(500).json({ error: 'Failed to pack order', details: error.message });
  } finally {
    client.release();
  }
});

/**
 * POST /orders/:orderId/cancel
 * Cancel an order and release inventory
 *
 * Body:
 * {
 *   reason: string,
 *   notes?: string
 * }
 */
router.post('/:orderId/cancel', verifyAuth, requireRole('admin', 'employee'), logAudit('order_cancel'), async (req, res) => {
  const client = await db.connect();

  try {
    const { orderId } = req.params;
    const { reason, notes } = req.body;
    const userId = req.user.uid;

    if (!reason) {
      return res.status(400).json({ error: 'reason is required' });
    }

    await client.query('BEGIN');

    try {
      // Get order and items
      const orderQuery = `
        SELECT id, status, total_amount
        FROM orders
        WHERE id = $1
        FOR UPDATE
      `;
      const orderResult = await client.query(orderQuery, [orderId]);

      if (orderResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Order not found' });
      }

      const order = orderResult.rows[0];

      // Only allow cancellation of non-completed orders
      if (['shipped', 'delivered', 'cancelled'].includes(order.status)) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Cannot cancel order in ' + order.status + ' status' });
      }

      // Get order items
      const itemsQuery = `
        SELECT product_id, quantity
        FROM order_items
        WHERE order_id = $1
      `;
      const itemsResult = await client.query(itemsQuery, [orderId]);
      const items = itemsResult.rows;

      // Release inventory if order was packed
      if (order.status === 'packed') {
        for (const item of items) {
          const invQuery = `
            SELECT quantity
            FROM inventory
            WHERE product_id = $1
            FOR UPDATE
          `;
          const invResult = await client.query(invQuery, [item.product_id]);
          if (invResult.rows.length > 0) {
            const oldStock = invResult.rows[0].quantity;
            const newStock = oldStock + item.quantity;

            await client.query('UPDATE inventory SET quantity = $1 WHERE product_id = $2', [newStock, item.product_id]);

            // Log reversal
            await client.query(
              `INSERT INTO inventory_transactions (product_id, quantity_change, reason, old_quantity, new_quantity, order_id, created_by_user_id, created_at)
               VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
              [item.product_id, item.quantity, 'order_cancelled', oldStock, newStock, orderId, userId]
            );
          }
        }
      }

      // Update order status
      const updateResult = await client.query(
        `UPDATE orders SET status = $1, updated_at = NOW() WHERE id = $2 RETURNING updated_at`,
        ['cancelled', orderId]
      );

      const cancelledAt = updateResult.rows[0].updated_at;

      // Log cancellation
      await client.query(
        `INSERT INTO audit_logs (entity_type, entity_id, action, old_value, new_value, user_id, metadata, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
        [
          'order',
          orderId,
          'cancel',
          JSON.stringify({ status: order.status }),
          JSON.stringify({ status: 'cancelled' }),
          userId,
          JSON.stringify({ reason, notes }),
        ]
      );

      await client.query('COMMIT');

      // Sync to Firestore
      syncOrderToFirestore(orderId, 'cancelled').catch(err => {
        console.error('Firestore sync failed for order cancel:', err);
      });

      res.json({
        success: true,
        orderId,
        status: 'cancelled',
        cancelledAt: cancelledAt.toISOString(),
        reason,
      });
    } catch (txError) {
      await client.query('ROLLBACK');
      throw txError;
    }
  } catch (error) {
    console.error('POST /orders/:orderId/cancel error:', error);
    res.status(500).json({ error: 'Failed to cancel order', details: error.message });
  } finally {
    client.release();
  }
});

/**
 * Helper: Sync order to Firestore
 */
async function syncOrderToFirestore(orderId, status) {
  try {
    await firestore.collection('orders').doc(orderId).set(
      {
        status,
        syncedAt: new Date().toISOString(),
      },
      { merge: true }
    );
    console.log(`Synced order ${orderId} status to Firestore`);
  } catch (error) {
    console.error(`Failed to sync order to Firestore for ${orderId}:`, error);
  }
}

module.exports = router;
