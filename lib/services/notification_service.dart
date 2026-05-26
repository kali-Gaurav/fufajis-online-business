import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Background message entry point (must be top-level static)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background push notification: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize(BuildContext context) async {
    if (_initialized) return;

    // 1. Request notification permissions from user
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User push notification status: ${settings.authorizationStatus}');

    // 2. Initialize local notifications for beautiful foreground alerts
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification clicked: ${response.payload}");
      },
    );

    // 3. Configure FCM background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Configure FCM foreground messaging listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Foreground message received: ${message.notification?.title}");
      
      // If notification payload exists, show a premium heads-up banner locally
      if (message.notification != null) {
        showLocalNotification(
          message.notification!.title ?? 'Fufaji\'s Online Update',
          message.notification!.body ?? '',
          payload: jsonEncode(message.data),
          type: message.data['type'],
        );
      }
    });

    // 5. Handle App opening from terminated state via push notification
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("App launched from terminated state via notification: ${initialMessage.messageId}");
    }

    // 6. Handle App opening from background state via push notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("App brought to foreground via notification: ${message.messageId}");
    });

    _initialized = true;
  }

  // Retrieve current FCM token for registration
  Future<String?> getFCMToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint("Error fetching FCM token: $e");
      return null;
    }
  }

  // Display beautiful local heads-up notification using FlutterLocalNotifications
  Future<void> showLocalNotification(
    String title,
    String body, {
    String? payload,
    String? type,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'fufajis_high_importance_channel',
      'Fufaji\'s Core Notifications',
      channelDescription: 'Highly important alerts regarding order lifecycle and operations.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  // Helper routine to trigger visual push simulation when Firestore statuses update
  void triggerLocalOrderStatusNotification(String orderNumber, String status) {
    String title = "📦 Order #${orderNumber.toUpperCase()} Update";
    String body = "";

    switch (status.toLowerCase()) {
      case 'confirmed':
        body = "Fufaji's Online has confirmed your order! We are preparing it now.";
        break;
      case 'processing':
        body = "Your order has been packed and is ready for pickup.";
        break;
      case 'outfordelivery':
        body = "Out for Delivery! 🚴 Our rider is heading your way. Share the OTP to verify.";
        break;
      case 'delivered':
        body = "Delivered! 🎉 Thank you for shopping with Fufaji's Online! Enjoy your items.";
        break;
      case 'cancelled':
        body = "Your order #${orderNumber.toUpperCase()} has been cancelled.";
        break;
      default:
        body = "Your order status is now: $status.";
    }

    showLocalNotification(title, body, type: 'orderUpdate');
  }

  // Trigger promotion notification
  void triggerPromotionNotification(String title, String body, {String? discount}) {
    final fullTitle = "🎉 $title";
    final fullBody = discount != null ? "$body - Save $discount!" : body;
    showLocalNotification(fullTitle, fullBody, type: 'promotion');
  }

  // Trigger price drop notification
  void triggerPriceDropNotification(String productName, String oldPrice, String newPrice) {
    final title = "💰 Price Drop on $productName";
    final body = "Was $oldPrice, now just $newPrice!";
    showLocalNotification(title, body, type: 'priceDrop');
  }

  // Trigger shop update notification
  void triggerShopUpdateNotification(String shopName, String updateType) {
    final title = "🏪 $shopName";
    final body = updateType == 'new_product'
        ? "Added new products! Check them out."
        : "Has an update for you!";
    showLocalNotification(title, body, type: 'shopUpdate');
  }

  // Trigger system message notification
  void triggerSystemNotification(String title, String body) {
    final fullTitle = "ℹ️ $title";
    showLocalNotification(fullTitle, body, type: 'systemMessage');
  }

  // Get notification color based on type
  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'orderUpdate':
        return Colors.blue;
      case 'promotion':
        return Colors.orange;
      case 'priceDrop':
        return Colors.green;
      case 'shopUpdate':
        return Colors.purple;
      case 'systemMessage':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  /// Send notification to a specific user by saving it to Firestore
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc();

      final notification = {
        'id': docRef.id,
        'title': title,
        'body': body,
        'type': data?['type'] ?? 'systemMessage',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': data,
      };

      await docRef.set(notification);
      debugPrint('Notification sent to user $userId: $title');
    } catch (e) {
      debugPrint('Error sending notification to user $userId: $e');
    }
  }
}
