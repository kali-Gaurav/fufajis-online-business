/**
 * routes/operations.js - Automated Service Workflows
 * Centralizes inventory check-in/out and automated logistics transitions.
 * Uses InventoryTransactionService for atomic operations with rollback support.
 */

const express = require('express');
const router = express.Router();
const { admin, db } = require('../firestore');
const { verifyToken, requireRole } = require('../auth');
const InventoryTransactionService = require('../services/InventoryTransactionService');

// ── 1. Order Check-out (Packing Complete) ──────────────────────────────────
// Deducts stock atomically, updates status, and logs to ledger.
// Uses InventoryTransactionService for robust retry & rollback support.
router.post('/checkout-order', verifyToken, requireRole('UserRole.employee', 'UserRole.shopOwner'), async (req, res) => {
  const { orderId } = req.body || {};
  if (!orderId) return res.status(400).json({ success: false, error: 'orderId is required.' });

  try {
    // Fetch order to get items
    const orderSnap = await db().collection('orders').doc(orderId).get();
    if (!orderSnap.exists) {
      return res.status(404).json({ success: false, error: 'Order not found.' });
    }

    const orderData = orderSnap.data();

    // Check if already packed
    if (orderData.status === 'OrderStatus.packed') {
      return res.json({ success: true, message: 'Order already packed' });
    }

    // Use InventoryTransactionService for atomic checkout with retry logic
    const items = orderData.items || [];
    const result = await InventoryTransactionService.checkoutOrder(
      orderId,
      items,
      req.user.uid,
      3 // max retries
    );

    if (!result.success) {
      const statusCode = result.error.includes('Validation') ? 400 : 500;
      return res.status(statusCode).json(result);
    }

    console.log(`[Operations] Order ${orderId} CHECKED OUT (Packed). Transaction: ${result.transactionId}`);
    return res.json(result);

  } catch (error) {
    console.error('[Operations] Checkout failed:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── 2. Order Check-in (Return / Cancellation Recovery) ───────────────────────
// Restores stock atomically, updates status, and logs to ledger.
// Uses InventoryTransactionService for robust transaction handling.
router.post('/checkin-order', verifyToken, requireRole('UserRole.employee', 'UserRole.shopOwner', 'UserRole.admin'), async (req, res) => {
  const { orderId, reason } = req.body || {};
  if (!orderId) return res.status(400).json({ success: false, error: 'orderId is required.' });

  try {
    // Use InventoryTransactionService for atomic check-in
    const result = await InventoryTransactionService.checkinOrder(
      orderId,
      reason || 'System check-in',
      req.user.uid
    );

    if (!result.success) {
      const statusCode = result.error.includes('not found') ? 404 : 500;
      return res.status(statusCode).json(result);
    }

    console.log(`[Operations] Order ${orderId} CHECKED IN (Restored). Transaction: ${result.transactionId}`);
    return res.json(result);

  } catch (error) {
    console.error('[Operations] Check-in failed:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── 3. Get Inventory Audit Trail ────────────────────────────────────────────
// Returns full audit trail of inventory changes for an order
router.get('/inventory-audit/:orderId', verifyToken, async (req, res) => {
  const { orderId } = req.params;

  try {
    const result = await InventoryTransactionService.getOrderInventoryAudit(orderId);

    if (!result.success) {
      return res.status(500).json(result);
    }

    return res.json(result);
  } catch (error) {
    console.error('[Operations] Audit fetch failed:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
