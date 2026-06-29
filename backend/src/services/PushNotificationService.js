/**
 * ============================================================================
 * PushNotificationService.js - Firebase Cloud Messaging Integration
 * ============================================================================
 * Handles:
 * - Push notification delivery via Firebase Cloud Messaging
 * - FCM token management and storage
 * - Batch notification delivery
 * - Scheduled notifications
 * - Notification tracking and logging
 * - Deep link routing
 * ============================================================================
 */

const { admin, db } = require('../firestore');

class PushNotificationService {
  /**
   * Send single push notification to user
   *
   * @param {string} userId - Firebase user ID
   * @param {string} title - Notification title
   * @param {string} body - Notification body text
   * @param {object} data - Additional data/deep link info
   *   - orderId: order reference
   *   - action: 'view_order', 'view_review', etc.
   *   - deepLink: 'app://order/123'
   *   - category: 'order', 'promo', 'review', etc.
   * @returns {Promise<object>} - { success: true, messageId, userId }
   */
  async sendPushNotification(userId, title, body, data = {}) {
    const firestore = db();

    try {
      // 1. Get user's FCM token from Firestore
      const userRef = firestore.collection('users').doc(userId);
      const userDoc = await userRef.get();

      if (!userDoc.exists) {
        throw new Error(`User ${userId} not found`);
      }

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken || userData.devices?.[0]?.fcmToken;

      if (!fcmToken) {
        console.warn(`[PushNotificationService] No FCM token for user ${userId}`);
        // Log as skipped, not an error - user may have notifications disabled
        await this._logNotification(userId, 'skipped', {
          title,
          body,
          reason: 'no_fcm_token',
        });
        return { success: false, userId, reason: 'no_fcm_token' };
      }

      // 2. Check notification preferences
      const prefsRef = firestore.collection('users').doc(userId).collection('settings').doc('notification_preferences');
      const prefsDoc = await prefsRef.get();
      const prefs = prefsDoc.exists ? prefsDoc.data() : {};

      // Map category to preference key
      const category = data.category || 'order';
      const prefKey = this._getCategoryPreferenceKey(category);
      const pushEnabled = prefs.channels?.push?.[prefKey] !== false;
      const quietHoursActive = this._isInQuietHours(prefs.quietHours);

      if (!pushEnabled || (quietHoursActive && data.priority !== 'high')) {
        console.log(`[PushNotificationService] Push skipped for ${userId}: push=${pushEnabled}, quiet=${quietHoursActive}`);
        await this._logNotification(userId, 'suppressed', {
          title,
          body,
          reason: pushEnabled ? 'quiet_hours' : 'user_disabled',
        });
        return { success: false, userId, reason: 'notification_preference' };
      }

      // 3. Build notification payload
      const payload = {
        notification: {
          title,
          body,
        },
        data: {
          ...data,
          timestamp: Date.now().toString(),
          userId,
        },
        android: {
          priority: data.priority || 'high',
          notification: {
            sound: 'default',
            channelId: 'orders',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              'content-available': 1,
            },
          },
        },
      };

      // 4. Send via Firebase Admin SDK
      const messageId = await admin.messaging().sendToDevice(fcmToken, payload);

      // 5. Log notification sent
      await this._logNotification(userId, 'sent', {
        title,
        body,
        messageId: messageId?.results?.[0]?.messageId,
        category,
        deepLink: data.deepLink,
      });

      console.log(`[PushNotificationService] Push sent to ${userId}: "${title}"`);

      return {
        success: true,
        userId,
        messageId: messageId?.results?.[0]?.messageId,
      };
    } catch (error) {
      console.error(`[PushNotificationService] Error sending push to ${userId}:`, error.message);
      await this._logNotification(userId, 'failed', {
        title,
        body,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Send batch notifications to multiple users
   * Uses Firebase multicast for efficiency
   *
   * @param {array} userIds - Array of user IDs
   * @param {string} title - Notification title
   * @param {string} body - Notification body
   * @param {object} data - Additional data
   * @returns {Promise<object>} - { successful: [...], failed: [...] }
   */
  async sendBatchNotification(userIds, title, body, data = {}) {
    const firestore = db();

    if (!Array.isArray(userIds) || userIds.length === 0) {
      throw new Error('userIds must be a non-empty array');
    }

    try {
      // 1. Fetch all users and their FCM tokens
      const tokens = [];
      const userTokenMap = {};

      for (const userId of userIds) {
        const userRef = firestore.collection('users').doc(userId);
        const userDoc = await userRef.get();

        if (userDoc.exists) {
          const userData = userDoc.data();
          const fcmToken = userData.fcmToken || userData.devices?.[0]?.fcmToken;

          if (fcmToken) {
            tokens.push(fcmToken);
            userTokenMap[fcmToken] = userId;
          }
        }
      }

      if (tokens.length === 0) {
        console.warn('[PushNotificationService] No valid FCM tokens for batch');
        return { successful: [], failed: userIds, reason: 'no_valid_tokens' };
      }

      // 2. Build payload
      const payload = {
        notification: {
          title,
          body,
        },
        data: {
          ...data,
          timestamp: Date.now().toString(),
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'orders',
          },
        },
      };

      // 3. Send multicast (max 500 per request)
      const chunkSize = 500;
      const successful = [];
      const failed = [];

      for (let i = 0; i < tokens.length; i += chunkSize) {
        const chunk = tokens.slice(i, i + chunkSize);
        const response = await admin.messaging().sendMulticast({
          ...payload,
          tokens: chunk,
        });

        // 4. Process results
        response.responses.forEach((result, idx) => {
          const token = chunk[idx];
          const userId = userTokenMap[token];

          if (result.success) {
            successful.push(userId);
            this._logNotification(userId, 'sent', {
              title,
              body,
              messageId: result.messageId,
              batch: true,
            });
          } else {
            failed.push(userId);
            this._logNotification(userId, 'failed', {
              title,
              body,
              error: result.error?.message,
              batch: true,
            });
          }
        });
      }

      console.log(`[PushNotificationService] Batch complete: ${successful.length} sent, ${failed.length} failed`);

      return { successful, failed };
    } catch (error) {
      console.error('[PushNotificationService] Batch error:', error.message);
      throw error;
    }
  }

  /**
   * Schedule a notification for future delivery
   * Stores in scheduled_notifications collection for Cloud Scheduler to process
   *
   * @param {string} userId - User ID
   * @param {string} title - Notification title
   * @param {string} body - Notification body
   * @param {Date} scheduledTime - When to send
   * @param {object} data - Additional data
   * @returns {Promise<string>} - Scheduled notification ID
   */
  async scheduleNotification(userId, title, body, scheduledTime, data = {}) {
    const firestore = db();

    if (!(scheduledTime instanceof Date)) {
      throw new Error('scheduledTime must be a Date object');
    }

    try {
      const FieldValue = admin.firestore.FieldValue;
      const scheduledRef = firestore.collection('scheduled_notifications').doc();

      await scheduledRef.set({
        userId,
        title,
        body,
        data,
        scheduledFor: scheduledTime,
        createdAt: FieldValue.serverTimestamp(),
        status: 'pending',
        attempts: 0,
        maxAttempts: 3,
      });

      console.log(`[PushNotificationService] Scheduled notification ${scheduledRef.id} for ${userId}`);

      return scheduledRef.id;
    } catch (error) {
      console.error('[PushNotificationService] Schedule error:', error.message);
      throw error;
    }
  }

  /**
   * Trigger notifications for common order events
   */

  async notifyOrderConfirmed(orderId, customerId, eta) {
    const title = `Order #${orderId.slice(-6)} Confirmed!`;
    const body = `Your order is confirmed. Estimated delivery: ${eta} minutes`;

    return this.sendPushNotification(customerId, title, body, {
      orderId,
      action: 'view_order',
      deepLink: `app://order/${orderId}`,
      category: 'order_update',
      priority: 'high',
    });
  }

  async notifyRiderPickedUp(orderId, customerId, riderName, riderPhone) {
    const title = `${riderName} is on the way!`;
    const body = `Your rider is picking up your order. Check tracking for details.`;

    return this.sendPushNotification(customerId, title, body, {
      orderId,
      riderName,
      riderPhone,
      action: 'view_order',
      deepLink: `app://order/${orderId}`,
      category: 'order_update',
      priority: 'high',
    });
  }

  async notifyOutForDelivery(orderId, customerId, eta) {
    const title = 'Out for delivery!';
    const body = `Your order is out for delivery. ETA: ${eta}`;

    return this.sendPushNotification(customerId, title, body, {
      orderId,
      action: 'view_order',
      deepLink: `app://order/${orderId}`,
      category: 'order_update',
      priority: 'high',
    });
  }

  async notifyDelivered(orderId, customerId) {
    const title = 'Order delivered!';
    const body = 'Your order has arrived. Rate your experience!';

    return this.sendPushNotification(customerId, title, body, {
      orderId,
      action: 'request_review',
      deepLink: `app://order/${orderId}/review`,
      category: 'order_update',
      priority: 'high',
    });
  }

  async notifyRefunded(customerId, amount, orderId) {
    const title = 'Refund processed!';
    const body = `₹${amount} has been refunded to your wallet.`;

    return this.sendPushNotification(customerId, title, body, {
      orderId,
      amount,
      action: 'view_wallet',
      deepLink: 'app://wallet',
      category: 'payment',
    });
  }

  async notifyPromotion(customerId, promoTitle, discount, deepLink) {
    const title = promoTitle;
    const body = `Save ₹${discount} on your next order!`;

    return this.sendPushNotification(customerId, title, body, {
      action: 'view_promo',
      deepLink,
      category: 'promotion',
    });
  }

  async notifyInventoryRestocked(customerId, itemName, itemId) {
    const title = `${itemName} is back in stock!`;
    const body = 'Your favorite item is available again.';

    return this.sendPushNotification(customerId, title, body, {
      itemId,
      action: 'view_product',
      deepLink: `app://product/${itemId}`,
      category: 'inventory',
    });
  }

  async notifyReviewRequest(customerId, orderId) {
    const title = 'Tell us about your delivery!';
    const body = 'Share your feedback and earn rewards.';

    return this.sendPushNotification(customerId, title, body, {
      orderId,
      action: 'request_review',
      deepLink: `app://order/${orderId}/review`,
      category: 'review',
    });
  }

  /**
   * Get user's FCM tokens (all devices)
   *
   * @param {string} userId
   * @returns {Promise<array>} - Array of { deviceId, fcmToken, deviceName }
   */
  async getUserFCMTokens(userId) {
    const firestore = db();

    try {
      const devicesRef = firestore.collection('users').doc(userId).collection('devices');
      const snapshot = await devicesRef.where('fcmToken', '!=', null).get();

      const devices = [];
      snapshot.forEach((doc) => {
        const data = doc.data();
        devices.push({
          deviceId: doc.id,
          fcmToken: data.fcmToken,
          deviceName: data.deviceName,
          lastSeen: data.lastSeen,
        });
      });

      return devices;
    } catch (error) {
      console.error('[PushNotificationService] Error fetching FCM tokens:', error.message);
      throw error;
    }
  }

  /**
   * Register/update FCM token for user's device
   *
   * @param {string} userId
   * @param {string} fcmToken - FCM token from mobile device
   * @param {string} deviceId - Device identifier
   * @param {string} deviceName - Device name (e.g., "iPhone 12")
   * @returns {Promise}
   */
  async registerFCMToken(userId, fcmToken, deviceId, deviceName) {
    const firestore = db();
    const FieldValue = admin.firestore.FieldValue;

    try {
      // Also store in users doc for quick lookup
      await firestore.collection('users').doc(userId).update({
        fcmToken, // Latest token
        lastFCMTokenUpdate: FieldValue.serverTimestamp(),
      });

      // Store in devices collection for multi-device support
      const deviceRef = firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceId);

      await deviceRef.set(
        {
          fcmToken,
          deviceName,
          lastSeen: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      console.log(`[PushNotificationService] FCM token registered for user ${userId}, device ${deviceId}`);

      return { success: true };
    } catch (error) {
      console.error('[PushNotificationService] Error registering FCM token:', error.message);
      throw error;
    }
  }

  /**
   * Remove FCM token (when user uninstalls or disables notifications)
   *
   * @param {string} userId
   * @param {string} deviceId
   * @returns {Promise}
   */
  async removeFCMToken(userId, deviceId) {
    const firestore = db();

    try {
      const deviceRef = firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceId);

      await deviceRef.delete();

      console.log(`[PushNotificationService] FCM token removed for ${userId}, device ${deviceId}`);

      return { success: true };
    } catch (error) {
      console.error('[PushNotificationService] Error removing FCM token:', error.message);
      throw error;
    }
  }

  /**
   * Get notification history for user
   *
   * @param {string} userId
   * @param {number} limit - Max results (default 50)
   * @returns {Promise<array>} - Notification log entries
   */
  async getNotificationHistory(userId, limit = 50) {
    const firestore = db();

    try {
      const historyRef = firestore
        .collection('users')
        .doc(userId)
        .collection('notification_history')
        .orderBy('timestamp', 'desc')
        .limit(limit);

      const snapshot = await historyRef.get();
      const history = [];

      snapshot.forEach((doc) => {
        history.push({
          id: doc.id,
          ...doc.data(),
        });
      });

      return history;
    } catch (error) {
      console.error('[PushNotificationService] Error fetching history:', error.message);
      throw error;
    }
  }

  /**
   * Handle invalid/expired FCM tokens
   * Called when Firebase reports delivery failure
   *
   * @param {string} userId
   * @param {string} fcmToken - The invalid token
   * @returns {Promise}
   */
  async handleInvalidToken(userId, fcmToken) {
    const firestore = db();

    try {
      // Find and remove device with this token
      const devicesRef = firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .where('fcmToken', '==', fcmToken);

      const snapshot = await devicesRef.get();

      snapshot.forEach((doc) => {
        doc.ref.delete();
      });

      console.log(`[PushNotificationService] Removed invalid token for ${userId}`);

      return { success: true };
    } catch (error) {
      console.error('[PushNotificationService] Error handling invalid token:', error.message);
      throw error;
    }
  }

  // ========== PRIVATE HELPERS ==========

  /**
   * Log notification send/delivery/failure
   * @private
   */
  async _logNotification(userId, status, details = {}) {
    const firestore = db();
    const FieldValue = admin.firestore.FieldValue;

    try {
      const historyRef = firestore
        .collection('users')
        .doc(userId)
        .collection('notification_history')
        .doc();

      await historyRef.set({
        status,
        ...details,
        timestamp: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('[PushNotificationService] Error logging notification:', error.message);
    }
  }

  /**
   * Map notification category to preference key
   * @private
   */
  _getCategoryPreferenceKey(category) {
    const map = {
      order_update: 'orders',
      order_confirmed: 'orders',
      order_status: 'orders',
      payment: 'payments',
      refund: 'payments',
      promotion: 'promotions',
      inventory: 'inventory',
      review: 'reviews',
    };
    return map[category] || 'orders';
  }

  /**
   * Check if current time is within quiet hours
   * @private
   */
  _isInQuietHours(quietHours) {
    if (!quietHours || !quietHours.enabled) {
      return false;
    }

    const now = new Date();
    const currentHour = now.getHours();
    const { startHour, endHour } = quietHours;

    if (startHour < endHour) {
      return currentHour >= startHour && currentHour < endHour;
    } else {
      // Quiet hours span midnight (e.g., 22:00 to 08:00)
      return currentHour >= startHour || currentHour < endHour;
    }
  }
}

module.exports = PushNotificationService;
