const supabaseService = require('../../config/supabase');

/**
 * Order Service - Unified order management using Supabase
 * Consolidates all order creation, status updates, and queries
 */
class SupabaseOrderService {
  /**
   * Create a new order
   */
  async createOrder({
    firestoreId = null,
    customerId,
    shopId,
    items,
    subtotal,
    total,
    deliveryCharge = 0,
    discount = 0,
    tax = 0,
    paymentMethod = null,
    deliveryAddress = null,
    deliveryType = 'standard',
  }) {
    try {
      const orderNumber = `ORD-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

      const order = await supabaseService.query('orders', 'insert', {
        payload: {
          firestore_id: firestoreId,
          order_number: orderNumber,
          user_id: customerId, // Matching core schema naming 'user_id'
          shop_id: shopId,
          subtotal,
          delivery_fee: deliveryCharge, // Matching core schema naming 'delivery_fee'
          discount,
          tax,
          total, // Matching core schema naming 'total'
          payment_method: paymentMethod,
          payment_status: 'pending',
          order_status: 'pending', // Matching core schema naming 'order_status'
          metadata: { items, deliveryAddress, deliveryType }, // Storing extra in metadata
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
      });

      console.log(`[Order] Created order: ${orderNumber} for customer: ${customerId}`);
      return order[0];
    } catch (error) {
      console.error('[Order] Create order failed:', error.message);
      throw error;
    }
  }

  /**
   * Get order by ID
   */
  async getOrder(orderId) {
    try {
      const order = await supabaseService.query('orders', 'select', {
        filters: { id: orderId },
      });
      return order[0] || null;
    } catch (error) {
      console.error('[Order] Get order failed:', error.message);
      throw error;
    }
  }

  /**
   * Get orders by customer
   */
  async getCustomerOrders(customerId, limit = 50, offset = 0) {
    try {
      const orders = await supabaseService.query('orders', 'select', {
        filters: { customer_id: customerId },
        order: { column: 'created_at', ascending: false },
        limit,
      });
      return orders;
    } catch (error) {
      console.error('[Order] Get customer orders failed:', error.message);
      throw error;
    }
  }

  /**
   * Get shop orders
   */
  async getShopOrders(shopId, status = null, limit = 50, offset = 0) {
    try {
      const filters = { shop_id: shopId };
      if (status) filters.status = status;

      const orders = await supabaseService.query('orders', 'select', {
        filters,
        order: { column: 'created_at', ascending: false },
        limit,
      });
      return orders;
    } catch (error) {
      console.error('[Order] Get shop orders failed:', error.message);
      throw error;
    }
  }

  /**
   * Update order status
   */
  async updateOrderStatus(firestoreId, status) {
    try {
      const validStatuses = [
        'pending',
        'confirmed',
        'preparing',
        'ready_for_pickup',
        'out_for_delivery',
        'delivered',
        'cancelled',
      ];

      // Map Firestore status to Supabase status if they differ
      let supabaseStatus = status;
      if (status.startsWith('OrderStatus.')) {
        supabaseStatus = status.replace('OrderStatus.', '');
      }

      const update = {
        order_status: supabaseStatus,
        updated_at: new Date().toISOString(),
      };

      if (supabaseStatus === 'delivered') {
        update.delivered_at = new Date().toISOString();
      }

      await supabaseService.query('orders', 'update', {
        payload: update,
        filters: { firestore_id: firestoreId },
      });

      console.log(`[Order] Updated order ${firestoreId} status to ${supabaseStatus}`);
      return true;
    } catch (error) {
      console.error('[Order] Update order status failed:', error.message);
      throw error;
    }
  }

  /**
   * Update payment status
   */
  async updatePaymentStatus(firestoreId, paymentStatus, paymentId = null) {
    try {
      const validStatuses = ['pending', 'paid', 'failed', 'refunded'];

      if (!validStatuses.includes(paymentStatus)) {
        throw new Error(`Invalid payment status: ${paymentStatus}`);
      }

      const update = {
        payment_status: paymentStatus,
        updated_at: new Date().toISOString(),
      };

      if (paymentId) {
        update.payment_id = paymentId;
      }

      if (paymentStatus === 'paid') {
        update.order_status = 'confirmed';
      }

      await supabaseService.query('orders', 'update', {
        payload: update,
        filters: { firestore_id: firestoreId },
      });

      console.log(`[Order] Updated order ${firestoreId} payment status to ${paymentStatus}`);
      return true;
    } catch (error) {
      console.error('[Order] Update payment status failed:', error.message);
      throw error;
    }
  }

  /**
   * Cancel order
   */
  async cancelOrder(orderId, reason = null) {
    try {
      const order = await this.getOrder(orderId);

      if (!order) {
        throw new Error(`Order not found: ${orderId}`);
      }

      if (['delivered', 'cancelled'].includes(order.status)) {
        throw new Error(
          `Cannot cancel order with status: ${order.status}`,
        );
      }

      const update = {
        status: 'cancelled',
        cancelled_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      if (reason) {
        update.special_instructions = reason;
      }

      await supabaseService.query('orders', 'update', {
        payload: update,
        filters: { id: orderId },
      });

      console.log(`[Order] Cancelled order ${orderId}`);
      return true;
    } catch (error) {
      console.error('[Order] Cancel order failed:', error.message);
      throw error;
    }
  }

  /**
   * Get orders by status
   */
  async getOrdersByStatus(status, shopId = null, limit = 50) {
    try {
      const filters = { status };
      if (shopId) filters.shop_id = shopId;

      const orders = await supabaseService.query('orders', 'select', {
        filters,
        order: { column: 'created_at', ascending: false },
        limit,
      });
      return orders;
    } catch (error) {
      console.error('[Order] Get orders by status failed:', error.message);
      throw error;
    }
  }

  /**
   * Get pending orders
   */
  async getPendingOrders(shopId = null, limit = 50) {
    return this.getOrdersByStatus('pending', shopId, limit);
  }

  /**
   * Get confirmed orders
   */
  async getConfirmedOrders(shopId = null, limit = 50) {
    return this.getOrdersByStatus('confirmed', shopId, limit);
  }

  /**
   * Apply coupon to order
   */
  async applyCoupon(orderId, couponCode) {
    try {
      const order = await this.getOrder(orderId);

      if (!order) {
        throw new Error(`Order not found: ${orderId}`);
      }

      // Validate coupon
      const coupons = await supabaseService.query('coupons', 'select', {
        filters: { code: couponCode, is_active: true },
      });

      if (coupons.length === 0) {
        throw new Error(`Invalid coupon: ${couponCode}`);
      }

      const coupon = coupons[0];

      // Check if valid
      const now = new Date();
      if (new Date(coupon.valid_from) > now || new Date(coupon.valid_till) < now) {
        throw new Error('Coupon expired');
      }

      // Calculate discount
      let discountAmount = 0;
      if (coupon.discount_type === 'fixed') {
        discountAmount = coupon.discount_value;
      } else if (coupon.discount_type === 'percentage') {
        discountAmount = (order.subtotal * coupon.discount_value) / 100;
      }

      if (coupon.max_discount_amount) {
        discountAmount = Math.min(discountAmount, coupon.max_discount_amount);
      }

      // Update order
      const newTotal = order.subtotal + order.delivery_charge - discountAmount + (order.tax || 0);

      await supabaseService.query('orders', 'update', {
        payload: {
          discount: discountAmount,
          total_amount: newTotal,
          updated_at: new Date().toISOString(),
        },
        filters: { id: orderId },
      });

      console.log(`[Order] Applied coupon ${couponCode} to order ${orderId}`);
      return { discountAmount, newTotal };
    } catch (error) {
      console.error('[Order] Apply coupon failed:', error.message);
      throw error;
    }
  }

  /**
   * Get order analytics
   */
  async getOrderAnalytics(shopId, days = 30) {
    try {
      const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

      const orders = await supabaseService.query('orders', 'select', {
        filters: { shop_id: shopId },
      });

      const recentOrders = orders.filter(
        (o) => new Date(o.created_at) > new Date(since),
      );

      return {
        total_orders: recentOrders.length,
        total_revenue: recentOrders.reduce(
          (sum, o) => sum + parseFloat(o.total_amount),
          0,
        ),
        average_order_value: recentOrders.length > 0
          ? recentOrders.reduce(
            (sum, o) => sum + parseFloat(o.total_amount),
            0,
          ) / recentOrders.length
          : 0,
        completed_orders: recentOrders.filter(
          (o) => o.status === 'delivered',
        ).length,
        cancelled_orders: recentOrders.filter(
          (o) => o.status === 'cancelled',
        ).length,
        pending_orders: recentOrders.filter(
          (o) => o.status === 'pending',
        ).length,
      };
    } catch (error) {
      console.error('[Order] Get analytics failed:', error.message);
      throw error;
    }
  }
}

module.exports = new SupabaseOrderService();
