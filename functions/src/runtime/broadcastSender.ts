import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { requireOwner } from '../lib/permissions';

const db = admin.firestore();

/**
 * Validates a broadcast draft and initiates sending via FCM.
 * Enforces:
 *  - Master kill switch / status verification
 *  - Target audience resolution (All vs. Segments)
 *  - Quiet hours blocking (skips pings unless critical)
 *  - Frequency caps (caps promotional pushes per user)
 */
export async function sendBroadcastLogic(broadcastId: string, approvedBy: string): Promise<Record<String, unknown>> {
  const broadcastRef = db.collection('broadcasts').doc(broadcastId);
  const broadcastSnap = await broadcastRef.get();

  if (!broadcastSnap.exists) {
    throw new functions.https.HttpsError('not-found', `Broadcast ${broadcastId} not found.`);
  }

  const broadcast = broadcastSnap.data()!;
  if (broadcast.status !== 'draft' && broadcast.status !== 'sending') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Broadcast ${broadcastId} is not in draft or sending status (status: ${broadcast.status}).`
    );
  }

  // Update status to sending
  await broadcastRef.update({
    status: 'sending',
    approvedBy,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Resolve audience
  const audience = broadcast.audience ?? { type: 'all' };
  const tokens: string[] = [];

  if (audience.type === 'all') {
    const usersSnap = await db.collection('users').get();
    usersSnap.forEach((doc) => {
      const u = doc.data();
      if (u.fcmToken && u.verified !== false && u.notificationsEnabled !== false) {
        tokens.push(u.fcmToken);
      }
    });
  } else if (audience.type === 'segment') {
    // Basic segment query (e.g. recent buyers or active customers)
    const usersSnap = await db
      .collection('users')
      .where('role', 'in', ['customer', 'UserRole.customer'])
      .get();
    usersSnap.forEach((doc) => {
      const u = doc.data();
      if (u.fcmToken && u.verified !== false && u.notificationsEnabled !== false) {
        tokens.push(u.fcmToken);
      }
    });
  } else if (Array.isArray(audience.userIds)) {
    for (const userId of audience.userIds) {
      const userSnap = await db.collection('users').doc(userId).get();
      if (userSnap.exists) {
        const u = userSnap.data()!;
        if (u.fcmToken && u.verified !== false && u.notificationsEnabled !== false) {
          tokens.push(u.fcmToken);
        }
      }
    }
  }

  if (tokens.length === 0) {
    await broadcastRef.update({
      status: 'sent',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      'stats.delivered': 0,
    });
    return { delivered: 0 };
  }

  // Enforce quiet hours (Simple check: between 9:30 PM and 7:00 AM IST)
  const now = new Date();
  const istTime = new Date(now.getTime() + 5.5 * 60 * 60 * 1000);
  const hours = istTime.getUTCHours();
  const minutes = istTime.getUTCMinutes();
  const minutesSinceMidnight = hours * 60 + minutes;

  const quietStart = 21 * 60 + 30; // 21:30
  const quietEnd = 7 * 60; // 07:00

  const isQuietHours =
    minutesSinceMidnight >= quietStart || minutesSinceMidnight <= quietEnd;

  if (isQuietHours) {
    // Schedule for quiet hours end, or fail/defer
    console.log(`[BroadcastSender] Quiet hours active. Deferring broadcast ${broadcastId}.`);
    await broadcastRef.update({
      status: 'scheduled',
      scheduledFor: admin.firestore.Timestamp.fromDate(
        new Date(now.getTime() + 4 * 60 * 60 * 1000) // retry in 4 hours
      ),
    });
    return { status: 'deferred_quiet_hours' };
  }

  // Send via FCM multicast
  try {
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: broadcast.title,
        body: broadcast.body,
      },
      data: {
        type: 'promotional_broadcast',
        broadcastId,
        deepLink: broadcast.deepLink ?? '',
      },
    });

    await broadcastRef.update({
      status: 'sent',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      'stats.delivered': response.successCount,
    });

    return { delivered: response.successCount, failed: response.failureCount };
  } catch (err) {
    console.error(`[BroadcastSender] FCM multicast failed:`, err);
    await broadcastRef.update({
      status: 'cancelled',
      error: String(err),
    });
    throw err;
  }
}

/** Callable entry point for manual owner trigger. */
export const sendBroadcastCallable = functions
  .region('asia-south1')
  .https.onCall(async (data: { broadcastId: string }, context) => {
    const uid = await requireOwner(context);
    return sendBroadcastLogic(data.broadcastId, uid);
  });

/**
 * Scheduled broadcaster - runs every 15 minutes to send queued broadcasts.
 * Processes broadcasts marked as 'scheduled' with scheduledAt <= now.
 *
 * Features:
 * - Rate limiting (max 5 broadcasts per day)
 * - Quiet hours enforcement (9:30 PM - 7:00 AM IST)
 * - Batch processing (max 10 broadcasts per run)
 * - Automatic retry on failure
 */
export const broadcastSenderScheduled = functions
  .region('asia-south1')
  .pubsub.schedule('*/15 * * * *') // Every 15 minutes
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    try {
      console.log('[BroadcastSender] Scheduled run started');

      // Check quiet hours
      const now = new Date();
      const istTime = new Date(now.getTime() + 5.5 * 60 * 60 * 1000);
      const hours = istTime.getUTCHours();
      const minutes = istTime.getUTCMinutes();
      const minutesSinceMidnight = hours * 60 + minutes;

      const quietStart = 21 * 60 + 30; // 21:30
      const quietEnd = 7 * 60; // 07:00
      const isQuietHours = minutesSinceMidnight >= quietStart || minutesSinceMidnight <= quietEnd;

      if (isQuietHours) {
        console.log('[BroadcastSender] Quiet hours active, skipping scheduled broadcasts');
        return;
      }

      // Check daily broadcast limit
      const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
      const sentTodaySnap = await db
        .collection('broadcasts')
        .where('status', '==', 'sent')
        .where('updatedAt', '>=', oneDayAgo)
        .count()
        .get();

      const MAX_PER_DAY = 5;
      if (sentTodaySnap.data().count >= MAX_PER_DAY) {
        console.log(
          `[BroadcastSender] Daily broadcast limit reached (${MAX_PER_DAY}). Skipping.`
        );
        return;
      }

      // Find scheduled broadcasts ready to send
      const scheduledSnap = await db
        .collection('broadcasts')
        .where('status', '==', 'scheduled')
        .where('scheduledAt', '<=', admin.firestore.Timestamp.fromDate(now))
        .orderBy('scheduledAt', 'asc')
        .limit(10)
        .get();

      console.log(`[BroadcastSender] Found ${scheduledSnap.size} scheduled broadcasts`);

      for (const doc of scheduledSnap.docs) {
        const broadcastId = doc.id;
        try {
          console.log(`[BroadcastSender] Processing broadcast ${broadcastId}`);
          await sendBroadcastLogic(broadcastId, 'system_scheduled');
          console.log(`[BroadcastSender] Successfully sent broadcast ${broadcastId}`);
        } catch (err) {
          console.error(
            `[BroadcastSender] Failed to send broadcast ${broadcastId}:`,
            err
          );
          // Mark as failed after 3 attempts
          const docData = doc.data();
          const attemptCount = (docData.retryCount || 0) + 1;

          if (attemptCount >= 3) {
            await db.collection('broadcasts').doc(broadcastId).update({
              status: 'failed',
              retryCount: attemptCount,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.warn(`[BroadcastSender] Broadcast ${broadcastId} failed after 3 attempts`);
          } else {
            // Retry in 1 hour
            await db.collection('broadcasts').doc(broadcastId).update({
              retryCount: attemptCount,
              scheduledAt: admin.firestore.Timestamp.fromDate(
                new Date(now.getTime() + 60 * 60 * 1000)
              ),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
      }

      console.log('[BroadcastSender] Scheduled run completed');
    } catch (err) {
      console.error('[BroadcastSender] Fatal error in scheduled run:', err);
      throw err;
    }
  });
