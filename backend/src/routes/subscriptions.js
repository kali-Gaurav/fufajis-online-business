/**
 * ============================================================================
 * routes/subscriptions.js - Subscription Management Endpoints
 * ============================================================================
 * POST /subscriptions/create       Create new subscription
 * GET  /subscriptions/:id          Get subscription details
 * GET  /subscriptions              List customer subscriptions
 * POST /subscriptions/:id/pause    Pause subscription
 * POST /subscriptions/:id/resume   Resume paused subscription
 * POST /subscriptions/:id/cancel   Cancel subscription
 * POST /subscriptions/process      (Admin) Process due subscriptions (cron)
 * ============================================================================
 */

const express = require('express');
const router = express.Router();
const SubscriptionService = require('../services/SubscriptionService');
const { authMiddleware, requireRole } = require('../middleware/validation');
const pool = require('../db/pool');

/**
 * POST /subscriptions/create
 * Create a new recurring subscription
 */
router.post('/create', authMiddleware, async (req, res) => {
  try {
    const {
      items,              // [{ productId, quantity }, ...]
      frequency,          // 'daily', 'weekly', 'monthly'
      startDate,         // ISO date or null for tomorrow
      deliveryAddressId,
      paymentMethodId,
      couponCode,
    } = req.body;

    const customerId = req.user.id;
    const idempotencyKey = req.headers['idempotency-key'];

    // Validate
    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'items array is required and must be non-empty'
      });
    }

    if (!frequency) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'frequency is required (daily, weekly, or monthly)'
      });
    }

    if (!deliveryAddressId) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'deliveryAddressId is required'
      });
    }

    if (!idempotencyKey) {
      return res.status(400).json({
        success: false,
        error: 'MISSING_IDEMPOTENCY_KEY',
        message: 'Idempotency-Key header is required'
      });
    }

    // Create subscription
    const subscription = await SubscriptionService.createSubscription({
      customerId,
      items,
      frequency,
      startDate,
      deliveryAddressId,
      paymentMethodId,
      couponCode,
      idempotencyKey,
    });

    console.log(`[subscriptions] ✅ Subscription created: ${subscription.id}`);

    res.status(201).json({
      success: true,
      data: {
        subscriptionId: subscription.id,
        status: subscription.status,
        frequency: subscription.frequency,
        nextDeliveryDate: subscription.next_delivery_date,
        totalAmount: subscription.total_amount,
        itemsCount: subscription.items_count,
        createdAt: subscription.created_at,
      }
    });
  } catch (err) {
    console.error('[subscriptions] ❌ Create failed:', err.message);

    if (err.message.includes('INSUFFICIENT_STOCK')) {
      return res.status(409).json({
        success: false,
        error: 'INSUFFICIENT_STOCK',
        message: err.message
      });
    }

    if (err.message.includes('ADDRESS_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'ADDRESS_NOT_FOUND',
        message: err.message
      });
    }

    if (err.message.includes('UNAUTHORIZED')) {
      return res.status(403).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: err.message
      });
    }

    res.status(500).json({
      success: false,
      error: 'CREATE_FAILED',
      message: err.message
    });
  }
});

/**
 * GET /subscriptions/:id
 * Get subscription details with items
 */
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const subscriptionId = req.params.id;
    const customerId = req.user.id;

    const subscription = await SubscriptionService.getSubscription(subscriptionId, customerId);

    res.json({
      success: true,
      data: subscription
    });
  } catch (err) {
    console.error('[subscriptions] ❌ Get failed:', err.message);

    if (err.message.includes('SUBSCRIPTION_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'SUBSCRIPTION_NOT_FOUND',
        message: err.message
      });
    }

    res.status(500).json({
      success: false,
      error: 'GET_FAILED',
      message: err.message
    });
  }
});

/**
 * GET /subscriptions
 * List all active subscriptions for customer
 */
router.get('/', authMiddleware, async (req, res) => {
  try {
    const customerId = req.user.id;
    const status = req.query.status || 'active'; // 'active', 'paused', 'cancelled', 'all'

    let query = `
      SELECT id, status, frequency, next_delivery_date, total_amount, items_count,
             churn_risk, predicted_lifetime_value, created_at
      FROM subscriptions
      WHERE customer_id = $1
    `;

    const params = [customerId];

    if (status !== 'all') {
      query += ` AND status = $2`;
      params.push(status);
    }

    query += ` ORDER BY created_at DESC LIMIT 50`;

    const result = await pool.query(query, params);

    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });
  } catch (err) {
    console.error('[subscriptions] ❌ List failed:', err.message);
    res.status(500).json({
      success: false,
      error: 'LIST_FAILED',
      message: err.message
    });
  }
});

/**
 * POST /subscriptions/:id/pause
 * Pause an active subscription
 */
router.post('/:id/pause', authMiddleware, async (req, res) => {
  try {
    const subscriptionId = req.params.id;
    const customerId = req.user.id;

    const subscription = await SubscriptionService.pauseSubscription(subscriptionId, customerId);

    console.log(`[subscriptions] ✅ Subscription paused: ${subscriptionId}`);

    res.json({
      success: true,
      data: {
        subscriptionId: subscription.id,
        status: subscription.status,
        message: 'Subscription paused successfully'
      }
    });
  } catch (err) {
    console.error('[subscriptions] ❌ Pause failed:', err.message);

    if (err.message.includes('SUBSCRIPTION_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'SUBSCRIPTION_NOT_FOUND',
        message: err.message
      });
    }

    if (err.message.includes('UNAUTHORIZED')) {
      return res.status(403).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: err.message
      });
    }

    if (err.message.includes('INVALID_STATUS')) {
      return res.status(409).json({
        success: false,
        error: 'INVALID_STATUS',
        message: err.message
      });
    }

    res.status(500).json({
      success: false,
      error: 'PAUSE_FAILED',
      message: err.message
    });
  }
});

/**
 * POST /subscriptions/:id/resume
 * Resume a paused subscription
 */
router.post('/:id/resume', authMiddleware, async (req, res) => {
  try {
    const subscriptionId = req.params.id;
    const customerId = req.user.id;

    const subscription = await SubscriptionService.resumeSubscription(subscriptionId, customerId);

    console.log(`[subscriptions] ✅ Subscription resumed: ${subscriptionId}`);

    res.json({
      success: true,
      data: {
        subscriptionId: subscription.id,
        status: subscription.status,
        nextDeliveryDate: subscription.next_delivery_date,
        message: 'Subscription resumed successfully'
      }
    });
  } catch (err) {
    console.error('[subscriptions] ❌ Resume failed:', err.message);

    if (err.message.includes('SUBSCRIPTION_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'SUBSCRIPTION_NOT_FOUND',
        message: err.message
      });
    }

    if (err.message.includes('UNAUTHORIZED')) {
      return res.status(403).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: err.message
      });
    }

    if (err.message.includes('INVALID_STATUS')) {
      return res.status(409).json({
        success: false,
        error: 'INVALID_STATUS',
        message: err.message
      });
    }

    res.status(500).json({
      success: false,
      error: 'RESUME_FAILED',
      message: err.message
    });
  }
});

/**
 * POST /subscriptions/:id/cancel
 * Cancel a subscription
 */
router.post('/:id/cancel', authMiddleware, async (req, res) => {
  try {
    const subscriptionId = req.params.id;
    const customerId = req.user.id;
    const { reason } = req.body || {};

    const result = await SubscriptionService.cancelSubscription(
      subscriptionId,
      customerId,
      reason
    );

    console.log(`[subscriptions] ✅ Subscription cancelled: ${subscriptionId}`);

    res.json({
      success: true,
      data: {
        subscriptionId: result.subscriptionId,
        message: 'Subscription cancelled successfully'
      }
    });
  } catch (err) {
    console.error('[subscriptions] ❌ Cancel failed:', err.message);

    if (err.message.includes('SUBSCRIPTION_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'SUBSCRIPTION_NOT_FOUND',
        message: err.message
      });
    }

    if (err.message.includes('UNAUTHORIZED')) {
      return res.status(403).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: err.message
      });
    }

    if (err.message.includes('ALREADY_CANCELLED')) {
      return res.status(409).json({
        success: false,
        error: 'ALREADY_CANCELLED',
        message: err.message
      });
    }

    res.status(500).json({
      success: false,
      error: 'CANCEL_FAILED',
      message: err.message
    });
  }
});

/**
 * POST /subscriptions/process (Admin/Cron only)
 * Process all subscriptions due for delivery today
 * Called by cron job daily at midnight
 */
router.post('/process', requireRole('UserRole.admin', 'UserRole.shopOwner'), async (req, res) => {
  try {
    const results = await SubscriptionService.processDueSubscriptions();

    console.log(`[subscriptions] ✅ Processed ${results.length} subscriptions`);

    res.json({
      success: true,
      data: {
        processed: results.length,
        results: results,
        message: `Processed ${results.length} subscriptions`
      }
    });
  } catch (err) {
    console.error('[subscriptions] ❌ Process failed:', err.message);
    res.status(500).json({
      success: false,
      error: 'PROCESS_FAILED',
      message: err.message
    });
  }
});

module.exports = router;
