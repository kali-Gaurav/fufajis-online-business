/**
 * ============================================================================
 * DeliveryDispatchService - Rider Assignment & Route Management
 * ============================================================================
 * Handles:
 * - Finding available riders near delivery location
 * - Assigning orders to riders with load balancing
 * - Generating delivery OTP for verification
 * - Route optimization (TSP)
 * - Real-time location tracking
 * - Delivery completion workflow
 *
 * CRITICAL: All assignments stored in PostgreSQL (source of truth)
 * Synced to Firestore for real-time UI updates
 * ============================================================================
 */

const pool = require('../db/pool');
const { v4: uuidv4 } = require('uuid');
const DeliveryOptimizationService = require('./DeliveryOptimizationService');

class DeliveryDispatchService {
  /**
   * Find available riders near delivery location
   * Considers: location proximity, current load, availability status
   */
  static async findAvailableRiders({
    latitude,
    longitude,
    maxDistanceKm = 2,
    maxLoadCapacity = 50,  // max items per rider
    excludeRiderIds = []
  }) {
    console.log(`[DeliveryDispatch] Finding riders near (${latitude}, ${longitude})`);

    // Use PostgreSQL PostGIS for location-based queries
    const query = `
      SELECT
        r.id, r.user_id, r.name, r.phone,
        r.current_latitude, r.current_longitude,
        r.current_load, r.load_capacity,
        r.status, r.total_deliveries, r.rating,
        -- Calculate distance using Haversine formula
        (6371 * acos(cos(radians($3)) * cos(radians(r.current_latitude)) *
          sin(radians($2) - radians(r.current_longitude)) +
          sin(radians($3)) * sin(radians(r.current_latitude)))) AS distance_km
      FROM riders r
      WHERE r.status = 'available'
        AND r.current_latitude IS NOT NULL
        AND r.current_longitude IS NOT NULL
        AND r.id != ALL($4)
        AND (6371 * acos(cos(radians($3)) * cos(radians(r.current_latitude)) *
          sin(radians($2) - radians(r.current_longitude)) +
          sin(radians($3)) * sin(radians(r.current_latitude)))) <= $1
        AND (r.load_capacity - r.current_load) > 0
      ORDER BY distance_km ASC, r.rating DESC
      LIMIT 10
    `;

    const result = await pool.query(query, [
      maxDistanceKm,
      longitude,
      latitude,
      excludeRiderIds || []
    ]);

    console.log(`[DeliveryDispatch] ✅ Found ${result.rows.length} available riders`);
    return result.rows;
  }

  /**
   * Assign order to rider with atomic transaction
   * CRITICAL: Must verify rider availability and generate OTP
   */
  static async assignOrderToRider({
    orderId,
    riderId,
    deliveryAddressLatitude,
    deliveryAddressLongitude,
    estimatedDeliveryTime = 30  // minutes
  }) {
    console.log(`[DeliveryDispatch] Assigning order ${orderId} to rider ${riderId}`);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Fetch order details
      const orderRes = await client.query(
        `SELECT id, customer_id, total_amount, items_count, delivery_address
         FROM orders WHERE id = $1`,
        [orderId]
      );

      if (orderRes.rows.length === 0) {
        throw new Error('ORDER_NOT_FOUND');
      }

      const order = orderRes.rows[0];

      // Verify rider exists and is available
      const riderRes = await client.query(
        `SELECT id, user_id, current_load, load_capacity, current_latitude, current_longitude
         FROM riders WHERE id = $1 FOR UPDATE`,
        [riderId]
      );

      if (riderRes.rows.length === 0) {
        throw new Error('RIDER_NOT_FOUND');
      }

      const rider = riderRes.rows[0];

      // Check rider has capacity
      if ((rider.current_load + order.items_count) > rider.load_capacity) {
        throw new Error('RIDER_OVERLOADED: Rider does not have capacity for this order');
      }

      // Generate delivery OTP (4-6 digits)
      const deliveryOtp = String(Math.floor(100000 + Math.random() * 900000)).substring(0, 6);

      // Create delivery tracking record
      const trackingId = uuidv4();
      const trackingRes = await client.query(
        `INSERT INTO delivery_tracking (
          id, order_id, rider_id, customer_id,
          current_status, current_latitude, current_longitude,
          delivery_otp, otp_verified,
          estimated_delivery, distance_remaining_km, eta_minutes,
          is_delayed, delay_reason,
          assigned_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14,
          CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        RETURNING *`,
        [
          trackingId, orderId, riderId, order.customer_id,
          'assigned', rider.current_latitude, rider.current_longitude,
          deliveryOtp, false,
          CURRENT_TIMESTAMP + INTERVAL '1 minute' * $1,
          null, estimatedDeliveryTime,
          false, null
        ]
      );

      const tracking = trackingRes.rows[0];

      // Update order with delivery info
      await client.query(
        `UPDATE orders
         SET delivery_agent_id = $2,
             delivery_status = 'assigned',
             otp = $3,
             estimated_delivery = CURRENT_TIMESTAMP + INTERVAL '1 minute' * $4,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $1`,
        [orderId, riderId, deliveryOtp, estimatedDeliveryTime]
      );

      // Update rider current load
      await client.query(
        `UPDATE riders
         SET current_load = current_load + $2,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $1`,
        [riderId, order.items_count]
      );

      // Create audit log
      await client.query(
        `INSERT INTO delivery_assignments_log (
          id, order_id, rider_id, action,
          details, created_at
        ) VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)`,
        [
          uuidv4(), orderId, riderId, 'assigned',
          JSON.stringify({
            estimatedDeliveryTime,
            deliveryAddress: order.delivery_address
          })
        ]
      );

      await client.query('COMMIT');
      console.log(`[DeliveryDispatch] ✅ Order assigned: ${orderId} → ${riderId}`);

      return {
        trackingId,
        orderId,
        riderId,
        deliveryOtp,
        estimatedDeliveryTime,
        status: 'assigned'
      };
    } catch (err) {
      await client.query('ROLLBACK');
      console.error(`[DeliveryDispatch] ❌ Assignment failed:`, err.message);
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Unassign order from rider (e.g., rider cancelled, reassigning)
   */
  static async unassignOrderFromRider(orderId) {
    console.log(`[DeliveryDispatch] Unassigning order ${orderId}`);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Get current tracking info
      const trackingRes = await client.query(
        `SELECT id, rider_id, order_id FROM delivery_tracking
         WHERE order_id = $1 AND current_status IN ('assigned', 'picked_up')`,
        [orderId]
      );

      if (trackingRes.rows.length === 0) {
        throw new Error('TRACKING_NOT_FOUND');
      }

      const tracking = trackingRes.rows[0];

      // Get order items count to update rider load
      const orderRes = await client.query(
        `SELECT items_count FROM orders WHERE id = $1`,
        [orderId]
      );

      const order = orderRes.rows[0];

      // Update tracking
      await client.query(
        `UPDATE delivery_tracking
         SET current_status = 'unassigned', updated_at = CURRENT_TIMESTAMP
         WHERE id = $1`,
        [tracking.id]
      );

      // Update order
      await client.query(
        `UPDATE orders
         SET delivery_agent_id = NULL, delivery_status = 'pending_assignment',
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $1`,
        [orderId]
      );

      // Reduce rider load
      await client.query(
        `UPDATE riders
         SET current_load = GREATEST(0, current_load - $2),
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $1`,
        [tracking.rider_id, order.items_count]
      );

      // Log
      await client.query(
        `INSERT INTO delivery_assignments_log (
          id, order_id, rider_id, action, created_at
        ) VALUES ($1, $2, $3, 'unassigned', CURRENT_TIMESTAMP)`,
        [uuidv4(), orderId, tracking.rider_id]
      );

      await client.query('COMMIT');
      console.log(`[DeliveryDispatch] ✅ Order unassigned: ${orderId}`);

      return { success: true, orderId };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Optimize delivery route for rider
   * Returns ordered list of stops for most efficient delivery
   */
  static async optimizeRiderRoute(riderId) {
    console.log(`[DeliveryDispatch] Optimizing route for rider ${riderId}`);

    // Get rider's current location
    const riderRes = await pool.query(
      `SELECT current_latitude, current_longitude FROM riders WHERE id = $1`,
      [riderId]
    );

    if (riderRes.rows.length === 0) {
      throw new Error('RIDER_NOT_FOUND');
    }

    const rider = riderRes.rows[0];

    // Get all assigned/picked-up orders for this rider
    const ordersRes = await pool.query(
      `SELECT o.id, o.delivery_address, da.latitude, da.longitude
       FROM orders o
       JOIN delivery_tracking dt ON o.id = dt.order_id
       LEFT JOIN delivery_addresses da ON da.address = o.delivery_address
       WHERE dt.rider_id = $1 AND dt.current_status IN ('assigned', 'picked_up')
       ORDER BY o.created_at ASC`,
      [riderId]
    );

    const stops = ordersRes.rows.map(order => ({
      id: order.id,
      lat: order.latitude,
      lng: order.longitude,
      address: order.delivery_address
    }));

    if (stops.length === 0) {
      return { orderedStops: [], totalDistanceKm: 0 };
    }

    // Optimize route using DeliveryOptimizationService
    const startLocation = {
      lat: rider.current_latitude,
      lng: rider.current_longitude
    };

    const optimized = DeliveryOptimizationService.optimizeRoute(startLocation, stops);

    console.log(`[DeliveryDispatch] ✅ Route optimized: ${stops.length} stops, ${optimized.totalDistanceKm}km`);

    return {
      orderedStops: optimized.orderedStops,
      totalDistanceKm: optimized.totalDistanceKm
    };
  }

  /**
   * Update delivery tracking with current location
   * Called by rider app every 10 seconds during delivery
   */
  static async updateDeliveryLocation({
    trackingId,
    latitude,
    longitude,
    accuracy = null
  }) {
    // Get delivery details for ETA calculation
    const trackingRes = await pool.query(
      `SELECT order_id, rider_id, delivery_otp, otp_verified
       FROM delivery_tracking WHERE id = $1`,
      [trackingId]
    );

    if (trackingRes.rows.length === 0) {
      throw new Error('TRACKING_NOT_FOUND');
    }

    const tracking = trackingRes.rows[0];

    // Update location
    await pool.query(
      `UPDATE delivery_tracking
       SET current_latitude = $2, current_longitude = $3,
           location_accuracy = $4, updated_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [trackingId, latitude, longitude, accuracy]
    );

    // Could calculate ETA here using Google Maps or similar
    // For now, just return success

    return { success: true, trackingId };
  }

  /**
   * Verify delivery OTP and mark as verified
   * Called when rider arrives at customer location
   */
  static async verifyDeliveryOtp(trackingId, otpProvided) {
    console.log(`[DeliveryDispatch] Verifying OTP for tracking ${trackingId}`);

    const trackingRes = await pool.query(
      `SELECT id, order_id, delivery_otp, otp_verified
       FROM delivery_tracking WHERE id = $1`,
      [trackingId]
    );

    if (trackingRes.rows.length === 0) {
      throw new Error('TRACKING_NOT_FOUND');
    }

    const tracking = trackingRes.rows[0];

    if (tracking.otp_verified) {
      throw new Error('OTP_ALREADY_VERIFIED');
    }

    if (tracking.delivery_otp !== otpProvided) {
      throw new Error('INVALID_OTP: OTP does not match');
    }

    // Mark as verified
    const updateRes = await pool.query(
      `UPDATE delivery_tracking
       SET otp_verified = true, verified_at = CURRENT_TIMESTAMP,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $1
       RETURNING *`,
      [trackingId]
    );

    console.log(`[DeliveryDispatch] ✅ OTP verified: ${trackingId}`);

    return updateRes.rows[0];
  }

  /**
   * Complete delivery (rider scanned items or photo proof)
   */
  static async completeDelivery({
    trackingId,
    proofPhotoUrl = null,
    itemsDelivered = null,
    signatureUrl = null,
    notes = ''
  }) {
    console.log(`[DeliveryDispatch] Completing delivery: ${trackingId}`);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Get tracking info
      const trackingRes = await client.query(
        `SELECT order_id, rider_id, otp_verified
         FROM delivery_tracking WHERE id = $1`,
        [trackingId]
      );

      if (trackingRes.rows.length === 0) {
        throw new Error('TRACKING_NOT_FOUND');
      }

      const tracking = trackingRes.rows[0];

      if (!tracking.otp_verified) {
        throw new Error('OTP_NOT_VERIFIED: Cannot complete delivery without OTP verification');
      }

      // Update tracking as delivered
      await client.query(
        `UPDATE delivery_tracking
         SET current_status = 'delivered',
             proof_photo_url = $2, signature_url = $3, notes = $4,
             delivered_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
         WHERE id = $1`,
        [trackingId, proofPhotoUrl, signatureUrl, notes]
      );

      // Update order as delivered
      await client.query(
        `UPDATE orders
         SET delivery_status = 'delivered',
             delivered_at = CURRENT_TIMESTAMP,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $1`,
        [tracking.order_id]
      );

      // Update rider stats
      await client.query(
        `UPDATE riders
         SET total_deliveries = total_deliveries + 1,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $1`,
        [tracking.rider_id]
      );

      // Log completion
      await client.query(
        `INSERT INTO delivery_assignments_log (
          id, order_id, rider_id, action, created_at
        ) VALUES ($1, $2, $3, 'delivered', CURRENT_TIMESTAMP)`,
        [uuidv4(), tracking.order_id, tracking.rider_id]
      );

      await client.query('COMMIT');
      console.log(`[DeliveryDispatch] ✅ Delivery completed: ${tracking.order_id}`);

      return { success: true, orderId: tracking.order_id };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Get delivery tracking info for customer
   */
  static async getDeliveryTracking(orderId, customerId) {
    const trackingRes = await pool.query(
      `SELECT dt.*, r.name as rider_name, r.phone as rider_phone, r.rating
       FROM delivery_tracking dt
       JOIN riders r ON dt.rider_id = r.id
       WHERE dt.order_id = $1 AND dt.customer_id = $2`,
      [orderId, customerId]
    );

    if (trackingRes.rows.length === 0) {
      throw new Error('TRACKING_NOT_FOUND');
    }

    return trackingRes.rows[0];
  }
}

module.exports = DeliveryDispatchService;
