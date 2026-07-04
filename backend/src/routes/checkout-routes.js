// Checkout Routes
// POST /checkout/create-order — Atomic checkout with inventory lock
// POST /inventory/confirm — Confirm reservation after payment
// POST /inventory/release — Release reservation on cancel

const express = require('express');
const router = express.Router();
const CheckoutService = require('../services/checkout-service');
const InventoryService = require('../services/inventory-service');
const ShippingService = require('../services/ShippingService');
const { validateRequest, authMiddleware } = require('../middleware/validation');

/**
 * POST /checkout/create-order
 * Atomic checkout: inventory lock → Razorpay order → order creation
 * Returns: { orderId, paymentOrderId, reservationId, expiresAt }
 */
router.post('/create-order', authMiddleware, async (req, res) => {
  try {
    const { items, paymentMethod, couponCode, deliveryAddressId, deliveryType = 'standard' } = req.body;
    const customerId = req.user.id;
    const idempotencyKey = req.headers['idempotency-key'];

    // Validate request
    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'items array is required and must be non-empty',
      });
    }

    for (const item of items) {
      if (!item.productId || !item.quantity || item.quantity <= 0) {
        return res.status(400).json({
          success: false,
          error: 'INVALID_ITEM',
          message: 'Each item must have productId, quantity, price, shopId',
        });
      }
    }

    if (!idempotencyKey) {
      return res.status(400).json({
        success: false,
        error: 'MISSING_IDEMPOTENCY_KEY',
        message: 'Idempotency-Key header is required',
      });
    }

    // Call checkout service (fully atomic)
    // ✅ FIX: discountAmount now calculated server-side by CouponService
    // ✅ FIX: shippingFee now calculated server-side by ShippingService
    const result = await CheckoutService.createOrderWithReservation({
      customerId,
      items,
      paymentMethod,
      couponCode,
      deliveryAddressId,
      deliveryType,
      idempotencyKey,
    });

    console.log(`[checkout-routes] ✅ Checkout successful: ${result.orderId}`);

    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    console.error('[checkout-routes] ❌ Checkout failed:', err.message);

    // Specific error handling
    if (err.message.includes('INSUFFICIENT_STOCK')) {
      return res.status(409).json({
        success: false,
        error: 'INSUFFICIENT_STOCK',
        message: err.message,
      });
    }
    if (err.message.includes('PRODUCT_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'PRODUCT_NOT_FOUND',
        message: err.message,
      });
    }
    if (err.message.includes('Razorpay')) {
      return res.status(502).json({
        success: false,
        error: 'PAYMENT_GATEWAY_ERROR',
        message: 'Failed to create payment order. Please try again.',
      });
    }

    res.status(500).json({
      success: false,
      error: 'CHECKOUT_FAILED',
      message: err.message,
    });
  }
});

/**
 * POST /inventory/confirm
 * Confirm reservation after payment webhook verification
 * Called by: Payment verification service
 */
router.post('/confirm', authMiddleware, async (req, res) => {
  try {
    const { reservationId, orderId, paymentId } = req.body;

    if (!reservationId || !orderId) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'reservationId and orderId are required',
      });
    }

    await InventoryService.confirmReservation(reservationId, orderId, paymentId);

    console.log(`[checkout-routes] ✅ Reservation confirmed: ${reservationId}`);

    res.status(200).json({
      success: true,
      message: 'Reservation confirmed',
      reservationId,
    });
  } catch (err) {
    console.error('[checkout-routes] ❌ Confirmation failed:', err.message);

    res.status(500).json({
      success: false,
      error: 'CONFIRMATION_FAILED',
      message: err.message,
    });
  }
});

/**
 * POST /inventory/release
 * ✅ FIXES:
 * - Verifies customer ownership before releasing
 * - Prevents user from releasing other users' reservations
 * Release reservation on checkout cancel or payment failure
 * Called by: Checkout screen cancel button, payment failure handler
 */
router.post('/release', authMiddleware, async (req, res) => {
  try {
    const { reservationId, orderId } = req.body;
    const customerId = req.user.id;

    if (!reservationId) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'reservationId is required',
      });
    }

    // ✅ FIX: Verify customer ownership before releasing
    const pool = require('../db/pool');
    const resCheckRes = await pool.query(
      `SELECT customer_id FROM reservations WHERE id = $1`,
      [reservationId]
    );

    if (resCheckRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'RESERVATION_NOT_FOUND',
        message: `Reservation ${reservationId} not found`,
      });
    }

    if (resCheckRes.rows[0].customer_id !== customerId) {
      console.warn(
        `[checkout-routes] 🚨 SECURITY: User ${customerId} attempted to release reservation owned by ${resCheckRes.rows[0].customer_id}`
      );
      return res.status(403).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: 'You do not own this reservation',
      });
    }

    await InventoryService.releaseReservation(reservationId);

    console.log(`[checkout-routes] ✅ Reservation released: ${reservationId} (customer: ${customerId})`);

    res.status(200).json({
      success: true,
      message: 'Reservation released, stock returned to available',
      reservationId,
    });
  } catch (err) {
    console.error('[checkout-routes] ❌ Release failed:', err.message);

    if (err.message.includes('RESERVATION_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'RESERVATION_NOT_FOUND',
        message: err.message,
      });
    }

    res.status(500).json({
      success: false,
      error: 'RELEASE_FAILED',
      message: err.message,
    });
  }
});

/**
 * ✅ NEW ENDPOINT - GET /checkout/shipping
 * ✅ FIXES:
 * - Validates delivery address belongs to customer
 * - Validates items array size
 * - Prevents users from checking shipping for other users' addresses
 * Calculate shipping fee based on delivery type, address, and items
 * Query params: deliveryType, deliveryAddressId, subtotal, items
 * Returns: { fee, breakdown, estimatedDeliveryDate, distance, weight }
 */
router.get('/shipping', authMiddleware, async (req, res) => {
  try {
    const customerId = req.user.id;
    const {deliveryType = 'standard', deliveryAddressId, subtotal, items: itemsJson} = req.query;
    const pool = require('../db/pool');

    // Validate required params
    if (!deliveryAddressId) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'deliveryAddressId is required',
      });
    }

    if (!subtotal) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'subtotal is required',
      });
    }

    // ✅ FIX: Verify delivery address belongs to customer
    const addrCheckRes = await pool.query(
      `SELECT id FROM users_addresses WHERE id = $1 AND user_id = $2`,
      [deliveryAddressId, customerId]
    );

    if (addrCheckRes.rows.length === 0) {
      console.warn(
        `[checkout-routes] 🚨 SECURITY: User ${customerId} attempted to calculate shipping for non-owned address ${deliveryAddressId}`
      );
      return res.status(403).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: 'This address does not belong to you',
      });
    }

    // Parse items array from query (sent as JSON string)
    let items = [];
    if (itemsJson) {
      try {
        items = JSON.parse(itemsJson);

        // ✅ FIX: Validate items array size
        if (!Array.isArray(items)) {
          throw new Error('items must be an array');
        }
        if (items.length > 100) {
          return res.status(400).json({
            success: false,
            error: 'INVALID_REQUEST',
            message: 'items array too large (max 100)',
          });
        }
      } catch (err) {
        return res.status(400).json({
          success: false,
          error: 'INVALID_JSON',
          message: 'items must be valid JSON array',
        });
      }
    }

    // Calculate shipping fee
    const shippingResult = await ShippingService.calculateFee({
      deliveryType,
      deliveryAddressId,
      subtotal: parseFloat(subtotal),
      items,
      shopId: null  // Will use default location
    });

    console.log(
      `[checkout-routes] Shipping calculated: ${shippingResult.fee}₹ for customer ${customerId}`
    );

    res.json({
      success: true,
      data: shippingResult
    });
  } catch (err) {
    console.error('[checkout-routes] ❌ Shipping calculation failed:', err.message);

    if (err.message.includes('not found') || err.message.includes('INVALID_ADDRESS')) {
      return res.status(404).json({
        success: false,
        error: 'ADDRESS_NOT_FOUND',
        message: err.message,
      });
    }

    res.status(500).json({
      success: false,
      error: 'SHIPPING_CALCULATION_FAILED',
      message: err.message,
    });
  }
});

module.exports = router;
