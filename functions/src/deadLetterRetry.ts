import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Pool } from "pg";

/**
 * deadLetterRetry — runs every 15 minutes.
 * Reads all pending docs from dead_letter_rds_sync (retryCount < 5),
 * retries the RDS upsert, and on success deletes the doc.
 * After 5 failures the doc is left in place for manual review.
 */
export const retryRdsSyncDeadLetter = functions.pubsub
  .schedule("every 15 minutes")
  .onRun(async () => {
    const db = admin.firestore();
    const pool = new Pool({ connectionString: process.env.RDS_CONNECTION_STRING });

    const snapshot = await db
      .collection("dead_letter_rds_sync")
      .where("retryCount", "<", 5)
      .limit(50)
      .get();

    if (snapshot.empty) {
      console.log("[deadLetterRetry] No pending dead-letter docs.");
      return;
    }

    const batch = db.batch();
    const client = await pool.connect();

    try {
      for (const doc of snapshot.docs) {
        const d = doc.data();
        try {
          await client.query(
            `INSERT INTO orders (id, order_number, customer_id, total_amount, status, payment_status, created_at, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
             ON CONFLICT (id) DO UPDATE SET
               status = EXCLUDED.status,
               payment_status = EXCLUDED.payment_status,
               updated_at = NOW()`,
            [d.orderId, d.orderNumber, d.customerId, d.totalAmount, d.status, d.paymentStatus]
          );
          // Success — remove from dead-letter queue
          batch.delete(doc.ref);
          console.log(`[deadLetterRetry] Synced order ${d.orderId}`);
        } catch (err) {
          // Increment retry count
          batch.update(doc.ref, {
            retryCount: (d.retryCount || 0) + 1,
            lastError: String(err),
            lastRetryAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.error(`[deadLetterRetry] Failed for order ${d.orderId}: ${err}`);
        }
      }
      await batch.commit();
    } finally {
      client.release();
      await pool.end();
    }
  });
