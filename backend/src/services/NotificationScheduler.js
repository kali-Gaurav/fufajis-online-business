/**
 * ============================================================================
 * NotificationScheduler.js - Cloud Function for Scheduled Notifications
 * ============================================================================
 * Runs hourly via Cloud Scheduler to:
 * - Check scheduled_notifications collection
 * - Send notifications whose time has arrived
 * - Retry failed notifications (up to 3 attempts)
 * - Clean up old notifications
 * ============================================================================
 */

const { admin, db } = require('../firestore');
const PushNotificationService = require('./PushNotificationService');
const EmailService = require('./EmailService');
const SmsService = require('./SmsService');

class NotificationScheduler {
  constructor() {
    this.pushService = new PushNotificationService();
    this.emailService = new EmailService();
    this.smsService = new SmsService();
  }

  /**
   * Main scheduler function
   * Called hourly by Cloud Scheduler
   */
  async processScheduledNotifications() {
    const firestore = db();
    const FieldValue = admin.firestore.FieldValue;

    try {
      console.log('[NotificationScheduler] Starting scheduled notification processing');

      // 1. Query pending notifications
      const now = new Date();
      const scheduledRef = firestore.collection('scheduled_notifications');

      const snapshot = await scheduledRef
        .where('status', '==', 'pending')
        .where('scheduledFor', '<=', now)
        .limit(100) // Process max 100 per run
        .get();

      if (snapshot.empty) {
        console.log('[NotificationScheduler] No notifications to process');
        return { success: true, processed: 0 };
      }

      let successCount = 0;
      let failureCount = 0;

      // 2. Process each notification
      for (const doc of snapshot.docs) {
        const notification = doc.data();
        const docRef = doc.ref;

        try {
          // Send based on type
          if (notification.type === 'push' || !notification.type) {
            await this.pushService.sendPushNotification(
              notification.userId,
              notification.title,
              notification.body,
              notification.data
            );
          }

          if (notification.type === 'email') {
            // Email sending would use emailService
          }

          if (notification.type === 'sms') {
            // SMS sending would use smsService
          }

          // Mark as sent
          await docRef.update({
            status: 'sent',
            sentAt: FieldValue.serverTimestamp(),
          });

          successCount++;
        } catch (error) {
          console.error(
            `[NotificationScheduler] Error processing notification ${doc.id}:`,
            error.message
          );

          const attempts = (notification.attempts || 0) + 1;
          const maxAttempts = notification.maxAttempts || 3;

          if (attempts >= maxAttempts) {
            // Max retries reached, mark as failed
            await docRef.update({
              status: 'failed',
              failedAt: FieldValue.serverTimestamp(),
              error: error.message,
            });
          } else {
            // Retry later (next hour)
            const nextRetry = new Date();
            nextRetry.setHours(nextRetry.getHours() + 1);

            await docRef.update({
              attempts,
              scheduledFor: nextRetry,
              lastError: error.message,
            });
          }

          failureCount++;
        }
      }

      console.log(
        `[NotificationScheduler] Completed: ${successCount} sent, ${failureCount} failed`
      );

      // 3. Clean up old notifications (older than 30 days)
      await this._cleanupOldNotifications();

      return {
        success: true,
        processed: snapshot.size,
        successful: successCount,
        failed: failureCount,
      };
    } catch (error) {
      console.error('[NotificationScheduler] Fatal error:', error);
      throw error;
    }
  }

  /**
   * Send weekly summary emails
   * Called once per week (e.g., Sunday 9 AM)
   */
  async sendWeeklySummaries() {
    const firestore = db();

    try {
      console.log('[NotificationScheduler] Starting weekly summary emails');

      // 1. Get all users with email summaries enabled
      const usersRef = firestore.collection('users');

      const snapshot = await usersRef
        .where('emailNotificationsEnabled', '==', true)
        .get();

      let sentCount = 0;

      // 2. Generate and send summary for each user
      for (const doc of snapshot.docs) {
        try {
          const userId = doc.id;
          const userData = doc.data();

          // Build summary data
          const summaryData = await this._buildWeeklySummary(userId);

          // Send email
          await this.emailService.sendWeeklySummary(userId, summaryData);

          sentCount++;
        } catch (error) {
          console.error(`Error sending summary to ${doc.id}:`, error.message);
        }
      }

      console.log(`[NotificationScheduler] Weekly summaries sent: ${sentCount}`);

      return { success: true, sent: sentCount };
    } catch (error) {
      console.error('[NotificationScheduler] Weekly summary error:', error);
      throw error;
    }
  }

  /**
   * Send order confirmation notifications
   * Called by order service after order created
   */
  async sendOrderConfirmationNotifications(orderId, customerId, orderData) {
    try {
      const eta = orderData.estimatedDeliveryTime || '30-45';
      const riderPhone = orderData.riderPhone || '';

      // Send push notification
      await this.pushService.notifyOrderConfirmed(orderId, customerId, eta);

      // Send email
      await this.emailService.sendOrderConfirmation(
        customerId,
        orderId,
        orderData
      );

      // Send SMS (optional, based on preferences)
      // const customer = await this._getCustomerPhone(customerId);
      // await this.smsService.sendOrderStatus(customer.phone, 'confirmed', orderId, customerId, { eta });

      console.log(`[NotificationScheduler] Order notifications sent for ${orderId}`);

      return { success: true };
    } catch (error) {
      console.error('[NotificationScheduler] Order notification error:', error);
      throw error;
    }
  }

  /**
   * Send delivery status notifications
   * Called by delivery service as order progresses
   */
  async sendDeliveryStatusNotifications(orderId, customerId, status, statusData) {
    try {
      const statusMap = {
        out_for_delivery: 'on_the_way',
        delivered: 'delivered',
      };

      const smsStatus = statusMap[status] || status;

      switch (status) {
        case 'out_for_delivery':
          await this.pushService.notifyOutForDelivery(
            orderId,
            customerId,
            statusData.eta
          );
          break;

        case 'delivered':
          await this.pushService.notifyDelivered(orderId, customerId);
          // Request review after 1 hour
          await this._scheduleReviewRequest(customerId, orderId, 3600000);
          break;
      }

      console.log(
        `[NotificationScheduler] Delivery notifications sent for ${orderId}: ${status}`
      );

      return { success: true };
    } catch (error) {
      console.error('[NotificationScheduler] Delivery notification error:', error);
      throw error;
    }
  }

  // ========== PRIVATE HELPERS ==========

  /**
   * Build weekly summary for user
   * @private
   */
  async _buildWeeklySummary(userId) {
    const firestore = db();

    // Get orders from last 7 days
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const ordersRef = firestore
      .collection('users')
      .doc(userId)
      .collection('orders')
      .where('createdAt', '>=', sevenDaysAgo)
      .where('status', '==', 'OrderStatus.delivered');

    const ordersSnapshot = await ordersRef.get();

    let totalOrders = 0;
    let totalSpent = 0;
    let favoriteItem = '';

    const itemCounts = {};

    ordersSnapshot.forEach((doc) => {
      const order = doc.data();
      totalOrders++;
      totalSpent += order.totalAmount || 0;

      // Track item frequencies
      order.items?.forEach((item) => {
        itemCounts[item.name] = (itemCounts[item.name] || 0) + 1;
      });
    });

    // Most ordered item
    if (Object.keys(itemCounts).length > 0) {
      favoriteItem = Object.entries(itemCounts).sort((a, b) => b[1] - a[1])[0][0];
    }

    // Next promo (from promos collection)
    // TODO: Implement promo lookup

    return {
      totalOrders,
      totalSpent,
      favoriteItem,
      nextPromo: 'Check app for latest offers!',
    };
  }

  /**
   * Schedule review request after delivery
   * @private
   */
  async _scheduleReviewRequest(customerId, orderId, delayMs) {
    const firestore = db();
    const scheduleTime = new Date(Date.now() + delayMs);

    const scheduledRef = firestore.collection('scheduled_notifications').doc();

    await scheduledRef.set({
      userId: customerId,
      type: 'push',
      title: 'Tell us about your delivery!',
      body: 'Share your feedback and earn rewards.',
      data: {
        orderId,
        action: 'request_review',
        deepLink: `app://order/${orderId}/review`,
        category: 'review',
      },
      scheduledFor: scheduleTime,
      createdAt: new Date(),
      status: 'pending',
      attempts: 0,
      maxAttempts: 3,
    });
  }

  /**
   * Clean up old notifications
   * @private
   */
  async _cleanupOldNotifications() {
    const firestore = db();
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const snapshot = await firestore
      .collection('scheduled_notifications')
      .where('status', 'in', ['sent', 'failed'])
      .where('createdAt', '<', thirtyDaysAgo)
      .limit(100)
      .get();

    let deletedCount = 0;

    for (const doc of snapshot.docs) {
      await doc.ref.delete();
      deletedCount++;
    }

    if (deletedCount > 0) {
      console.log(`[NotificationScheduler] Cleaned up ${deletedCount} old notifications`);
    }
  }

  /**
   * Get customer phone number
   * @private
   */
  async _getCustomerPhone(customerId) {
    const firestore = db();
    const userRef = firestore.collection('users').doc(customerId);
    const userDoc = await userRef.get();

    if (userDoc.exists) {
      const userData = userDoc.data();
      return {
        phone: userData.phoneNumber,
        countryCode: userData.countryCode || '+91',
      };
    }

    return null;
  }
}

module.exports = NotificationScheduler;
