/**
 * EVENT ROUTER — Dispatch events to correct worker class
 *
 * Responsibility:
 * - Validate event schema
 * - Check for duplicates (idempotency)
 * - Route to Class A/B/C worker based on event type
 * - Handle routing failures gracefully
 *
 * File: /backend/src/services/event-router.js
 */

const { v4: uuidv4 } = require('uuid');
const supabaseService = require('../config/supabase');
const Sentry = require('@sentry/node');

/**
 * Worker class definitions
 */
const WORKER_CLASS = {
  A_SYNC_INVENTORY: 'A_SYNC_INVENTORY_TO_FIRESTORE',
  A_REPLICATE_ORDERS: 'A_REPLICATE_ORDERS_TO_SUPABASE',
  B_SYNC_PRODUCTS: 'B_SYNC_PRODUCTS_TO_FIRESTORE',
  B_REFRESH_SEARCH: 'B_REFRESH_SEARCH_CACHE',
  B_DETECT_DRIFT: 'B_DETECT_DRIFT',
  C_RETRY_FAILED: 'C_RETRY_FAILED_SYNC_JOBS',
  C_PROCESS_DLQ: 'C_PROCESS_DEAD_LETTER_QUEUE',
};

/**
 * Event type enum
 */
const EVENT_TYPE = {
  PRODUCT_CREATED: 'PRODUCT_CREATED',
  PRODUCT_UPDATED: 'PRODUCT_UPDATED',
  PRODUCT_DELETED: 'PRODUCT_DELETED',
  VARIANT_CREATED: 'VARIANT_CREATED',
  VARIANT_UPDATED: 'VARIANT_UPDATED',
  INVENTORY_UPDATED: 'INVENTORY_UPDATED',
  ORDER_CREATED: 'ORDER_CREATED',
  ORDER_STATUS_CHANGED: 'ORDER_STATUS_CHANGED',
  PRICE_CHANGED: 'PRICE_CHANGED',
  SYNC_FAILED: 'SYNC_FAILED',
  DRIFT_DETECTED: 'DRIFT_DETECTED',
};

/**
 * Validate event schema
 */
function validateEventSchema(event) {
  if (!event.event_type || !EVENT_TYPE[event.event_type]) {
    throw new Error(`Invalid event_type: ${event.event_type}`);
  }
  if (!event.entity_type) {
    throw new Error('Missing entity_type');
  }
  if (!event.entity_id) {
    throw new Error('Missing entity_id');
  }
  if (!event.payload || typeof event.payload !== 'object') {
    throw new Error('Missing or invalid payload');
  }
  if (!event.source_system) {
    throw new Error('Missing source_system');
  }
  return true;
}

/**
 * Check for duplicate event (idempotency)
 * Returns: { isDuplicate: boolean, existingEvent?: object }
 */
async function checkIdempotency(event) {
  try {
    // event_id_checksum is composite key: event_id + source + entity_type
    const eventIdChecksum = event.event_id_checksum ||
      `${event.source_system}:${event.event_type}:${event.entity_id}`;

    const { data, error } = await supabaseService.query(
      'sync_events',
      'select',
      {
        filters: {
          event_id_checksum: eventIdChecksum,
          entity_type: event.entity_type,
          source_system: event.source_system,
        },
      }
    );

    if (error) {
      console.warn('[EventRouter] Idempotency check failed:', error.message);
      return { isDuplicate: false };  // Fail open (process the event)
    }

    if (!data || data.length === 0) {
      return { isDuplicate: false };  // New event
    }

    const existingEvent = data[0];

    // If already completed, skip
    if (existingEvent.status === 'completed') {
      console.log(`[EventRouter] Duplicate (completed): ${eventIdChecksum}`);
      return { isDuplicate: true, existingEvent };
    }

    // If in progress, skip (don't double-process)
    if (existingEvent.status === 'processing') {
      console.log(`[EventRouter] Duplicate (in-progress): ${eventIdChecksum}`);
      return { isDuplicate: true, existingEvent };
    }

    // If failed, allow retry (return false)
    return { isDuplicate: false };
  } catch (error) {
    console.error('[EventRouter] Idempotency check error:', error.message);
    return { isDuplicate: false };  // Fail open
  }
}

/**
 * DECISION TREE: Route event to correct worker class
 */
function routeEvent(event) {
  const { event_type, source_system, batch_size = 1 } = event;

  // CLASS A: Realtime (<2s SLA)
  if (event_type === EVENT_TYPE.INVENTORY_UPDATED) {
    if (source_system === 'supabase') {
      return WORKER_CLASS.A_SYNC_INVENTORY;
    }
    if (source_system === 'firestore') {
      return WORKER_CLASS.A_REPLICATE_ORDERS;
    }
  }

  if (event_type === EVENT_TYPE.ORDER_CREATED) {
    return WORKER_CLASS.A_REPLICATE_ORDERS;
  }

  // CLASS B: Scheduled (5m-1h SLA)
  if (
    event_type === EVENT_TYPE.PRODUCT_CREATED ||
    event_type === EVENT_TYPE.PRODUCT_UPDATED ||
    event_type === EVENT_TYPE.PRODUCT_DELETED ||
    event_type === EVENT_TYPE.VARIANT_CREATED ||
    event_type === EVENT_TYPE.VARIANT_UPDATED ||
    event_type === EVENT_TYPE.PRICE_CHANGED
  ) {
    // Single item: sync individually
    // Batch: queue for scheduled batch job
    return batch_size > 50
      ? WORKER_CLASS.B_SYNC_PRODUCTS  // Will batch in worker
      : WORKER_CLASS.B_SYNC_PRODUCTS;
  }

  if (event_type === 'SEARCH_CACHE_STALE') {
    return WORKER_CLASS.B_REFRESH_SEARCH;
  }

  if (event_type === EVENT_TYPE.DRIFT_DETECTED) {
    return WORKER_CLASS.B_DETECT_DRIFT;
  }

  // CLASS C: Recovery (Best Effort)
  if (event_type === EVENT_TYPE.SYNC_FAILED) {
    return WORKER_CLASS.C_RETRY_FAILED;
  }

  if (event_type === 'DLQ_ITEM_PENDING') {
    return WORKER_CLASS.C_PROCESS_DLQ;
  }

  // Unknown event type
  throw new Error(`No worker route for event_type: ${event_type}`);
}

/**
 * Get worker class SLA (for timeout configuration)
 */
function getWorkerSLA(workerClass) {
  const SLAs = {
    [WORKER_CLASS.A_SYNC_INVENTORY]: { timeout: 30, targetLatency: 2 },  // seconds
    [WORKER_CLASS.A_REPLICATE_ORDERS]: { timeout: 30, targetLatency: 2 },
    [WORKER_CLASS.B_SYNC_PRODUCTS]: { timeout: 300, targetLatency: 300 },
    [WORKER_CLASS.B_REFRESH_SEARCH]: { timeout: 300, targetLatency: 300 },
    [WORKER_CLASS.B_DETECT_DRIFT]: { timeout: 300, targetLatency: 300 },
    [WORKER_CLASS.C_RETRY_FAILED]: { timeout: 600, targetLatency: 600 },
    [WORKER_CLASS.C_PROCESS_DLQ]: { timeout: 600, targetLatency: 600 },
  };
  return SLAs[workerClass] || { timeout: 30, targetLatency: 30 };
}

/**
 * Log event to sync_events table
 */
async function logEvent(event, status = 'pending', errorMessage = null) {
  try {
    const eventIdChecksum = event.event_id_checksum ||
      `${event.source_system}:${event.event_type}:${event.entity_id}`;

    const payload = {
      event_type: event.event_type,
      entity_type: event.entity_type,
      entity_id: event.entity_id,
      payload: event.payload,
      status,
      event_id_checksum: eventIdChecksum,
      version: 1,
      retry_count: 0,
      max_retries: 3,
      source_system: event.source_system,
      source_table: event.source_table,
      source_operation: event.source_operation,
      error_message: errorMessage,
      priority: getWorkerSLA(routeEvent(event)).targetLatency <= 2 ? 1 : 5,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { data, error } = await supabaseService.query(
      'sync_events',
      'insert',
      { payload }
    );

    if (error) {
      console.error('[EventRouter] Failed to log event:', error.message);
      return null;
    }

    return data?.[0];
  } catch (error) {
    console.error('[EventRouter] Log event error:', error.message);
    return null;
  }
}

/**
 * Move event to DLQ (dead letter queue)
 */
async function moveToDeadLetterQueue(event, errorMessage, errorCode) {
  try {
    const payload = {
      event_type: event.event_type,
      entity_type: event.entity_type,
      entity_id: event.entity_id,
      payload: event.payload,
      status: 'pending',
      failure_reason: errorCode,
      severity: event_type === 'INVENTORY_UPDATED' ? 'critical' : 'high',
      error_details: {
        message: errorMessage,
        timestamp: new Date().toISOString(),
      },
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { data, error } = await supabaseService.query(
      'sync_dlq',
      'insert',
      { payload }
    );

    if (error) {
      console.error('[EventRouter] Failed to move to DLQ:', error.message);
      return null;
    }

    return data?.[0];
  } catch (error) {
    console.error('[EventRouter] DLQ move error:', error.message);
    return null;
  }
}

/**
 * MAIN ROUTER FUNCTION
 *
 * Orchestrates event routing:
 * 1. Validate schema
 * 2. Check idempotency
 * 3. Route to worker class
 * 4. Log to sync_events
 * 5. Return routing decision
 */
async function routeEventToWorker(event) {
  const startTime = Date.now();
  const requestId = event.requestId || uuidv4();

  try {
    // Step 1: Validate
    validateEventSchema(event);

    // Step 2: Check idempotency
    const { isDuplicate, existingEvent } = await checkIdempotency(event);
    if (isDuplicate) {
      console.log(`[EventRouter] Skipping duplicate event: ${requestId}`);
      return {
        success: true,
        routed: false,
        reason: 'duplicate',
        requestId,
        existingEventId: existingEvent?.id,
      };
    }

    // Step 3: Route to worker class
    const workerClass = routeEvent(event);
    const sla = getWorkerSLA(workerClass);

    // Step 4: Log to sync_events
    const syncEvent = await logEvent(event, 'pending');
    if (!syncEvent) {
      // Fallback if logging fails
      console.warn('[EventRouter] Event logging failed, but proceeding');
    }

    console.log(`[EventRouter] Routed ${event.event_type} → ${workerClass} (requestId: ${requestId})`);

    // Step 5: Return routing decision
    return {
      success: true,
      routed: true,
      requestId,
      syncEventId: syncEvent?.id,
      workerClass,
      sla,
      estimatedLatency: sla.targetLatency,
      routedAt: new Date().toISOString(),
    };
  } catch (error) {
    console.error(`[EventRouter] Routing error: ${error.message}`, { requestId });

    // Log error to Sentry
    Sentry.captureException(error, {
      tags: { component: 'event-router', requestId },
      contexts: { event },
    });

    // Move to DLQ for manual review
    await moveToDeadLetterQueue(
      event,
      error.message,
      error.code || 'ROUTING_ERROR'
    );

    // Alert ops
    if (event.event_type === EVENT_TYPE.INVENTORY_UPDATED) {
      console.error(`[ALERT] Critical: Inventory event routing failed - ${error.message}`);
      // TODO: Trigger PagerDuty alert
    }

    return {
      success: false,
      routed: false,
      reason: 'routing_error',
      error: error.message,
      requestId,
      routedAt: new Date().toISOString(),
    };
  }
}

/**
 * Get worker class details
 */
function getWorkerDetails(workerClass) {
  const details = {
    [WORKER_CLASS.A_SYNC_INVENTORY]: {
      name: 'syncInventoryToFirestore',
      class: 'A',
      sla: '<2s',
      description: 'Sync inventory from Supabase to Firestore cache',
    },
    [WORKER_CLASS.A_REPLICATE_ORDERS]: {
      name: 'replicateOrdersToSupabase',
      class: 'A',
      sla: '<2s',
      description: 'Replicate orders from Firestore to Supabase',
    },
    [WORKER_CLASS.B_SYNC_PRODUCTS]: {
      name: 'syncProductsToFirestore',
      class: 'B',
      sla: '<5min',
      description: 'Batch sync products to Firestore',
    },
    [WORKER_CLASS.B_REFRESH_SEARCH]: {
      name: 'refreshSearchCache',
      class: 'B',
      sla: '<1hour',
      description: 'Rebuild search cache (FTS)',
    },
    [WORKER_CLASS.B_DETECT_DRIFT]: {
      name: 'detectDrift',
      class: 'B',
      sla: '<5min',
      description: 'Detect drift between Firestore and Supabase',
    },
    [WORKER_CLASS.C_RETRY_FAILED]: {
      name: 'retryFailedSyncJobs',
      class: 'C',
      sla: 'best effort',
      description: 'Retry failed sync jobs with exponential backoff',
    },
    [WORKER_CLASS.C_PROCESS_DLQ]: {
      name: 'processDeadLetterQueue',
      class: 'C',
      sla: 'best effort',
      description: 'Process and resolve DLQ items',
    },
  };
  return details[workerClass];
}

module.exports = {
  routeEventToWorker,
  logEvent,
  moveToDeadLetterQueue,
  checkIdempotency,
  validateEventSchema,
  routeEvent,
  getWorkerSLA,
  getWorkerDetails,
  WORKER_CLASS,
  EVENT_TYPE,
};
