/**
 * ============================================================================
 * routes/dispatch.js - Delivery Dispatch Management
 * ============================================================================
 * POST   /dispatch/find-riders          Find available riders near location
 * POST   /dispatch/assign                Assign order to rider
 * POST   /dispatch/unassign              Unassign order from rider
 * GET    /dispatch/optimize-route        Get optimized route for rider
 * POST   /dispatch/update-location       Update rider location (from app)
 * POST   /dispatch/verify-otp            Verify delivery OTP
 * POST   /dispatch/complete              Complete delivery
 * GET    /dispatch/track/:orderId        Get tracking info (customer)
 * ============================================================================
 */

const express = require('express');
const router = express.Router();
const DeliveryDispatchService = require('../services/DeliveryDispatchService');
const { authMiddleware, requireRole } = require('../middleware/validation');

/**
 * POST /dispatch/find-riders
 * Find available riders near delivery location
 * Used by: Admin dispatch system, auto-assignment algorithm
 */
router.post('/find-riders', requireRole('UserRole.admin', 'UserRole.shopOwner'), async (req, res) => {
  try {
    const {
      latitude,
      longitude,
      maxDistanceKm = 2,
      excludeRiderIds = []
    } = req.body;

    if (!latitude || !longitude) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'latitude and longitude are required'
      });
    }

    const riders = await DeliveryDispatchService.findAvailableRiders({
      latitude,
      longitude,
      maxDistanceKm,
      excludeRiderIds
    });

    res.json({
      success: true,
      data: {
        riders: riders,
        count: riders.length
      }
    });
  } catch (err) {
    console.error('[dispatch] ❌ Find riders failed:', err.message);
    res.status(500).json({
      success: false,
      error: 'FIND_RIDERS_FAILED',
      message: err.message
    });
  }
});

/**
 * POST /dispatch/assign
 * Assign order to rider with atomic transaction
 */
router.post('/assign', requireRole('UserRole.admin', 'UserRole.shopOwner'), async (req, res) => {
  try {
    const {
      orderId,
      riderId,
      deliveryAddressLatitude,
      deliveryAddressLongitude,
      estimatedDeliveryTime = 30
    } = req.body;

    if (!orderId || !riderId) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'orderId and riderId are required'
      });
    }

    const result = await DeliveryDispatchService.assignOrderToRider({
      orderId,
      riderId,
      deliveryAddressLatitude,
      deliveryAddressLongitude,
      estimatedDeliveryTime
    });

    console.log(`[dispatch] ✅ Order assigned: ${orderId} → ${riderId}`);

    res.status(201).json({
      success: true,
      data: result
    });
  } catch (err) {
    console.error('[dispatch] ❌ Assign failed:', err.message);

    if (err.message.includes('ORDER_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'ORDER_NOT_FOUND',
        message: err.message
      });
    }

    if (err.message.includes('RIDER_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'RIDER_NOT_FOUND',
        message: err.message
      });
    }

    if (err.message.includes('RIDER_OVERLOADED')) {
      return res.status(409).json({
        success: false,
        error: 'RIDER_OVERLOADED',
        message: err.message
      });
    }

    res.status(500).json({
      success: false,
      error: 'ASSIGN_FAILED',
      message: err.message
    });
  }
});

/**
 * POST /dispatch/unassign
 * Unassign order from rider (e.g., rider cancelled, reassigning)
 */
router.post('/unassign', requireRole('UserRole.admin', 'UserRole.shopOwner'), async (req, res) => {
  try {
    const { orderId } = req.body;

    if (!orderId) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'orderId is required'
      });
    }

    const result = await DeliveryDispatchService.unassignOrderFromRider(orderId);

    console.log(`[dispatch] ✅ Order unassigned: ${orderId}`);

    res.json({
      success: true,
      data: result
    });
  } catch (err) {
    console.error('[dispatch] ❌ Unassign failed:', err.message);

    if (err.message.includes('TRACKING_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'TRACKING_NOT_FOUND',
        message: err.message
      });
    }

    res.status(500).json({
      success: false,
      error: 'UNASSIGN_FAILED',
      message: err.message
    });
  }
});

/**
 * GET /dispatch/optimize-route?riderId=...
 * Get optimized delivery route for rider
 */
router.get('/optimize-route', authMiddleware, async (req, res) => {
  try {
    const { riderId } = req.query;

    if (!riderId) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'riderId query parameter is required'
      });
    }

    // Verify rider can access own route or admin can access any
    if (req.user.role !== 'UserRole.admin' && req.user.id !== riderId) {
      return res.status(403).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: 'You can only view your own route'
      });
    }

    const result = await DeliveryDispatchService.optimizeRiderRoute(riderId);

    res.json({
      success: true,
      data: result
    });
  } catch (err) {
    console.error('[dispatch] ❌ Optimize route failed:', err.message);

    if (err.message.includes('RIDER_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'RIDER_NOT_FOUND',
        message: err.message
      });
    }

    res.status(500).json({
      success: false,
      error: 'OPTIMIZE_ROUTE_FAILED',
      message: err.message
    });
  }
});

/**
 * POST /dispatch/update-location
 * Update delivery tracking with current location
 * Called by rider app every 10 seconds
 */
router.post('/update-location', authMiddleware, async (req, res) => {
  try {
    const { trackingId, latitude, longitude, accuracy } = req.body;

    if (!trackingId || latitude === undefined || longitude === undefined) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'trackingId, latitude, and longitude are required'
      });
    }

    const result = await DeliveryDispatchService.updateDeliveryLocation({
      trackingId,
      latitude: parseFloat(latitude),
      longitude: parseFloat(longitude),
      accuracy: accuracy ? parseFloat(accuracy) : null
    });

    res.json({
      success: true,
      data: result
    });
  } catch (err) {
    console.error('[dispatch] ❌ Update location failed:', err.message);

    if (err.message.includes('TRACKING_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'TRACKING_NOT_FOUND',
        message: err.message
      });
    }

    res.status(500).json({
      success: false,
      error: 'UPDATE_LOCATION_FAILED',
      message: err.message
    });
  }
});

/**
 * POST /dispatch/verify-otp
 * Verify delivery OTP at customer location
 */
router.post('/verify-otp', authMiddleware, async (req, res) => {
  try {
    const { trackingId, otp } = req.body;

    if (!trackingId || !otp) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'trackingId and otp are required'
      });
    }

    const result = await DeliveryDispatchService.verifyDeliveryOtp(trackingId, otp);

    console.log(`[dispatch] ✅ OTP verified: ${trackingId}`);

    res.json({
      success: true,
      data: {
        trackingId: result.id,
        verified: true,
        message: 'OTP verified successfully'
      }
    });
  } catch (err) {
    console.error('[dispatch] ❌ Verify OTP failed:', err.message);

    if (err.message.includes('TRACKING_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'TRACKING_NOT_FOUND',
        message: err.message
      });
    }

    if (err.message.includes('INVALID_OTP')) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_OTP',
        message: err.message
      });
    }

    if (err.message.includes('OTP_ALREADY_VERIFIED')) {
      return res.status(409).json({
        success: false,
        error: 'OTP_ALREADY_VERIFIED',
        message: err.message
      });
    }

    res.status(500).json({
      success: false,
      error: 'VERIFY_OTP_FAILED',
      message: err.message
    });
  }
});

/**
 * POST /dispatch/complete
 * Complete delivery (rider submits proof)
 */
router.post('/complete', authMiddleware, async (req, res) => {
  try {
    const {
      trackingId,
      proofPhotoUrl,
      signatureUrl,
      notes = ''
    } = req.body;

    if (!trackingId) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_REQUEST',
        message: 'trackingId is required'
      });
    }

    const result = await DeliveryDispatchService.completeDelivery({
      trackingId,
      proofPhotoUrl,
      signatureUrl,
      notes
    });

    console.log(`[dispatch] ✅ Delivery completed: ${result.orderId}`);

    res.json({
      success: true,
      data: result
    });
  } catch (err) {
    console.error('[dispatch] ❌ Complete failed:', err.message);

    if (err.message.includes('TRACKING_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'TRACKING_NOT_FOUND',
        message: err.message
      });
    }

    if (err.message.includes('OTP_NOT_VERIFIED')) {
      return res.status(409).json({
        success: false,
        error: 'OTP_NOT_VERIFIED',
        message: err.message
      });
    }

    res.status(500).json({
      success: false,
      error: 'COMPLETE_FAILED',
      message: err.message
    });
  }
});

/**
 * GET /dispatch/track/:orderId
 * Get delivery tracking info for customer
 */
router.get('/track/:orderId', authMiddleware, async (req, res) => {
  try {
    const orderId = req.params.orderId;
    const customerId = req.user.id;

    const tracking = await DeliveryDispatchService.getDeliveryTracking(orderId, customerId);

    res.json({
      success: true,
      data: tracking
    });
  } catch (err) {
    console.error('[dispatch] ❌ Track failed:', err.message);

    if (err.message.includes('TRACKING_NOT_FOUND')) {
      return res.status(404).json({
        success: false,
        error: 'TRACKING_NOT_FOUND',
        message: 'Delivery tracking information not found'
      });
    }

    res.status(500).json({
      success: false,
      error: 'TRACK_FAILED',
      message: err.message
    });
  }
});

module.exports = router;
