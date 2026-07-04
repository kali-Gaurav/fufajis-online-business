/**
 * Firestore Sync Queue
 *
 * PROBLEM: Firestore sync can fail.
 * - Network timeout
 * - Rate limit
 * - Permission error
 *
 * If we just log + continue:
 * - Backend has correct data
 * - Firestore has stale data
 * - UI never catches up
 * - Data divergence forever
 *
 * SOLUTION: Retry queue with exponential backoff.
 *
 * Jobs:
 * 1. Try immediately
 * 2. If fail → queue for retry
 * 3. Retry with backoff: 1s, 2s, 4s, 8s, 16s
 * 4. After 5 retries → dead letter queue (alert ops)
 *
 * Storage: PostgreSQL sync_queue table
 */

const pool = require('../db/pool');
const firebaseAdmin = require('./firebaseAdmin');

// In-memory queue for immediate processing
const immediateQueue = [];
let isProcessing = false;

/**
 * Enqueue a sync job
 */
async function enqueueSyncJob(job) {
  const {
    type, // 'inventory_update', 'order_update', 'payment_update'
    productId,
    orderId,
    paymentId,
    data,
    retryCount = 0,
    maxRetries = 5,
  } = job;

  const jobId = `sync_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  const createdAt = new Date();
  const nextRetryAt = calculateNextRetryTime(retryCount);

  try {
    // Store in database
    const query = `
      INSERT INTO sync_queue (job_id, type, entity_type, entity_id, data, retry_count, max_retries, next_retry_at, status, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
    `;

    const entityType = type.split('_')[0]; // 'inventory', 'order', 'payment'
    const entityId = productId || orderId || paymentId;

    await db.query(query, [jobId, type, entityType, entityId, JSON.stringify(job), retryCount, maxRetries, nextRetryAt, 'pending']);

    // Try immediately if this is the first attempt
    if (retryCount === 0) {
      immediateQueue.push({ jobId, ...job });
      processQueue();
    }
  } catch (error) {
    console.error('Failed to enqueue sync job:', error);
  }
}

/**
 * Process queue
 */
async function processQueue() {
  if (isProcessing || immediateQueue.length === 0) {
    return;
  }

  isProcessing = true;

  while (immediateQueue.length > 0) {
    const job = immediateQueue.shift();

    try {
      await processSyncJob(job);

      // Mark as completed
      await pool.query('UPDATE sync_queue SET status = $1, completed_at = NOW() WHERE job_id = $2', ['completed', job.jobId]);
    } catch (error) {
      console.error(`Sync job ${job.jobId} failed:`, error);

      // Check if we should retry
      const newRetryCount = (job.retryCount || 0) + 1;

      if (newRetryCount >= (job.maxRetries || 5)) {
        // Dead letter — max retries exceeded
        await pool.query(
          'UPDATE sync_queue SET status = $1, error = $2, failed_at = NOW() WHERE job_id = $3',
          ['dead_letter', error.message, job.jobId]
        );

        // Alert ops
        console.error(`CRITICAL: Sync job ${job.jobId} moved to dead letter after ${newRetryCount} retries`, job);
      } else {
        // Schedule retry
        const nextRetryAt = calculateNextRetryTime(newRetryCount);
        await pool.query(
          'UPDATE sync_queue SET retry_count = $1, next_retry_at = $2, last_error = $3, status = $4 WHERE job_id = $5',
          [newRetryCount, nextRetryAt, error.message, 'retry_pending', job.jobId]
        );
      }
    }
  }

  isProcessing = false;
}

/**
 * Process a single sync job
 */
async function processSyncJob(job) {
  const { type, productId, orderId, newQuantity, status, data } = job;

  switch (type) {
    case 'inventory_update':
      return await syncInventoryToFirestore(productId, newQuantity);

    case 'order_update':
      return await syncOrderToFirestore(orderId, status);

    case 'payment_update':
      return await syncPaymentToFirestore(orderId, status);

    default:
      throw new Error(`Unknown sync job type: ${type}`);
  }
}

/**
 * Retry stuck jobs (called by background worker)
 */
async function retryStuckJobs() {
  try {
    const query = `
      SELECT job_id, type, entity_type, entity_id, data, retry_count, max_retries
      FROM sync_queue
      WHERE status = $1 AND next_retry_at <= NOW()
      ORDER BY next_retry_at ASC
      LIMIT 10
    `;

    const result = await pool.query(query, ['retry_pending']);

    for (const row of result.rows) {
      const job = JSON.parse(row.data);
      job.jobId = row.job_id;
      job.retryCount = row.retry_count;
      job.maxRetries = row.max_retries;

      immediateQueue.push(job);
    }

    if (immediateQueue.length > 0) {
      await processQueue();
    }
  } catch (error) {
    console.error('Failed to retry stuck jobs:', error);
  }
}

/**
 * Get dead letter jobs (failed permanently)
 */
async function getDeadLetterJobs() {
  try {
    const query = `
      SELECT job_id, type, entity_type, entity_id, retry_count, last_error, failed_at
      FROM sync_queue
      WHERE status = $1
      ORDER BY failed_at DESC
      LIMIT 100
    `;

    const result = await db.query(query, ['dead_letter']);
    return result.rows;
  } catch (error) {
    console.error('Failed to get dead letter jobs:', error);
    return [];
  }
}

/**
 * Calculate next retry time with exponential backoff
 */
function calculateNextRetryTime(retryCount) {
  // Backoff: 1s, 2s, 4s, 8s, 16s
  const backoffMs = Math.pow(2, retryCount) * 1000;
  const jitterMs = Math.random() * 1000; // Add jitter to prevent thundering herd
  return new Date(Date.now() + backoffMs + jitterMs);
}

/**
 * Sync inventory to Firestore
 */
async function syncInventoryToFirestore(productId, newQuantity) {
  const updatedAt = new Date().toISOString();

  await firestore.collection('inventory').doc(productId).set(
    {
      productId,
      quantity: newQuantity,
      syncedAt: updatedAt,
    },
    { merge: true }
  );

  console.log(`Synced inventory for product ${productId} to Firestore: quantity=${newQuantity}`);
}

/**
 * Sync order to Firestore
 */
async function syncOrderToFirestore(orderId, status) {
  const updatedAt = new Date().toISOString();

  await firestore.collection('orders').doc(orderId).set(
    {
      status,
      syncedAt: updatedAt,
    },
    { merge: true }
  );

  console.log(`Synced order ${orderId} to Firestore: status=${status}`);
}

/**
 * Sync payment to Firestore
 */
async function syncPaymentToFirestore(orderId, status) {
  const updatedAt = new Date().toISOString();

  await firestore.collection('orders').doc(orderId).set(
    {
      paymentStatus: status,
      paymentSyncedAt: updatedAt,
    },
    { merge: true }
  );

  console.log(`Synced payment for order ${orderId} to Firestore: status=${status}`);
}

/**
 * Start background worker
 */
function startSyncWorker() {
  // Retry stuck jobs every 30 seconds
  setInterval(() => {
    retryStuckJobs().catch(err => {
      console.error('Sync worker error:', err);
    });
  }, 30 * 1000);

  console.log('Sync queue worker started (retry interval: 30s)');
}

module.exports = {
  enqueueSyncJob,
  retryStuckJobs,
  getDeadLetterJobs,
  startSyncWorker,
};
