const supabaseService = require('../../config/supabase');

/**
 * Delivery Service - Manages delivery tasks and rider assignments
 * Consolidates all delivery workflows into a single service
 */
class SupabaseDeliveryService {
  /**
   * Create delivery task
   */
  async createDeliveryTask({
    orderId,
    customerId,
    shopId,
    pickupAddress,
    deliveryAddress,
    deliveryType = 'standard',
    estimatedDelivery = null,
  }) {
    try {
      const task = await supabaseService.query('delivery_tasks', 'insert', {
        payload: {
          order_id: orderId,
          customer_id: customerId,
          shop_id: shopId,
          status: 'pending',
          pickup_address: pickupAddress,
          delivery_address: deliveryAddress,
          estimated_delivery: estimatedDelivery,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
      });

      console.log(`[Delivery] Created delivery task for order: ${orderId}`);
      return task[0];
    } catch (error) {
      console.error('[Delivery] Create task failed:', error.message);
      throw error;
    }
  }

  /**
   * Get delivery task
   */
  async getDeliveryTask(deliveryTaskId) {
    try {
      const tasks = await supabaseService.query('delivery_tasks', 'select', {
        filters: { id: deliveryTaskId },
      });
      return tasks[0] || null;
    } catch (error) {
      console.error('[Delivery] Get task failed:', error.message);
      throw error;
    }
  }

  /**
   * Get delivery tasks for order
   */
  async getOrderDeliveryTasks(orderId) {
    try {
      const tasks = await supabaseService.query('delivery_tasks', 'select', {
        filters: { order_id: orderId },
      });
      return tasks;
    } catch (error) {
      console.error('[Delivery] Get order tasks failed:', error.message);
      throw error;
    }
  }

  /**
   * Assign rider to delivery
   */
  async assignRider(deliveryTaskId, riderId) {
    try {
      const task = await this.getDeliveryTask(deliveryTaskId);

      if (!task) {
        throw new Error(`Delivery task not found: ${deliveryTaskId}`);
      }

      // Create assignment record
      const assignment = await supabaseService.query('delivery_assignments', 'insert', {
        payload: {
          delivery_task_id: deliveryTaskId,
          rider_id: riderId,
          status: 'pending',
          assigned_at: new Date().toISOString(),
        },
      });

      // Update delivery task
      await supabaseService.query('delivery_tasks', 'update', {
        payload: {
          rider_id: riderId,
          status: 'assigned',
          updated_at: new Date().toISOString(),
        },
        filters: { id: deliveryTaskId },
      });

      console.log(`[Delivery] Assigned rider ${riderId} to delivery ${deliveryTaskId}`);
      return assignment[0];
    } catch (error) {
      console.error('[Delivery] Assign rider failed:', error.message);
      throw error;
    }
  }

  /**
   * Accept delivery by rider
   */
  async acceptDelivery(deliveryTaskId, riderId) {
    try {
      const task = await this.getDeliveryTask(deliveryTaskId);

      if (!task) {
        throw new Error(`Delivery task not found: ${deliveryTaskId}`);
      }

      if (task.rider_id !== riderId) {
        throw new Error('Unauthorized: Rider not assigned to this delivery');
      }

      // Update assignment
      const assignments = await supabaseService.query('delivery_assignments', 'select', {
        filters: { delivery_task_id: deliveryTaskId, rider_id: riderId },
      });

      if (assignments.length > 0) {
        await supabaseService.query('delivery_assignments', 'update', {
          payload: {
            status: 'accepted',
            accepted_at: new Date().toISOString(),
          },
          filters: { id: assignments[0].id },
        });
      }

      // Update delivery task
      await supabaseService.query('delivery_tasks', 'update', {
        payload: {
          status: 'accepted',
          updated_at: new Date().toISOString(),
        },
        filters: { id: deliveryTaskId },
      });

      console.log(`[Delivery] Rider ${riderId} accepted delivery ${deliveryTaskId}`);
      return true;
    } catch (error) {
      console.error('[Delivery] Accept delivery failed:', error.message);
      throw error;
    }
  }

  /**
   * Mark delivery as picked up
   */
  async markPickedUp(deliveryTaskId, riderId, location = null) {
    try {
      const task = await this.getDeliveryTask(deliveryTaskId);

      if (!task) {
        throw new Error(`Delivery task not found: ${deliveryTaskId}`);
      }

      if (task.rider_id !== riderId) {
        throw new Error('Unauthorized: Rider not assigned to this delivery');
      }

      const update = {
        status: 'picked_up',
        start_time: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      if (location) {
        update.current_location = location;
      }

      await supabaseService.query('delivery_tasks', 'update', {
        payload: update,
        filters: { id: deliveryTaskId },
      });

      console.log(`[Delivery] Marked delivery ${deliveryTaskId} as picked up`);
      return true;
    } catch (error) {
      console.error('[Delivery] Mark picked up failed:', error.message);
      throw error;
    }
  }

  /**
   * Update delivery location
   */
  async updateLocation(deliveryTaskId, latitude, longitude) {
    try {
      await supabaseService.query('delivery_tasks', 'update', {
        payload: {
          current_location: { latitude, longitude },
          updated_at: new Date().toISOString(),
        },
        filters: { id: deliveryTaskId },
      });

      return true;
    } catch (error) {
      console.error('[Delivery] Update location failed:', error.message);
      throw error;
    }
  }

  /**
   * Verify OTP and mark delivered
   */
  async verifyAndMarkDelivered(deliveryTaskId, riderId, otp, proofUrl = null) {
    try {
      const task = await this.getDeliveryTask(deliveryTaskId);

      if (!task) {
        throw new Error(`Delivery task not found: ${deliveryTaskId}`);
      }

      if (task.rider_id !== riderId) {
        throw new Error('Unauthorized: Rider not assigned to this delivery');
      }

      // In production, verify OTP against order
      // For now, just mark as verified
      const update = {
        status: 'delivered',
        otp_verified: true,
        end_time: new Date().toISOString(),
        actual_delivery: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      if (proofUrl) {
        update.delivery_proof_url = proofUrl;
      }

      await supabaseService.query('delivery_tasks', 'update', {
        payload: update,
        filters: { id: deliveryTaskId },
      });

      // Update order status
      const orderService = require('./SupabaseOrderService');
      await orderService.updateOrderStatus(task.order_id, 'delivered');

      console.log(`[Delivery] Marked delivery ${deliveryTaskId} as delivered`);
      return true;
    } catch (error) {
      console.error('[Delivery] Verify and mark delivered failed:', error.message);
      throw error;
    }
  }

  /**
   * Mark delivery as failed
   */
  async markFailed(deliveryTaskId, riderId, reason = null, notes = null) {
    try {
      const task = await this.getDeliveryTask(deliveryTaskId);

      if (!task) {
        throw new Error(`Delivery task not found: ${deliveryTaskId}`);
      }

      if (task.rider_id !== riderId) {
        throw new Error('Unauthorized: Rider not assigned to this delivery');
      }

      const update = {
        status: 'failed',
        end_time: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      if (notes) {
        update.notes = `${reason || ''} - ${notes}`.trim();
      } else if (reason) {
        update.notes = reason;
      }

      await supabaseService.query('delivery_tasks', 'update', {
        payload: update,
        filters: { id: deliveryTaskId },
      });

      console.log(`[Delivery] Marked delivery ${deliveryTaskId} as failed`);
      return true;
    } catch (error) {
      console.error('[Delivery] Mark failed failed:', error.message);
      throw error;
    }
  }

  /**
   * Get pending deliveries for rider
   */
  async getRiderDeliveries(riderId, status = 'assigned') {
    try {
      const deliveries = await supabaseService.query('delivery_tasks', 'select', {
        filters: { rider_id: riderId, status },
        order: { column: 'created_at', ascending: false },
      });
      return deliveries;
    } catch (error) {
      console.error('[Delivery] Get rider deliveries failed:', error.message);
      throw error;
    }
  }

  /**
   * Get shop deliveries
   */
  async getShopDeliveries(shopId, status = null, limit = 50) {
    try {
      const filters = { shop_id: shopId };
      if (status) filters.status = status;

      const deliveries = await supabaseService.query('delivery_tasks', 'select', {
        filters,
        order: { column: 'created_at', ascending: false },
        limit,
      });
      return deliveries;
    } catch (error) {
      console.error('[Delivery] Get shop deliveries failed:', error.message);
      throw error;
    }
  }

  /**
   * Get delivery analytics
   */
  async getDeliveryAnalytics(shopId = null, days = 30) {
    try {
      const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

      const filters = shopId ? { shop_id: shopId } : {};
      const deliveries = await supabaseService.query('delivery_tasks', 'select', {
        filters,
      });

      const recentDeliveries = deliveries.filter(
        (d) => new Date(d.created_at) > new Date(since),
      );

      const delivered = recentDeliveries.filter((d) => d.status === 'delivered');
      const failed = recentDeliveries.filter((d) => d.status === 'failed');

      return {
        total_deliveries: recentDeliveries.length,
        completed_deliveries: delivered.length,
        failed_deliveries: failed.length,
        pending_deliveries: recentDeliveries.filter(
          (d) => !['delivered', 'failed', 'cancelled'].includes(d.status),
        ).length,
        average_delivery_time: delivered.length > 0
          ? delivered.reduce((sum, d) => {
            if (d.start_time && d.end_time) {
              return (
                sum
                + (new Date(d.end_time) - new Date(d.start_time)) / 1000 / 60
              );
            }
            return sum;
          }, 0) / delivered.length
          : 0,
        success_rate: recentDeliveries.length > 0
          ? (delivered.length / recentDeliveries.length) * 100
          : 0,
      };
    } catch (error) {
      console.error('[Delivery] Get analytics failed:', error.message);
      throw error;
    }
  }
}

module.exports = new SupabaseDeliveryService();
