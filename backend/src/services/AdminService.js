const pool = require('../db/pool');

/**
 * Admin Service - Manage system metrics, reports, and settings
 */
class AdminService {
  /**
   * Get dashboard metrics
   */
  static async getDashboardMetrics(dateRange = { from: null, to: null }) {
    try {
      const { from, to } = dateRange;
      let dateFilter = '';

      if (from && to) {
        dateFilter = `WHERE created_at BETWEEN $1 AND $2`;
      }

      // Total users
      const users = await pool.query('SELECT COUNT(*) as total FROM users');

      // Total orders
      let orderQuery = 'SELECT COUNT(*) as total, SUM(total_price) as revenue FROM orders';
      let orderParams = [];

      if (from && to) {
        orderQuery += ' WHERE created_at BETWEEN $1 AND $2';
        orderParams = [from, to];
      }

      const orders = await pool.query(orderQuery, orderParams);

      // Order status breakdown
      const statusBreakdown = await pool.query(
        `SELECT status, COUNT(*) as count FROM orders ${dateFilter} GROUP BY status`,
        dateFilter ? [from, to] : []
      );

      // Average order value
      const avgOrder = await pool.query(
        `SELECT AVG(total_price) as avg_order_value FROM orders ${dateFilter}`,
        dateFilter ? [from, to] : []
      );

      // Top products
      const topProducts = await pool.query(
        `SELECT p.id, p.name, COUNT(*) as order_count, SUM(oi.quantity) as total_sold
         FROM products p
         JOIN order_items oi ON p.id = oi.product_id
         JOIN orders o ON o.id = oi.order_id
         ${dateFilter}
         GROUP BY p.id, p.name
         ORDER BY order_count DESC
         LIMIT 10`,
        dateFilter ? [from, to] : []
      );

      return {
        totalUsers: parseInt(users.rows[0].total),
        totalOrders: parseInt(orders.rows[0].total),
        totalRevenue: parseFloat(orders.rows[0].revenue || 0),
        averageOrderValue: parseFloat(avgOrder.rows[0].avg_order_value || 0),
        statusBreakdown: statusBreakdown.rows,
        topProducts: topProducts.rows,
      };
    } catch (error) {
      console.error('[Admin] Dashboard metrics failed:', error.message);
      throw error;
    }
  }

  /**
   * Get order analytics
   */
  static async getOrderAnalytics(days = 30) {
    try {
      // Orders by day
      const ordersByDay = await pool.query(
        `SELECT DATE(created_at) as date, COUNT(*) as count, SUM(total_price) as revenue
         FROM orders
         WHERE created_at > NOW() - INTERVAL '${days} days'
         GROUP BY DATE(created_at)
         ORDER BY date DESC`
      );

      // Delivery success rate
      const deliveryStats = await pool.query(
        `SELECT
           COUNT(*) as total_orders,
           SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) as delivered,
           SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as cancelled
         FROM orders
         WHERE created_at > NOW() - INTERVAL '${days} days'`
      );

      const stats = deliveryStats.rows[0];
      const successRate = stats.total_orders > 0
        ? ((stats.delivered / stats.total_orders) * 100).toFixed(2)
        : 0;

      // Refund rate
      const refundStats = await pool.query(
        `SELECT
           COUNT(*) as total_refunds,
           SUM(refund_amount) as total_refunded
         FROM refunds
         WHERE created_at > NOW() - INTERVAL '${days} days' AND status = 'completed'`
      );

      return {
        ordersByDay: ordersByDay.rows,
        deliverySuccessRate: parseFloat(successRate),
        totalOrders: parseInt(stats.total_orders),
        totalDelivered: parseInt(stats.delivered),
        totalCancelled: parseInt(stats.cancelled),
        refunds: {
          totalRefunds: parseInt(refundStats.rows[0].total_refunds),
          totalRefunded: parseFloat(refundStats.rows[0].total_refunded || 0),
        },
      };
    } catch (error) {
      console.error('[Admin] Order analytics failed:', error.message);
      throw error;
    }
  }

  /**
   * Get inventory status
   */
  static async getInventoryStatus() {
    try {
      const inventory = await pool.query(
        `SELECT
           COUNT(*) as total_products,
           SUM(quantity_on_hand) as total_stock,
           SUM(quantity_reserved) as total_reserved,
           SUM(CASE WHEN quantity_on_hand = 0 THEN 1 ELSE 0 END) as out_of_stock_count
         FROM inventory`
      );

      const lowStock = await pool.query(
        `SELECT p.id, p.name, i.quantity_on_hand
         FROM inventory i
         JOIN products p ON i.product_id = p.id
         WHERE i.quantity_on_hand < 10
         ORDER BY i.quantity_on_hand ASC
         LIMIT 20`
      );

      return {
        totalProducts: parseInt(inventory.rows[0].total_products),
        totalStock: parseInt(inventory.rows[0].total_stock || 0),
        totalReserved: parseInt(inventory.rows[0].total_reserved || 0),
        outOfStockCount: parseInt(inventory.rows[0].out_of_stock_count),
        lowStockProducts: lowStock.rows,
      };
    } catch (error) {
      console.error('[Admin] Inventory status failed:', error.message);
      throw error;
    }
  }

  /**
   * Get delivery analytics
   */
  static async getDeliveryAnalytics() {
    try {
      // Rider performance
      const riders = await pool.query(
        `SELECT
           dr.id, dr.name, dr.rating, dr.total_deliveries, dr.earnings,
           COUNT(da.id) as current_assignments,
           AVG(EXTRACT(EPOCH FROM (da.delivered_at - da.assigned_at))/3600) as avg_delivery_hours
         FROM delivery_riders dr
         LEFT JOIN delivery_assignments da ON dr.id = da.rider_id
         GROUP BY dr.id
         ORDER BY dr.rating DESC`
      );

      // Delivery performance by status
      const statusStats = await pool.query(
        `SELECT
           status,
           COUNT(*) as count,
           AVG(EXTRACT(EPOCH FROM (delivered_at - assigned_at))/3600) as avg_hours
         FROM delivery_assignments
         GROUP BY status`
      );

      return {
        riderPerformance: riders.rows,
        deliveryStatusStats: statusStats.rows,
      };
    } catch (error) {
      console.error('[Admin] Delivery analytics failed:', error.message);
      throw error;
    }
  }

  /**
   * Get user demographics and behavior
   */
  static async getUserAnalytics() {
    try {
      // Total users and growth
      const users = await pool.query(
        `SELECT
           COUNT(*) as total,
           DATE(DATE_TRUNC('month', created_at)) as month,
           COUNT(*) as monthly_signups
         FROM users
         GROUP BY DATE(DATE_TRUNC('month', created_at))
         ORDER BY month DESC
         LIMIT 12`
      );

      // User segments
      const segments = await pool.query(
        `SELECT
           COUNT(*) as total,
           SUM(CASE WHEN gender = 'M' THEN 1 ELSE 0 END) as male_users,
           SUM(CASE WHEN gender = 'F' THEN 1 ELSE 0 END) as female_users,
           AVG(EXTRACT(YEAR FROM AGE(date_of_birth))) as avg_age
         FROM users`
      );

      // Most active users (by order count)
      const activeUsers = await pool.query(
        `SELECT u.id, u.name, COUNT(o.id) as order_count, SUM(o.total_price) as lifetime_spent
         FROM users u
         LEFT JOIN orders o ON u.id = o.user_id
         GROUP BY u.id
         ORDER BY order_count DESC
         LIMIT 20`
      );

      return {
        monthlySignups: users.rows,
        totalUsers: segments.rows[0]?.total || 0,
        demographics: {
          maleUsers: segments.rows[0]?.male_users || 0,
          femaleUsers: segments.rows[0]?.female_users || 0,
          averageAge: segments.rows[0]?.avg_age || 0,
        },
        topUsers: activeUsers.rows,
      };
    } catch (error) {
      console.error('[Admin] User analytics failed:', error.message);
      throw error;
    }
  }

  /**
   * Get payment analytics
   */
  static async getPaymentAnalytics(days = 30) {
    try {
      const payments = await pool.query(
        `SELECT
           COUNT(*) as total_transactions,
           SUM(amount) as total_amount,
           payment_method,
           status,
           COUNT(*) as count
         FROM payments
         WHERE created_at > NOW() - INTERVAL '${days} days'
         GROUP BY payment_method, status
         ORDER BY count DESC`
      );

      const successRate = await pool.query(
        `SELECT
           COUNT(*) as total,
           SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as successful,
           SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed
         FROM payments
         WHERE created_at > NOW() - INTERVAL '${days} days'`
      );

      const stats = successRate.rows[0];
      const rate = stats.total > 0
        ? ((stats.successful / stats.total) * 100).toFixed(2)
        : 0;

      return {
        transactionsByMethod: payments.rows,
        paymentSuccessRate: parseFloat(rate),
        totalTransactions: parseInt(stats.total),
        successfulTransactions: parseInt(stats.successful),
        failedTransactions: parseInt(stats.failed),
      };
    } catch (error) {
      console.error('[Admin] Payment analytics failed:', error.message);
      throw error;
    }
  }
}

module.exports = AdminService;
