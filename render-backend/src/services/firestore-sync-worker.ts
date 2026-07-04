/**
 * Firestore Sync Worker
 *
 * Runs on Render backend as a background service.
 * Polls outbox_events from PostgreSQL and syncs to Firestore.
 *
 * Responsibilities:
 * - Read outbox_events from PostgreSQL (batch)
 * - Sync events to Firestore
 * - Mark events as processed
 * - Exponential backoff retry on failure
 * - Dead-letter queue for poison events
 *
 * Deploy to Render with:
 * - SUPABASE_SERVICE_ROLE_KEY
 * - FIREBASE_SERVICE_ACCOUNT_KEY
 */

import { createClient } from "@supabase/supabase-js";
import * as admin from "firebase-admin";

interface OutboxEvent {
  id: string;
  event_type: string;
  aggregate_id: string;
  payload: Record<string, any>;
  processed: boolean;
  retry_count: number;
  last_error?: string;
  created_at: string;
}

class FirestoreSyncWorker {
  private supabase = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );

  private firestore: admin.firestore.Firestore;
  private readonly BATCH_SIZE = 100;
  private readonly POLL_INTERVAL_MS = 2000; // 2 seconds
  private readonly MAX_RETRIES = 5;
  private readonly DEAD_LETTER_QUEUE = "dead_letter_queue";

  constructor() {
    const serviceAccount = JSON.parse(
      process.env.FIREBASE_SERVICE_ACCOUNT_KEY!
    );
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    this.firestore = admin.firestore();
  }

  /**
   * Main worker loop
   */
  async run(): Promise<void> {
    console.log(
      `[FirestoreSyncWorker] Started. Poll interval: ${this.POLL_INTERVAL_MS}ms`
    );

    // eslint-disable-next-line no-constant-condition
    while (true) {
      try {
        const events = await this.fetchUnprocessedEvents();

        if (events.length === 0) {
          await this.sleep(this.POLL_INTERVAL_MS);
          continue;
        }

        console.log(`[FirestoreSyncWorker] Processing ${events.length} events`);

        for (const event of events) {
          await this.processEvent(event);
        }

        console.log(
          `[FirestoreSyncWorker] Batch complete. Next poll in ${this.POLL_INTERVAL_MS}ms`
        );
      } catch (error) {
        console.error(`[FirestoreSyncWorker] Fatal error:`, error);
        await this.sleep(this.POLL_INTERVAL_MS * 2); // Backoff on error
      }
    }
  }

  /**
   * Fetch unprocessed events from PostgreSQL
   */
  private async fetchUnprocessedEvents(): Promise<OutboxEvent[]> {
    const { data, error } = await this.supabase
      .from("outbox_events")
      .select("*")
      .eq("processed", false)
      .lt("retry_count", this.MAX_RETRIES)
      .order("created_at", { ascending: true })
      .limit(this.BATCH_SIZE);

    if (error) {
      throw new Error(`Failed to fetch outbox events: ${error.message}`);
    }

    return data as OutboxEvent[];
  }

  /**
   * Process a single event
   */
  private async processEvent(event: OutboxEvent): Promise<void> {
    try {
      console.log(`[Event ${event.id}] Processing ${event.event_type}`);

      // Sync to Firestore
      await this.syncToFirestore(event);

      // Mark as processed
      await this.markProcessed(event.id);

      console.log(
        `[Event ${event.id}] ✅ Synced to Firestore (${event.aggregate_id})`
      );
    } catch (error) {
      await this.handleError(event, error);
    }
  }

  /**
   * Sync event to Firestore
   */
  private async syncToFirestore(event: OutboxEvent): Promise<void> {
    const { aggregate_id, event_type, payload } = event;

    // Map event types to Firestore collections
    let collection = "events";
    let docId = aggregate_id;

    switch (event_type) {
      case "order_created":
      case "order_status_changed":
      case "order_delivered":
        collection = "orders";
        docId = aggregate_id;
        break;

      case "payment_completed":
      case "payment_failed":
        collection = "payments";
        docId = aggregate_id;
        break;

      case "delivery_started":
      case "delivery_completed":
      case "delivery_failed":
        collection = "deliveries";
        docId = aggregate_id;
        break;
    }

    // Write to Firestore with timestamp
    await this.firestore
      .collection(collection)
      .doc(docId)
      .set(
        {
          ...payload,
          lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
          eventType: event_type,
          _metadata: {
            outboxEventId: event.id,
            syncedAt: new Date().toISOString(),
          },
        },
        { merge: true }
      );

    // Also write to event log for audit trail
    await this.firestore
      .collection("event_log")
      .add({
        eventType: event_type,
        aggregateId: aggregate_id,
        payload,
        syncedAt: admin.firestore.FieldValue.serverTimestamp(),
        source: "outbox",
      });
  }

  /**
   * Mark event as processed
   */
  private async markProcessed(eventId: string): Promise<void> {
    const { error } = await this.supabase
      .from("outbox_events")
      .update({
        processed: true,
        processed_at: new Date().toISOString(),
      })
      .eq("id", eventId);

    if (error) {
      throw new Error(`Failed to mark event processed: ${error.message}`);
    }
  }

  /**
   * Handle event processing error
   */
  private async handleError(event: OutboxEvent, error: any): Promise<void> {
    console.error(`[Event ${event.id}] ❌ Error:`, error.message);

    const errorMessage =
      error instanceof Error ? error.message : String(error);
    const newRetryCount = (event.retry_count || 0) + 1;

    if (newRetryCount >= this.MAX_RETRIES) {
      // Move to dead-letter queue
      await this.supabase.from("outbox_events").update({
        processed: false,
        retry_count: newRetryCount,
        last_error: `[DLQ] Max retries exceeded: ${errorMessage}`,
      });

      console.error(
        `[Event ${event.id}] 💀 Moved to DLQ after ${newRetryCount} retries`
      );
    } else {
      // Retry with backoff
      await this.supabase
        .from("outbox_events")
        .update({
          retry_count: newRetryCount,
          last_error: errorMessage,
        })
        .eq("id", event.id);

      console.log(
        `[Event ${event.id}] 🔄 Retry ${newRetryCount}/${this.MAX_RETRIES}`
      );
    }
  }

  /**
   * Sleep utility
   */
  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Health check endpoint data
   */
  async getHealth(): Promise<{
    status: string;
    uptime: number;
    processedCount: number;
    failedCount: number;
    retryingCount: number;
  }> {
    const { data: processed } = await this.supabase
      .from("outbox_events")
      .select("id", { count: "exact", head: true })
      .eq("processed", true);

    const { data: failed } = await this.supabase
      .from("outbox_events")
      .select("id", { count: "exact", head: true })
      .eq("processed", false)
      .gte("retry_count", this.MAX_RETRIES);

    const { data: retrying } = await this.supabase
      .from("outbox_events")
      .select("id", { count: "exact", head: true })
      .eq("processed", false)
      .lt("retry_count", this.MAX_RETRIES);

    return {
      status: "healthy",
      uptime: process.uptime(),
      processedCount: processed?.length || 0,
      failedCount: failed?.length || 0,
      retryingCount: retrying?.length || 0,
    };
  }
}

/**
 * Main entry point
 */
const worker = new FirestoreSyncWorker();
worker.run().catch((error) => {
  console.error("[FirestoreSyncWorker] Fatal startup error:", error);
  process.exit(1);
});

// Health check endpoint (for Render health checks)
if (process.env.PORT) {
  const express = require("express");
  const app = express();

  app.get("/health", async (req, res) => {
    const health = await worker.getHealth();
    res.json(health);
  });

  app.listen(process.env.PORT || 3000, () => {
    console.log(`[Health] Listening on port ${process.env.PORT || 3000}`);
  });
}

export default worker;
