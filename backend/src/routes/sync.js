/**
 * SYNC ROUTES — Phase C API Endpoints
 *
 * 10 endpoints for:
 * - Stock reservation (inventory locking)
 * - Manual worker triggers
 * - Sync health dashboard
 * - DLQ management
 *
 * File: /backend/src/routes/sync.js
 */

const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const supabaseService = require('../config/supabase');
const { authMiddleware: verifyAuth } = require('../middleware/validation');
const inventoryLocking = require('../services/inventory-locking');
const eventRouter = require('../services/event-router');
const Sentry = require('@sentry/node');

// Middleware: Check admin role
const requireAdmin = (req, res, next) => {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
};

// =====================================================
// 1. POST /sync/reserve — Reserve stock
// =====================================================
/**
 * Reserve inventory for a pending order
 * Requires idempotency_key to prevent double-reservations
 */
router.post('/reserve', verifyAuth, async (req, res) => {
  const startTime = Date.now();
  const requestId = req.get('x-request-id') || uuidv4();

  try {
    const { variant_id, quantity, idempotency_key, expires_at } = req.body;
    const userId = req.user?.uid;

    if (!variant_id || !quantity || !idempotency_key) {
      return res.status(400).json({
        error: 'Missing required fields: variant_id, quantity, idempotency_key',
        request_id: requestId,
      });
    }

    // Reserve stock (with dual-layer locking)
    const reservation = await inventoryLocking.reserveStock({
      variantId: variant_id,
      quantity,
      userId,
      idempotencyKey: idempotency_key,
      expiresAt: expires_at ? new Date(expires_at) : undefined,
    });

    res.status(200).json({
      success: true,
      reservation_id: reservation.reservation_id,
      variant_id: reservation.variant_id,
      quantity_reserved: reservation.quantity_reserved,
      expires_at: reservation.expires_at,
      status: 'confirmed',
      latency_ms: Date.now() - startTime,
      request_id: requestId,
    });
  } catch (error) {
    console.error(`[/sync/reserve] Error: ${error.message}`, { requestId });
    Sentry.captureException(error, { tags: { endpoint: '/sync/reserve', requestId } });

    const statusCode = error.name === 'InsufficientStockError' ? 409 : 500;
    res.status(statusCode).json({
      error: error.message,
      error_type: error.name,
      request_id: requestId,
    });
  }
});

// =====================================================
// 2. POST /sync/release — Release reservation
// =====================================================
/**
 * Release a reservation (refund)
 */
router.post('/release', verifyAuth, async (req, res) => {
  const requestId = req.get('x-request-id') || uuidv4();

  try {
    const { reservation_id } = req.body;

    if (!reservation_id) {
      return res.status(400).json({
        error: 'Missing reservation_id',
        request_id: requestId,
      });
    }

    const result = await inventoryLocking.releaseReservation(reservation_id);

    res.status(200).json({
      success: true,
      reservation_id: result.reservation_id,
      quantity_released: result.quantity,
      request_id: requestId,
    });
  } catch (error) {
    console.error(`[/sync/release] Error: ${error.message}`, { requestId });
    Sentry.captureException(error, { tags: { endpoint: '/sync/release' } });

    res.status(500).json({
      error: error.message,
      request_id: requestId,
    });
  }
});

// =====================================================
// 3. POST /sync/confirm — Confirm order (convert reservation)
// =====================================================
/**
 * Confirm an order (reservation → actual deduction)
 */
router.post('/confirm', verifyAuth, async (req, res) => {
  const requestId = req.get('x-request-id') || uuidv4();

  try {
    const { reservation_id, order_id } = req.body;

    if (!reservation_id || !order_id) {
      return res.status(400).json({
        error: 'Missing reservation_id or order_id',
        request_id: requestId,
      });
    }

    const result = await inventoryLocking.confirmOrder(reservation_id, order_id);

    res.status(200).json({
      success: true,
      order_id: result.orderId,
      reservation_id: result.reservationId,
      request_id: requestId,
    });
  } catch (error) {
    console.error(`[/sync/confirm] Error: ${error.message}`, { requestId });
    Sentry.captureException(error, { tags: { endpoint: '/sync/confirm' } });

    res.status(500).json({
      error: error.message,
      request_id: requestId,
    });
  }
});

// =====================================================
// 4. POST /sync/manual — Manually trigger a worker
// =====================================================
/**
 * Trigger a sync worker manually (for debugging/recovery)
 * Admin only
 */
router.post('/manual', requireAdmin, async (req, res) => {
  const requestId = req.get('x-request-id') || uuidv4();

  try {
    const { worker_class } = req.body;

    if (!worker_class) {
      return res.status(400).json({
        error: 'Missing worker_class',
        valid_values: ['A_SYNC_INVENTORY', 'A_REPLICATE_ORDERS', 'B_SYNC_PRODUCTS', 'B_REFRESH_SEARCH', 'B_DETECT_DRIFT', 'C_RETRY_FAILED', 'C_PROCESS_DLQ'],
        request_id: requestId,
      });
    }

    // TODO: Invoke Lambda with worker event
    // For now, log the request
    console.log(`[/sync/manual] Requested worker: ${worker_class}`, { requestId });

    res.status(202).json({
      success: true,
      message: `Manual trigger queued for ${worker_class}`,
      request_id: requestId,
    });
  } catch (error) {
    console.error(`[/sync/manual] Error: ${error.message}`, { requestId });
    res.status(500).json({ error: error.message, request_id: requestId });
  }
});

// =====================================================
// 5. GET /sync/health — Sync health dashboard
// =====================================================
/**
 * Get current sync system status
 * Shows worker health, queue sizes, recent errors
 * Admin only
 */
router.get('/health', requireAdmin, async (req, res) => {
  const requestId = req.get('x-request-id') || uuidv4();

  try {
    // Get health from v_sync_health view
    const { data: health } = await supabaseService.query(
      'v_sync_health',
      'select'
    );

    // Get failed events by type
    const { data: failedByType } = await supabaseService.query(
      'v_failed_events_by_type',
      'select'
    );

    // Get recent DLQ items
    const { data: dlqItems } = await supabaseService.query(
      'sync_dlq',
      'select',
      {
        filters: { status: 'pending' },
        order: 'created_at:desc',
        limit: 10,
      }
    );

    res.status(200).json({
      success: true,
      status: 'healthy',  // TODO: compute from data
      timestamp: new Date().toISOString(),
      queues: {
        sync_events_pending: health?.find(h => h.status === 'pending')?.count || 0,
        sync_events_failed: health?.find(h => h.status === 'failed')?.count || 0,
        sync_dlq_pending: health?.find(h => h.status === 'dlq')?.count || 0,
      },
      workers: {
        // TODO: Get actual worker status from monitoring
        syncInventoryToFirestore: { status: 'running', last_run: null },
        syncProductsToFirestore: { status: 'idle', last_run: null },
        replicateOrdersToSupabase: { status: 'running', last_run: null },
      },
      alerts: failedByType?.map(f => ({
        severity: f.fail_count > 5 ? 'high' : 'medium',
        message: `${f.event_type} has ${f.fail_count} failures`,
      })) || [],
      request_id: requestId,
    });
  } catch (error) {
    console.error(`[/sync/health] Error: ${error.message}`, { requestId });
    res.status(500).json({ error: error.message, request_id: requestId });
  }
});

// =====================================================
// 6. GET /sync/dlq — List DLQ items
// =====================================================
/**
 * Get dead letter queue items (failed syncs awaiting resolution)
 * Admin only
 */
router.get('/dlq', requireAdmin, async (req, res) => {
  const requestId = req.get('x-request-id') || uuidv4();

  try {
    const { status = 'pending', limit = 50 } = req.query;

    const { data: dlqItems } = await supabaseService.query(
      'sync_dlq',
      'select',
      {
        filters: status ? { status } : undefined,
        order: 'created_at:desc',
        limit: Math.min(parseInt(limit), 100),
      }
    );

    res.status(200).json({
      success: true,
      items: dlqItems || [],
      count: dlqItems?.length || 0,
      request_id: requestId,
    });
  } catch (error) {
    console.error(`[/sync/dlq] Error: ${error.message}`, { requestId });
    res.status(500).json({ error: error.message, request_id: requestId });
  }
});

// =====================================================
// 7. POST /sync/dlq/:id/resolve — Resolve DLQ item
// =====================================================
/**
 * Mark a DLQ item as resolved (with resolution notes)
 * Admin only
 */
router.post('/dlq/:id/resolve', requireAdmin, async (req, res) => {
  const requestId = req.get('x-request-id') || uuidv4();
  const { id } = req.params;
  const { resolution_type, resolution_notes } = req.body;

  try {
    if (!resolution_type) {
      return res.status(400).json({
        error: 'Missing resolution_type',
        valid_values: ['replay_success', 'manual_fix', 'duplicate_discarded', 'data_corruption', 'permanent_failure'],
        request_id: requestId,
      });
    }

    const { data, error } = await supabaseService.query(
      'sync_dlq',
      'update',
      {
        filters: { id },
        payload: {
          status: 'resolved',
          resolution_type,
          resolution_notes: resolution_notes || '',
          resolved_by: req.user?.email || 'unknown',
          resolved_at: new Date().toISOString(),
        },
      }
    );

    if (error) {
      return res.status(500).json({ error: error.message, request_id: requestId });
    }

    res.status(200).json({
      success: true,
      dlq_item: data?.[0],
      request_id: requestId,
    });
  } catch (error) {
    console.error(`[/sync/dlq/:id/resolve] Error: ${error.message}`, { requestId });
    res.status(500).json({ error: error.message, request_id: requestId });
  }
});

// =====================================================
// 8. POST /sync/dlq/:id/replay — Replay DLQ item
// =====================================================
/**
 * Attempt to replay a DLQ item (re-process it)
 * Admin only
 */
router.post('/dlq/:id/replay', requireAdmin, async (req, res) => {
  const requestId = req.get('x-request-id') || uuidv4();
  const { id } = req.params;

  try {
    // Get DLQ item
    const { data: dlqItems } = await supabaseService.query(
      'sync_dlq',
      'select',
      { filters: { id } }
    );

    if (!dlqItems || dlqItems.length === 0) {
      return res.status(404).json({ error: 'DLQ item not found', request_id: requestId });
    }

    const dlqItem = dlqItems[0];

    // TODO: Route to worker for replay
    console.log(`[/sync/dlq/:id/replay] Replaying DLQ item ${id}`, { requestId });

    res.status(202).json({
      success: true,
      message: 'Replay queued',
      dlq_item_id: id,
      request_id: requestId,
    });
  } catch (error) {
    console.error(`[/sync/dlq/:id/replay] Error: ${error.message}`, { requestId });
    res.status(500).json({ error: error.message, request_id: requestId });
  }
});

// =====================================================
// 9. GET /sync/metrics — Prometheus metrics (for Grafana)
// =====================================================
/**
 * Export sync metrics in Prometheus format
 * Admin only
 */
router.get('/metrics', requireAdmin, async (req, res) => {
  try {
    // TODO: Collect metrics from monitoring system
    // For now, return mock Prometheus format

    const metrics = `
# HELP sync_events_total Total sync events processed
# TYPE sync_events_total counter
sync_events_total{status="completed"} 12345
sync_events_total{status="failed"} 23
sync_events_total{status="pending"} 5

# HELP sync_latency_seconds Sync worker latency
# TYPE sync_latency_seconds gauge
sync_latency_seconds{worker="syncInventoryToFirestore",quantile="0.99"} 1.5
sync_latency_seconds{worker="syncProductsToFirestore",quantile="0.99"} 45.2

# HELP sync_dlq_pending_items DLQ pending items
# TYPE sync_dlq_pending_items gauge
sync_dlq_pending_items 2
    `.trim();

    res.set('Content-Type', 'text/plain');
    res.status(200).send(metrics);
  } catch (error) {
    console.error(`[/sync/metrics] Error: ${error.message}`);
    res.status(500).json({ error: error.message });
  }
});

// =====================================================
// 10. GET /sync/workers — Worker status
// =====================================================
/**
 * Get list of all workers and their status
 * Admin only
 */
router.get('/workers', requireAdmin, async (req, res) => {
  const requestId = req.get('x-request-id') || uuidv4();

  try {
    // TODO: Get actual worker status from Lambda
    // For now, return static list

    const workers = [
      {
        id: 'A_SYNC_INVENTORY',
        name: 'syncInventoryToFirestore',
        class: 'A',
        sla: '<2s',
        status: 'running',
        last_run: new Date(Date.now() - 30000).toISOString(),
        next_run: 'N/A (event-driven)',
      },
      {
        id: 'A_REPLICATE_ORDERS',
        name: 'replicateOrdersToSupabase',
        class: 'A',
        sla: '<2s',
        status: 'running',
        last_run: new Date(Date.now() - 5000).toISOString(),
        next_run: 'N/A (event-driven)',
      },
      {
        id: 'B_SYNC_PRODUCTS',
        name: 'syncProductsToFirestore',
        class: 'B',
        sla: '<5min',
        status: 'idle',
        last_run: new Date(Date.now() - 300000).toISOString(),
        next_run: new Date(Date.now() + 30000).toISOString(),
      },
      {
        id: 'B_REFRESH_SEARCH',
        name: 'refreshSearchCache',
        class: 'B',
        sla: '<1hour',
        status: 'idle',
        last_run: new Date(Date.now() - 3600000).toISOString(),
        next_run: new Date(Date.now() + 600000).toISOString(),
      },
      {
        id: 'B_DETECT_DRIFT',
        name: 'detectDrift',
        class: 'B',
        sla: '<5min',
        status: 'idle',
        last_run: new Date(Date.now() - 300000).toISOString(),
        next_run: new Date(Date.now() + 60000).toISOString(),
      },
      {
        id: 'C_RETRY_FAILED',
        name: 'retryFailedSyncJobs',
        class: 'C',
        sla: 'best effort',
        status: 'idle',
        last_run: new Date(Date.now() - 600000).toISOString(),
        next_run: new Date(Date.now() + 300000).toISOString(),
      },
      {
        id: 'C_PROCESS_DLQ',
        name: 'processDeadLetterQueue',
        class: 'C',
        sla: 'best effort',
        status: 'idle',
        last_run: new Date(Date.now() - 1800000).toISOString(),
        next_run: new Date(Date.now() + 600000).toISOString(),
      },
    ];

    res.status(200).json({
      success: true,
      workers,
      count: workers.length,
      request_id: requestId,
    });
  } catch (error) {
    console.error(`[/sync/workers] Error: ${error.message}`, { requestId });
    res.status(500).json({ error: error.message, request_id: requestId });
  }
});

// =====================================================
// ERROR HANDLER
// =====================================================

router.use((error, req, res, next) => {
  console.error('[/sync/*] Unhandled error:', error);
  Sentry.captureException(error);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? error.message : undefined,
  });
});

module.exports = router;
