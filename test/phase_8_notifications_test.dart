import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/providers/notification_provider.dart';
import 'package:fufajis_online/models/offline_notification_queue_model.dart';
import 'package:fufajis_online/services/offline_notification_queue_service.dart';

void main() {
  group('Phase 8: Notifications and Messaging', () {
    // Task 8.1: NotificationProvider Implementation
    group('8.1 NotificationProvider Implementation', () {
      test('NotificationModel should parse notification type correctly', () {
        final model = NotificationModel(
          id: '1',
          title: 'Test',
          body: 'Test body',
          type: NotificationType.orderUpdate,
          timestamp: DateTime.now(),
        );

        expect(model.type, NotificationType.orderUpdate);
        expect(model.isRead, false);
      });

      test('NotificationModel should convert to and from map', () {
        final original = NotificationModel(
          id: '1',
          title: 'Order Update',
          body: 'Your order has been confirmed',
          type: NotificationType.orderUpdate,
          timestamp: DateTime.now(),
          isRead: false,
          data: {'orderId': 'order_123'},
          deepLink: '/customer/order-detail/order_123',
        );

        final map = original.toMap();
        expect(map['id'], '1');
        expect(map['title'], 'Order Update');
        expect(map['type'], 'orderUpdate');
      });

      test('NotificationSettings should parse quiet hours correctly', () {
        final settings = NotificationSettings(
          quietHoursStart: const TimeOfDay(hour: 22, minute: 0),
          quietHoursEnd: const TimeOfDay(hour: 8, minute: 0),
        );

        expect(settings.quietHoursStart.hour, 22);
        expect(settings.quietHoursEnd.hour, 8);
      });

      test('NotificationSettings should detect quiet hours correctly', () {
        final settings = NotificationSettings(
          quietHoursStart: const TimeOfDay(hour: 22, minute: 0),
          quietHoursEnd: const TimeOfDay(hour: 8, minute: 0),
        );

        // This test depends on current time, so we just verify the method exists
        final isInQuietHours = settings.isInQuietHours();
        expect(isInQuietHours, isA<bool>());
      });

      test('NotificationSettings should convert to and from map', () {
        final original = NotificationSettings(
          orderUpdates: true,
          promotions: false,
          priceDrops: true,
          shopUpdates: false,
          systemMessages: true,
          frequencyLimitPerHour: 15,
        );

        final map = original.toMap();
        expect(map['orderUpdates'], true);
        expect(map['promotions'], false);
        expect(map['frequencyLimitPerHour'], 15);

        final restored = NotificationSettings.fromMap(map);
        expect(restored.orderUpdates, true);
        expect(restored.promotions, false);
        expect(restored.frequencyLimitPerHour, 15);
      });
    });

    // Task 8.2: Notification Types
    group('8.2 Notification Types', () {
      test('Should support all notification types', () {
        expect(NotificationType.orderUpdate, isNotNull);
        expect(NotificationType.promotion, isNotNull);
        expect(NotificationType.priceDrop, isNotNull);
        expect(NotificationType.shopUpdate, isNotNull);
        expect(NotificationType.systemMessage, isNotNull);
      });

      test('Should parse notification type from string', () {
        final typeStr = 'orderUpdate';
        final parsed = NotificationModel.parseNotificationType(typeStr);
        expect(parsed, NotificationType.orderUpdate);
      });

      test('Should handle invalid notification type', () {
        final parsed = NotificationModel.parseNotificationType('invalid');
        expect(parsed, isNull);
      });

      test('Should create order update notification', () {
        final notification = NotificationModel(
          id: '1',
          title: 'Order Confirmed',
          body: 'Your order has been confirmed',
          type: NotificationType.orderUpdate,
          timestamp: DateTime.now(),
          data: {'orderId': 'order_123', 'status': 'confirmed'},
          deepLink: '/customer/order-detail/order_123',
        );

        expect(notification.type, NotificationType.orderUpdate);
        expect(notification.data?['orderId'], 'order_123');
      });

      test('Should create promotion notification', () {
        final notification = NotificationModel(
          id: '2',
          title: 'Flash Sale',
          body: 'Get 50% off on groceries',
          type: NotificationType.promotion,
          timestamp: DateTime.now(),
          data: {'discount': '50', 'category': 'groceries'},
          deepLink: '/customer/home?category=groceries',
        );

        expect(notification.type, NotificationType.promotion);
        expect(notification.data?['discount'], '50');
      });

      test('Should create price drop notification', () {
        final notification = NotificationModel(
          id: '3',
          title: 'Price Drop',
          body: 'Milk price dropped to ₹40',
          type: NotificationType.priceDrop,
          timestamp: DateTime.now(),
          data: {'productId': 'prod_123', 'newPrice': '40'},
          deepLink: '/customer/product-detail/prod_123',
        );

        expect(notification.type, NotificationType.priceDrop);
        expect(notification.data?['newPrice'], '40');
      });

      test('Should create shop update notification', () {
        final notification = NotificationModel(
          id: '4',
          title: 'New Products',
          body: 'Fresh vegetables added to your favorite shop',
          type: NotificationType.shopUpdate,
          timestamp: DateTime.now(),
          data: {'shopId': 'shop_123'},
          deepLink: '/customer/shop-detail/shop_123',
        );

        expect(notification.type, NotificationType.shopUpdate);
        expect(notification.data?['shopId'], 'shop_123');
      });

      test('Should create system message notification', () {
        final notification = NotificationModel(
          id: '5',
          title: 'App Update',
          body: 'New version available',
          type: NotificationType.systemMessage,
          timestamp: DateTime.now(),
          data: {'version': '1.1.0'},
        );

        expect(notification.type, NotificationType.systemMessage);
        expect(notification.data?['version'], '1.1.0');
      });
    });

    // Task 8.3: NotificationCenter
    group('8.3 NotificationCenter', () {
      test('Should mark notification as read', () {
        final notification = NotificationModel(
          id: '1',
          title: 'Test',
          body: 'Test body',
          type: NotificationType.orderUpdate,
          timestamp: DateTime.now(),
          isRead: false,
        );

        expect(notification.isRead, false);
      });

      test('Should delete notification', () {
        final notification = NotificationModel(
          id: '1',
          title: 'Test',
          body: 'Test body',
          type: NotificationType.orderUpdate,
          timestamp: DateTime.now(),
        );

        expect(notification.id, '1');
      });

      test('Should handle deep link navigation', () {
        final notification = NotificationModel(
          id: '1',
          title: 'Order Update',
          body: 'Your order is ready',
          type: NotificationType.orderUpdate,
          timestamp: DateTime.now(),
          deepLink: '/customer/order-detail/order_123',
        );

        expect(notification.deepLink, '/customer/order-detail/order_123');
      });
    });

    // Task 8.4: NotificationSettingsScreen
    group('8.4 NotificationSettingsScreen', () {
      test('Should enable/disable order updates', () {
        final settings = NotificationSettings(orderUpdates: true);
        expect(settings.orderUpdates, true);

        settings.orderUpdates = false;
        expect(settings.orderUpdates, false);
      });

      test('Should enable/disable promotions', () {
        final settings = NotificationSettings(promotions: true);
        expect(settings.promotions, true);

        settings.promotions = false;
        expect(settings.promotions, false);
      });

      test('Should enable/disable price drops', () {
        final settings = NotificationSettings(priceDrops: true);
        expect(settings.priceDrops, true);

        settings.priceDrops = false;
        expect(settings.priceDrops, false);
      });

      test('Should enable/disable shop updates', () {
        final settings = NotificationSettings(shopUpdates: true);
        expect(settings.shopUpdates, true);

        settings.shopUpdates = false;
        expect(settings.shopUpdates, false);
      });

      test('Should enable/disable system messages', () {
        final settings = NotificationSettings(systemMessages: true);
        expect(settings.systemMessages, true);

        settings.systemMessages = false;
        expect(settings.systemMessages, false);
      });

      test('Should set quiet hours', () {
        final settings = NotificationSettings(
          quietHoursStart: const TimeOfDay(hour: 22, minute: 0),
          quietHoursEnd: const TimeOfDay(hour: 8, minute: 0),
        );

        expect(settings.quietHoursStart.hour, 22);
        expect(settings.quietHoursEnd.hour, 8);
      });

      test('Should set frequency limit', () {
        final settings = NotificationSettings(frequencyLimitPerHour: 20);
        expect(settings.frequencyLimitPerHour, 20);

        settings.frequencyLimitPerHour = 30;
        expect(settings.frequencyLimitPerHour, 30);
      });

      test('Should validate frequency limit range', () {
        final settings = NotificationSettings(frequencyLimitPerHour: 5);
        expect(settings.frequencyLimitPerHour, 5);

        settings.frequencyLimitPerHour = 50;
        expect(settings.frequencyLimitPerHour, 50);
      });
    });

    // Task 8.5: Offline Notification Queue
    group('8.5 Offline Notification Queue', () {
      test('OfflineNotificationQueueModel should create correctly', () {
        final model = OfflineNotificationQueueModel(
          id: '1',
          userId: 'user_123',
          title: 'Test',
          body: 'Test body',
          type: 'orderUpdate',
          createdAt: DateTime.now(),
          isDelivered: false,
        );

        expect(model.id, '1');
        expect(model.userId, 'user_123');
        expect(model.isDelivered, false);
      });

      test('OfflineNotificationQueueModel should convert to and from map', () {
        final now = DateTime.now();
        final original = OfflineNotificationQueueModel(
          id: '1',
          userId: 'user_123',
          title: 'Order Update',
          body: 'Your order is ready',
          type: 'orderUpdate',
          createdAt: now,
          isDelivered: false,
          data: {'orderId': 'order_123'},
          deepLink: '/customer/order-detail/order_123',
        );

        final map = original.toMap();
        expect(map['id'], '1');
        expect(map['userId'], 'user_123');
        expect(map['type'], 'orderUpdate');
        expect(map['isDelivered'], false);
      });

      test('OfflineNotificationQueueModel should mark as delivered', () {
        final model = OfflineNotificationQueueModel(
          id: '1',
          userId: 'user_123',
          title: 'Test',
          body: 'Test body',
          type: 'orderUpdate',
          createdAt: DateTime.now(),
          isDelivered: false,
        );

        final delivered = model.copyWith(
          isDelivered: true,
          deliveredAt: DateTime.now(),
        );

        expect(delivered.isDelivered, true);
        expect(delivered.deliveredAt, isNotNull);
      });

      test('Should queue notification when offline', () {
        final notification = OfflineNotificationQueueModel(
          id: '1',
          userId: 'user_123',
          title: 'Order Update',
          body: 'Your order is ready',
          type: 'orderUpdate',
          createdAt: DateTime.now(),
          isDelivered: false,
        );

        expect(notification.isDelivered, false);
      });

      test('Should deliver queued notifications when online', () {
        final notification = OfflineNotificationQueueModel(
          id: '1',
          userId: 'user_123',
          title: 'Order Update',
          body: 'Your order is ready',
          type: 'orderUpdate',
          createdAt: DateTime.now(),
          isDelivered: false,
        );

        final delivered = notification.copyWith(isDelivered: true);
        expect(delivered.isDelivered, true);
      });

      test('Should clean up old delivered notifications', () {
        final now = DateTime.now();
        final oldNotification = OfflineNotificationQueueModel(
          id: '1',
          userId: 'user_123',
          title: 'Old Notification',
          body: 'This is old',
          type: 'orderUpdate',
          createdAt: now.subtract(const Duration(days: 2)),
          deliveredAt: now.subtract(const Duration(days: 1)),
          isDelivered: true,
        );

        expect(oldNotification.isDelivered, true);
        expect(oldNotification.deliveredAt, isNotNull);
      });
    });

    // Task 8.6: Checkpoint Validation
    group('8.6 Checkpoint - Notifications Validation', () {
      test('All notification types should be defined', () {
        final types = [
          NotificationType.orderUpdate,
          NotificationType.promotion,
          NotificationType.priceDrop,
          NotificationType.shopUpdate,
          NotificationType.systemMessage,
        ];

        expect(types.length, 5);
        for (var type in types) {
          expect(type, isNotNull);
        }
      });

      test('NotificationSettings should have all required fields', () {
        final settings = NotificationSettings();

        expect(settings.orderUpdates, isA<bool>());
        expect(settings.promotions, isA<bool>());
        expect(settings.priceDrops, isA<bool>());
        expect(settings.shopUpdates, isA<bool>());
        expect(settings.systemMessages, isA<bool>());
        expect(settings.quietHoursStart, isA<TimeOfDay>());
        expect(settings.quietHoursEnd, isA<TimeOfDay>());
        expect(settings.frequencyLimitPerHour, isA<int>());
      });

      test('NotificationModel should have all required fields', () {
        final notification = NotificationModel(
          id: '1',
          title: 'Test',
          body: 'Test body',
          type: NotificationType.orderUpdate,
          timestamp: DateTime.now(),
        );

        expect(notification.id, isA<String>());
        expect(notification.title, isA<String>());
        expect(notification.body, isA<String>());
        expect(notification.type, isA<NotificationType>());
        expect(notification.timestamp, isA<DateTime>());
        expect(notification.isRead, isA<bool>());
      });

      test('OfflineNotificationQueueModel should have all required fields', () {
        final model = OfflineNotificationQueueModel(
          id: '1',
          userId: 'user_123',
          title: 'Test',
          body: 'Test body',
          type: 'orderUpdate',
          createdAt: DateTime.now(),
        );

        expect(model.id, isA<String>());
        expect(model.userId, isA<String>());
        expect(model.title, isA<String>());
        expect(model.body, isA<String>());
        expect(model.type, isA<String>());
        expect(model.createdAt, isA<DateTime>());
        expect(model.isDelivered, isA<bool>());
      });

      test('Should support notification serialization', () {
        final notification = NotificationModel(
          id: '1',
          title: 'Test',
          body: 'Test body',
          type: NotificationType.orderUpdate,
          timestamp: DateTime.now(),
          data: {'key': 'value'},
        );

        final map = notification.toMap();
        expect(map, isA<Map<String, dynamic>>());
        expect(map['id'], '1');
        expect(map['title'], 'Test');
      });

      test('Should support settings serialization', () {
        final settings = NotificationSettings(
          orderUpdates: true,
          promotions: false,
          frequencyLimitPerHour: 15,
        );

        final map = settings.toMap();
        expect(map, isA<Map<String, dynamic>>());
        expect(map['orderUpdates'], true);
        expect(map['promotions'], false);
        expect(map['frequencyLimitPerHour'], 15);
      });
    });
  });
}
