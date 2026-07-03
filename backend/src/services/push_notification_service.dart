/// ============================================================================
/// push_notification_service.dart - Mobile-side Push Notification Handling
/// ============================================================================
/// Handles:
/// - FCM token management
/// - Notification permission requests
/// - Deep link routing
/// - Local notification display
/// - Background message handling
/// ============================================================================
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();

  factory PushNotificationService() {
    return _instance;
  }

  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Request notification permissions (Android 13+)
    await _requestPermission();

    // 2. Set up local notifications
    await _setupLocalNotifications();

    // 3. Get and save FCM token
    await _saveFCMToken();

    // 4. Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 6. Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    debugPrint('[PushNotificationService] Initialized');
  }

  /// Request notification permission from user
  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('[PushNotificationService] Notifications authorized');
    } else {
      debugPrint('[PushNotificationService] Notifications denied or provisional');
    }
  }

  /// Set up local notification channel
  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'orders',
      'Order Updates',
      description: 'Notifications about order status and delivery',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Save FCM token to device and backend
  Future<void> _saveFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString('fcm_token');

      // Only update if token changed
      if (oldToken != token) {
        await prefs.setString('fcm_token', token);

        // Send to backend
        // await _registerTokenWithBackend(token);

        debugPrint('[PushNotificationService] FCM token saved: ${token.substring(0, 20)}...');
      }

      // Listen for token refreshes
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        await prefs.setString('fcm_token', newToken);
        debugPrint('[PushNotificationService] FCM token refreshed');
        // await _registerTokenWithBackend(newToken);
      });
    } catch (error) {
      debugPrint('[PushNotificationService] Error saving FCM token: $error');
    }
  }

  /// Handle notification received while app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[PushNotificationService] Foreground message: ${message.notification?.title}');

    // Show local notification even if app is in foreground
    await _showLocalNotification(
      message.notification?.title ?? 'New notification',
      message.notification?.body ?? '',
      message.data,
    );
  }

  /// Handle background message (when app is closed or in background)
  @pragma('vm:entry-point')
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('[PushNotificationService] Background message: ${message.notification?.title}');
    // Background message is automatically shown by Firebase
  }

  /// Handle notification tap (both foreground and background)
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('[PushNotificationService] Notification tapped: ${message.data}');
    await _routeToDeepLink(message.data);
  }

  /// Handle notification response (for local notifications)
  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      debugPrint('[PushNotificationService] Local notification tapped: $payload');
      // Parse and route to deep link
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'orders',
      'Order Updates',
      channelDescription: 'Order status updates',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final orderId = data['orderId'] ?? '';

    await _localNotifications.show(
      id: orderId.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: orderId,
    );
  }

  /// Route to deep link destination
  Future<void> _routeToDeepLink(Map<String, dynamic> data) async {
    final deepLink = data['deepLink'];
    final action = data['action'];

    debugPrint('[PushNotificationService] Routing to: $deepLink, action: $action');

    // This would be implemented in the app's navigation/routing layer
    // Example:
    // if (deepLink.startsWith('app://order/')) {
    //   final orderId = deepLink.split('/').last;
    //   navigatorKey.currentState?.pushNamed('/order', arguments: orderId);
    // }
  }

  /// Get FCM token
  Future<String?> getFCMToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Request notification permission (can be called again if previously denied)
  Future<bool> requestNotificationPermission() async {
    await _requestPermission();
    return areNotificationsEnabled();
  }

  /// Disable notifications (unsubscribe)
  Future<void> disableNotifications() async {
    await _firebaseMessaging.deleteToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fcm_token');
    debugPrint('[PushNotificationService] Notifications disabled');
  }
}
