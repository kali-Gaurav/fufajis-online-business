// Order Status Routes
// POST /orders/:id/status-transition — State machine for order transitions

const express = require('express');
const router = express.Router();
const pool = require('../db/pool');
const { v4: uuidv4 } = require('uuid');

const VALID_TRANSITIONS = {
  pending: ['confirmed', 'cancelled'],
  confirmed: ['processing', 'cancelled'],
  processing: ['packed', 'cancelled'],
  packed: ['outForDelivery', 'shipped', 'cancelled'],
  shipped: ['delivered', 'cancelled'],
  outForDelivery: ['delivered', 'cancelled'],
  delivered: ['returned', 'refunded', 'completed'],
  completed: ['returned', 'refunded'],
  cancelled: ['refunded'],
  returned: ['refunded'],
  refunded: [],
};

const ALLOWED_ROLES = {
  pending: ['customer', 'admin', 'manager'],
  confirmed: ['admin', 'manager', 'shop_owner'],
  processing: ['admin', 'manager', 'shop_owner', 'employee'],
  packed: ['admin', 'manager', 'shop_owner', 'employee'],
  shipped: ['admin', 'manager', 'delivery_partner'],
  outForDelivery: ['admin', 'manager', 'delivery_partner'],
  delivered: ['admin', 'manager', 'delivery_partner'],
  completed: ['admin', 'manager', 'customer', 'delivery_partner'],
  cancelled: ['admin', 'manager', 'customer', 'shop_owner'],
  returned: ['admin', 'manager', 'customer'],
  refunded: ['admin', 'manager', 'finance'],
};

/**
 * POST /orders/:id/status-transition
 * Validate state transition and execute atomically
 */
router.post('/:id/status-transition', async (req, res) => {
  try {
    const orderId = req.params.id;
    const { targetStatus, actorId, actorRole, actorName, note, isOtpVerified, managerOverride } = req.body;

    if (!targetStatus || !actorId || !actorRole) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'targetStatus, actorId, actorRole required',
      });
    }

    // Get current order status
    const orderRes = await pool.query(
      `SELECT status, customer_id, shop_id FROM orders WHERE id = $1`,
      [orderId]
    );

    if (orderRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'ORDER_NOT_FOUND',
      });
    }

    const currentStatus = orderRes.rows[0].status;

    // Validate transition
    if (!VALID_TRANSITIONS[currentStatus]?.includes(targetStatus)) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_TRANSITION',
        message: `Cannot transition from ${currentStatus} to ${targetStatus}`,
      });
    }

    // Validate RBAC
    const allowedRoles = ALLOWED_ROLES[targetStatus] || [];
    if (!allowedRoles.includes(actorRole) && actorRole !== 'admin' && actorRole !== 'super_admin') {
      return res.status(403).json({
        success: false,
        error: 'FORBIDDEN',
        message: `Role ${actorRole} cannot perform this transition`,
      });
    }

    // OTP verification for delivery
    if (targetStatus === 'delivered' && !isOtpVerified && !managerOverride) {
      return res.status(400).json({
        success: false,
        error: 'OTP_REQUIRED',
        message: 'OTP verification required for delivery completion',
      });
    }

    // Idempotency key
    const idempotencyKey = `${orderId}_${targetStatus}_${Date.now()}_${uuidv4().substring(0, 8)}`;

    // Atomic update
    const updateRes = await pool.query(
      `UPDATE orders
       SET status = $2, updated_at = CURRENT_TIMESTAMP
       WHERE id = $1 AND status = $3
       RETURNING *`,
      [orderId, targetStatus, currentStatus]
    );

    if (updateRes.rows.length === 0) {
      return res.status(409).json({
        success: false,
        error: 'STATE_MISMATCH',
        message: 'Order status changed by another request',
      });
    }

    // Log audit trail
    await pool.query(
      `INSERT INTO order_audit_log (order_id, from_status, to_status, actor_id, actor_role, actor_name, note, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP)`,
      [orderId, currentStatus, targetStatus, actorId, actorRole, actorName || 'System', note || '']
    );

    console.log(`[order-status-routes] ✅ Order ${orderId} transitioned: ${currentStatus} → ${targetStatus}`);

    res.status(200).json({
      success: true,
      data: {
        orderId,
        previousStatus: currentStatus,
        newStatus: targetStatus,
        transitionedAt: new Date(),
      },
    });
  } catch (err) {
    console.error('[order-status-routes] ❌ Transition failed:', err.message);

    res.status(500).json({
      success: false,
      error: 'TRANSITION_FAILED',
      message: err.message,
    });
  }
});

module.exports = router;
