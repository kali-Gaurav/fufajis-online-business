/**
 * DeliveryAssignmentService
 *
 * Core service for assigning orders to the nearest available riders.
 * Implements nearest-neighbor algorithm with capacity checks and ETA calculation.
 *
 * Features:
 * - Find available riders within 5km
 * - Respect capacity limits (max 5 orders per trip)
 * - Calculate ETA per rider
 * - Assign to lowest ETA
 * - Batch assignment support (100+ orders)
 * - Reassignment if rider cancels/fails
 */

const admin = require('firebase-admin');
const db = admin.firestore();

const DELIVERY_EARTH_RADIUS = 6371; // km
const MAX_DELIVERY_DISTANCE = 5; // km
const MAX_ORDERS_PER_RIDER = 5;
const ETA_BUFFER_MINUTES = 5; // Add buffer to ETA for safety

class DeliveryAssignmentService {
  /**
   * Assign an order to the nearest available rider
   *
   * @param {Object} orderData - Order with delivery details
   * @param {string} orderId - Order document ID
   * @param {string} customerId - Customer ID
   * @param {Object} deliveryAddress - Address with lat/lng
   * @returns {Promise<Object>} - Assignment result
   */
  async assignOrderToRider(orderId, customerId, deliveryAddress) {
    try {
      // Validate input
      if (!orderId || !deliveryAddress?.latitude || !deliveryAddress?.longitude) {
        throw new Error('Invalid order or delivery address');
      }

      // Get available riders within range
      const availableRiders = await this.getAvailableRiders(
        deliveryAddress.latitude,
        deliveryAddress.longitude,
        MAX_DELIVERY_DISTANCE
      );

      if (availableRiders.length === 0) {
        return {
          success: false,
          error: 'No available riders found',
          retryable: true,
          code: 'NO_RIDERS_AVAILABLE'
        };
      }

      // Calculate ETA for each rider
      const ridersWithEta = await Promise.all(
        availableRiders.map(async (rider) => {
          const eta = await this.calculateETA(
            rider.latitude,
            rider.longitude,
            deliveryAddress.latitude,
            deliveryAddress.longitude
          );
          return {
            ...rider,
            eta_minutes: eta
          };
        })
      );

      // Sort by ETA and select best rider
      const sortedRiders = ridersWithEta.sort((a, b) => a.eta_minutes - b.eta_minutes);
      const selectedRider = sortedRiders[0];

      // Create delivery task
      const deliveryTaskRef = db.collection('delivery_tasks').doc();
      const deliveryTask = {
        id: deliveryTaskRef.id,
        order_id: orderId,
        customer_id: customerId,
        rider_id: selectedRider.id,
        status: 'assigned',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        delivery_address: deliveryAddress,
        rider_details: {
          name: selectedRider.name,
          phone: selectedRider.phone,
          vehicle: selectedRider.vehicle_type,
          latitude: selectedRider.latitude,
          longitude: selectedRider.longitude
        },
        eta_minutes: selectedRider.eta_minutes,
        assigned_at: admin.firestore.FieldValue.serverTimestamp(),
        estimated_delivery_time: new Date(Date.now() + selectedRider.eta_minutes * 60000).toISOString(),
        reassignments: 0
      };

      // Save delivery task
      await deliveryTaskRef.set(deliveryTask);

      // Update rider's current load
      await this.updateRiderLoad(selectedRider.id, 1);

      // Update order status to 'assigned_to_delivery'
      await db.collection('orders').doc(orderId).update({
        status: 'assigned_to_delivery',
        delivery_task_id: deliveryTaskRef.id,
        assigned_rider_id: selectedRider.id,
        assigned_at: admin.firestore.FieldValue.serverTimestamp()
      });

      // Create assignment history record
      await db.collection('delivery_assignments').add({
        delivery_task_id: deliveryTaskRef.id,
        order_id: orderId,
        rider_id: selectedRider.id,
        assignment_type: 'initial',
        assigned_at: admin.firestore.FieldValue.serverTimestamp(),
        eta_minutes: selectedRider.eta_minutes,
        distance_km: this.calculateDistance(
          selectedRider.latitude,
          selectedRider.longitude,
          deliveryAddress.latitude,
          deliveryAddress.longitude
        )
      });

      // Notify rider via Firestore
      await this.notifyRider(selectedRider.id, deliveryTask);

      return {
        success: true,
        delivery_task_id: deliveryTaskRef.id,
        rider_id: selectedRider.id,
        rider_name: selectedRider.name,
        eta_minutes: selectedRider.eta_minutes,
        estimated_delivery_time: deliveryTask.estimated_delivery_time
      };
    } catch (error) {
      console.error('Error assigning order to rider:', error);
      return {
        success: false,
        error: error.message,
        retryable: true,
        code: 'ASSIGNMENT_ERROR'
      };
    }
  }

  /**
   * Get available riders within specified distance
   *
   * @param {number} latitude - Delivery latitude
   * @param {number} longitude - Delivery longitude
   * @param {number} maxDistance - Max distance in km
   * @returns {Promise<Array>} - Array of available riders
   */
  async getAvailableRiders(latitude, longitude, maxDistance) {
    try {
      // Query all delivery agents
      const ridersSnapshot = await db.collection('delivery_agents')
        .where('status', '==', 'active')
        .where('is_available', '==', true)
        .get();

      if (ridersSnapshot.empty) {
        return [];
      }

      const availableRiders = [];

      for (const doc of ridersSnapshot.docs) {
        const rider = doc.data();
        rider.id = doc.id;

        // Check capacity
        const capacity = await this.checkRiderCapacity(doc.id);
        if (!capacity.is_available) {
          continue;
        }

        // Calculate distance
        const distance = this.calculateDistance(
          rider.latitude,
          rider.longitude,
          latitude,
          longitude
        );

        // Filter by max distance
        if (distance <= maxDistance) {
          availableRiders.push({
            ...rider,
            distance_km: distance
          });
        }
      }

      return availableRiders;
    } catch (error) {
      console.error('Error getting available riders:', error);
      return [];
    }
  }

  /**
   * Check rider capacity and availability
   *
   * @param {string} riderId - Rider document ID
   * @returns {Promise<Object>} - Capacity info
   */
  async checkRiderCapacity(riderId) {
    try {
      // Count active deliveries
      const activeDeliveriesSnapshot = await db.collection('delivery_tasks')
        .where('rider_id', '==', riderId)
        .where('status', 'in', ['assigned', 'in_progress', 'arrived'])
        .get();

      const activeCount = activeDeliveriesSnapshot.size;
      const availableSlots = Math.max(0, MAX_ORDERS_PER_RIDER - activeCount);
      const isAvailable = availableSlots > 0;

      return {
        active_deliveries: activeCount,
        available_slots: availableSlots,
        is_available: isAvailable,
        max_capacity: MAX_ORDERS_PER_RIDER
      };
    } catch (error) {
      console.error('Error checking rider capacity:', error);
      return {
        active_deliveries: 0,
        available_slots: 0,
        is_available: false,
        error: error.message
      };
    }
  }

  /**
   * Calculate distance between two points using Haversine formula
   *
   * @param {number} lat1 - Start latitude
   * @param {number} lng1 - Start longitude
   * @param {number} lat2 - End latitude
   * @param {number} lng2 - End longitude
   * @returns {number} - Distance in km
   */
  calculateDistance(lat1, lng1, lat2, lng2) {
    const dLat = this.toRad(lat2 - lat1);
    const dLng = this.toRad(lng2 - lng1);

    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRad(lat1)) * Math.cos(this.toRad(lat2)) *
      Math.sin(dLng / 2) * Math.sin(dLng / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return DELIVERY_EARTH_RADIUS * c;
  }

  toRad(degrees) {
    return degrees * (Math.PI / 180);
  }

  /**
   * Calculate ETA from current location to delivery location
   * For production, integrate with Google Maps Distance Matrix API
   * Currently uses simple formula: 1 minute per 1km + buffer
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

      // Simple formula: 1 min per 1km + buffer
      // In production, use Google Maps API for traffic-aware ETAs
      const baseEta = Math.ceil(distanceKm * 1.2); // 20% buffer for urban traffic
      const finalEta = baseEta + ETA_BUFFER_MINUTES;

      return Math.min(finalEta, 60); // Cap at 60 minutes
    } catch (error) {
      console.error('Error calculating ETA:', error);
      return 30; // Default fallback
    }
  }

  /**
   * Update rider's current load
   *
   * @param {string} riderId - Rider ID
   * @param {number} delta - Change in load count
   */
  async updateRiderLoad(riderId, delta) {
    try {
      await db.collection('delivery_agents').doc(riderId).update({
        current_load: admin.firestore.FieldValue.increment(delta),
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (error) {
      console.error('Error updating rider load:', error);
    }
  }

  /**
   * Notify rider about new delivery task
   *
   * @param {string} riderId - Rider ID
   * @param {Object} deliveryTask - Delivery task data
   */
  async notifyRider(riderId, deliveryTask) {
    try {
      // Store notification in Firestore
      await db.collection('rider_notifications').add({
        rider_id: riderId,
        type: 'new_delivery_assignment',
        delivery_task_id: deliveryTask.id,
        order_id: deliveryTask.order_id,
        customer_id: deliveryTask.customer_id,
        delivery_address: deliveryTask.delivery_address,
        eta_minutes: deliveryTask.eta_minutes,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });

      // Update rider's active tasks list
      await db.collection('delivery_agents').doc(riderId).update({
        active_delivery_tasks: admin.firestore.FieldValue.arrayUnion([deliveryTask.id])
      });
    } catch (error) {
      console.error('Error notifying rider:', error);
    }
  }

  /**
   * Reassign delivery if rider cancels or fails
   *
   * @param {string} deliveryTaskId - Delivery task ID
   * @param {string} reason - Reason for reassignment
   * @returns {Promise<Object>} - Reassignment result
   */
  async reassignIfNeeded(deliveryTaskId, reason) {
    try {
      const taskDoc = await db.collection('delivery_tasks').doc(deliveryTaskId).get();

      if (!taskDoc.exists) {
        return { success: false, error: 'Delivery task not found' };
      }

      const task = taskDoc.data();
      const orderId = task.order_id;

      // Mark current task as reassigned
      await db.collection('delivery_tasks').doc(deliveryTaskId).update({
        status: 'reassigned',
        reassignment_reason: reason,
        updated_at: admin.firestore.FieldValue.serverTimestamp()
      });

      // Decrement old rider's load
      await this.updateRiderLoad(task.rider_id, -1);

      // Reassign to new rider
      const result = await this.assignOrderToRider(
        orderId,
        task.customer_id,
        task.delivery_address
      );

      // Record reassignment
      if (result.success) {
        await db.collection('delivery_assignments').add({
          delivery_task_id: deliveryTaskId,
          original_rider_id: task.rider_id,
          new_rider_id: result.rider_id,
          assignment_type: 'reassignment',
          reason,
          reassigned_at: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      return result;
    } catch (error) {
      console.error('Error reassigning delivery:', error);
      return {
        success: false,
        error: error.message,
        retryable: true
      };
    }
  }

  /**
   * Batch assign multiple orders to riders
   * Useful for bulk operations (e.g., morning assignments)
   *
   * @param {Array} orders - Array of order objects with IDs and delivery addresses
   * @returns {Promise<Object>} - Batch assignment results
   */
  async batchAssignOrders(orders) {
    try {
      const results = {
        total: orders.length,
        successful: 0,
        failed: 0,
        assignments: []
      };

      // Process in parallel with concurrency limit (max 5 at a time)
      const batchSize = 5;
      for (let i = 0; i < orders.length; i += batchSize) {
        const batch = orders.slice(i, i + batchSize);
        const assignments = await Promise.all(
          batch.map(order => this.assignOrderToRider(
            order.id,
            order.customer_id,
            order.delivery_address
          ))
        );

        for (const assignment of assignments) {
          if (assignment.success) {
            results.successful++;
            results.assignments.push({
              order_id: assignment.delivery_task_id,
              rider_id: assignment.rider_id,
              status: 'assigned'
            });
          } else {
            results.failed++;
            results.assignments.push({
              status: 'failed',
              error: assignment.error
            });
          }
        }
      }

      return results;
    } catch (error) {
      console.error('Error in batch assignment:', error);
      return {
        success: false,
        error: error.message,
        total: orders.length,
        successful: 0,
        failed: orders.length
      };
    }
  }
}

module.exports = new DeliveryAssignmentService();
