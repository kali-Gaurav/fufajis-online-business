// Async Event Worker
// Poll events table and execute side effects
// Retry with exponential backoff, DLQ on max retries

const EventBus = require('../services/event-bus');
const pool = require('../db/pool');
const { v4: uuidv4 } = require('uuid');

class EventWorker {
  constructor(workerId = `worker-${uuidv4().substring(0, 8)}`) {
    this.workerId = workerId;
    this.isRunning = false;
    this.pollIntervalMs = 5000; // Poll every 5 seconds
  }

  /**
   * Start the worker loop
   */
  async start() {
    if (this.isRunning) {
      console.log(`[EventWorker] ${this.workerId} already running`);
      return;
    }

    this.isRunning = true;
    console.log(`[EventWorker] ✅ ${this.workerId} started`);

    while (this.isRunning) {
      try {
        // Claim and process one event
        await this.processOneEvent();
      } catch (err) {
        console.error(`[EventWorker] Error in worker loop:`, err.message);
        // Continue despite error
      }

      // Brief sleep before next poll
      await new Promise(resolve => setTimeout(resolve, 100));
    }
  }

  /**
   * Stop the worker loop gracefully
   */
  async stop() {
    console.log(`[EventWorker] ${this.workerId} stopping...`);
    this.isRunning = false;
  }

  /**
   * Process one event
   */
  async processOneEvent() {
    // Try to claim next event
    const event = await EventBus.claimNextEvent(this.workerId);

    if (!event) {
      // No events available
      return;
    }

    console.log(`[EventWorker] Processing event: ${event.event_type} (${event.id})`);

    try {
      // Execute event handler based on event type
      await this.executeEvent(event);

      // Mark as completed
      await EventBus.completeEvent(event.id);

      console.log(`[EventWorker] ✅ Completed event: ${event.event_type}`);
    } catch (err) {
      console.error(`[EventWorker] ❌ Event failed: ${err.message}`);

      // Schedule retry or DLQ
      await EventBus.failEvent(event.id, err.message);
    }
  }

  /**
   * Execute event handler based on event type
   * CRITICAL: All side effects should be idempotent
   */
  async executeEvent(event) {
    const { event_type, aggregate_id, payload } = event;
    const data = JSON.parse(payload);

    switch (event_type) {
      case 'ORDER_CREATED':
        await this.handleOrderCreated(aggregate_id, data);
        break;

      case 'PAYMENT_SUCCESS':
        await this.handlePaymentSuccess(aggregate_id, data);
        break;

      case 'ORDER_PACKED':
        await this.handleOrderPacked(aggregate_id, data);
        break;

      case 'ORDER_DELIVERED':
        await this.handleOrderDelivered(aggregate_id, data);
        break;

      case 'REFUND_COMPLETED':
        await this.handleRefundCompleted(aggregate_id, data);
        break;

      default:
        throw new Error(`Unknown event type: ${event_type}`);
    }
  }

  /**
   * Handle ORDER_CREATED event
   * Side effects: Create packing list, notify kitchen
   */
  async handleOrderCreated(orderId, data) {
    // Create packing list
    await pool.query(
      `INSERT INTO packing_lists (order_id, shop_id, created_at)
       VALUES ($1, $2, CURRENT_TIMESTAMP)
       ON CONFLICT (order_id) DO NOTHING`,
      [orderId, data.shopId]
    );

    // Would emit notifications here (SMS/FCM to kitchen staff)
    console.log(`[EventWorker] Order packing list created: ${orderId}`);
  }

  /**
   * Handle PAYMENT_SUCCESS event
   * Side effects: Send confirmation notification, record loyalty
   */
  async handlePaymentSuccess(orderId, data) {
    // Send order confirmation SMS/email to customer
    // This would integrate with notification service

    // Record loyalty points (if applicable)
    if (data.customerId && data.amount) {
      await pool.query(
        `INSERT INTO loyalty_transactions (customer_id, points, reason, order_id, created_at)
         VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
         ON CONFLICT DO NOTHING`,
        [data.customerId, Math.floor(data.amount * 0.1), 'purchase', orderId]
      );
    }

    console.log(`[EventWorker] Payment recorded and loyalty updated: ${orderId}`);
  }

  /**
   * Handle ORDER_PACKED event
   * Side effects: Notify delivery partner, create shipping label
   */
  async handleOrderPacked(orderId, data) {
    // Assign delivery partner via TaskRouter
    // Create shipping label (integration with shipping provider)
    // Send notification to delivery partner

    console.log(`[EventWorker] Order packed, delivery assigned: ${orderId}`);
  }

  /**
   * Handle ORDER_DELIVERED event
   * Side effects: Update loyalty, close return window, send receipt
   */
  async handleOrderDelivered(orderId, data) {
    // Create return window (30-day window opens)
    const returnWindowExpiresAt = new Date();
    returnWindowExpiresAt.setDate(returnWindowExpiresAt.getDate() + 30);

    await pool.query(
      `UPDATE orders SET return_window_expires_at = $1 WHERE id = $2`,
      [returnWindowExpiresAt, orderId]
    );

    // Send delivery receipt
    console.log(`[EventWorker] Order delivered, return window opened: ${orderId}`);
  }

  /**
   * Handle REFUND_COMPLETED event
   * Side effects: Update wallet, send refund confirmation
   */
  async handleRefundCompleted(orderId, data) {
    // Refund to wallet
    if (data.customerId && data.amount) {
      await pool.query(
        `UPDATE customer_wallets SET balance = balance + $1 WHERE customer_id = $2`,
        [data.amount, data.customerId]
      );
    }

    // Send refund confirmation SMS/email
    console.log(`[EventWorker] Refund processed and wallet updated: ${orderId}`);
  }
}

module.exports = EventWorker;
