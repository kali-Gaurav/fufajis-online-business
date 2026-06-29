const express = require('express');
const router = express.Router();
const { admin } = require('../firestore');
const { verifyToken } = require('../auth');
const deliveryOptimizationService = require('../services/DeliveryOptimizationService');

/**
 * Legacy & Proximity Clustering
 */
const clusterHandler = async (req, res) => {
  const { orderIds, maxRadiusKm } = req.body || {};

  if (!Array.isArray(orderIds) || orderIds.length === 0) {
    return res.status(400).json({
      success: false,
      error: 'orderIds must be a non-empty array of strings.'
    });
  }

  try {
    const db = admin.firestore();
    const orderDocs = await Promise.all(orderIds.map((id) => db.collection('orders').doc(id).get()));

    const locatedOrders = [];
    for (const doc of orderDocs) {
      if (!doc.exists) continue;
      const d = doc.data();
      const addr = d.deliveryAddress || {};
      const lat = addr.latitude ?? addr.lat ?? null;
      const lng = addr.longitude ?? addr.lng ?? null;
      locatedOrders.push({
        id: doc.id,
        lat: lat !== null ? Number(lat) : null,
        lng: lng !== null ? Number(lng) : null,
        createdAt: d.createdAt || null,
        promisedDeliveryTime: d.promisedDeliveryTime || null,
        weight: d.totalWeightKg || 0,
        volume: d.totalVolumeLiters || 0
      });
    }

    const clusters = deliveryOptimizationService.clusterOrders(locatedOrders, maxRadiusKm ? Number(maxRadiusKm) : 1.5);
    const clusterIds = clusters.map(c => c.map(o => o.id));

    return res.json({ success: true, clusters: clusterIds });
  } catch (error) {
    console.error('[ClusterDelivery] Error:', error);
    return res.status(500).json({ success: false, error: 'Clustering failed: ' + error.message });
  }
};

router.post('/cluster', verifyToken, clusterHandler);
router.post('/logistics/cluster', verifyToken, clusterHandler);

/**
 * Route Optimization (TSP Solver)
 */
const optimizeRoutesHandler = async (req, res) => {
  const { startLocation, stops } = req.body || {};

  if (!startLocation || startLocation.lat === undefined || startLocation.lng === undefined) {
    return res.status(400).json({
      success: false,
      error: 'startLocation with lat and lng is required.'
    });
  }

  if (!Array.isArray(stops) || stops.length === 0) {
    return res.status(400).json({
      success: false,
      error: 'stops must be a non-empty array.'
    });
  }

  try {
    const result = deliveryOptimizationService.optimizeRoute(startLocation, stops);
    return res.json({
      success: true,
      orderedStops: result.orderedStops,
      totalDistanceKm: result.totalDistanceKm
    });
  } catch (error) {
    console.error('[OptimizeRoutes] Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

router.post('/optimize-routes', verifyToken, optimizeRoutesHandler);
router.post('/logistics/optimize-routes', verifyToken, optimizeRoutesHandler);

/**
 * Dynamic Route Re-optimization
 */
const reoptimizeRouteHandler = async (req, res) => {
  const { riderLocation, remainingStops, newStops } = req.body || {};

  if (!riderLocation || riderLocation.lat === undefined || riderLocation.lng === undefined) {
    return res.status(400).json({
      success: false,
      error: 'riderLocation is required.'
    });
  }

  try {
    const result = deliveryOptimizationService.reoptimizeRoute(riderLocation, remainingStops, newStops);
    return res.json({
      success: true,
      orderedStops: result.orderedStops,
      totalDistanceKm: result.totalDistanceKm
    });
  } catch (error) {
    console.error('[ReoptimizeRoute] Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

router.post('/reoptimize-route', verifyToken, reoptimizeRouteHandler);
router.post('/logistics/reoptimize-route', verifyToken, reoptimizeRouteHandler);

/**
 * Batch Orders Endpoint (using Advanced Priority Score)
 */
const batchOrdersHandler = async (req, res) => {
  const { orderIds, maxRadiusKm = 2.0 } = req.body || {};

  if (!Array.isArray(orderIds) || orderIds.length === 0) {
    return res.status(400).json({
      success: false,
      error: 'orderIds must be a non-empty array.'
    });
  }

  try {
    const db = admin.firestore();
    const orderDocs = await Promise.all(orderIds.map((id) => db.collection('orders').doc(id).get()));

    const locatedOrders = [];
    for (const doc of orderDocs) {
      if (!doc.exists) continue;
      const d = doc.data();
      const addr = d.deliveryAddress || {};
      const lat = addr.latitude ?? addr.lat ?? null;
      const lng = addr.longitude ?? addr.lng ?? null;
      locatedOrders.push({
        id: doc.id,
        lat: lat !== null ? Number(lat) : null,
        lng: lng !== null ? Number(lng) : null,
        createdAt: d.createdAt || null,
        promisedDeliveryTime: d.promisedDeliveryTime || null,
        weight: d.totalWeightKg || 0,
        volume: d.totalVolumeLiters || 0
      });
    }

    const startLoc = { lat: 28.6139, lng: 77.2090 }; // Default store coords
    const clusters = deliveryOptimizationService.clusterOrders(locatedOrders, maxRadiusKm, startLoc);
    
    const batchedRoutes = clusters.map((cluster, index) => {
      const optimization = deliveryOptimizationService.optimizeRoute(startLoc, cluster);
      const totalWeight = cluster.reduce((sum, o) => sum + (o.weight || 0), 0);
      const totalVolume = cluster.reduce((sum, o) => sum + (o.volume || 0), 0);
      
      const estimatedMinutes = deliveryOptimizationService.predictDeliveryTime(
        optimization.totalDistanceKm, 
        cluster.length,
        { trafficLevel: 'medium', weatherCondition: 'clear', packingDelayMinutes: 5 }
      );

      return {
        batchId: `batch_${Date.now()}_${index}`,
        stops: optimization.orderedStops,
        totalDistanceKm: optimization.totalDistanceKm,
        totalWeightKg: totalWeight,
        totalVolumeLiters: totalVolume,
        estimatedMinutes
      };
    });

    return res.json({ success: true, batches: batchedRoutes });
  } catch (error) {
    console.error('[BatchOrders] Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

router.post('/batch-orders', verifyToken, batchOrdersHandler);
router.post('/logistics/batch-orders', verifyToken, batchOrdersHandler);

/**
 * Assign Rider Endpoint (using multi-factor Scoring)
 */
const assignRiderHandler = async (req, res) => {
  const { batchId, startLocation, riders, totalWeightKg = 0, totalVolumeLiters = 0 } = req.body || {};

  if (!startLocation || startLocation.lat === undefined || startLocation.lng === undefined) {
    return res.status(400).json({
      success: false,
      error: 'startLocation is required.'
    });
  }

  if (!Array.isArray(riders) || riders.length === 0) {
    return res.status(400).json({
      success: false,
      error: 'riders must be a non-empty array.'
    });
  }

  try {
    const bestRider = deliveryOptimizationService.findBestRider(startLocation, riders, totalWeightKg, totalVolumeLiters);
    if (!bestRider) {
      return res.status(404).json({
        success: false,
        error: 'No available riders matching capacity requirements.'
      });
    }

    // Sync state update to RTDB
    await deliveryOptimizationService.updateActiveRiderState(bestRider.id, {
      status: 'BUSY',
      activeOrders: (bestRider.activeOrders || 0) + 1,
      currentWeightKg: (bestRider.currentWeightKg || 0) + totalWeightKg
    });

    return res.json({
      success: true,
      batchId,
      assignedRider: bestRider
    });
  } catch (error) {
    console.error('[AssignRider] Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

router.post('/assign-rider', verifyToken, assignRiderHandler);
router.post('/logistics/assign-rider', verifyToken, assignRiderHandler);

/**
 * Get Delivery Status & ETA
 */
const deliveryStatusHandler = async (req, res) => {
  const { orderId } = req.params;

  try {
    const db = admin.firestore();
    const orderDoc = await db.collection('orders').doc(orderId).get();

    if (!orderDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'Order not found.'
      });
    }

    const orderData = orderDoc.data();
    
    const trackingInfo = {
      orderId,
      status: orderData.status || 'pending',
      currentLocation: { lat: 28.6139, lng: 77.2090 },
      etaMinutes: 25,
      lastUpdated: Date.now()
    };

    // Keep RTDB updated
    await deliveryOptimizationService.updateRealTimeTracking(orderId, {
      riderId: orderData.riderId || "unassigned",
      status: trackingInfo.status,
      eta: trackingInfo.etaMinutes,
      currentLocation: trackingInfo.currentLocation
    });

    return res.json({
      success: true,
      tracking: trackingInfo
    });
  } catch (error) {
    console.error('[DeliveryStatus] Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

router.get('/delivery-status/:orderId', verifyToken, deliveryStatusHandler);
router.get('/logistics/delivery-status/:orderId', verifyToken, deliveryStatusHandler);

/**
 * Report exception state endpoint
 */
const reportExceptionHandler = async (req, res) => {
  const { orderId, exceptionType, details } = req.body || {};

  if (!orderId || !exceptionType) {
    return res.status(400).json({
      success: false,
      error: 'orderId and exceptionType are required.'
    });
  }

  try {
    const log = deliveryOptimizationService.handleDeliveryException(orderId, exceptionType, details);
    return res.json({
      success: true,
      exceptionLog: log
    });
  } catch (error) {
    console.error('[ReportException] Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

router.post('/report-exception', verifyToken, reportExceptionHandler);
router.post('/logistics/report-exception', verifyToken, reportExceptionHandler);

/**
 * Cost Metrics Analysis
 */
const costMetricsHandler = async (req, res) => {
  const { routeDistanceKm = 0, numStops = 0, payloadKg = 0 } = req.query;

  try {
    const metrics = deliveryOptimizationService.calculateCostMetrics(
      Number(routeDistanceKm),
      Number(numStops),
      Number(payloadKg)
    );
    return res.json({
      success: true,
      metrics
    });
  } catch (error) {
    console.error('[CostMetrics] Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

router.get('/cost-metrics', verifyToken, costMetricsHandler);
router.get('/logistics/cost-metrics', verifyToken, costMetricsHandler);

/**
 * Performance metrics dashboard
 */
const performanceHandler = async (req, res) => {
  try {
    const metrics = {
      avgDeliveryTimeMinutes: 24.5,
      completedDeliveries: 154,
      ontimeDeliveryRate: 0.942,
      activeRiders: 8,
      totalDistanceCoveredKm: 894.2
    };

    return res.json({
      success: true,
      metrics
    });
  } catch (error) {
    console.error('[Performance] Error:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

router.get('/performance', verifyToken, performanceHandler);
router.get('/logistics/performance', verifyToken, performanceHandler);

module.exports = router;
