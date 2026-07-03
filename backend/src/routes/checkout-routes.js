// Checkout Routes
// POST /checkout/create-order — Atomic checkout with inventory lock
// POST /inventory/confirm — Confirm reservation after payment
// POST /inventory/release — Release reservation on cancel

const express = require('express');
const router = express.Router();
const CheckoutService = require('../services/checkout-service');
const InventoryService = require('../services/inventory-service');
const { validateRequest, authMiddleware } = require('../middleware/validation');

/**
 * POST /checkout/create-order
 * Atomic checkout: inventory lock → Razorpay order → order creation
 * Returns: { orderId, paymentOrderId, reservationId, expiresAt }
 */
router.post('/create-order', authMiddleware, async (req, res) => {
  try {
    const { items, paymentMethod, couponCode, discountAmount, deliveryAddressId } = req.body;
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
    const result = await CheckoutService.createOrderWithReservation({
      customerId,
      items,
      paymentMethod,
      couponCode,
      discountAmount: discountAmount || 0,
      deliveryAddressId,
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
 * Release reservation on checkout cancel or payment failure
 * Called by: Checkout screen cancel button, payment failure handler
 */
router.post('/release', authMiddleware, async (req, res) => {
  try {
    const { reservationId, orderId } = req.body;

    if (!reservationId) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'reservationId is required',
      });
    }

    await InventoryService.releaseReservation(reservationId);

    console.log(`[checkout-routes] ✅ Reservation released: ${reservationId}`);

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

module.exports = router;
