/**
 * GpsTrackingService (Backend)
 *
 * Manages real-time GPS tracking for delivery riders.
 * Handles location updates, ETA calculations, and customer notifications.
 *
 * Features:
 * - Real-time location streaming to Firestore
 * - Automatic arrival detection
 * - ETA recalculation based on current location
 * - Location history tracking
 * - Outlier detection and filtering
 * - Customer real-time notifications
 */

const admin = require('firebase-admin');
const db = admin.firestore();

const ARRIVAL_THRESHOLD_METERS = 50;
const LOCATION_OUTLIER_THRESHOLD = 0.05; // 50m max jump
const LOCATION_UPDATE_BATCH_SIZE = 10;

class GpsTrackingService {
  /**
   * Update rider's location in real-time
   *
   * @param {string} riderId - Rider ID
   * @param {number} latitude - Current latitude
   * @param {number} longitude - Current longitude
   * @param {number} accuracy - GPS accuracy in meters (optional)
   * @returns {Promise<Object>} - Update result
   */
  async updateRiderLocation(riderId, latitude, longitude, accuracy) {
    try {
      // Validate coordinates
      if (!this.isValidCoordinate(latitude, longitude)) {
        return {
          success: false,
          error: 'Invalid coordinates',
          code: 'INVALID_COORDINATES'
        };
      }

      // Get rider's current location for outlier detection
      const previousLocation = await this.getRiderCurrentLocation(riderId);

      // Check for outliers (impossible jumps)
      if (previousLocation && !this.isValidLocationUpdate(previousLocation, latitude, longitude)) {
        return {
          success: false,
          error: 'Location update rejected - impossible jump',
          code: 'LOCATION_OUTLIER',
          previous: previousLocation,
          current: { latitude, longitude }
        };
      }

      // Create location timestamp record
      const timestamp = admin.firestore.FieldValue.serverTimestamp();
      const locationId = `${riderId}-${Date.now()}`;

      // Store location in delivery_locations collection
      await db.collection('delivery_locations').doc(locationId).set({
        rider_id: riderId,
        latitude,
        longitude,
        accuracy: accuracy || 10,
        timestamp: timestamp,
        created_at: timestamp,
        is_current: true
      });

      // Update rider's current location doc
      await db.collection('rider_locations').doc(riderId).set({
        rider_id: riderId,
        latitude,
        longitude,
        accuracy: accuracy || 10,
        updated_at: timestamp,
        previous_location: previousLocation
      }, { merge: true });

      // Get rider's active delivery tasks
      const activeTasks = await this.getRiderActiveTasks(riderId);

      if (activeTasks.length > 0) {
        // Check for arrival at destination
        const arrivals = [];

        for (const task of activeTasks) {
          const distance = this.calculateDistance(
            latitude,
            longitude,
            task.delivery_address.latitude,
            task.delivery_address.longitude
          );

          if (distance <= (ARRIVAL_THRESHOLD_METERS / 1000)) {
            // Mark as arrived
            await this.markTaskArrived(task.id);
            arrivals.push(task);
          }
        }

        // Calculate new ETAs
        for (const task of activeTasks) {
          const eta = await this.calculateETA(
            latitude,
            longitude,
            task.delivery_address.latitude,
            task.delivery_address.longitude
          );

          await this.updateTaskETA(task.id, eta);
        }

        // Notify customers of arrival and updated ETA
        for (const arrival of arrivals) {
          await this.notifyCustomerArrival(arrival.customer_id, arrival.id);
        }
      }

      return {
        success: true,
        rider_id: riderId,
        location: { latitude, longitude },
        timestamp: new Date().toISOString(),
        active_tasks: activeTasks.length
      };
    } catch (error) {
      console.error('Error updating rider location:', error);
      return {
        success: false,
        error: error.message,
        retryable: true,
        code: 'LOCATION_UPDATE_ERROR'
      };
    }
  }

  /**
   * Get rider's current location
   *
   * @param {string} riderId - Rider ID
   * @returns {Promise<Object|null>} - Current location or null
   */
  async getRiderCurrentLocation(riderId) {
    try {
      const doc = await db.collection('rider_locations').doc(riderId).get();

      if (!doc.exists) {
        return null;
      }

      const data = doc.data();
      return {
        latitude: data.latitude,
        longitude: data.longitude,
        accuracy: data.accuracy,
        updated_at: data.updated_at
      };
    } catch (error) {
      console.error('Error getting rider current location:', error);
      return null;
    }
  }

  /**
   * Check if location update is valid (no impossible jumps)
   *
   * @param {Object} previousLocation - Previous location
   * @param {number} newLat - New latitude
   * @param {number} newLng - New longitude
   * @returns {boolean} - Is valid update
   */
  isValidLocationUpdate(previousLocation, newLat, newLng) {
    if (!previousLocation) return true;

    const distance = this.calculateDistance(
      previousLocation.latitude,
      previousLocation.longitude,
      newLat,
      newLng
    );

    // Max 5km distance in one update (reasonable for fast movement)
    return distance <= 5;
  }

  /**
   * Validate coordinate format
   *
   * @param {number} lat - Latitude
   * @param {number} lng - Longitude
   * @returns {boolean} - Is valid
   */
  isValidCoordinate(lat, lng) {
    return typeof lat === 'number' && typeof lng === 'number' &&
      lat >= -90 && lat <= 90 &&
      lng >= -180 && lng <= 180;
  }

  /**
   * Get rider's active delivery tasks
   *
   * @param {string} riderId - Rider ID
   * @returns {Promise<Array>} - Active delivery tasks
   */
  async getRiderActiveTasks(riderId) {
    try {
      const snapshot = await db.collection('delivery_tasks')
        .where('rider_id', '==', riderId)
        .where('status', 'in', ['assigned', 'in_progress'])
        .get();

      return snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
    } catch (error) {
      console.error('Error getting rider active tasks:', error);
      return [];
    }
  }

  /**
   * Mark delivery task as arrived
   *
   * @param {string} taskId - Task ID
   */
  async markTaskArrived(taskId) {
    try {
      await db.collection('delivery_tasks').doc(taskId).update({
        status: 'arrived',
        arrived_at: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (error) {
      console.error('Error marking task arrived:', error);
    }
  }

  /**
   * Update task ETA
   *
   * @param {string} taskId - Task ID
   * @param {number} etaMinutes - New ETA in minutes
   */
  async updateTaskETA(taskId, etaMinutes) {
    try {
      await db.collection('delivery_tasks').doc(taskId).update({
        current_eta_minutes: etaMinutes,
        estimated_arrival: new Date(Date.now() + etaMinutes * 60000).toISOString(),
        eta_updated_at: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (error) {
      console.error('Error updating task ETA:', error);
    }
  }

  /**
   * Calculate ETA from current location to destination
   *
   * @param {number} fromLat - Start latitude
   * @param {number} fromLng - Start longitude
   * @param {number} toLat - Destination latitude
   * @param {number} toLng - Destination longitude
   * @returns {Promise<number>} - ETA in minutes
   */
  async calculateETA(fromLat, fromLng, toLat, toLng) {
    try {
      const distanceKm = this.calculateDistance(fromLat, fromLng, toLat, toLng);

      // Simple formula: average delivery speed
      // In production, use Google Maps API
      const baseEta = Math.ceil(distanceKm * 1.5); // 1.5 min per km average

      return Math.min(baseEta, 60);
    } catch (error) {
      console.error('Error calculating ETA:', error);
      return 30;
    }
  }

  /**
   * Calculate distance between two points
   *
   * @param {number} lat1 - Start latitude
   * @param {number} lng1 - Start longitude
   * @param {number} lat2 - End latitude
   * @param {number} lng2 - End longitude
   * @returns {number} - Distance in km
   */
  calculateDistance(lat1, lng1, lat2, lng2) {
    const EARTH_RADIUS = 6371;
    const dLat = this.toRad(lat2 - lat1);
    const dLng = this.toRad(lng2 - lng1);

    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRad(lat1)) * Math.cos(this.toRad(lat2)) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return EARTH_RADIUS * c;
  }

  toRad(degrees) {
    return degrees * (Math.PI / 180);
  }

  /**
   * Notify customer of rider arrival
   *
   * @param {string} customerId - Customer ID
   * @param {string} taskId - Delivery task ID
   */
  async notifyCustomerArrival(customerId, taskId) {
    try {
      await db.collection('customer_notifications').add({
        customer_id: customerId,
        type: 'rider_arrived',
        delivery_task_id: taskId,
        message: 'Your delivery rider has arrived',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });
    } catch (error) {
      console.error('Error notifying customer arrival:', error);
    }
  }

  /**
   * Get location history for a rider
   *
   * @param {string} riderId - Rider ID
   * @param {number} hoursBack - Hours to look back (default 24)
   * @returns {Promise<Array>} - Location history
   */
  async getLocationHistory(riderId, hoursBack = 24) {
    try {
      const cutoffTime = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - hoursBack * 3600000)
      );

      const snapshot = await db.collection('delivery_locations')
        .where('rider_id', '==', riderId)
        .where('timestamp', '>=', cutoffTime)
        .orderBy('timestamp', 'asc')
        .get();

      return snapshot.docs.map(doc => {
        const data = doc.data();
        return {
          latitude: data.latitude,
          longitude: data.longitude,
          timestamp: data.timestamp.toDate().toISOString(),
          accuracy: data.accuracy
        };
      });
    } catch (error) {
      console.error('Error getting location history:', error);
      return [];
    }
  }

  /**
   * Get delivery tracking data for customer
   *
   * @param {string} orderId - Order ID
   * @returns {Promise<Object>} - Tracking data with rider location and ETA
   */
  async getDeliveryTracking(orderId) {
    try {
      // Get delivery task
      const taskSnapshot = await db.collection('delivery_tasks')
        .where('order_id', '==', orderId)
        .where('status', 'in', ['assigned', 'in_progress', 'arrived'])
        .limit(1)
        .get();

      if (taskSnapshot.empty) {
        return {
          success: false,
          error: 'Delivery task not found',
          code: 'TASK_NOT_FOUND'
        };
      }

      const task = taskSnapshot.docs[0].data();
      const taskId = taskSnapshot.docs[0].id;

      // Get rider's current location
      const riderLocation = await this.getRiderCurrentLocation(task.rider_id);

      if (!riderLocation) {
        return {
          success: false,
          error: 'Rider location not available',
          code: 'LOCATION_UNAVAILABLE'
        };
      }

      // Get recent location history (last 10 points)
      const locationHistory = await this.getLocationHistory(task.rider_id, 2);
      const recentHistory = locationHistory.slice(-10);

      // Calculate distance to delivery
      const distanceToDelivery = this.calculateDistance(
        riderLocation.latitude,
        riderLocation.longitude,
        task.delivery_address.latitude,
        task.delivery_address.longitude
      );

      return {
        success: true,
        order_id: orderId,
        delivery_task_id: taskId,
        status: task.status,
        rider: {
          name: task.rider_details.name,
          phone: task.rider_details.phone,
          vehicle: task.rider_details.vehicle
        },
        current_location: riderLocation,
        destination: task.delivery_address,
        distance_to_delivery_km: distanceToDelivery,
        eta_minutes: task.current_eta_minutes || task.eta_minutes,
        estimated_arrival: task.estimated_arrival,
        location_history: recentHistory,
        assignment_time: task.assigned_at,
        last_update: riderLocation.updated_at
      };
    } catch (error) {
      console.error('Error getting delivery tracking:', error);
      return {
        success: false,
        error: error.message,
        code: 'TRACKING_ERROR'
      };
    }
  }

  /**
   * Start background tracking for a rider
   * Creates a background task that streams location updates
   *
   * @param {string} riderId - Rider ID
   * @param {string} taskId - Delivery task ID
   */
  async startTrackingSession(riderId, taskId) {
    try {
      await db.collection('tracking_sessions').add({
        rider_id: riderId,
        delivery_task_id: taskId,
        status: 'active',
        started_at: admin.firestore.FieldValue.serverTimestamp(),
        last_ping: admin.firestore.FieldValue.serverTimestamp()
      });

      return {
        success: true,
        rider_id: riderId,
        task_id: taskId,
        message: 'Tracking session started'
      };
    } catch (error) {
      console.error('Error starting tracking session:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Stop tracking for a rider
   *
   * @param {string} riderId - Rider ID
   * @param {string} taskId - Delivery task ID
   */
  async stopTrackingSession(riderId, taskId) {
    try {
      const snapshot = await db.collection('tracking_sessions')
        .where('rider_id', '==', riderId)
        .where('delivery_task_id', '==', taskId)
        .where('status', '==', 'active')
        .get();

      for (const doc of snapshot.docs) {
        await doc.ref.update({
          status: 'completed',
          ended_at: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      return {
        success: true,
        rider_id: riderId,
        task_id: taskId
      };
    } catch (error) {
      console.error('Error stopping tracking session:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }
}

module.exports = new GpsTrackingService();
