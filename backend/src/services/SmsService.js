/**
 * ============================================================================
 * SmsService.js - Twilio SMS Integration
 * ============================================================================
 * Handles:
 * - SMS delivery via Twilio
 * - Delivery OTP messages
 * - Order status updates
 * - Payment/refund alerts
 * - Promotional SMS
 * - Delivery report tracking
 * ============================================================================
 */

const twilio = require('twilio');
const { admin, db } = require('../firestore');

class SmsService {
  constructor() {
    const accountSid = process.env.TWILIO_ACCOUNT_SID;
    const authToken = process.env.TWILIO_AUTH_TOKEN;
    const fromNumber = process.env.TWILIO_PHONE_NUMBER;

    if (!accountSid || !authToken || !fromNumber) {
      console.warn('[SmsService] Twilio credentials not configured. Mocking client to avoid runtime crashes.');
      this.client = {
        messages: {
          create: async (payload) => {
            console.log(`[SmsService Mock] Mock SMS sent to ${payload.to}: ${payload.body}`);
            return { sid: `SMmock_${Date.now()}` };
          }
        }
      };
      this.fromNumber = fromNumber || '+15017122661';
    } else {
      this.client = twilio(accountSid, authToken);
      this.fromNumber = fromNumber;
    }
  }

  /**
   * Send SMS
   *
   * @param {string} phoneNumber - E.164 format (+91XXXXXXXXXX)
   * @param {string} message - SMS text
   * @param {object} options - { category, orderId, etc. }
   * @returns {Promise<object>} - { success: true, messageSid }
   */
  async sendSms(phoneNumber, message, options = {}) {
    const firestore = db();

    try {
      // 1. Validate phone number format
      if (!phoneNumber.startsWith('+')) {
        throw new Error('Phone number must be in E.164 format (+91XXXXXXXXXX)');
      }

      // 2. Check preferences if customer is known
      let smsSuppressed = false;
      if (options.customerId) {
        const prefsRef = firestore
          .collection('users')
          .doc(options.customerId)
          .collection('settings')
          .doc('notification_preferences');

        const prefsDoc = await prefsRef.get();
        const prefs = prefsDoc.exists ? prefsDoc.data() : {};

        const category = options.category || 'order';
        const prefKey = this._getCategoryPreferenceKey(category);
        const smsEnabled = prefs.channels?.sms?.[prefKey] !== false;
        const quietHoursActive = this._isInQuietHours(prefs.quietHours);

        if (!smsEnabled || (quietHoursActive && options.priority !== 'high')) {
          smsSuppressed = true;
        }
      }

      if (smsSuppressed) {
        console.log(`[SmsService] SMS suppressed for ${phoneNumber}: preference`);
        return { success: false, reason: 'suppressed' };
      }

      // 3. Send via Twilio
      const result = await this.client.messages.create({
        body: message,
        from: this.fromNumber,
        to: phoneNumber,
      });

      // 4. Log SMS sent
      await this._logSms(options.customerId, 'sent', {
        phoneNumber,
        message,
        messageSid: result.sid,
        category: options.category,
      });

      console.log(`[SmsService] SMS sent to ${phoneNumber}: ${result.sid}`);

      return {
        success: true,
        messageSid: result.sid,
        phoneNumber,
      };
    } catch (error) {
      console.error(`[SmsService] Error sending SMS to ${phoneNumber}:`, error.message);

      await this._logSms(options.customerId, 'failed', {
        phoneNumber,
        message,
        error: error.message,
        category: options.category,
      });

      throw error;
    }
  }

  /**
   * Send delivery OTP
   *
   * @param {string} phoneNumber - Customer phone
   * @param {string} otp - 4-6 digit OTP
   * @param {string} customerId - Optional
   * @returns {Promise}
   */
  async sendDeliveryOtp(phoneNumber, otp, customerId) {
    const message = `Your Fufaji delivery OTP is ${otp}. Valid for 10 minutes. Do not share with anyone.`;

    return this.sendSms(phoneNumber, message, {
      category: 'otp',
      customerId,
      priority: 'high',
    });
  }

  /**
   * Send order status update SMS
   *
   * @param {string} phoneNumber
   * @param {string} status - 'confirmed', 'packed', 'on_the_way', 'delivered'
   * @param {string} orderId
   * @param {string} customerId
   * @param {object} extraData - { eta, riderName, etc. }
   * @returns {Promise}
   */
  async sendOrderStatus(phoneNumber, status, orderId, customerId, extraData = {}) {
    let message = '';

    const orderRef = `#${orderId.slice(-6)}`;

    switch (status) {
      case 'confirmed':
        message = `Your order ${orderRef} is confirmed! Estimated delivery: ${extraData.eta || '30 min'}. Track: https://fufaji.app/order/${orderId}`;
        break;
      case 'packed':
        message = `Your order ${orderRef} is packed and ready for dispatch!`;
        break;
      case 'on_the_way':
        message = `Your order ${orderRef} is on the way! Rider: ${extraData.riderName || 'Pending'}. ETA: ${extraData.eta || '15 min'}`;
        break;
      case 'delivered':
        message = `Your order ${orderRef} has been delivered! Rate your experience: https://fufaji.app/order/${orderId}/review`;
        break;
      default:
        message = `Order ${orderRef} status updated. Check app for details.`;
    }

    return this.sendSms(phoneNumber, message, {
      category: 'order_status',
      orderId,
      customerId,
      priority: status === 'confirmed' || status === 'on_the_way' ? 'high' : 'normal',
    });
  }

  /**
   * Send payment alert SMS
   *
   * @param {string} phoneNumber
   * @param {number} amount
   * @param {string} type - 'deducted' or 'refunded'
   * @param {string} customerId
   * @param {object} extraData - { orderId, method, etc. }
   * @returns {Promise}
   */
  async sendPaymentAlert(phoneNumber, amount, type, customerId, extraData = {}) {
    const action = type === 'deducted' ? 'Payment of' : 'Refund of';
    const preposition = type === 'deducted' ? 'from' : 'to';

    let message = `${action} ₹${amount.toFixed(0)} ${preposition} your Fufaji wallet.`;

    if (extraData.orderId) {
      message += ` Order: ${extraData.orderId.slice(-6)}`;
    }

    return this.sendSms(phoneNumber, message, {
      category: 'payment',
      customerId,
      priority: 'high',
    });
  }

  /**
   * Send promotional SMS
   *
   * @param {string} phoneNumber
   * @param {string} promoText - Offer text
   * @param {string} deepLink - Short link to offer
   * @param {string} customerId
   * @returns {Promise}
   */
  async sendPromotion(phoneNumber, promoText, deepLink, customerId) {
    const message = `${promoText} Tap: ${deepLink}`;

    return this.sendSms(phoneNumber, message, {
      category: 'promotion',
      customerId,
    });
  }

  /**
   * Send batch SMS to multiple numbers
   *
   * @param {array} phoneNumbers - Array of E.164 numbers
   * @param {string} message
   * @param {object} options
   * @returns {Promise<object>} - { successful: [...], failed: [...] }
   */
  async sendBatchSms(phoneNumbers, message, options = {}) {
    if (!Array.isArray(phoneNumbers) || phoneNumbers.length === 0) {
      throw new Error('phoneNumbers must be a non-empty array');
    }

    const successful = [];
    const failed = [];

    for (const phoneNumber of phoneNumbers) {
      try {
        const result = await this.sendSms(phoneNumber, message, options);
        if (result.success) {
          successful.push(phoneNumber);
        } else {
          failed.push(phoneNumber);
        }
      } catch (error) {
        console.error(`[SmsService] Batch error for ${phoneNumber}:`, error.message);
        failed.push(phoneNumber);
      }
    }

    console.log(`[SmsService] Batch complete: ${successful.length} sent, ${failed.length} failed`);

    return { successful, failed };
  }

  /**
   * Get SMS delivery status
   *
   * @param {string} messageSid - Twilio message SID
   * @returns {Promise<object>} - { status, sentAt, deliveredAt, errorCode }
   */
  async getSmsStatus(messageSid) {
    try {
      const message = await this.client.messages(messageSid).fetch();

      return {
        status: message.status,
        sentAt: message.dateCreated,
        deliveredAt: message.dateSent,
        errorCode: message.errorCode,
        errorMessage: message.errorMessage,
      };
    } catch (error) {
      console.error('[SmsService] Error fetching SMS status:', error.message);
      throw error;
    }
  }

  /**
   * Handle SMS delivery reports (webhook from Twilio)
   *
   * @param {object} webhookData - { messageSid, messageStatus, errorCode }
   * @returns {Promise}
   */
  async handleDeliveryReport(webhookData) {
    const firestore = db();
    const FieldValue = admin.firestore.FieldValue;

    try {
      const { messageSid, messageStatus, errorCode } = webhookData;

      // Log delivery status
      const reportRef = firestore.collection('sms_delivery_reports').doc(messageSid);

      await reportRef.set({
        messageSid,
        status: messageStatus,
        errorCode,
        reportedAt: FieldValue.serverTimestamp(),
      });

      console.log(`[SmsService] Delivery report logged for ${messageSid}: ${messageStatus}`);

      return { success: true };
    } catch (error) {
      console.error('[SmsService] Error handling delivery report:', error.message);
      throw error;
    }
  }

  /**
   * Get SMS history for customer
   *
   * @param {string} customerId
   * @param {number} limit
   * @returns {Promise<array>}
   */
  async getSmsHistory(customerId, limit = 50) {
    const firestore = db();

    try {
      const historyRef = firestore
        .collection('users')
        .doc(customerId)
        .collection('sms_history')
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
      console.error('[SmsService] Error fetching SMS history:', error.message);
      throw error;
    }
  }

  // ========== PRIVATE HELPERS ==========

  /**
   * Log SMS sent
   * @private
   */
  async _logSms(customerId, status, details = {}) {
    const firestore = db();
    const FieldValue = admin.firestore.FieldValue;

    try {
      if (!customerId) return; // Skip if no customer ID

      const historyRef = firestore
        .collection('users')
        .doc(customerId)
        .collection('sms_history')
        .doc();

      await historyRef.set({
        status,
        ...details,
        timestamp: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('[SmsService] Error logging SMS:', error.message);
    }
  }

  /**
   * Map notification category to preference key
   * @private
   */
  _getCategoryPreferenceKey(category) {
    const map = {
      otp: 'critical',
      order_status: 'orders',
      payment: 'payments',
      promotion: 'promotions',
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
      return currentHour >= startHour || currentHour < endHour;
    }
  }
}

module.exports = SmsService;
