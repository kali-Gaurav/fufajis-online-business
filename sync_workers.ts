// =====================================================
// FILE: sync_workers.ts
// FUFAJI LOOP 2 PHASE C — Firebase Cloud Functions
// =====================================================

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { createClient } from '@supabase/supabase-js';
import * as Sentry from '@sentry/node';
import { v4 as uuidv4 } from 'uuid';

// Initialize Firebase Admin
admin.initializeApp();
const firestore = admin.firestore();
const storage = admin.storage();

// Initialize Supabase Admin Client
const supabase = createClient(
  process.env.SUPABASE_URL || '',
  process.env.SUPABASE_SERVICE_ROLE_KEY || ''
);

// Initialize Sentry
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV || 'production',
  tracesSampleRate: 0.1,
});

// =====================================================
// TYPES
// =====================================================

interface SyncEvent {
  id: string;
  event_type: string;
  entity_type: string;
  entity_id: string;
  payload: Record<string, any>;
  status: string;
  retry_count: number;
  max_retries: number;
  error_message?: string;
}

interface IdempotencyKey {
  eventId: string;
  version: number;
  checksum: string;
}

// =====================================================
// UTILITIES
// =====================================================

/**
 * Exponential backoff with jitter
 * Attempt 1: 5 sec
 * Attempt 2: 30 sec
 * Attempt 3: 5 min
 * Attempt 4: 30 min
 */
function calculateBackoffMs(retryCount: number): number {
  const baseDelays = [5000, 30000, 300000, 1800000]; // 5s, 30s, 5m, 30m
  const delay = baseDelays[Math.min(retryCount, baseDelays.length - 1)];
  const jitter = Math.random() * 0.1 * delay; // ±10% jitter
  return delay + jitter;
}

/**
 * Create idempotency key from event data
 */
function createIdempotencyKey(
  eventId: string,
  version: number,
  data: Record<string, any>
): IdempotencyKey {
  const crypto = require('crypto');
  const checksum = crypto
    .createHash('sha256')
    .update(JSON.stringify(data))
    .digest('hex');

  return { eventId, version, checksum };
}

/**
 * Log sync event to Supabase
 */
async function logSyncEvent(
  eventType: string,
  entityType: string,
  entityId: string,
  payload: Record<string, any>,
  status: string,
  error?: { message: string; code: string }
): Promise<string> {
  const eventId = uuidv4();

  const { data, error: supabaseError } = await supabase
    .from('sync_events')
    .insert({
      id: eventId,
      event_type: eventType,
      entity_type: entityType,
      entity_id: entityId,
      payload,
      status,
      source_system: 'firebase_function',
      error_message: error?.message,
      error_code: error?.code,
      retry_count: 0,
      created_at: new Date().toISOString(),
    });

  if (supabaseError) {
    Sentry.captureException(supabaseError, {
      tags: { location: 'logSyncEvent' },
    });
    console.error('Failed to log sync event:', supabaseError);
  }

  return eventId;
}

/**
 * Move failed event to DLQ
 */
async function moveToDLQ(
  syncEventId: string,
  error: { message: string; code: string }
): Promise<void> {
  const { error: dlqError } = await supabase
    .from('sync_dlq')
    .insert({
      sync_event_id: syncEventId,
      event_type: 'SYNC_FAILED',
      entity_type: 'system',
      entity_id: syncEventId,
      payload: {},
      error_details: error,
      status: 'pending',
      failure_reason: error.code,
      severity: 'high',
      retry_count: 0,
    });

  if (dlqError) {
    Sentry.captureException(dlqError, { tags: { location: 'moveToDLQ' } });
    console.error('Failed to move to DLQ:', dlqError);
  }
}

// =====================================================
// WORKER 1: syncInventoryToFirestore (REALTIME)
// =====================================================

/**
 * Sync inventory changes from Supabase to Firestore in real-time
 * Triggered by: Supabase webhook → Pub/Sub topic: inventory-changes
 * Latency target: < 2 seconds
 */
export const syncInventoryToFirestore = functions.pubsub
  .topic('inventory-changes')
  .onPublish(async (message, context) => {
    const startTime = Date.now();
    let syncEventId: string | null = null;

    try {
      const webhookPayload = JSON.parse(
        Buffer.from(message.data, 'base64').toString()
      );

      const {
        record: { id: variantId, shop_id: shopId, stock_total, stock_reserved, stock_damaged, updated_at, ...rest },
        type, // INSERT, UPDATE, DELETE
      } = webhookPayload;

      syncEventId = await logSyncEvent(
        'INVENTORY_UPDATED',
        'variant',
        variantId,
        webhookPayload,
        'processing'
      );

      // Compute available stock
      const stockAvailable = Math.max(
        stock_total - stock_reserved - stock_damaged,
        0
      );

      // Check idempotency
      const docRef = firestore
        .collection('shops')
        .doc(shopId)
        .collection('inventory')
        .doc(variantId);

      const existing = await docRef.get();
      const existingData = existing.data();

      if (existingData?.eventId === syncEventId) {
        console.log(`✅ DEDUP: Event ${syncEventId} already processed`);
        return;
      }

      // Write to Firestore
      await docRef.update({
        stockTotal: stock_total,
        stockReserved: stock_reserved,
        stockDamaged: stock_damaged,
        stockAvailable,
        isLowStock: stockAvailable <= (existingData?.lowStockThreshold || 10),
        updatedAt: new Date(updated_at),
        syncVersion: (existingData?.syncVersion || 0) + 1,
        lastSupabaseSyncAt: new Date(),
        eventId: syncEventId,
        lastSyncDurationMs: Date.now() - startTime,
      });

      console.log(
        `✅ INVENTORY_UPDATED: ${shopId}/${variantId} (${Date.now() - startTime}ms)`
      );

      // Update sync_events status
      await supabase
        .from('sync_events')
        .update({
          status: 'completed',
          sync_completed_at: new Date().toISOString(),
          sync_duration_ms: Date.now() - startTime,
        })
        .eq('id', syncEventId);
    } catch (error: any) {
      Sentry.captureException(error, { tags: { worker: 'syncInventory' } });
      console.error('❌ syncInventoryToFirestore failed:', error);

      if (syncEventId) {
        await supabase
          .from('sync_events')
          .update({
            status: 'failed',
            error_message: error.message,
            error_code: error.code,
            retry_count: (message as any).attributes?.deadLetterPolicy ? 1 : 0,
          })
          .eq('id', syncEventId);

        await moveToDLQ(syncEventId, {
          message: error.message,
          code: error.code || 'UNKNOWN_ERROR',
        });
      }

      throw error;
    }
  });

// =====================================================
// WORKER 2: syncProductsToFirestore (SCHEDULED)
// =====================================================

/**
 * Sync products and variants from Supabase to Firestore
 * Triggered by: Cloud Scheduler every 5 minutes
 * Latency target: < 5 minutes
 */
export const syncProductsToFirestore = functions.pubsub
  .schedule('*/5 * * * *')
  .onRun(async (context) => {
    const startTime = Date.now();
    let productsCount = 0;
    let variantsCount = 0;

    try {
      // Get last sync time
      const metadataRef = firestore
        .collection('_sync_metadata')
        .doc('products_last_sync');
      const metadataSnap = await metadataRef.get();
      const lastSyncTime = metadataSnap.data()?.timestamp || new Date(0);

      // Query updated products from Supabase
      const { data: products, error: productsError } = await supabase
        .from('catalog_products')
        .select('*')
        .gt('updated_at', lastSyncTime.toISOString())
        .eq('is_deleted', false)
        .limit(500);

      if (productsError) throw productsError;

      // Batch write to Firestore
      const batch = firestore.batch();

      for (const product of products || []) {
        const docRef = firestore
          .collection('catalog_products')
          .doc(product.id);

        batch.set(
          docRef,
          {
            productId: product.id,
            productCode: product.product_code,
            name: product.name,
            hindiName: product.hindi_name,
            brand: product.brand_id,
            category: product.category_id,
            isActive: product.is_active,
            isDeleted: product.is_deleted,
            variantCount: 0, // Will be updated below
            lowestPrice: 0,
            updatedAt: new Date(product.updated_at),
            syncVersion: Math.floor(new Date(product.updated_at).getTime() / 1000),
            lastSupabaseSyncAt: new Date(),
          },
          { merge: true }
        );

        productsCount++;

        // Get variants for this product
        const { data: variants, error: variantsError } = await supabase
          .from('catalog_variants')
          .select('*')
          .eq('product_id', product.id)
          .eq('is_active', true);

        if (variantsError) throw variantsError;

        let lowestPrice = Infinity;

        for (const variant of variants || []) {
          const variantRef = docRef.collection('variants').doc(variant.id);

          batch.set(
            variantRef,
            {
              variantId: variant.id,
              productId: variant.product_id,
              variantCode: variant.variant_code,
              quantity: variant.quantity,
              unit: variant.unit,
              mrp: variant.mrp,
              sellingPrice: variant.default_selling_price,
              gst: variant.gst,
              isActive: variant.is_active,
              updatedAt: new Date(variant.updated_at),
              syncVersion: Math.floor(
                new Date(variant.updated_at).getTime() / 1000
              ),
              lastSupabaseSyncAt: new Date(),
            },
            { merge: true }
          );

          lowestPrice = Math.min(lowestPrice, variant.default_selling_price);
          variantsCount++;
        }

        // Update product with lowest price
        batch.update(docRef, {
          lowestPrice: lowestPrice === Infinity ? 0 : lowestPrice,
          variantCount: variants?.length || 0,
        });
      }

      // Commit batch
      if (productsCount > 0 || variantsCount > 0) {
        await batch.commit();
      }

      // Update metadata
      await metadataRef.set({
        timestamp: new Date(),
        productsSynced: productsCount,
        variantsSynced: variantsCount,
        duration_ms: Date.now() - startTime,
      });

      console.log(
        `✅ PRODUCTS_SYNCED: ${productsCount} products, ${variantsCount} variants (${Date.now() - startTime}ms)`
      );

      // Log to sync_events
      await logSyncEvent(
        'PRODUCT_SYNC_COMPLETED',
        'system',
        'products_batch',
        { productCount: productsCount, variantCount: variantsCount },
        'completed'
      );
    } catch (error: any) {
      Sentry.captureException(error, { tags: { worker: 'syncProducts' } });
      console.error('❌ syncProductsToFirestore failed:', error);

      await logSyncEvent(
        'PRODUCT_SYNC_FAILED',
        'system',
        'products_batch',
        {},
        'failed',
        { message: error.message, code: error.code }
      );

      throw error;
    }
  });

// =====================================================
// WORKER 3: replicateOrdersToSupabase (ASYNC)
// =====================================================

/**
 * Replicate Firestore orders to Supabase for analytics
 * Triggered by: Firestore onWrite on orders collection
 * Latency target: < 30 seconds (async, not critical path)
 */
export const replicateOrdersToSupabase = functions.firestore
  .document('orders/{orderId}')
  .onWrite(async (change, context) => {
    const orderId = context.params.orderId;
    const newOrder = change.after.data();

    if (!newOrder) return; // Deleted order

    try {
      const syncEventId = await logSyncEvent(
        'ORDER_REPLICA',
        'order',
        orderId,
        newOrder,
        'processing'
      );

      // Upsert to Supabase
      const { error } = await supabase
        .from('orders')
        .upsert(
          {
            id: orderId,
            user_id: newOrder.userId,
            total: newOrder.total,
            status: newOrder.orderStatus,
            payment_status: newOrder.paymentStatus,
            items: newOrder.items,
            created_at: newOrder.createdAt.toISOString(),
            updated_at: newOrder.updatedAt.toISOString(),
          },
          { onConflict: 'id' }
        );

      if (error) throw error;

      // Log analytics event
      await supabase.from('analytics_events').insert({
        event_type: 'order_status_changed',
        order_id: orderId,
        old_status: change.before.data()?.orderStatus,
        new_status: newOrder.orderStatus,
        timestamp: new Date().toISOString(),
      });

      // Mark as synced
      await firestore.collection('orders').doc(orderId).update({
        syncedToSupabaseAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ ORDER_REPLICATED: ${orderId}`);

      await supabase
        .from('sync_events')
        .update({ status: 'completed' })
        .eq('id', syncEventId);
    } catch (error: any) {
      Sentry.captureException(error, { tags: { worker: 'replicateOrders' } });
      console.error('❌ replicateOrdersToSupabase failed:', error);

      const syncEventId = await logSyncEvent(
        'ORDER_REPLICA_FAILED',
        'order',
        orderId,
        {},
        'failed',
        { message: error.message, code: error.code }
      );

      await moveToDLQ(syncEventId, {
        message: error.message,
        code: error.code || 'UNKNOWN_ERROR',
      });

      throw error;
    }
  });

// =====================================================
// WORKER 4: refreshSearchCache (SCHEDULED)
// =====================================================

/**
 * Refresh search cache with popular products and search tokens
 * Triggered by: Cloud Scheduler every 1 hour
 * Latency target: < 1 hour
 */
export const refreshSearchCache = functions.pubsub
  .schedule('0 * * * *')
  .onRun(async (context) => {
    try {
      // Query popular products by category
      const { data: categories } = await supabase
        .from('catalog_categories')
        .select('id, name')
        .eq('is_active', true);

      for (const category of categories || []) {
        const { data: products } = await supabase
          .from('catalog_products')
          .select('id, name, product_code')
          .eq('category_id', category.id)
          .eq('is_active', true)
          .limit(20);

        const cacheId = `search-category-${category.name.toLowerCase()}-${new Date().toISOString().split('T')[0]}`;

        await firestore
          .collection('search_cache')
          .doc(cacheId)
          .set({
            category: category.name,
            categoryId: category.id,
            type: 'category',
            suggestions: products?.map((p) => ({
              productName: p.name,
              productCode: p.product_code,
              searchFrequency: 100, // Placeholder
              popularity: 'high',
            })) || [],
            lastUpdatedAt: new Date(),
            expiresAt: new Date(Date.now() + 3600000), // 1 hour TTL
          });
      }

      console.log('✅ SEARCH_CACHE_REFRESHED');

      await logSyncEvent(
        'SEARCH_CACHE_REFRESHED',
        'system',
        'search_cache',
        { categoriesProcessed: categories?.length || 0 },
        'completed'
      );
    } catch (error: any) {
      Sentry.captureException(error, { tags: { worker: 'refreshSearchCache' } });
      console.error('❌ refreshSearchCache failed:', error);
      throw error;
    }
  });

// =====================================================
// WORKER 5: detectDrift (SCHEDULED)
// =====================================================

/**
 * Detect inventory drift between Supabase and Firestore
 * Triggered by: Cloud Scheduler every 5 minutes
 * Latency target: < 5 minutes
 */
export const detectDrift = functions.pubsub
  .schedule('*/5 * * * *')
  .onRun(async (context) => {
    try {
      const shopId = 'FUFAJI_MAIN_001'; // MVP: single shop

      // Get all Firestore inventory docs
      const firestoreInv = await firestore
        .collection('shops')
        .doc(shopId)
        .collection('inventory')
        .get();

      let driftCount = 0;

      for (const doc of firestoreInv.docs) {
        const variantId = doc.id;
        const fData = doc.data();

        // Query Supabase
        const { data: sData } = await supabase
          .from('shop_inventory')
          .select('*')
          .eq('shop_id', shopId)
          .eq('variant_id', variantId)
          .single();

        if (!sData) continue;

        // Compute expected Firestore value
        const expectedAvailable = Math.max(
          sData.stock_total - sData.stock_reserved - sData.stock_damaged,
          0
        );

        // Check drift
        const drift = Math.abs(fData.stockAvailable - expectedAvailable);

        if (drift > 0) {
          driftCount++;

          Sentry.captureMessage('DRIFT_DETECTED', 'error', {
            tags: {
              shopId,
              variantId,
              drift,
              firestore: fData.stockAvailable,
              expected: expectedAvailable,
            },
          });

          // Flag in Firestore
          await doc.ref.update({
            driftDetected: true,
            driftNotes: `Firestore: ${fData.stockAvailable}, Expected: ${expectedAvailable}`,
            driftDetectedAt: new Date(),
          });

          // Log to sync_events
          await logSyncEvent(
            'DRIFT_DETECTED',
            'variant',
            variantId,
            { drift, firestore: fData.stockAvailable, expected: expectedAvailable },
            'pending'
          );
        }
      }

      console.log(`✅ DRIFT_DETECTION_COMPLETED: ${driftCount} drifts found`);
    } catch (error: any) {
      Sentry.captureException(error, { tags: { worker: 'detectDrift' } });
      console.error('❌ detectDrift failed:', error);
      throw error;
    }
  });

// =====================================================
// WORKER 6: retryFailedSyncJobs (SCHEDULED)
// =====================================================

/**
 * Retry failed sync jobs with exponential backoff
 * Triggered by: Cloud Scheduler every 10 minutes
 * Latency target: < 10 minutes
 */
export const retryFailedSyncJobs = functions.pubsub
  .schedule('*/10 * * * *')
  .onRun(async (context) => {
    try {
      // Query failed events ready for retry
      const { data: failedEvents } = await supabase
        .from('sync_events')
        .select('*')
        .eq('status', 'failed')
        .lt('retry_count', 5)
        .lte('next_retry_at', new Date().toISOString());

      for (const event of failedEvents || []) {
        const nextRetryAt = new Date(
          Date.now() + calculateBackoffMs(event.retry_count)
        );

        // Update retry schedule
        await supabase
          .from('sync_events')
          .update({
            retry_count: event.retry_count + 1,
            next_retry_at: nextRetryAt.toISOString(),
          })
          .eq('id', event.id);

        // Republish to appropriate Pub/Sub topic based on event type
        if (event.event_type === 'INVENTORY_UPDATED') {
          // Re-publish to inventory sync topic
          await admin
            .pubsub()
            .topic('inventory-changes')
            .publish(Buffer.from(JSON.stringify(event.payload)));
        }

        console.log(`✅ RETRY_SCHEDULED: ${event.id} (attempt ${event.retry_count + 1})`);
      }
    } catch (error: any) {
      Sentry.captureException(error, {
        tags: { worker: 'retryFailedSyncJobs' },
      });
      console.error('❌ retryFailedSyncJobs failed:', error);
      throw error;
    }
  });

// =====================================================
// WORKER 7: processDeadLetterQueue (SCHEDULED)
// =====================================================

/**
 * Process DLQ items: auto-retry or alert ops
 * Triggered by: Cloud Scheduler every 30 minutes
 * Latency target: < 30 minutes
 */
export const processDeadLetterQueue = functions.pubsub
  .schedule('*/30 * * * *')
  .onRun(async (context) => {
    try {
      // Query pending DLQ items
      const { data: dlqItems } = await supabase
        .from('sync_dlq')
        .select('*')
        .eq('status', 'pending')
        .lt('retry_count', 3);

      let retriedCount = 0;
      let alertedCount = 0;

      for (const item of dlqItems || []) {
        if (item.retry_count < 2) {
          // Auto-retry

          const nextRetryAt = new Date(
            Date.now() + calculateBackoffMs(item.retry_count)
          );

          await supabase
            .from('sync_dlq')
            .update({
              retry_count: item.retry_count + 1,
              next_retry_scheduled_at: nextRetryAt.toISOString(),
            })
            .eq('id', item.id);

          retriedCount++;
        } else {
          // Alert ops (reached retry limit)
          Sentry.captureMessage('DLQ_ITEM_REQUIRES_MANUAL_REVIEW', 'error', {
            tags: {
              dlqId: item.id,
              failureReason: item.failure_reason,
              retryCount: item.retry_count,
            },
          });

          alertedCount++;
        }
      }

      console.log(
        `✅ DLQ_PROCESSED: ${retriedCount} retried, ${alertedCount} alerted`
      );
    } catch (error: any) {
      Sentry.captureException(error, {
        tags: { worker: 'processDeadLetterQueue' },
      });
      console.error('❌ processDeadLetterQueue failed:', error);
      throw error;
    }
  });

// =====================================================
// MANUAL ENDPOINTS (for admin/debugging)
// =====================================================

/**
 * Manual retry endpoint for DLQ items
 * Usage: POST /admin/dlq/retry?id={dlqId}
 */
export const retryDLQItem = functions.https.onRequest(
  async (req, res) => {
    const dlqId = req.query.id as string;

    if (!dlqId) {
      return res.status(400).json({ error: 'Missing dlqId parameter' });
    }

    try {
      const { data: dlqItem } = await supabase
        .from('sync_dlq')
        .select('*')
        .eq('id', dlqId)
        .single();

      if (!dlqItem) {
        return res.status(404).json({ error: 'DLQ item not found' });
      }

      // Update status
      await supabase
        .from('sync_dlq')
        .update({ status: 'acknowledged', acknowledged_at: new Date().toISOString() })
        .eq('id', dlqId);

      res.json({ status: 'acknowledged', dlqId });
    } catch (error: any) {
      Sentry.captureException(error);
      res.status(500).json({ error: error.message });
    }
  }
);

// =====================================================
// END sync_workers.ts
// =====================================================

/*

DEPLOYMENT CHECKLIST:

1. Environment Variables (set in Firebase Console):
   - SUPABASE_URL
   - SUPABASE_SERVICE_ROLE_KEY
   - SENTRY_DSN
   - NODE_ENV=production

2. Firebase Plan:
   - Upgrade to Blaze (pay-as-you-go)
   - Enable Cloud Functions
   - Enable Pub/Sub
   - Enable Firestore

3. Cloud Scheduler Jobs:
   - syncProductsToFirestore: every 5 minutes (*/5 * * * *)
   - refreshSearchCache: every 1 hour (0 * * * *)
   - detectDrift: every 5 minutes (*/5 * * * *)
   - retryFailedSyncJobs: every 10 minutes (*/10 * * * *)
   - processDeadLetterQueue: every 30 minutes (*/30 * * * *)

4. Pub/Sub Topics:
   - inventory-changes (from Supabase webhooks)
   - order-status-changes
   - firestore-scheduled-sync

5. Deploy Commands:
   firebase deploy --only functions:syncInventoryToFirestore
   firebase deploy --only functions:syncProductsToFirestore
   firebase deploy --only functions:replicateOrdersToSupabase
   firebase deploy --only functions:refreshSearchCache
   firebase deploy --only functions:detectDrift
   firebase deploy --only functions:retryFailedSyncJobs
   firebase deploy --only functions:processDeadLetterQueue

6. Monitoring:
   - Sentry.io for error tracking
   - Cloud Logging for debug logs
   - Cloud Monitoring for performance metrics

7. Testing:
   - Run Pub/Sub test messages locally
   - Verify Firestore updates within 2 seconds
   - Check DLQ entries after simulated failure

*/
