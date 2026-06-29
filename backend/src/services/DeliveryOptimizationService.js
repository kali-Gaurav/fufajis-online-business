const firebaseAdmin = require('./firebaseAdmin');

class DeliveryOptimizationService {
  /**
   * Calculates Haversine distance in kilometers between two coordinates
   */
  haversineDistance(lat1, lng1, lat2, lng2) {
    const R = 6371; // Earth radius in km
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLng = ((lng2 - lng1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  /**
   * Solves the Traveling Salesman Problem (TSP) using Nearest Neighbor with 2-opt optimization.
   * @param {Object} startLoc { lat, lng }
   * @param {Array} stops Array of { id, lat, lng }
   * @returns {Object} { orderedStops, totalDistanceKm }
   */
  optimizeRoute(startLoc, stops) {
    if (!stops || stops.length === 0) {
      return { orderedStops: [], totalDistanceKm: 0 };
    }

    // Filter out stops without coordinates
    const validStops = stops.filter(s => s.lat !== null && s.lng !== null && s.lat !== undefined && s.lng !== undefined);
    const invalidStops = stops.filter(s => s.lat === null || s.lng === null || s.lat === undefined || s.lng === undefined);

    if (validStops.length === 0) {
      return { orderedStops: invalidStops, totalDistanceKm: 0 };
    }

    // Step 1: Nearest Neighbor Heuristic
    const unvisited = [...validStops];
    const orderedStops = [];
    let currentLoc = startLoc;
    let totalDistanceKm = 0;

    while (unvisited.length > 0) {
      let nearestIndex = 0;
      let minDistance = Infinity;

      for (let i = 0; i < unvisited.length; i++) {
        const dist = this.haversineDistance(currentLoc.lat, currentLoc.lng, unvisited[i].lat, unvisited[i].lng);
        if (dist < minDistance) {
          minDistance = dist;
          nearestIndex = i;
        }
      }

      const nextStop = unvisited.splice(nearestIndex, 1)[0];
      orderedStops.push(nextStop);
      totalDistanceKm += minDistance;
      currentLoc = nextStop;
    }

    // Step 2: 2-Opt Optimization for paths with more than 3 nodes
    let improved = true;
    while (improved && orderedStops.length > 3) {
      improved = false;
      for (let i = 0; i < orderedStops.length - 1; i++) {
        for (let j = i + 2; j < orderedStops.length; j++) {
          const p1 = i === 0 ? startLoc : orderedStops[i - 1];
          const p2 = orderedStops[i];
          const p3 = orderedStops[j];
          const p4 = j === orderedStops.length - 1 ? null : orderedStops[j + 1];

          const currentDist = this.haversineDistance(p1.lat, p1.lng, p2.lat, p2.lng) +
            (p4 ? this.haversineDistance(p3.lat, p3.lng, p4.lat, p4.lng) : 0);

          const newDist = this.haversineDistance(p1.lat, p1.lng, p3.lat, p3.lng) +
            (p4 ? this.haversineDistance(p2.lat, p2.lng, p4.lat, p4.lng) : 0);

          if (newDist < currentDist) {
            this.reverseSegment(orderedStops, i, j);
            totalDistanceKm = totalDistanceKm - currentDist + newDist;
            improved = true;
          }
        }
      }
    }

    return {
      orderedStops: [...orderedStops, ...invalidStops],
      totalDistanceKm
    };
  }

  reverseSegment(arr, start, end) {
    while (start < end) {
      const temp = arr[start];
      arr[start] = arr[end];
      arr[end] = temp;
      start++;
      end--;
    }
  }

  /**
   * Re-optimize an active route when a new order is dynamically added/changed.
   * @param {Object} riderLoc Current rider coordinates { lat, lng }
   * @param {Array} currentStops Remaining stops in current route
   * @param {Array} newStops New stops to insert/merge
   */
  reoptimizeRoute(riderLoc, currentStops = [], newStops = []) {
    const combinedStops = [...currentStops, ...newStops];
    return this.optimizeRoute(riderLoc, combinedStops);
  }

  /**
   * Calculates dynamic batch priority score for orders
   * Score = (distance * 0.4) + (orderAgeMinutes * 0.3) + (slaPenalty * 0.3) - (weightPenalty * 0.1)
   */
  calculatePriorityScore(order, storeLoc) {
    const distance = (order.lat !== null && order.lng !== null) 
      ? this.haversineDistance(storeLoc.lat, storeLoc.lng, order.lat, order.lng)
      : 5.0; // Fallback distance

    const orderAgeMinutes = order.createdAt 
      ? Math.max(0, Math.round((Date.now() - new Date(order.createdAt).getTime()) / 60000))
      : 0;

    const promisedTime = order.promisedDeliveryTime ? new Date(order.promisedDeliveryTime).getTime() : Date.now() + 45 * 60000;
    const minutesToSLA = Math.round((promisedTime - Date.now()) / 60000);
    const slaPenalty = minutesToSLA < 15 ? Math.max(0, 30 - minutesToSLA) * 2 : 0;

    const weightKg = order.weight || 0;
    const weightPenalty = weightKg > 15 ? (weightKg - 15) * 0.5 : 0;

    return (distance * 4.0) + (orderAgeMinutes * 3.0) + (slaPenalty * 3.0) - weightPenalty;
  }

  /**
   * Clusters orders based on geographic proximity & Batch Priority Score
   */
  clusterOrders(orders, maxRadiusKm = 2.0, storeLoc = { lat: 28.6139, lng: 77.2090 }) {
    // Inject Batch Priority Score into each order
    const scoredOrders = orders.map(o => ({
      ...o,
      priorityScore: this.calculatePriorityScore(o, storeLoc)
    }));

    // Sort by priority score descending to process highest priority orders first
    scoredOrders.sort((a, b) => b.priorityScore - a.priorityScore);

    const withLoc = scoredOrders.filter(o => o.lat !== null && o.lng !== null && o.lat !== undefined && o.lng !== undefined);
    const withoutLoc = scoredOrders.filter(o => o.lat === null || o.lng === null || o.lat === undefined || o.lng === undefined);

    const clusters = [];
    const visited = new Set();

    for (let i = 0; i < withLoc.length; i++) {
      if (visited.has(withLoc[i].id)) continue;

      const cluster = [withLoc[i]];
      visited.add(withLoc[i].id);

      for (let j = i + 1; j < withLoc.length; j++) {
        if (visited.has(withLoc[j].id)) continue;

        const centroid = this.calculateCentroid(cluster);
        const dist = this.haversineDistance(centroid.lat, centroid.lng, withLoc[j].lat, withLoc[j].lng);

        if (dist <= maxRadiusKm) {
          cluster.push(withLoc[j]);
          visited.add(withLoc[j].id);
        }
      }
      clusters.push(cluster);
    }

    for (const order of withoutLoc) {
      clusters.push([order]);
    }

    return clusters;
  }

  calculateCentroid(points) {
    let latSum = 0;
    let lngSum = 0;
    for (const p of points) {
      latSum += p.lat;
      lngSum += p.lng;
    }
    return {
      lat: latSum / points.length,
      lng: lngSum / points.length
    };
  }

  /**
   * Predicts delivery time in minutes based on distance, traffic/weather factors, and stops
   */
  predictDeliveryTime(distanceKm, numStops, options = {}) {
    const {
      trafficLevel = 'medium',
      weatherCondition = 'clear',
      packingDelayMinutes = 5
    } = options;

    const avgSpeedKmH = 20; // Avg rider speed
    const baseTravelTimeMin = (distanceKm / avgSpeedKmH) * 60;
    const serviceTimePerStopMin = 8; // Time to hand over order, park, etc.

    let trafficMultiplier = 1.0;
    if (trafficLevel === 'low') trafficMultiplier = 0.8;
    if (trafficLevel === 'high') trafficMultiplier = 1.5;

    let weatherMultiplier = 1.0;
    if (weatherCondition === 'rainy') weatherMultiplier = 1.3;
    if (weatherCondition === 'stormy') weatherMultiplier = 1.6;

    const travelTimeCalculated = baseTravelTimeMin * trafficMultiplier * weatherMultiplier;
    const totalServiceTime = numStops * serviceTimePerStopMin;

    return Math.round(travelTimeCalculated + totalServiceTime + packingDelayMinutes);
  }

  /**
   * Rider assignment using a multi-factor score
   * Score = 40% Proximity + 30% Load Capacity + 20% Completion Rate + 10% Acceptance Rate
   */
  findBestRider(startLoc, riders, totalWeightKg = 0, totalVolumeLiters = 0) {
    const availableRiders = riders.filter(r => 
      r.status === 'active' && 
      (!r.maxWeightKg || r.maxWeightKg >= totalWeightKg) &&
      (!r.maxVolumeLiters || r.maxVolumeLiters >= totalVolumeLiters)
    );

    if (availableRiders.length === 0) return null;

    let bestRider = null;
    let maxScore = -Infinity;

    for (const rider of availableRiders) {
      if (rider.lat === null || rider.lng === null || rider.lat === undefined || rider.lng === undefined) continue;

      // 1) Proximity score (closer is better, max range 10km)
      const dist = this.haversineDistance(startLoc.lat, startLoc.lng, rider.lat, rider.lng);
      const proximityScore = Math.max(0, 10 - dist) * 10; // scale to 100

      // 2) Load capacity score (free capacity ratio)
      const activeWeight = rider.currentWeightKg || 0;
      const capacityMargin = rider.maxWeightKg ? (1 - (activeWeight / rider.maxWeightKg)) * 100 : 100;

      // 3) Performance rates (default to 90% if not specified)
      const completionRate = (rider.completionRate !== undefined) ? rider.completionRate * 100 : 90;
      const acceptanceRate = (rider.acceptanceRate !== undefined) ? rider.acceptanceRate * 100 : 90;

      // Combined assignment score
      const score = (proximityScore * 0.4) + (capacityMargin * 0.3) + (completionRate * 0.2) + (acceptanceRate * 0.1);

      if (score > maxScore) {
        maxScore = score;
        bestRider = { ...rider, assignmentScore: score, distanceToStartKm: dist };
      }
    }

    return bestRider || availableRiders[0];
  }

  /**
   * Exception engine - logs, marks and outputs tracking updates for exceptional states
   */
  handleDeliveryException(orderId, exceptionType, details = {}) {
    const validExceptions = ['NO_RESPONSE', 'ADDRESS_ISSUE', 'PAYMENT_FAILURE', 'RIDER_ISSUE'];
    if (!validExceptions.includes(exceptionType)) {
      throw new Error(`Invalid delivery exception code: ${exceptionType}`);
    }

    const logEntry = {
      orderId,
      exceptionType,
      details,
      timestamp: Date.now(),
      status: 'EXCEPTION_PENDING'
    };

    console.warn(`[DeliveryException] Exception recorded for order ${orderId}: ${exceptionType}`, details);

    // Sync exception update to Firebase RTDB
    this.updateRealTimeTracking(orderId, {
      status: 'EXCEPTION',
      exception: logEntry
    });

    return logEntry;
  }

  /**
   * Cost Optimization Engine metrics
   */
  calculateCostMetrics(routeDistanceKm, numStops, riderPayloadKg) {
    const fuelRatePerKm = 3.5; // Rs per km
    const stopHandlingIncentive = 15; // Rs per stop
    const baseRiderPay = 40; // Rs flat base pay

    const travelCost = routeDistanceKm * fuelRatePerKm;
    const handlingCost = numStops * stopHandlingIncentive;
    const weightSurcharge = riderPayloadKg > 15 ? (riderPayloadKg - 15) * 2 : 0;

    const totalDeliveryCost = baseRiderPay + travelCost + handlingCost + weightSurcharge;
    const costPerOrder = numStops > 0 ? totalDeliveryCost / numStops : totalDeliveryCost;

    return {
      routeDistanceKm,
      numStops,
      estimatedFuelCost: travelCost,
      estimatedHandlingCost: handlingCost,
      weightSurcharge,
      totalDeliveryCost,
      costPerOrder,
      riderUtilizationRate: Math.min(1.0, (riderPayloadKg / 25)) // Scaled to max standard moto cargo payload
    };
  }

  /**
   * Hardened Firebase Realtime DB schema update for tracking
   */
  async updateRealTimeTracking(orderId, trackingData) {
    try {
      const rdb = firebaseAdmin.admin.database();
      
      // Structure conforming to specification:
      // delivery_tracking/${orderId}
      const trackingRef = rdb.ref(`delivery_tracking/${orderId}`);
      await trackingRef.update({
        ...trackingData,
        updatedAt: Date.now()
      });
      return true;
    } catch (err) {
      console.warn('[DeliveryOptimization] Firebase RTDB track update error:', err.message);
      return false;
    }
  }

  /**
   * Hardened Firebase Realtime DB schema update for active riders
   */
  async updateActiveRiderState(riderId, stateData) {
    try {
      const rdb = firebaseAdmin.admin.database();
      // active_riders/${riderId}
      const riderRef = rdb.ref(`active_riders/${riderId}`);
      await riderRef.update({
        ...stateData,
        updatedAt: Date.now()
      });
      return true;
    } catch (err) {
      console.warn('[DeliveryOptimization] Firebase RTDB rider update error:', err.message);
      return false;
    }
  }
}

module.exports = new DeliveryOptimizationService();
