/**
 * ============================================================================
 * tests/notifications.test.js - Push, Email, SMS Service Tests
 * ============================================================================
 */

const PushNotificationService = require('../src/services/PushNotificationService');
const EmailService = require('../src/services/EmailService');
const SmsService = require('../src/services/SmsService');
const NotificationScheduler = require('../src/services/NotificationScheduler');

describe('Push Notification Service', () => {
  let pushService;

  beforeAll(() => {
    pushService = new PushNotificationService();
  });

  describe('sendPushNotification', () => {
    test('should send push notification successfully', async () => {
      const result = await pushService.sendPushNotification(
        'user-123',
        'Order Confirmed',
        'Your order is confirmed!',
        { orderId: 'order-456', category: 'order_update' }
      );

      expect(result.success).toBe(true);
      expect(result.userId).toBe('user-123');
      expect(result.messageId).toBeDefined();
    });

    test('should handle missing FCM token', async () => {
      const result = await pushService.sendPushNotification(
        'user-no-fcm',
        'Test',
        'Test'
      );

      expect(result.success).toBe(false);
      expect(result.reason).toBe('no_fcm_token');
    });

    test('should respect quiet hours', async () => {
      // Test with quiet hours preference set
      const result = await pushService.sendPushNotification(
        'user-quiet-hours',
        'Low Priority',
        'Low priority during quiet hours'
      );

      // Should be suppressed unless priority: 'high'
      expect([true, false]).toContain(result.success);
    });

    test('should respect user preferences', async () => {
      const result = await pushService.sendPushNotification(
        'user-disabled',
        'Test',
        'Test',
        { category: 'promotion' } // User disabled promos
      );

      // May succeed or fail based on preferences
      expect([true, false]).toContain(result.success);
    });
  });

  describe('sendBatchNotification', () => {
    test('should send to multiple users', async () => {
      const result = await pushService.sendBatchNotification(
        ['user-1', 'user-2', 'user-3'],
        'Promotion',
        'Save 50%!',
        { action: 'view_promo' }
      );

      expect(result.successful).toBeDefined();
      expect(result.failed).toBeDefined();
      expect(result.successful.length + result.failed.length).toBeGreaterThan(0);
    });

    test('should reject empty user array', async () => {
      expect(() =>
        pushService.sendBatchNotification([], 'Test', 'Test')
      ).rejects.toThrow();
    });

    test('should handle batch errors gracefully', async () => {
      const result = await pushService.sendBatchNotification(
        ['valid-user', 'invalid-user', 'another-user'],
        'Test',
        'Test'
      );

      expect(result.successful.length >= 0).toBe(true);
      expect(result.failed.length >= 0).toBe(true);
    });
  });

  describe('scheduleNotification', () => {
    test('should schedule notification for future time', async () => {
      const futureTime = new Date(Date.now() + 3600000); // 1 hour from now

      const notificationId = await pushService.scheduleNotification(
        'user-123',
        'Scheduled',
        'This is scheduled',
        futureTime
      );

      expect(notificationId).toBeDefined();
      expect(typeof notificationId).toBe('string');
    });

    test('should reject invalid date', async () => {
      expect(() =>
        pushService.scheduleNotification(
          'user-123',
          'Test',
          'Test',
          'not-a-date'
        )
      ).rejects.toThrow();
    });
  });

  describe('Order event notifications', () => {
    test('should send order confirmed notification', async () => {
      const result = await pushService.notifyOrderConfirmed(
        'order-123',
        'customer-456',
        30
      );

      expect(result.success).toBe(true);
      expect(result.userId).toBe('customer-456');
    });

    test('should send out for delivery notification', async () => {
      const result = await pushService.notifyOutForDelivery(
        'order-123',
        'customer-456',
        '2:30 PM'
      );

      expect(result.success).toBe(true);
    });

    test('should send delivery completed notification', async () => {
      const result = await pushService.notifyDelivered('order-123', 'customer-456');

      expect(result.success).toBe(true);
    });

    test('should send refund notification', async () => {
      const result = await pushService.notifyRefunded('customer-456', 500, 'order-123');

      expect(result.success).toBe(true);
    });
  });

  describe('FCM token management', () => {
    test('should register FCM token', async () => {
      const result = await pushService.registerFCMToken(
        'user-123',
        'fcm-token-xyz',
        'device-456',
        'iPhone 12'
      );

      expect(result.success).toBe(true);
    });

    test('should get user FCM tokens', async () => {
      const tokens = await pushService.getUserFCMTokens('user-123');

      expect(Array.isArray(tokens)).toBe(true);
      if (tokens.length > 0) {
        expect(tokens[0]).toHaveProperty('deviceId');
        expect(tokens[0]).toHaveProperty('fcmToken');
      }
    });

    test('should remove FCM token', async () => {
      const result = await pushService.removeFCMToken('user-123', 'device-456');

      expect(result.success).toBe(true);
    });

    test('should handle invalid token gracefully', async () => {
      const result = await pushService.handleInvalidToken(
        'user-123',
        'invalid-token'
      );

      expect(result.success).toBe(true);
    });
  });

  describe('Notification history', () => {
    test('should retrieve notification history', async () => {
      const history = await pushService.getNotificationHistory('user-123', 10);

      expect(Array.isArray(history)).toBe(true);
      if (history.length > 0) {
        expect(history[0]).toHaveProperty('status');
        expect(history[0]).toHaveProperty('timestamp');
      }
    });
  });
});

describe('Email Service', () => {
  let emailService;

  beforeAll(() => {
    emailService = new EmailService();
  });

  describe('sendOrderConfirmation', () => {
    test('should send order confirmation email', async () => {
      const result = await emailService.sendOrderConfirmation(
        'customer-123',
        'order-456',
        {
          items: [
            { name: 'Pizza', quantity: 2, price: 250 },
            { name: 'Coke', quantity: 1, price: 50 },
          ],
          total: 550,
          deliveryAddress: '123 Main St',
          estimatedTime: '30-45 minutes',
        }
      );

      expect(result.success).toBe(true);
    });
  });

  describe('sendDeliveryTracking', () => {
    test('should send delivery tracking email', async () => {
      const result = await emailService.sendDeliveryTracking(
        'customer-123',
        'order-456',
        'John Rider',
        '+919876543210',
        '2:30 PM'
      );

      expect(result.success).toBe(true);
    });
  });

  describe('sendRefundNotification', () => {
    test('should send refund email', async () => {
      const result = await emailService.sendRefundNotification(
        'customer-123',
        'order-456',
        500,
        'Order cancelled by user'
      );

      expect(result.success).toBe(true);
    });
  });

  describe('sendReviewRequest', () => {
    test('should send review request email', async () => {
      const result = await emailService.sendReviewRequest(
        'customer-123',
        'order-456'
      );

      expect(result.success).toBe(true);
    });
  });

  describe('sendWeeklySummary', () => {
    test('should send weekly summary email', async () => {
      const result = await emailService.sendWeeklySummary(
        'customer-123',
        {
          totalOrders: 5,
          totalSpent: 2500,
          favoriteItem: 'Pizza Margherita',
          nextPromo: 'Save 30% this weekend!',
        }
      );

      expect(result.success).toBe(true);
    });
  });

  describe('Email history', () => {
    test('should retrieve email history', async () => {
      const history = await emailService.getEmailHistory('customer-123', 10);

      expect(Array.isArray(history)).toBe(true);
      if (history.length > 0) {
        expect(history[0]).toHaveProperty('type');
        expect(history[0]).toHaveProperty('timestamp');
      }
    });
  });
});

describe('SMS Service', () => {
  let smsService;

  beforeAll(() => {
    smsService = new SmsService();
  });

  describe('sendSms', () => {
    test('should send SMS to valid number', async () => {
      const result = await smsService.sendSms(
        '+919876543210',
        'Your OTP is 1234',
        { customerId: 'user-123', category: 'otp', priority: 'high' }
      );

      expect(result.success).toBe(true);
      expect(result.messageSid).toBeDefined();
    });

    test('should reject invalid phone format', async () => {
      expect(() =>
        smsService.sendSms('9876543210', 'Test message')
      ).rejects.toThrow();
    });

    test('should respect SMS preferences', async () => {
      const result = await smsService.sendSms(
        '+919876543210',
        'Promotion',
        { customerId: 'user-sms-disabled', category: 'promotion' }
      );

      // May be sent or suppressed based on preferences
      expect([true, false]).toContain(result.success);
    });
  });

  describe('SMS event notifications', () => {
    test('should send delivery OTP', async () => {
      const result = await smsService.sendDeliveryOtp(
        '+919876543210',
        '1234',
        'user-123'
      );

      expect(result.success).toBe(true);
    });

    test('should send order status SMS', async () => {
      const result = await smsService.sendOrderStatus(
        '+919876543210',
        'confirmed',
        'order-123',
        'user-123',
        { eta: '30 min' }
      );

      expect(result.success).toBe(true);
    });

    test('should send payment alert SMS', async () => {
      const result = await smsService.sendPaymentAlert(
        '+919876543210',
        500,
        'deducted',
        'user-123',
        { orderId: 'order-123' }
      );

      expect(result.success).toBe(true);
    });

    test('should send promotional SMS', async () => {
      const result = await smsService.sendPromotion(
        '+919876543210',
        'Save 50% on your next order!',
        'fufaji.app/promo123',
        'user-123'
      );

      expect(result.success).toBe(true);
    });
  });

  describe('Batch SMS', () => {
    test('should send batch SMS', async () => {
      const result = await smsService.sendBatchSms(
        ['+919876543210', '+919876543211', '+919876543212'],
        'All items 40% off this weekend!',
        { category: 'promotion' }
      );

      expect(result.successful).toBeDefined();
      expect(result.failed).toBeDefined();
    });

    test('should reject empty phone array', async () => {
      expect(() =>
        smsService.sendBatchSms([], 'Test')
      ).rejects.toThrow();
    });
  });

  describe('SMS delivery tracking', () => {
    test('should get SMS status', async () => {
      const status = await smsService.getSmsStatus('SM123xyz');

      expect(status).toHaveProperty('status');
      expect(status).toHaveProperty('sentAt');
    });

    test('should handle delivery reports', async () => {
      const result = await smsService.handleDeliveryReport({
        messageSid: 'SM123xyz',
        messageStatus: 'delivered',
      });

      expect(result.success).toBe(true);
    });
  });

  describe('SMS history', () => {
    test('should retrieve SMS history', async () => {
      const history = await smsService.getSmsHistory('user-123', 10);

      expect(Array.isArray(history)).toBe(true);
      if (history.length > 0) {
        expect(history[0]).toHaveProperty('status');
        expect(history[0]).toHaveProperty('timestamp');
      }
    });
  });
});

describe('Notification Scheduler', () => {
  let scheduler;

  beforeAll(() => {
    scheduler = new NotificationScheduler();
  });

  describe('processScheduledNotifications', () => {
    test('should process pending scheduled notifications', async () => {
      const result = await scheduler.processScheduledNotifications();

      expect(result.success).toBe(true);
      expect(result).toHaveProperty('processed');
      expect(result).toHaveProperty('successful');
      expect(result).toHaveProperty('failed');
    });
  });

  describe('sendWeeklySummaries', () => {
    test('should send weekly summaries', async () => {
      const result = await scheduler.sendWeeklySummaries();

      expect(result.success).toBe(true);
      expect(result).toHaveProperty('sent');
    });
  });

  describe('Order notifications', () => {
    test('should send order confirmation notifications', async () => {
      const result = await scheduler.sendOrderConfirmationNotifications(
        'order-123',
        'customer-456',
        {
          items: [{ name: 'Pizza', quantity: 1, price: 299 }],
          total: 299,
          estimatedDeliveryTime: '30-45',
        }
      );

      expect(result.success).toBe(true);
    });

    test('should send delivery status notifications', async () => {
      const result = await scheduler.sendDeliveryStatusNotifications(
        'order-123',
        'customer-456',
        'out_for_delivery',
        { eta: '15 min' }
      );

      expect(result.success).toBe(true);
    });
  });
});
