// Event Bus Service
// Simple, reliable async event processing
// Publish events → PostgreSQL table → workers pick up

const pool = require('../db/pool');
const { v4: uuidv4 } = require('uuid');

class EventBus {
  /**
   * Publish an event to the event bus
   * Event types: ORDER_CREATED, PAYMENT_SUCCESS, ORDER_PACKED, ORDER_DELIVERED, REFUND_COMPLETED
   * Priority: 1=critical, 5=normal, 10=background
   * Partition key: ensures ordered processing per aggregate (e.g., orderId)
   */
  static async publishEvent(eventType, aggregateId, payload, { priority = 5, partitionKey = null } = {}) {
    const eventId = uuidv4();
    const pKey = partitionKey || aggregateId; // Use aggregateId as default partition

    try {
      await pool.query(
        `INSERT INTO events (id, event_type, aggregate_id, partition_key, payload, priority, status, scheduled_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP)`,
        [eventId, eventType, aggregateId, pKey, JSON.stringify(payload), priority, 'pending']
      );

      console.log(`[EventBus] ✅ Published event: ${eventType} (${eventId})`);
      return eventId;
    } catch (err) {
      console.error(`[EventBus] ❌ Failed to publish event ${eventType}:`, err.message);
      throw err;
    }
  }

  /**
   * Get next event to process (ordered by priority, then scheduled_at)
   * Includes built-in deadlock prevention via SKIP LOCKED
   */
  static async claimNextEvent(workerId) {
    const result = await pool.query(
      `UPDATE events
       SET status = 'processing', worker_id = $1
       WHERE id = (
         SELECT id FROM events
         WHERE status = 'pending' AND scheduled_at <= CURRENT_TIMESTAMP
         ORDER BY priority ASC, scheduled_at ASC
         LIMIT 1
         FOR UPDATE SKIP LOCKED
       )
       RETURNING id, event_type, aggregate_id, partition_key, payload, attempt_count`,
      [workerId]
    );

    if (result.rows.length === 0) {
      return null; // No events to process
    }

    return result.rows[0];
  }

  /**
   * Mark event as completed
   */
  static async completeEvent(eventId) {
    await pool.query(
      `UPDATE events
       SET status = 'completed', processed_at = CURRENT_TIMESTAMP, worker_id = NULL
       WHERE id = $1`,
      [eventId]
    );
  }

  /**
   * Mark event as failed and schedule retry
   */
  static async failEvent(eventId, errorMessage) {
    // Get current attempt count
    const res = await pool.query(
      `SELECT attempt_count, max_attempts FROM events WHERE id = $1`,
      [eventId]
    );

    if (res.rows.length === 0) return;

    const { attempt_count: currentAttempt, max_attempts: maxAttempts } = res.rows[0];
    const nextAttempt = currentAttempt + 1;

    // Calculate backoff: 30s, 2m, 10m, 30m, 2h
    const backoffMs = this.calculateBackoff(nextAttempt);
    const nextRetryAt = new Date(Date.now() + backoffMs);

    if (nextAttempt >= maxAttempts) {
      // Max retries exceeded, move to DLQ
      await pool.query(
        `UPDATE events
         SET status = 'dead_letter', attempt_count = $2, last_error = $3, failed_at = CURRENT_TIMESTAMP, worker_id = NULL
         WHERE id = $1`,
        [eventId, nextAttempt, errorMessage]
      );

      console.log(`[EventBus] ❌ Event moved to DLQ after ${nextAttempt} attempts: ${eventId}`);
    } else {
      // Schedule retry
      await pool.query(
        `UPDATE events
         SET status = 'pending', attempt_count = $2, last_error = $3, next_retry_at = $4, worker_id = NULL
         WHERE id = $1`,
        [eventId, nextAttempt, errorMessage, nextRetryAt]
      );

      console.log(
        `[EventBus] ⏰ Event scheduled for retry in ${backoffMs}ms: ${eventId} (attempt ${nextAttempt})`
      );
    }
  }

  /**
   * Calculate exponential backoff
   * Attempts: 30s, 2m, 10m, 30m, 2h
   */
  static calculateBackoff(attemptNumber) {
    const backoffs = [
      30 * 1000,      // 30 seconds
      2 * 60 * 1000,  // 2 minutes
      10 * 60 * 1000, // 10 minutes
      30 * 60 * 1000, // 30 minutes
      2 * 60 * 60 * 1000, // 2 hours
    ];

    if (attemptNumber >= backoffs.length) {
      return backoffs[backoffs.length - 1];
    }

    // Add jitter (±10%)
    const base = backoffs[attemptNumber - 1];
    const jitter = base * (Math.random() * 0.2 - 0.1);
    return base + jitter;
  }

  /**
   * Get event bus metrics
   */
  static async getMetrics() {
    const result = await pool.query(
      `SELECT
        COUNT(*) FILTER (WHERE status = 'pending') as pending_events,
        COUNT(*) FILTER (WHERE status = 'processing') as processing_events,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_events,
        COUNT(*) FILTER (WHERE status = 'dead_letter') as dlq_events
       FROM events`
    );

    return result.rows[0];
  }
}

module.exports = EventBus;
