/**
 * Delivery API Routes
 *
 * REST API endpoints for the delivery system.
 * All endpoints require authentication.
 */

const express = require('express');
const router = express.Router();
const DeliveryAssignmentService = require('../services/DeliveryAssignmentService');
const RouteOptimizationService = require('../services/RouteOptimizationService');
const GpsTrackingService = require('../services/GpsTrackingService');
const DeliveryCompletionService = require('../services/DeliveryCompletionService');

// Middleware for authentication
const authenticateRequest = (req, res, next) => {
  const authToken = req.headers.authorization?.replace('Bearer ', '');
  if (!authToken) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  // In production, verify token with Firebase
  next();
};

router.use(authenticateRequest);

/**
 * POST /api/delivery/assign
 * Assign an order to the nearest available rider
 */
router.post('/assign', async (req, res) => {
  try {
    const { order_id, customer_id, delivery_address } = req.body;

    if (!order_id || !customer_id || !delivery_address) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await DeliveryAssignmentService.assignOrderToRider(
      order_id,
      customer_id,
      delivery_address
    );

    return res.status(result.success ? 200 : 400).json(result);
  } catch (error) {
    console.error('Error in /assign:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/delivery/batch-assign
 * Batch assign multiple orders to riders
 */
router.post('/batch-assign', async (req, res) => {
  try {
    const { orders } = req.body;

    if (!Array.isArray(orders) || orders.length === 0) {
      return res.status(400).json({ error: 'Orders array required' });
    }

    const result = await DeliveryAssignmentService.batchAssignOrders(orders);
    return res.status(200).json(result);
  } catch (error) {
    console.error('Error in /batch-assign:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/delivery/riders/available
 * Get available riders within a radius
 */
router.get('/riders/available', async (req, res) => {
  try {
    const { latitude, longitude, distance } = req.query;

    if (!latitude || !longitude) {
      return res.status(400).json({ error: 'Latitude and longitude required' });
    }

    const maxDistance = parseFloat(distance) || 5; // Default 5km
    const riders = await DeliveryAssignmentService.getAvailableRiders(
      parseFloat(latitude),
      parseFloat(longitude),
      maxDistance
    );

    return res.status(200).json({ success: true, riders });
  } catch (error) {
    console.error('Error in /riders/available:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/delivery/rider/:riderId/capacity
 * Check rider capacity
 */
router.get('/rider/:riderId/capacity', async (req, res) => {
  try {
    const { riderId } = req.params;
    const capacity = await DeliveryAssignmentService.checkRiderCapacity(riderId);

    return res.status(200).json({ success: true, capacity });
  } catch (error) {
    console.error('Error in /rider/:riderId/capacity:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/delivery/route/optimize
 * Optimize delivery route for a rider
 */
router.post('/route/optimize', async (req, res) => {
  try {
    const { delivery_tasks, rider_location } = req.body;

    if (!delivery_tasks || !rider_location) {
      return res.status(400).json({ error: 'Missing delivery_tasks or rider_location' });
    }

    const result = await RouteOptimizationService.optimizeRoute(
      delivery_tasks,
      rider_location
    );

    return res.status(result.success ? 200 : 400).json(result);
  } catch (error) {
    console.error('Error in /route/optimize:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/delivery/location
 * Update rider GPS location
 */
router.post('/location', async (req, res) => {
  try {
    const { rider_id, latitude, longitude, accuracy } = req.body;

    if (!rider_id || latitude === undefined || longitude === undefined) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await GpsTrackingService.updateRiderLocation(
      rider_id,
      latitude,
      longitude,
      accuracy
    );

    return res.status(result.success ? 200 : 400).json(result);
  } catch (error) {
    console.error('Error in /location:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/delivery/rider/:riderId/current-location
 * Get rider's current location
 */
router.get('/rider/:riderId/current-location', async (req, res) => {
  try {
    const { riderId } = req.params;
    const location = await GpsTrackingService.getRiderCurrentLocation(riderId);

    return res.status(location ? 200 : 404).json({
      success: !!location,
      location
    });
  } catch (error) {
    console.error('Error in /rider/:riderId/current-location:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/delivery/:taskId/eta
 * Get current ETA for a delivery task
 */
router.get('/:taskId/eta', async (req, res) => {
  try {
    const { taskId } = req.params;

    // In production, retrieve task and calculate ETA
    // This is a placeholder implementation

    return res.status(200).json({
      success: true,
      task_id: taskId,
      eta_minutes: 15,
      estimated_arrival: new Date(Date.now() + 15 * 60000).toISOString()
    });
  } catch (error) {
    console.error('Error in /:taskId/eta:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/delivery/tracking/:orderId
 * Get real-time tracking for order
 */
router.get('/tracking/:orderId', async (req, res) => {
  try {
    const { orderId } = req.params;
    const tracking = await GpsTrackingService.getDeliveryTracking(orderId);

    return res.status(tracking.success ? 200 : 404).json(tracking);
  } catch (error) {
    console.error('Error in /tracking/:orderId:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/delivery/rider/:riderId/history
 * Get rider's location history
 */
router.get('/rider/:riderId/history', async (req, res) => {
  try {
    const { riderId } = req.params;
    const { hours } = req.query;

    const history = await GpsTrackingService.getLocationHistory(
      riderId,
      parseInt(hours) || 24
    );

    return res.status(200).json({
      success: true,
      rider_id: riderId,
      history
    });
  } catch (error) {
    console.error('Error in /rider/:riderId/history:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/delivery/:taskId/complete
 * Mark delivery as complete
 */
router.post('/:taskId/complete', async (req, res) => {
  try {
    const { taskId } = req.params;
    const { proof_type, proof_data } = req.body;

    if (!proof_type || !proof_data) {
      return res.status(400).json({ error: 'Missing proof_type or proof_data' });
    }

    const result = await DeliveryCompletionService.completeDelivery(
      taskId,
      proof_type,
      proof_data
    );

    return res.status(result.success ? 200 : 400).json(result);
  } catch (error) {
    console.error('Error in /:taskId/complete:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/delivery/:taskId/otp/generate
 * Generate OTP for delivery verification
 */
router.post('/:taskId/otp/generate', async (req, res) => {
  try {
    const { taskId } = req.params;
    const { customer_id } = req.body;

    if (!customer_id) {
      return res.status(400).json({ error: 'customer_id required' });
    }

    const result = await DeliveryCompletionService.generateOTP(taskId, customer_id);
    return res.status(result.success ? 200 : 400).json(result);
  } catch (error) {
    console.error('Error in /:taskId/otp/generate:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/delivery/:taskId/otp/verify
 * Verify OTP
 */
router.post('/:taskId/otp/verify', async (req, res) => {
  try {
    const { taskId } = req.params;
    const { otp } = req.body;

    if (!otp) {
      return res.status(400).json({ error: 'OTP required' });
    }

    const result = await DeliveryCompletionService.verifyOTP(otp, taskId);
    return res.status(result.valid ? 200 : 400).json(result);
  } catch (error) {
    console.error('Error in /:taskId/otp/verify:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/delivery/:taskId/reassign
 * Reassign delivery to new rider
 */
router.post('/:taskId/reassign', async (req, res) => {
  try {
    const { taskId } = req.params;
    const { reason } = req.body;

    if (!reason) {
      return res.status(400).json({ error: 'Reassignment reason required' });
    }

    const result = await DeliveryAssignmentService.reassignIfNeeded(taskId, reason);
    return res.status(result.success ? 200 : 400).json(result);
  } catch (error) {
    console.error('Error in /:taskId/reassign:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/delivery/tracking/start
 * Start tracking session
 */
router.post('/tracking/start', async (req, res) => {
  try {
    const { rider_id, delivery_task_id } = req.body;

    if (!rider_id || !delivery_task_id) {
      return res.status(400).json({ error: 'Missing rider_id or delivery_task_id' });
    }

    const result = await GpsTrackingService.startTrackingSession(
      rider_id,
      delivery_task_id
    );

    return res.status(result.success ? 200 : 400).json(result);
  } catch (error) {
    console.error('Error in /tracking/start:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * POST /api/delivery/tracking/stop
 * Stop tracking session
 */
router.post('/tracking/stop', async (req, res) => {
  try {
    const { rider_id, delivery_task_id } = req.body;

    if (!rider_id || !delivery_task_id) {
      return res.status(400).json({ error: 'Missing rider_id or delivery_task_id' });
    }

    const result = await GpsTrackingService.stopTrackingSession(
      rider_id,
      delivery_task_id
    );

    return res.status(result.success ? 200 : 400).json(result);
  } catch (error) {
    console.error('Error in /tracking/stop:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
