/**
 * Inventory API Routes
 *
 * CRITICAL: These endpoints MUST maintain strict PostgreSQL transaction safety.
 * All stock changes go through atomic transactions with row-level locks.
 *
 * Architecture:
 * 1. BEGIN TRANSACTION
 * 2. SELECT FOR UPDATE (row-level locks)
 * 3. Validate stock
 * 4. Update inventory
 * 5. Create audit log
 * 6. COMMIT
 * 7. Sync to Firestore (eventually consistent)
 *
 * PREVENTS:
 * - Overselling
 * - Double-packing
 * - Race conditions
 * - Lost inventory
 */

const express = require('express');
const router = express.Router();
const { db } = require('../db'); // PostgreSQL pool
const { firestore } = require('../firebase'); // Firebase admin
const { verifyAuth, requireRole } = require('../middleware/auth');
const { logAudit } = require('../middleware/audit');

/**
 * GET /inventory
 * Fetch current inventory status with pagination
 *
 * Query params:
 * - page: int (default 1)
 * - limit: int (default 20)
 * - status: 'low' | 'normal' | 'overstocked' (optional)
 * - searchQuery: string (product name search, optional)
 *
 * Response:
 * {
 *   items: [{productId, name, currentStock, minStock, maxStock, status, lastUpdated}],
 *   total: int,
 *   page: int,
 *   limit: int
 * }
 */
router.get('/', verifyAuth, requireRole('admin', 'employee'), async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const status = req.query.status; // 'low', 'normal', 'overstocked'
    const searchQuery = req.query.searchQuery;

    const offset = (page - 1) * limit;

    // Build WHERE clause
    let whereClause = 'WHERE 1=1';
    const params = [];

    if (status === 'low') {
      whereClause += ' AND inventory.quantity <= inventory.min_stock';
    } else if (status === 'normal') {
      whereClause += ' AND inventory.quantity > inventory.min_stock AND inventory.quantity < inventory.max_stock';
    } else if (status === 'overstocked') {
      whereClause += ' AND inventory.quantity >= inventory.max_stock';
    }

    if (searchQuery) {
      whereClause += ' AND LOWER(products.name) LIKE LOWER($1)';
      params.push(`%${searchQuery}%`);
      params.push(offset);
      params.push(limit);
    } else {
      params.push(offset);
      params.push(limit);
    }

    // Fetch total count
    const countQuery = `
      SELECT COUNT(*) as total
      FROM inventory
      JOIN products ON inventory.product_id = products.id
      ${whereClause}
    `;
    const countResult = await db.query(countQuery, searchQuery ? params.slice(0, -2) : []);
    const total = parseInt(countResult.rows[0].total);

    // Fetch paginated inventory
    const query = `
      SELECT
        inventory.product_id,
        products.name,
        products.name_hi,
        inventory.quantity as currentStock,
        inventory.min_stock as minStock,
        inventory.max_stock as maxStock,
        CASE
          WHEN inventory.quantity <= inventory.min_stock THEN 'low'
          WHEN inventory.quantity >= inventory.max_stock THEN 'overstocked'
          ELSE 'normal'
        END as status,
        inventory.updated_at as lastUpdated
      FROM inventory
      JOIN products ON inventory.product_id = products.id
      ${whereClause}
      ORDER BY products.name ASC
      LIMIT $${searchQuery ? 3 : 2} OFFSET $${searchQuery ? 2 : 1}
    `;

    const result = await db.query(query, params);

    res.json({
      items: result.rows,
      total,
      page,
      limit,
    });
  } catch (error) {
    console.error('GET /inventory error:', error);
    res.status(500).json({ error: 'Failed to fetch inventory' });
  }
});

/**
 * POST /inventory/adjust
 * Adjust inventory stock (with atomic transaction)
 *
 * Body:
 * {
 *   productId: string,
 *   quantity: int (can be negative for reductions),
 *   reason: 'order_packed' | 'stock_correction' | 'return' | 'damage' | 'manual_adjustment',
 *   employeeId?: string,
 *   orderId?: string,
 *   notes?: string
 * }
 *
 * CRITICAL: This must be ATOMIC to prevent overselling
 *
 * Response:
 * {
 *   productId: string,
 *   oldStock: int,
 *   newStock: int,
 *   quantityAdjusted: int,
 *   reason: string,
 *   timestamp: ISO8601
 * }
 */
router.post('/adjust', verifyAuth, requireRole('admin', 'employee'), logAudit('inventory_adjust'), async (req, res) => {
  const client = await db.connect(); // Get dedicated connection for transaction

  try {
    const { productId, quantity, reason, employeeId, orderId, notes } = req.body;
    const userId = req.user.uid;

    // Validation
    if (!productId || quantity === undefined || !reason) {
      return res.status(400).json({ error: 'Missing required fields: productId, quantity, reason' });
    }

    if (!Number.isInteger(quantity)) {
      return res.status(400).json({ error: 'quantity must be an integer' });
    }

    const validReasons = ['order_packed', 'stock_correction', 'return', 'damage', 'manual_adjustment'];
    if (!validReasons.includes(reason)) {
      return res.status(400).json({ error: `reason must be one of: ${validReasons.join(', ')}` });
    }

    // BEGIN TRANSACTION
    await client.query('BEGIN');

    try {
      // STEP 1: Lock the inventory row
      const lockQuery = `
        SELECT id, product_id, quantity, min_stock, max_stock
        FROM inventory
        WHERE product_id = $1
        FOR UPDATE
      `;
      const lockResult = await client.query(lockQuery, [productId]);

      if (lockResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Product not found in inventory' });
      }

      const inventoryRow = lockResult.rows[0];
      const oldStock = inventoryRow.quantity;
      const newStock = oldStock + quantity;

      // STEP 2: Validate new stock is not negative
      if (newStock < 0) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          error: 'Insufficient inventory',
          details: {
            productId,
            currentStock: oldStock,
            requestedReduction: Math.abs(quantity),
            available: oldStock,
          },
        });
      }

      // STEP 3: Update inventory
      const updateQuery = `
        UPDATE inventory
        SET quantity = $1, updated_at = NOW()
        WHERE product_id = $2
      `;
      await client.query(updateQuery, [newStock, productId]);

      // STEP 4: Create inventory transaction record
      const transactionQuery = `
        INSERT INTO inventory_transactions (product_id, quantity_change, reason, old_quantity, new_quantity, employee_id, order_id, notes, created_by_user_id, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
        RETURNING id, created_at
      `;
      const transactionResult = await client.query(transactionQuery, [
        productId,
        quantity,
        reason,
        oldStock,
        newStock,
        employeeId || null,
        orderId || null,
        notes || null,
        userId,
      ]);

      const transactionId = transactionResult.rows[0].id;
      const createdAt = transactionResult.rows[0].created_at;

      // STEP 5: Create audit log
      const auditQuery = `
        INSERT INTO audit_logs (entity_type, entity_id, action, old_value, new_value, user_id, metadata, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
      `;
      await client.query(auditQuery, [
        'inventory',
        productId,
        'adjust',
        JSON.stringify({ quantity: oldStock }),
        JSON.stringify({ quantity: newStock }),
        userId,
        JSON.stringify({ reason, transactionId, orderId, employeeId }),
      ]);

      // STEP 6: COMMIT TRANSACTION
      await client.query('COMMIT');

      // STEP 7: Sync to Firestore (background, not blocking)
      syncInventoryToFirestore(productId, newStock).catch(err => {
        console.error('Firestore sync failed for inventory adjust:', err);
      });

      // Return success
      res.json({
        success: true,
        productId,
        oldStock,
        newStock,
        quantityAdjusted: quantity,
        reason,
        transactionId,
        timestamp: createdAt,
      });
    } catch (txError) {
      await client.query('ROLLBACK');
      throw txError;
    }
  } catch (error) {
    console.error('POST /inventory/adjust error:', error);
    res.status(500).json({ error: 'Failed to adjust inventory', details: error.message });
  } finally {
    client.release();
  }
});

/**
 * POST /inventory/reserve
 * Reserve stock for an order (without consuming it yet)
 *
 * Used during order creation to check availability before payment.
 *
 * Body:
 * {
 *   orderId: string,
 *   items: [{productId: string, quantity: int}]
 * }
 *
 * Response:
 * {
 *   reservationId: string,
 *   orderId: string,
 *   reserved: [{productId, quantity}],
 *   expiresAt: ISO8601
 * }
 */
router.post('/reserve', verifyAuth, requireRole('customer', 'admin'), async (req, res) => {
  const client = await db.connect();

  try {
    const { orderId, items } = req.body;
    const userId = req.user.uid;

    if (!orderId || !items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Missing required fields: orderId, items[]' });
    }

    await client.query('BEGIN');

    try {
      // Lock all product rows
      const productIds = items.map(i => i.productId);
      const lockQuery = `
        SELECT product_id, quantity
        FROM inventory
        WHERE product_id = ANY($1)
        FOR UPDATE
      `;
      const lockResult = await client.query(lockQuery, [productIds]);
      const inventoryMap = {};
      lockResult.rows.forEach(row => {
        inventoryMap[row.product_id] = row.quantity;
      });

      // Validate all items have sufficient stock
      for (const item of items) {
        const available = inventoryMap[item.productId];
        if (available === undefined) {
          await client.query('ROLLBACK');
          return res.status(404).json({ error: `Product ${item.productId} not found` });
        }
        if (available < item.quantity) {
          await client.query('ROLLBACK');
          return res.status(400).json({
            error: 'Insufficient inventory',
            details: { productId: item.productId, requested: item.quantity, available },
          });
        }
      }

      // Create reservation
      const reservationId = `res_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

      const reservationQuery = `
        INSERT INTO inventory_reservations (reservation_id, order_id, user_id, items, expires_at, created_at)
        VALUES ($1, $2, $3, $4, $5, NOW())
        RETURNING created_at
      `;
      await client.query(reservationQuery, [
        reservationId,
        orderId,
        userId,
        JSON.stringify(items),
        expiresAt,
      ]);

      await client.query('COMMIT');

      res.json({
        reservationId,
        orderId,
        reserved: items,
        expiresAt: expiresAt.toISOString(),
      });
    } catch (txError) {
      await client.query('ROLLBACK');
      throw txError;
    }
  } catch (error) {
    console.error('POST /inventory/reserve error:', error);
    res.status(500).json({ error: 'Failed to reserve inventory', details: error.message });
  } finally {
    client.release();
  }
});

/**
 * POST /inventory/release
 * Release a reservation (if order cancelled)
 *
 * Body:
 * {
 *   reservationId: string
 * }
 */
router.post('/release', verifyAuth, requireRole('admin'), async (req, res) => {
  try {
    const { reservationId } = req.body;

    if (!reservationId) {
      return res.status(400).json({ error: 'Missing required field: reservationId' });
    }

    const query = `
      UPDATE inventory_reservations
      SET cancelled = true, cancelled_at = NOW()
      WHERE reservation_id = $1
      RETURNING order_id
    `;
    const result = await db.query(query, [reservationId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Reservation not found' });
    }

    res.json({
      success: true,
      reservationId,
      releasedAt: new Date().toISOString(),
    });
  } catch (error) {
    console.error('POST /inventory/release error:', error);
    res.status(500).json({ error: 'Failed to release reservation', details: error.message });
  }
});

/**
 * Helper: Sync inventory to Firestore (background)
 * This is a write-back to keep Firestore in eventual consistency
 */
async function syncInventoryToFirestore(productId, newQuantity) {
  try {
    const doc = await firestore.collection('inventory').doc(productId).get();
    const updatedAt = new Date().toISOString();

    await firestore.collection('inventory').doc(productId).set(
      {
        productId,
        quantity: newQuantity,
        syncedAt: updatedAt,
      },
      { merge: true }
    );

    console.log(`Synced inventory for product ${productId} to Firestore`);
  } catch (error) {
    console.error(`Failed to sync inventory to Firestore for product ${productId}:`, error);
    // Don't throw — this is a background sync failure, not critical
  }
}

module.exports = router;
