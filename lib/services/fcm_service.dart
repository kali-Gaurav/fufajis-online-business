import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background notification: ${message.messageId}');
  debugPrint('Message data: ${message.data}');

  // Save notification to Firestore even in background
  if (message.data.containsKey('userId')) {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(message.data['userId'] as String?)
          .collection('notifications')
          .doc(message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString())
          .set({
        'title': message.notification?.title ?? message.data['title'],
        'body': message.notification?.body ?? message.data['body'],
        'type': message.data['type'] ?? 'systemAlert',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': message.data,
        'deepLink': message.data['deepLink'],
      });
    } catch (e) {
      debugPrint('Error saving background notification: $e');
    }
  }
}

/// Firebase Cloud Messaging service
/// Handles FCM initialization, token management, and topic subscriptions
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _initialized = false;

  /// Initialize FCM
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request notification permissions
      await _requestPermissions();

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Get FCM token
      _fcmToken = await _fcm.getToken();
      debugPrint('FCM Token obtained: $_fcmToken');

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((token) {
        _fcmToken = token;
        debugPrint('FCM Token refreshed: $token');
      });

      _initialized = true;
      debugPrint('FCM Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing FCM: $e');
      rethrow;
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('Notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  /// Save FCM token to Firestore
  Future<void> saveTokenToServer(String userId) async {
    _fcmToken ??= await _fcm.getToken();

    if (_fcmToken == null) return;

    try {
      await _firestore.collection('fcm_tokens').doc(userId).set({
        'token': _fcmToken,
        'updatedAt': FieldValue.serverTimestamp(),
        'device': 'mobile',
        'os': 'android', // Update based on platform if needed
      }, SetOptions(merge: true));

      debugPrint('FCM token saved for user: $userId');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic $topic: $e');
    }
  }

  /// Subscribe to user-specific topics based on role
  Future<void> subscribeToRoleTopics(String userId, String role) async {
    try {
      // Common topics for all users
      await subscribeToTopic('all_users');
      await subscribeToTopic('user_$userId');

      // Role-specific topics
      switch (role.toLowerCase()) {
        case 'customer':
          await subscribeToTopic('customers');
          await subscribeToTopic('customer_$userId');
          await subscribeToTopic('promotions');
          break;

        case 'employee':
          await subscribeToTopic('employees');
          await subscribeToTopic('employee_$userId');
          await subscribeToTopic('new_orders');
          break;

        case 'delivery_agent':
          await subscribeToTopic('delivery_agents');
          await subscribeToTopic('delivery_agent_$userId');
          await subscribeToTopic('delivery_assignments');
          break;

        case 'owner':
        case 'admin':
          await subscribeToTopic('owners');
          await subscribeToTopic('owner_$userId');
          await subscribeToTopic('order_alerts');
          await subscribeToTopic('low_stock_alerts');
          await subscribeToTopic('fraud_alerts');
          break;
      }

      // System alerts for all
      await subscribeToTopic('system_alerts');

      debugPrint('Subscribed to role-based topics for role: $role');
    } catch (e) {
      debugPrint('Error subscribing to role topics: $e');
    }
  }

  /// Unsubscribe from user topics when logging out
  Future<void> unsubscribeFromUserTopics(String userId, String role) async {
    try {
      await unsubscribeFromTopic('user_$userId');

      switch (role.toLowerCase()) {
        case 'customer':
          await unsubscribeFromTopic('customer_$userId');
          break;
        case 'employee':
          await unsubscribeFromTopic('employee_$userId');
          break;
        case 'delivery_agent':
          await unsubscribeFromTopic('delivery_agent_$userId');
          break;
        case 'owner':
        case 'admin':
          await unsubscribeFromTopic('owner_$userId');
          break;
      }

      debugPrint('Unsubscribed from user-specific topics');
    } catch (e) {
      debugPrint('Error unsubscribing from user topics: $e');
    }
  }

  /// Handle foreground notification (when app is open)
  void setupForegroundNotificationHandler(
    Function(RemoteMessage) onMessageHandler,
  ) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground notification received: ${message.notification?.title}');
      onMessageHandler(message);
    });
  }

  /// Handle notification when app is opened from background
  void setupMessageOpenedHandler(
    Function(RemoteMessage) onMessageOpenedHandler,
  ) {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Message opened from background: ${message.notification?.title}');
      onMessageOpenedHandler(message);
    });
  }

  /// Get initial message (when app is launched from notification)
  Future<RemoteMessage?> getInitialMessage() async {
    return await _fcm.getInitialMessage();
  }

  /// Send data-only message (for testing)
  Future<void> sendTestNotification(String title, String body) async {
    try {
      await _firestore.collection('test_notifications').add({
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('Test notification sent');
    } catch (e) {
      debugPrint('Error sending test notification: $e');
    }
  }
}
