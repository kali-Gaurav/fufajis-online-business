import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fufajis_online/services/notification_service.dart';
import 'package:fufajis_online/services/whatsapp_notification_service.dart';
import 'package:fufajis_online/services/notification_retry_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late NotificationService notificationService;
  late NotificationRetryService retryService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    notificationService = NotificationService();
    notificationService.db = fakeFirestore;

    retryService = NotificationRetryService();
    retryService.db = fakeFirestore;

    WhatsAppNotificationService.db = fakeFirestore;
  });

  group('Notification System Tests', () {
    const String userId = 'test_user_123';
    const String phoneNumber = '919999999999';

    test('Quiet Hours Buffering for Non-Essential Notifications', () async {
      // Set quiet hours settings to cover the current time
      final nowHour = DateTime.now().hour;
      final startHour = (nowHour - 1 + 24) % 24;
      final endHour = (nowHour + 1) % 24;

      await fakeFirestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('notifications')
          .set({
            'promotions': true,
            'quietHoursStart': '$startHour:00',
            'quietHoursEnd': '$endHour:00',
          });

      // Try sending a non-essential promotion notification
      final sent = await notificationService.sendNotificationToUser(
        userId: userId,
        title: 'Special Discount!',
        body: 'Get 20% off on all vegetables.',
        data: {'type': 'promotion'},
      );

      // It should be buffered, so sent returns false
      expect(sent, isFalse);

      // Check that it was logged to notification_failures (buffered queue)
      final failures = await fakeFirestore.collection('notification_failures').get();
      expect(failures.docs.length, 1);
      expect(failures.docs.first.data()['errorMessage'], contains('Buffered due to Quiet Hours'));
    });

    test('Quiet Hours Transactional Bypass', () async {
      // Set quiet hours settings to cover the current time
      final nowHour = DateTime.now().hour;
      final startHour = (nowHour - 1 + 24) % 24;
      final endHour = (nowHour + 1) % 24;

      await fakeFirestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('notifications')
          .set({
            'orderUpdates': true,
            'quietHoursStart': '$startHour:00',
            'quietHoursEnd': '$endHour:00',
          });

      // Try sending a transactional orderUpdate notification
      final sent = await notificationService.sendNotificationToUser(
        userId: userId,
        title: 'Order Out for Delivery',
        body: 'Your order is on the way.',
        data: {'type': 'orderUpdate'},
      );

      // Transactional should bypass quiet hours and be sent immediately
      expect(sent, isTrue);

      final notifications = await fakeFirestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();
      expect(notifications.docs.length, 1);
      expect(notifications.docs.first.data()['title'], 'Order Out for Delivery');
    });

    test('Non-Essential Notification Hourly Rate Limiting', () async {
      // Set limit to 2 per hour for non-essential notifications
      await fakeFirestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('notifications')
          .set({
            'promotions': true,
            'quietHoursStart': '23:00', // Non-quiet hours
            'quietHoursEnd': '05:00',
            'frequencyLimitPerHour': 2,
          });

      // Seed 2 existing promotion notifications within the last hour
      final notificationsCol = fakeFirestore
          .collection('users')
          .doc(userId)
          .collection('notifications');

      await notificationsCol.add({
        'title': 'Promo 1',
        'type': 'promotion',
        'timestamp': DateTime.now(),
      });
      await notificationsCol.add({
        'title': 'Promo 2',
        'type': 'promotion',
        'timestamp': DateTime.now(),
      });

      // Attempt to send a 3rd promotion notification
      final sent = await notificationService.sendNotificationToUser(
        userId: userId,
        title: 'Promo 3',
        body: 'Limited time offer!',
        data: {'type': 'promotion'},
      );

      // Third should be rate limited (sent returns false)
      expect(sent, isFalse);
    });

    test('Resilient Channel Fallback Routing', () async {
      // Configure user with no FCM token
      await fakeFirestore.collection('users').doc(userId).set({'name': 'Test User'});

      // Send with fallback (should fail WhatsApp, FCM, and SMS, but succeed at In-app)
      final success = await WhatsAppNotificationService.sendWithFallback(
        customerId: userId,
        phoneNumber: phoneNumber,
        title: 'Fallback Test',
        body: 'Testing channel routing fallback.',
        notificationType: 'orderUpdate',
      );

      expect(success, isTrue);

      // Verify that the final fallback (In-app) was recorded
      final inAppNotifications = await fakeFirestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();
      expect(inAppNotifications.docs.length, 1);
      expect(inAppNotifications.docs.first.data()['title'], 'Fallback Test');

      // Verify audit logs in Firestore
      final logs = await fakeFirestore.collection('notification_delivery_log').get();
      expect(logs.docs.length, 1);
      expect(logs.docs.first.data()['channelUsed'], 'in_app');
    });
  });
}
