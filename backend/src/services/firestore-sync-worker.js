/**
 * Firestore Sync Worker
 * 
 * Architecture:
 *   Supabase Edge Functions → outbox_events table → THIS WORKER → Firestore
 *
 * Runs as a background cron on Render every 5 seconds.
 * Polls unprocessed outbox_events and mirrors them into Firestore.
 * Postgres stays source of truth; Firestore is read-only sync layer for Flutter.
 */

'use strict';

const { createClient } = require('@supabase/supabase-js');
const admin = require('firebase-admin');

// ─── Firebase Init ────────────────────────────────────────────────────────────
let _db = null;

function getFirestore() {
  if (_db) return _db;

  if (!admin.apps.length) {
    const serviceAccountRaw = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
    if (!serviceAccountRaw) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_KEY env var is missing');
    }

    let serviceAccount;
    try {
      serviceAccount = JSON.parse(serviceAccountRaw);
    } catch {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_KEY is not valid JSON');
    }

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    console.log('[FirestoreSync] Firebase Admin initialized');
  }

  _db = admin.firestore();
  return _db;
}

// ─── Supabase Client ──────────────────────────────────────────────────────────
function getSupabase() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.supabase_service_role;

  if (!url || !key) {
    throw new Error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY env vars missing');
  }

  return createClient(url, key);
}

// ─── Event Handlers ───────────────────────────────────────────────────────────

/**
 * Map Supabase outbox event types → Firestore handler functions
 */
const HANDLERS = {
  order_status_changed: syncOrderStatusChanged,
  order_delivered:      syncOrderDelivered,
  order_created:        syncOrderCreated,
  order_cancelled:      syncOrderCancelled,
  inventory_updated:    syncInventoryUpdated,
  payment_completed:    syncPaymentCompleted,
};

async function syncOrderStatusChanged(db, payload) {
  const { orderId, newStatus, order } = payload;
  await db.collection('orders').doc(orderId).set(
    {
      status: newStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(order ? { ...flattenOrder(order) } : {}),
    },
    { merge: true }
  );
  console.log(`[FirestoreSync] order/${orderId} status → ${newStatus}`);
}

async function syncOrderDelivered(db, payload) {
  const { orderId, order } = payload;
  await db.collection('orders').doc(orderId).set(
    {
      status: 'delivered',
      deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(order ? { ...flattenOrder(order) } : {}),
    },
    { merge: true }
  );
  console.log(`[FirestoreSync] order/${orderId} → delivered`);
}

async function syncOrderCreated(db, payload) {
  const { orderId, order } = payload;
  if (!order) return;
  await db.collection('orders').doc(orderId).set(
    {
      ...flattenOrder(order),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`[FirestoreSync] order/${orderId} created`);
}

async function syncOrderCancelled(db, payload) {
  const { orderId, reason } = payload;
  await db.collection('orders').doc(orderId).set(
    {
      status: 'cancelled',
      cancellationReason: reason ?? '',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`[FirestoreSync] order/${orderId} → cancelled`);
}

async function syncInventoryUpdated(db, payload) {
  const { productId, branchId, newStock } = payload;
  const docId = `${productId}_${branchId ?? 'primary'}`;
  await db.collection('inventory').doc(docId).set(
    {
      productId,
      branchId: branchId ?? 'primary',
      availableStock: newStock,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`[FirestoreSync] inventory/${docId} stock → ${newStock}`);
}

async function syncPaymentCompleted(db, payload) {
  const { orderId, paymentId, amount, method } = payload;
  await db.collection('payments').doc(paymentId).set(
    {
      orderId,
      paymentId,
      amount,
      method,
      status: 'completed',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: false }
  );
  console.log(`[FirestoreSync] payment/${paymentId} recorded`);
}

/** Strip Postgres-only fields before writing to Firestore */
function flattenOrder(order) {
  const { id, customer_id, shop_id, ...rest } = order;
  return {
    id,
    customerId: customer_id,
    shopId: shop_id,
    ...rest,
  };
}

// ─── Worker State & Metrics ──────────────────────────────────────────────────

let _worker_running = false;
let _worker_interval = null;
let _metrics = {
  processed: 0,
  failed: 0,
  queue_depth: 0,
  last_poll: null,
  last_error: null,
};

// ─── Main Polling Loop ────────────────────────────────────────────────────────

const BATCH_SIZE = 25;
const POLL_INTERVAL_MS = 5_000;
const MAX_RETRY = 3;

async function processOutbox() {
  if (!_worker_running) return;

  try {
    const supabase = getSupabase();
    const db = getFirestore();

    // Fetch unprocessed events ordered by creation time
    const { data: events, error } = await supabase
      .from('outbox_events')
      .select('*')
      .eq('processed', false)
      .lt('retry_count', MAX_RETRY)
      .order('created_at', { ascending: true })
      .limit(BATCH_SIZE);

    if (error) {
      console.error('[FirestoreSync] Failed to fetch outbox_events:', error.message);
      _metrics.last_error = error.message;
      return;
    }

    // Update queue depth metric
    _metrics.queue_depth = events ? events.length : 0;
    _metrics.last_poll = new Date().toISOString();

    if (!events || events.length === 0) return;

    console.log(`[FirestoreSync] Processing ${events.length} event(s)...`);

    for (const event of events) {
      const handler = HANDLERS[event.event_type];
      if (!handler) {
        console.warn(`[FirestoreSync] Unknown event type: ${event.event_type} — skipping`);
        await markProcessed(supabase, event.id, null, 'Unknown event type — skipped');
        _metrics.processed++;
        continue;
      }

      try {
        await handler(db, event.payload ?? {});
        await markProcessed(supabase, event.id, null, null);
        _metrics.processed++;
      } catch (err) {
        console.error(`[FirestoreSync] Event ${event.id} (${event.event_type}) failed:`, err.message);
        await markProcessed(supabase, event.id, err, null);
        _metrics.failed++;
        _metrics.last_error = err.message;
      }
    }
  } catch (error) {
    console.error('[FirestoreSync] processOutbox error:', error.message);
    _metrics.last_error = error.message;
  }
}

async function markProcessed(supabase, id, err, skipReason) {
  if (err) {
    // Increment retry_count; don't mark as processed yet
    await supabase
      .from('outbox_events')
      .update({
        retry_count: supabase.rpc('increment', { x: 1 }), // fallback below
        last_error: err.message,
      })
      .eq('id', id);

    // Simpler increment without RPC:
    await supabase.rpc('increment_retry_count', { event_id: id }).catch(() => {
      // If the RPC doesn't exist yet, just update with raw SQL fallback
      supabase
        .from('outbox_events')
        .update({ last_error: err.message })
        .eq('id', id);
    });
  } else {
    await supabase
      .from('outbox_events')
      .update({
        processed: true,
        processed_at: new Date().toISOString(),
        ...(skipReason ? { last_error: skipReason } : {}),
      })
      .eq('id', id);
  }
}

// ─── Worker Control & Health ──────────────────────────────────────────────────

async function start() {
  if (_worker_running) {
    console.log('[FirestoreSync] Worker already running');
    return;
  }

  _worker_running = true;
  console.log('[FirestoreSync] Sync worker starting...');
  console.log(`[FirestoreSync] Polling every ${POLL_INTERVAL_MS / 1000}s, batch size: ${BATCH_SIZE}`);

  // Initial check
  await processOutbox().catch(err => console.error('[FirestoreSync] Initial poll error:', err.message));

  // Poll on interval
  _worker_interval = setInterval(async () => {
    try {
      await processOutbox();
    } catch (err) {
      console.error('[FirestoreSync] Poll error:', err.message);
      _metrics.last_error = err.message;
    }
  }, POLL_INTERVAL_MS);
}

function stop() {
  if (!_worker_running) {
    console.log('[FirestoreSync] Worker not running');
    return;
  }

  _worker_running = false;
  if (_worker_interval) {
    clearInterval(_worker_interval);
    _worker_interval = null;
  }
  console.log('[FirestoreSync] Sync worker stopped');
}

async function getHealth() {
  return {
    running: _worker_running,
    processed: _metrics.processed,
    failed: _metrics.failed,
    queue_depth: _metrics.queue_depth,
    last_poll: _metrics.last_poll,
    last_error: _metrics.last_error,
  };
}

// Auto-start on module load
start();

// Export for external control
module.exports = {
  start,
  stop,
  getHealth,
};
