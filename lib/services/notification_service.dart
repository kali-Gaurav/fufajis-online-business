import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_router.dart';
import 'notification_retry_service.dart';
import 'rds_database_service.dart';

// Background message entry point (must be top-level static)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background push notification: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _customFcm;
  FirebaseMessaging get _fcm => _customFcm ?? FirebaseMessaging.instance;
  set fcm(FirebaseMessaging value) => _customFcm = value;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  set db(FirebaseFirestore database) => _customDb = database;

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
        AndroidInitializationSettings('@drawable/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification tapped: ${response.payload}");
        if (response.payload != null) {
          _navigateFromPayload(response.payload!);
        }
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
      debugPrint(
        "App launched from terminated state via notification: ${initialMessage.messageId}",
      );
    }

    // 6. Handle App opening from background state via push notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("App brought to foreground via notification: ${message.messageId}");
      _navigateFromMessage(message);
    });

    _initialized = true;
  }

  /// Navigate to the appropriate screen based on notification data
  void _navigateFromPayload(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateFromData(data);
    } catch (e) {
      debugPrint('[NotificationService] Could not parse payload for navigation: $e');
    }
  }

  void _navigateFromMessage(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final router = AppRouter.router;
    final String type = data['type']?.toString() ?? '';
    final String orderId = data['orderId']?.toString() ?? '';

    switch (type) {
      case 'orderUpdate':
        if (orderId.isNotEmpty) {
          router.push('/customer/order-detail/$orderId');
        } else {
          router.push('/customer/orders');
        }
        break;
      case 'promotion':
      case 'priceDrop':
        router.push('/customer/home');
        break;
      case 'stapleRefill':
        router.push('/customer/home');
        break;
      default:
        router.push('/customer/notifications');
    }
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
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
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

  // Trigger staple refill notification (Idea 27)
  void triggerStapleRefillNotification(String productName, int daysLeft) {
    const title = "🛒 Smart Kitchen Reminder";
    final body = daysLeft <= 0
        ? "You've likely run out of $productName! Refill now from your Smart Kitchen."
        : "You're running low on $productName! (Estimated: $daysLeft days left).";
    showLocalNotification(title, body, type: 'stapleRefill');
  }

  /// Send notification to a specific user by saving it to Firestore
  /// Enforces quiet hours, rate limits (frequency limit per hour), and mirrors to RDS.
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? channelUsed,
  }) async {
    final String type = data?['type'] ?? 'systemMessage';
    final bool isTransactional =
        type == 'orderUpdate' ||
        type == 'auth' ||
        type == 'otp' ||
        type == 'paymentReceived' ||
        type == 'systemAlert';

    try {
      // 1. Load User Settings for Quiet Hours & Frequency Limit
      final settingsDoc = await _db
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('notifications')
          .get();

      bool orderUpdates = true;
      bool promotions = true;
      bool priceDrops = true;
      bool shopUpdates = true;
      bool systemMessages = true;
      String quietHoursStart = "22:0";
      String quietHoursEnd = "8:0";
      int frequencyLimit = 10;

      if (settingsDoc.exists && settingsDoc.data() != null) {
        final s = settingsDoc.data()!;
        orderUpdates = s['orderUpdates'] ?? true;
        promotions = s['promotions'] ?? true;
        priceDrops = s['priceDrops'] ?? true;
        shopUpdates = s['shopUpdates'] ?? true;
        systemMessages = s['systemMessages'] ?? true;
        quietHoursStart = s['quietHoursStart'] ?? "22:0";
        quietHoursEnd = s['quietHoursEnd'] ?? "8:0";
        frequencyLimit = s['frequencyLimitPerHour'] ?? 10;
      }

      // Check user preferences
      if (type == 'orderUpdate' && !orderUpdates) return false;
      if (type == 'promotion' && !promotions) return false;
      if (type == 'priceDrop' && !priceDrops) return false;
      if (type == 'shopUpdate' && !shopUpdates) return false;
      if (type == 'systemMessage' && !systemMessages) return false;

      // 2. Check Quiet Hours for non-essential notifications
      if (!isTransactional) {
        final now = TimeOfDay.now();
        final nowMin = now.hour * 60 + now.minute;

        final startParts = quietHoursStart.split(':');
        final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);

        final endParts = quietHoursEnd.split(':');
        final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

        bool inQuietHours = false;
        if (startMin < endMin) {
          inQuietHours = nowMin >= startMin && nowMin < endMin;
        } else {
          inQuietHours = nowMin >= startMin || nowMin < endMin;
        }

        if (inQuietHours) {
          debugPrint(
            '[NotificationService] Quiet Hours active. Buffering non-essential notification: $title',
          );
          // Buffer it for tomorrow morning (8:00 AM)
          final docId = 'buf_${DateTime.now().millisecondsSinceEpoch}';
          await NotificationRetryService().handleFailure(
            notificationId: docId,
            recipientId: userId,
            channel: channelUsed ?? 'in_app',
            errorMessage: 'Buffered due to Quiet Hours',
            originalPayload: {
              'title': title,
              'body': body,
              'phoneNumber': data?['phoneNumber'] ?? '',
              'orderNumber': data?['orderNumber'] ?? '',
              'status': data?['status'] ?? '',
              'type': type,
            },
          );
          return false;
        }
      }

      // 3. Rate Limiter (Frequency Limit per hour)
      if (!isTransactional) {
        final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
        final recentNotifications = await _db
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .where('timestamp', isGreaterThan: Timestamp.fromDate(oneHourAgo))
            .get();

        final nonEssentialCount = recentNotifications.docs.where((doc) {
          final t = doc.data()['type'] ?? 'systemMessage';
          return t == 'promotion' || t == 'priceDrop' || t == 'shopUpdate' || t == 'systemMessage';
        }).length;

        if (nonEssentialCount >= frequencyLimit) {
          debugPrint(
            '[NotificationService] Frequency limit exceeded ($nonEssentialCount/$frequencyLimit per hour) for user $userId. Discarding: $title',
          );
          return false;
        }
      }

      // 4. Save to Firestore
      final docRef = _db.collection('users').doc(userId).collection('notifications').doc();

      final notification = {
        'id': docRef.id,
        'title': title,
        'body': body,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': data,
      };

      await docRef.set(notification);

      // 5. Mirror to RDS
      final rds = RDSDatabaseService();
      try {
        await rds.query(
          '''
          INSERT INTO notifications (id, recipient_id, title, body, type, channel, status, is_read, deep_link)
          VALUES (\$1, \$2, \$3, \$4, \$5, \$6, 'delivered', false, \$7)
          ''',
          params: [
            docRef.id,
            userId,
            title,
            body,
            type,
            channelUsed ?? 'in_app',
            data?['deepLink'] ?? '',
          ],
          allowWrite: true,
        );

        await rds.query(
          '''
          INSERT INTO notification_logs (notification_id, recipient_id, channel, status, response_payload)
          VALUES (\$1, \$2, \$3, 'delivered', \$4)
          ''',
          params: [docRef.id, userId, channelUsed ?? 'in_app', jsonEncode(data ?? {})],
          allowWrite: true,
        );
      } catch (rdsError) {
        debugPrint('[NotificationService] RDS replication failed: $rdsError');
      }

      return true;
    } catch (e) {
      debugPrint('NotificationService error: $e');
      final failureId = 'fail_${DateTime.now().millisecondsSinceEpoch}';
      await NotificationRetryService().handleFailure(
        notificationId: failureId,
        recipientId: userId,
        channel: channelUsed ?? 'in_app',
        errorMessage: e.toString(),
        originalPayload: {
          'title': title,
          'body': body,
          'phoneNumber': data?['phoneNumber'] ?? '',
          'orderNumber': data?['orderNumber'] ?? '',
          'status': data?['status'] ?? '',
          'type': type,
        },
      );
      return false;
    }
  }

  Future<void> sendOrderStatusNotification({
    required String userId,
    required String orderId,
    required String orderNumber,
    required String status,
    required String message,
  }) async {
    await sendNotificationToUser(
      userId: userId,
      title: 'Order $orderNumber Update',
      body: message,
      channelUsed: 'in_app',
      data: {'type': 'orderUpdate', 'orderId': orderId, 'status': status},
    );
  }

  /// Send a broadcast push notification to all users matching [topic].
  Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    String topic = 'all_users',
    Map<String, dynamic>? data,
  }) async {
    try {
      await _db.collection('broadcast_notifications').add({
        'title': title,
        'body': body,
        'topic': topic,
        'data': data ?? {},
        'sentAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[NotificationService] Broadcast queued: title= topic=');
    } catch (e) {
      debugPrint('[NotificationService] sendBroadcastNotification failed: ');
      rethrow;
    }
  }

  Future<bool> notifyRider(String riderId, String message, Map<String, dynamic> data) async {
    return sendNotificationToUser(
      userId: riderId,
      title: 'Delivery Task Update',
      body: message,
      data: data,
    );
  }

  Future<bool> notifyCustomer(String customerId, String message, Map<String, dynamic> data) async {
    return sendNotificationToUser(
      userId: customerId,
      title: 'Order Status Update',
      body: message,
      data: data,
    );
  }

  Future<void> notifyDispatcher(String message, Map<String, dynamic> data) async {
    try {
      await _db.collection('dispatcher_notifications').add({
        'message': message,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('[NotificationService] Dispatcher notified: $message');
    } catch (e) {
      debugPrint('[NotificationService] notifyDispatcher failed: $e');
    }
  }

  Future<bool> notifyShop(String shopId, String message, Map<String, dynamic> data) async {
    return sendNotificationToUser(
      userId: 'shop_$shopId',
      title: 'Shop Notification',
      body: message,
      data: data,
    );
  }

  Future<bool> notifyEmployee(String employeeId, String message, Map<String, dynamic> data) async {
    return sendNotificationToUser(
      userId: employeeId,
      title: 'Employee Notification',
      body: message,
      data: data,
    );
  }

  Future<void> notifyQCTeam(String message, Map<String, dynamic> data) async {
    try {
      await _db.collection('qc_notifications').add({
        'message': message,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('[NotificationService] QC Team notified: $message');
    } catch (e) {
      debugPrint('[NotificationService] notifyQCTeam failed: $e');
    }
  }
}
