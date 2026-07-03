/**
 * Reconciliation Jobs
 *
 * Even with perfect architecture, data drift can happen:
 * - Network timeouts during sync
 * - Bugs in edge cases
 * - External API failures
 *
 * These jobs periodically verify consistency and auto-repair.
 *
 * Runs on background schedule (every 15 min / 30 min / 1 hour)
 */

const { db } = require('../db');
const { firestore, admin } = require('../firebase');

/**
 * Inventory Reconciliation (every 15 minutes)
 *
 * Compare PostgreSQL inventory with Firestore
 * Fix mismatches automatically
 */
async function reconcileInventory() {
  try {
    console.log('[Reconciliation] Starting inventory check at', new Date().toISOString());

    // Get all products from PostgreSQL
    const pgResult = await db.query(`
      SELECT product_id, quantity
      FROM inventory
      ORDER BY product_id ASC
    `);

    const pgInventory = {};
    pgResult.rows.forEach(row => {
      pgInventory[row.product_id] = row.quantity;
    });

    // Get all products from Firestore
    const fsSnapshot = await firestore.collection('inventory').get();
    const fsInventory = {};
    fsSnapshot.forEach(doc => {
      fsInventory[doc.id] = doc.data().quantity;
    });

    // Find mismatches
    const mismatches = [];

    // Check all PostgreSQL products
    for (const [productId, pgQty] of Object.entries(pgInventory)) {
      const fsQty = fsInventory[productId];

      if (!fsQty && fsQty !== 0) {
        // Missing in Firestore, add it
        mismatches.push({
          productId,
          type: 'missing_in_firestore',
          pgQty,
          fsQty: null,
          action: 'sync_to_firestore',
        });
      } else if (pgQty !== fsQty) {
        // Quantity mismatch, PostgreSQL is authoritative
        mismatches.push({
          productId,
          type: 'quantity_mismatch',
          pgQty,
          fsQty,
          divergence: Math.abs(pgQty - fsQty),
          action: 'overwrite_firestore',
        });
      }
    }

    // Check Firestore products not in PostgreSQL (shouldn't happen, but flag it)
    for (const [productId, fsQty] of Object.entries(fsInventory)) {
      if (!pgInventory[productId] && pgInventory[productId] !== 0) {
        mismatches.push({
          productId,
          type: 'orphaned_in_firestore',
          pgQty: null,
          fsQty,
          action: 'delete_from_firestore',
        });
      }
    }

    // Auto-repair mismatches
    for (const mismatch of mismatches) {
      try {
        if (mismatch.action === 'sync_to_firestore' || mismatch.action === 'overwrite_firestore') {
          // PostgreSQL is source of truth, sync to Firestore
          await firestore.collection('inventory').doc(mismatch.productId).set(
            {
              productId: mismatch.productId,
              quantity: mismatch.pgQty,
              reconciled: true,
              reconciledAt: new Date().toISOString(),
            },
            { merge: true }
          );
        } else if (mismatch.action === 'delete_from_firestore') {
          // Delete orphaned Firestore record
          await firestore.collection('inventory').doc(mismatch.productId).delete();
        }

        // Log repair
        await db.query(
          `INSERT INTO audit_logs (entity_type, entity_id, action, metadata, created_at)
           VALUES ($1, $2, $3, $4, NOW())`,
          [
            'inventory',
            mismatch.productId,
            'reconciliation_auto_repair',
            JSON.stringify(mismatch),
          ]
        );

        console.log(`[Reconciliation] Fixed inventory mismatch: ${mismatch.productId} (${mismatch.action})`);
      } catch (error) {
        console.error(`[Reconciliation] Failed to fix mismatch for ${mismatch.productId}:`, error);
      }
    }

    if (mismatches.length > 0) {
      console.log(`[Reconciliation] Found and fixed ${mismatches.length} inventory mismatches`);
    } else {
      console.log('[Reconciliation] Inventory check passed, no mismatches found');
    }

    return { status: 'completed', mismatches: mismatches.length };
  } catch (error) {
    console.error('[Reconciliation] Inventory check failed:', error);
    return { status: 'failed', error: error.message };
  }
}

/**
 * Order Status Reconciliation (every 30 minutes)
 *
 * Verify order status consistency
 */
async function reconcileOrders() {
  try {
    console.log('[Reconciliation] Starting order check at', new Date().toISOString());

    // Find orders with mismatches between:
    // - order status
    // - payment status
    // - inventory deductions
    const result = await db.query(`
      SELECT
        o.id,
        o.status,
        o.payment_status,
        COUNT(DISTINCT oi.id) as item_count,
        COUNT(DISTINCT it.id) as deduction_count
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN inventory_transactions it ON o.id = it.order_id AND it.reason = 'order_packed'
      WHERE o.status IN ('confirmed', 'packed', 'shipped')
      GROUP BY o.id, o.status, o.payment_status
      HAVING COUNT(DISTINCT oi.id) != COUNT(DISTINCT it.id)
    `);

    const mismatches = result.rows;

    for (const mismatch of mismatches) {
      console.log(`[Reconciliation] Order mismatch: ${mismatch.id} (items=${mismatch.item_count}, deductions=${mismatch.deduction_count})`);

      // Log for ops review (don't auto-repair — orders are critical)
      await db.query(
        `INSERT INTO audit_logs (entity_type, entity_id, action, metadata, created_at)
         VALUES ($1, $2, $3, $4, NOW())`,
        [
          'order',
          mismatch.id,
          'reconciliation_mismatch_detected',
          JSON.stringify(mismatch),
        ]
      );
    }

    if (mismatches.length > 0) {
      console.log(`[Reconciliation] Found ${mismatches.length} order mismatches (requiring manual review)`);
    } else {
      console.log('[Reconciliation] Order check passed, no mismatches found');
    }

    return { status: 'completed', mismatches: mismatches.length };
  } catch (error) {
    console.error('[Reconciliation] Order check failed:', error);
    return { status: 'failed', error: error.message };
  }
}

/**
 * Payment Reconciliation (every 1 hour)
 *
 * Verify payment amounts and statuses
 */
async function reconcilePayments() {
  try {
    console.log('[Reconciliation] Starting payment check at', new Date().toISOString());

    // Check for payments where order amount ≠ payment amount
    const result = await db.query(`
      SELECT
        p.id,
        p.order_id,
        p.amount as payment_amount,
        o.total_amount as order_amount,
        ABS(p.amount - o.total_amount) as divergence
      FROM payments p
      JOIN orders o ON p.order_id = o.id
      WHERE p.amount != o.total_amount
      AND p.signature_verified = TRUE
      ORDER BY divergence DESC
    `);

    const mismatches = result.rows;

    for (const mismatch of mismatches) {
      console.log(`[Reconciliation] Payment mismatch: ${mismatch.id} (payment=${mismatch.payment_amount}, order=${mismatch.order_amount})`);

      // Alert ops — potential payment issue
      await db.query(
        `INSERT INTO audit_logs (entity_type, entity_id, action, metadata, created_at)
         VALUES ($1, $2, $3, $4, NOW())`,
        [
          'payment',
          mismatch.order_id,
          'reconciliation_amount_mismatch',
          JSON.stringify(mismatch),
        ]
      );
    }

    if (mismatches.length > 0) {
      console.log(`[Reconciliation] Found ${mismatches.length} payment mismatches (ops review required)`);
    } else {
      console.log('[Reconciliation] Payment check passed, no mismatches found');
    }

    return { status: 'completed', mismatches: mismatches.length };
  } catch (error) {
    console.error('[Reconciliation] Payment check failed:', error);
    return { status: 'failed', error: error.message };
  }
}

/**
 * Sync Queue Health Check (every 5 minutes)
 *
 * Monitor dead letter queue, alert if grows too large
 */
async function checkSyncQueueHealth() {
  try {
    const result = await db.query(`
      SELECT
        status,
        COUNT(*) as count
      FROM sync_queue
      WHERE created_at > NOW() - INTERVAL '24 hours'
      GROUP BY status
    `);

    const health = {};
    result.rows.forEach(row => {
      health[row.status] = row.count;
    });

    console.log('[Reconciliation] Sync queue health:', health);

    // Alert if too many dead letters
    const dlqCount = health.dead_letter || 0;
    if (dlqCount > 10) {
      console.error(`[ALERT] Sync queue has ${dlqCount} dead letter jobs — ops intervention needed`);

      await db.query(
        `INSERT INTO audit_logs (entity_type, entity_id, action, metadata, created_at)
         VALUES ($1, $2, $3, $4, NOW())`,
        [
          'system',
          'sync_queue',
          'alert_high_dlq_count',
          JSON.stringify({ dlqCount, threshold: 10 }),
        ]
      );
    }

    return health;
  } catch (error) {
    console.error('[Reconciliation] Sync queue health check failed:', error);
    return { error: error.message };
  }
}

/**
 * Start reconciliation worker
 * Runs on scheduled intervals
 */
function startReconciliationWorker() {
  // Inventory: every 15 minutes
  setInterval(() => {
    reconcileInventory().catch(err => console.error('Inventory reconciliation error:', err));
  }, 15 * 60 * 1000);

  // Orders: every 30 minutes
  setInterval(() => {
    reconcileOrders().catch(err => console.error('Order reconciliation error:', err));
  }, 30 * 60 * 1000);

  // Payments: every 1 hour
  setInterval(() => {
    reconcilePayments().catch(err => console.error('Payment reconciliation error:', err));
  }, 60 * 60 * 1000);

  // Sync queue: every 5 minutes
  setInterval(() => {
    checkSyncQueueHealth().catch(err => console.error('Sync queue health check error:', err));
  }, 5 * 60 * 1000);

  console.log('Reconciliation worker started');
  console.log('  - Inventory check: every 15 minutes');
  console.log('  - Order check: every 30 minutes');
  console.log('  - Payment check: every 1 hour');
  console.log('  - Sync queue health: every 5 minutes');
}

module.exports = {
  reconcileInventory,
  reconcileOrders,
  reconcilePayments,
  checkSyncQueueHealth,
  startReconciliationWorker,
};
