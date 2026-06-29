/**
 * ============================================================================
 * routes/notifications.js - Push, Email, SMS API Endpoints
 * ============================================================================
 */

const express = require('express');
const router = express.Router();
const PushNotificationService = require('../services/PushNotificationService');
const EmailService = require('../services/EmailService');
const SmsService = require('../services/SmsService');
const { verifyToken: authenticateUser } = require('../auth');

const pushService = new PushNotificationService();
const emailService = new EmailService();
const smsService = new SmsService();

/**
 * POST /api/notifications/push
 * Send push notification
 */
router.post('/push', authenticateUser, async (req, res) => {
  try {
    const { userId, title, body, data } = req.body;

    if (!userId || !title || !body) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await pushService.sendPushNotification(userId, title, body, data);

    res.json({
      success: true,
      message: 'Push notification sent',
      data: result,
    });
  } catch (error) {
    console.error('Push notification error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/notifications/push/batch
 * Send batch push notifications
 */
router.post('/push/batch', authenticateUser, async (req, res) => {
  try {
    const { userIds, title, body, data } = req.body;

    if (!userIds || !Array.isArray(userIds) || !title || !body) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const result = await pushService.sendBatchNotification(userIds, title, body, data);

    res.json({
      success: true,
      message: 'Batch notifications sent',
      data: result,
    });
  } catch (error) {
    console.error('Batch push error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/notifications/fcm-token
 * Register FCM token for user's device
 */
router.post('/fcm-token', authenticateUser, async (req, res) => {
  try {
    const { fcmToken, deviceId, deviceName } = req.body;
    const userId = req.user.uid;

    if (!fcmToken || !deviceId) {
      return res.status(400).json({ error: 'Missing fcmToken or deviceId' });
    }

    const result = await pushService.registerFCMToken(
      userId,
      fcmToken,
      deviceId,
      deviceName
    );

    res.json({
      success: true,
      message: 'FCM token registered',
      data: result,
    });
  } catch (error) {
    console.error('FCM token error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * DELETE /api/notifications/fcm-token/:deviceId
 * Remove FCM token
 */
router.delete('/fcm-token/:deviceId', authenticateUser, async (req, res) => {
  try {
    const { deviceId } = req.params;
    const userId = req.user.uid;

    const result = await pushService.removeFCMToken(userId, deviceId);

    res.json({
      success: true,
      message: 'FCM token removed',
      data: result,
    });
  } catch (error) {
    console.error('Remove FCM token error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/notifications/history
 * Get user's notification history
 */
router.get('/history', authenticateUser, async (req, res) => {
  try {
    const userId = req.user.uid;
    const limit = parseInt(req.query.limit) || 50;

    const history = await pushService.getNotificationHistory(userId, limit);

    res.json({
      success: true,
      data: history,
    });
  } catch (error) {
    console.error('Get history error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/notifications/email
 * Send email
 */
router.post('/email', authenticateUser, async (req, res) => {
  try {
    const { customerId, type, data } = req.body;

    if (!customerId || !type) {
      return res.status(400).json({ error: 'Missing customerId or type' });
    }

    let result;

    switch (type) {
      case 'order_confirmation':
        result = await emailService.sendOrderConfirmation(customerId, data.orderId, data);
        break;
      case 'delivery_tracking':
        result = await emailService.sendDeliveryTracking(
          customerId,
          data.orderId,
          data.riderName,
          data.riderPhone,
          data.eta
        );
        break;
      case 'refund_notification':
        result = await emailService.sendRefundNotification(
          customerId,
          data.orderId,
          data.refundAmount,
          data.reason
        );
        break;
      case 'review_request':
        result = await emailService.sendReviewRequest(customerId, data.orderId);
        break;
      case 'weekly_summary':
        result = await emailService.sendWeeklySummary(customerId, data);
        break;
      default:
        return res.status(400).json({ error: 'Unknown email type' });
    }

    res.json({
      success: true,
      message: `${type} email sent`,
      data: result,
    });
  } catch (error) {
    console.error('Email error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/notifications/email/history
 * Get email history
 */
router.get('/email/history', authenticateUser, async (req, res) => {
  try {
    const customerId = req.user.uid;
    const limit = parseInt(req.query.limit) || 50;

    const history = await emailService.getEmailHistory(customerId, limit);

    res.json({
      success: true,
      data: history,
    });
  } catch (error) {
    console.error('Get email history error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/notifications/sms
 * Send SMS
 */
router.post('/sms', authenticateUser, async (req, res) => {
  try {
    const { phoneNumber, message, category } = req.body;
    const customerId = req.user.uid;

    if (!phoneNumber || !message) {
      return res.status(400).json({ error: 'Missing phoneNumber or message' });
    }

    const result = await smsService.sendSms(phoneNumber, message, {
      customerId,
      category,
    });

    res.json({
      success: true,
      message: 'SMS sent',
      data: result,
    });
  } catch (error) {
    console.error('SMS error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/notifications/sms/batch
 * Send batch SMS
 */
router.post('/sms/batch', authenticateUser, async (req, res) => {
  try {
    const { phoneNumbers, message, category } = req.body;

    if (!phoneNumbers || !Array.isArray(phoneNumbers) || !message) {
      return res.status(400).json({ error: 'Invalid input' });
    }

    const result = await smsService.sendBatchSms(phoneNumbers, message, {
      category,
    });

    res.json({
      success: true,
      message: 'Batch SMS sent',
      data: result,
    });
  } catch (error) {
    console.error('Batch SMS error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/notifications/sms/history
 * Get SMS history
 */
router.get('/sms/history', authenticateUser, async (req, res) => {
  try {
    const customerId = req.user.uid;
    const limit = parseInt(req.query.limit) || 50;

    const history = await smsService.getSmsHistory(customerId, limit);

    res.json({
      success: true,
      data: history,
    });
  } catch (error) {
    console.error('Get SMS history error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/notifications/preferences
 * Update notification preferences
 */
router.post('/preferences', authenticateUser, async (req, res) => {
  try {
    const { db } = require('../firestore');
    const firestore = db();
    const userId = req.user.uid;
    const { channels, quietHours, emailFrequency } = req.body;

    const prefsRef = firestore
      .collection('users')
      .doc(userId)
      .collection('settings')
      .doc('notification_preferences');

    await prefsRef.set(
      {
        channels: channels || {},
        quietHours: quietHours || {},
        emailFrequency: emailFrequency || 'daily',
        updatedAt: new Date(),
      },
      { merge: true }
    );

    res.json({
      success: true,
      message: 'Preferences updated',
    });
  } catch (error) {
    console.error('Preferences error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/notifications/preferences
 * Get notification preferences
 */
router.get('/preferences', authenticateUser, async (req, res) => {
  try {
    const { db } = require('../firestore');
    const firestore = db();
    const userId = req.user.uid;

    const prefsRef = firestore
      .collection('users')
      .doc(userId)
      .collection('settings')
      .doc('notification_preferences');

    const prefsDoc = await prefsRef.get();
    const prefs = prefsDoc.exists ? prefsDoc.data() : {};

    res.json({
      success: true,
      data: prefs,
    });
  } catch (error) {
    console.error('Get preferences error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/notifications/sms/webhook
 * Webhook for Twilio delivery reports (public, no auth)
 */
router.post('/sms/webhook', async (req, res) => {
  try {
    const { messageSid, messageStatus, errorCode } = req.body;

    await smsService.handleDeliveryReport({
      messageSid,
      messageStatus,
      errorCode,
    });

    res.json({ success: true });
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
