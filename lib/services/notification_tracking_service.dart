import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationTrackingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const Map<String, Map<String, dynamic>> notificationTemplates = {
    'order_confirmed': {
      'priority': 'low',
      'title': 'Order Confirmed!',
      'body': 'Your order has been confirmed and will be prepared shortly.',
    },
    'order_packing': {
      'priority': 'low',
      'title': 'Packing Order',
      'body': 'We\'re preparing your items for delivery.',
    },
    'order_packed': {
      'priority': 'medium',
      'title': 'Ready for Delivery',
      'body': 'Your order is packed and ready to ship.',
    },
    'order_out_for_delivery': {
      'priority': 'high',
      'title': 'Out for Delivery!',
      'body': 'Your order is on the way to you.',
    },
    'order_arriving_soon': {
      'priority': 'high',
      'title': 'Arriving Soon!',
      'body': 'Delivery arriving in approximately 5 minutes.',
    },
    'order_delivered': {
      'priority': 'high',
      'title': 'Order Delivered ✓',
      'body': 'Your order has been delivered. Thank you for ordering!',
    },
    'order_delivery_failed': {
      'priority': 'high',
      'title': 'Delivery Failed',
      'body': 'We couldn\'t reach you. Please contact support.',
    },
    'support_ticket_update': {
      'priority': 'medium',
      'title': 'Support Update',
      'body': 'Your support ticket has been updated.',
    },
  };

  Future<String?> getDeviceToken() async {
    try {
      final token = await _messaging.getToken();
      return token;
    } catch (e) {
      print('Error getting device token: $e');
      return null;
    }
  }

  Future<void> sendOrderNotification({
    required String userId,
    required String eventType, // order_confirmed, order_out_for_delivery, etc.
    required Map<String, dynamic> data,
  }) async {
    try {
      final template = notificationTemplates[eventType];
      if (template == null) {
        print('Unknown notification type: $eventType');
        return;
      }

      // In production, this would send via a backend service
      // For now, we'll just log it
      print('Sending notification to $userId: ${template['title']}');
      print('Data: $data');

      // You would typically send this to a backend service which sends via FCM
      // Example endpoint: POST /notifications/send
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Future<void> sendNotificationNow({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // This would typically call a backend endpoint
      // The backend would use Firebase Admin SDK to send the message
      print('Notification: $title');
      print('Body: $body');
      print('Data: $data');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  void setupNotificationHandlers() {
    // Handle notification when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });

    // Handle notification when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      print('Message data: ${message.data}');
    });
  }
}
