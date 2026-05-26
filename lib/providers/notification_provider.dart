import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../services/offline_notification_queue_service.dart';

// Notification types enum
enum NotificationType {
  orderUpdate,
  promotion,
  priceDrop,
  shopUpdate,
  systemMessage,
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationType? type;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data;
  final String? deepLink;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    required this.timestamp,
    this.isRead = false,
    this.data,
    this.deepLink,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: parseNotificationType(map['type']),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      data: map['data'],
      deepLink: map['deepLink'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type?.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'data': data,
      'deepLink': deepLink,
    };
  }

  static NotificationType? parseNotificationType(String? typeStr) {
    if (typeStr == null) return null;
    try {
      return NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == typeStr,
      );
    } catch (e) {
      return null;
    }
  }
}

// Notification settings model
class NotificationSettings {
  bool orderUpdates;
  bool promotions;
  bool priceDrops;
  bool shopUpdates;
  bool systemMessages;
  TimeOfDay quietHoursStart;
  TimeOfDay quietHoursEnd;
  int frequencyLimitPerHour;

  NotificationSettings({
    this.orderUpdates = true,
    this.promotions = true,
    this.priceDrops = true,
    this.shopUpdates = true,
    this.systemMessages = true,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    this.frequencyLimitPerHour = 10,
  })  : quietHoursStart = quietHoursStart ?? const TimeOfDay(hour: 22, minute: 0),
        quietHoursEnd = quietHoursEnd ?? const TimeOfDay(hour: 8, minute: 0);

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      orderUpdates: map['orderUpdates'] ?? true,
      promotions: map['promotions'] ?? true,
      priceDrops: map['priceDrops'] ?? true,
      shopUpdates: map['shopUpdates'] ?? true,
      systemMessages: map['systemMessages'] ?? true,
      quietHoursStart: _parseTimeOfDay(map['quietHoursStart']),
      quietHoursEnd: _parseTimeOfDay(map['quietHoursEnd']),
      frequencyLimitPerHour: map['frequencyLimitPerHour'] ?? 10,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderUpdates': orderUpdates,
      'promotions': promotions,
      'priceDrops': priceDrops,
      'shopUpdates': shopUpdates,
      'systemMessages': systemMessages,
      'quietHoursStart': '${quietHoursStart.hour}:${quietHoursStart.minute}',
      'quietHoursEnd': '${quietHoursEnd.hour}:${quietHoursEnd.minute}',
      'frequencyLimitPerHour': frequencyLimitPerHour,
    };
  }

  static TimeOfDay _parseTimeOfDay(String? timeStr) {
    if (timeStr == null) return const TimeOfDay(hour: 22, minute: 0);
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return const TimeOfDay(hour: 22, minute: 0);
    }
  }

  bool isInQuietHours() {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = quietHoursStart.hour * 60 + quietHoursStart.minute;
    final endMinutes = quietHoursEnd.hour * 60 + quietHoursEnd.minute;

    if (startMinutes < endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
  }
}

class NotificationProvider with ChangeNotifier {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OfflineNotificationQueueService _queueService = OfflineNotificationQueueService();
  final Connectivity _connectivity = Connectivity();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications => _notifications;

  NotificationSettings _settings = NotificationSettings();
  NotificationSettings get settings => _settings;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription? _notificationSubscription;
  StreamSubscription? _connectivitySubscription;

  // Initialize notifications
  Future<void> initialize(String? userId) async {
    try {
      await _queueService.initialize();
      await _requestPermission();
      await _getToken(userId);
      await _loadSettings(userId);
      await _setupInteractedMessage();
      await _setupConnectivityListener(userId);
      if (userId != null) {
        await fetchNotifications(userId);
        await _subscribeToTopics(userId);
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  // Setup connectivity listener
  Future<void> _setupConnectivityListener(String? userId) async {
    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(result, userId);

      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
        _updateConnectivityStatus(result, userId);
      });
    } catch (e) {
      debugPrint('Error setting up connectivity listener: $e');
    }
  }

  void _updateConnectivityStatus(dynamic result, String? userId) {
    bool isOnline = false;
    if (result is List) {
      isOnline = result.any((r) => r != ConnectivityResult.none);
    } else {
      isOnline = result != ConnectivityResult.none;
    }

    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      debugPrint('Connectivity changed: $_isOnline');

      if (_isOnline && userId != null) {
        // Deliver queued notifications when coming online
        _deliverQueuedNotifications(userId);
      }
      notifyListeners();
    }
  }

  // Fetch notifications from Firestore
  Future<void> fetchNotifications(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _notificationSubscription?.cancel();
      _notificationSubscription = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .listen((data) {
        _notifications = data.docs
            .map((doc) => NotificationModel.fromMap({...doc.data(), 'id': doc.id}))
            .toList();
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final unread = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  // Delete all notifications
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final batch = _firestore.batch();
      final docs = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      for (var doc in docs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting all notifications: $e');
    }
  }

  // Load notification settings
  Future<void> _loadSettings(String? userId) async {
    try {
      if (userId == null) return;

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('notifications')
          .get();

      if (doc.exists) {
        _settings = NotificationSettings.fromMap(doc.data() ?? {});
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
    notifyListeners();
  }

  // Save notification settings
  Future<void> saveSettings(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('notifications')
          .set(_settings.toMap());
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  // Update individual settings
  void updateOrderUpdates(bool value) {
    _settings.orderUpdates = value;
    notifyListeners();
  }

  void updatePromotions(bool value) {
    _settings.promotions = value;
    notifyListeners();
  }

  void updatePriceDrops(bool value) {
    _settings.priceDrops = value;
    notifyListeners();
  }

  void updateShopUpdates(bool value) {
    _settings.shopUpdates = value;
    notifyListeners();
  }

  void updateSystemMessages(bool value) {
    _settings.systemMessages = value;
    notifyListeners();
  }

  void updateQuietHours(TimeOfDay start, TimeOfDay end) {
    _settings.quietHoursStart = start;
    _settings.quietHoursEnd = end;
    notifyListeners();
  }

  void updateFrequencyLimit(int limit) {
    _settings.frequencyLimitPerHour = limit;
    notifyListeners();
  }

  // Request notification permission
  Future<void> _requestPermission() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('Notification permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  // Get FCM token
  Future<void> _getToken(String? userId) async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      if (userId != null && _fcmToken != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcmToken': _fcmToken});
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  // Refresh token
  Future<void> refreshToken(String? userId) async {
    _firebaseMessaging.onTokenRefresh.listen((token) async {
      _fcmToken = token;
      debugPrint('Refreshed FCM Token: $token');

      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcmToken': token});
      }
    });
  }

  // Subscribe to topics
  Future<void> _subscribeToTopics(String userId) async {
    try {
      // Subscribe to user-specific topic
      await subscribeToTopic('user_$userId');

      // Subscribe to role-based topics (will be set based on user role)
      // This should be called after user role is determined
    } catch (e) {
      debugPrint('Error subscribing to topics: $e');
    }
  }

  // Setup message handling
  Future<void> _setupInteractedMessage() async {
    // Handle notification when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      // Check if notification should be shown based on settings and quiet hours
      if (_shouldShowNotification(message)) {
        _handleForegroundNotification(message);
      } else if (!_isOnline) {
        // Queue notification if offline
        _queueNotification(message);
      }
    });

    // Handle notification when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Message clicked!');
      debugPrint('Message data: ${message.data}');
      _handleNotificationTap(message);
    });

    // Handle notification when app is launched from terminated state
    final message = await _firebaseMessaging.getInitialMessage();
    if (message != null) {
      debugPrint('App launched from notification');
      debugPrint('Message data: ${message.data}');
      _handleNotificationTap(message);
    }
  }

  // Check if notification should be shown
  bool _shouldShowNotification(RemoteMessage message) {
    // Check quiet hours
    if (_settings.isInQuietHours()) {
      return false;
    }

    // Check notification type settings
    final type = message.data['type'];
    switch (type) {
      case 'orderUpdate':
        return _settings.orderUpdates;
      case 'promotion':
        return _settings.promotions;
      case 'priceDrop':
        return _settings.priceDrops;
      case 'shopUpdate':
        return _settings.shopUpdates;
      case 'systemMessage':
        return _settings.systemMessages;
      default:
        return true;
    }
  }

  // Handle foreground notification
  void _handleForegroundNotification(RemoteMessage message) {
    if (message.notification != null) {
      debugPrint('Showing notification: ${message.notification?.title}');
      // Local notification will be shown by NotificationService
    }
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    final deepLink = message.data['deepLink'];
    if (deepLink != null) {
      debugPrint('Navigating to: $deepLink');
      // Navigation will be handled by the app router
    }
  }

  // Queue notification for offline delivery
  void _queueNotification(RemoteMessage message) {
    final userId = message.data['userId'];
    if (userId == null) return;

    _queueService.queueNotification(
      userId,
      message.notification?.title ?? 'Notification',
      message.notification?.body ?? '',
      message.data['type'] ?? 'systemMessage',
      data: message.data,
      deepLink: message.data['deepLink'],
    );
  }

  // Deliver queued notifications
  Future<void> _deliverQueuedNotifications(String userId) async {
    try {
      await _queueService.deliverQueuedNotifications(userId);
      debugPrint('Queued notifications delivered for user $userId');
    } catch (e) {
      debugPrint('Error delivering queued notifications: $e');
    }
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }

  // Subscribe to district topic
  Future<void> subscribeToDistrict(String district) async {
    await subscribeToTopic('district_$district');
  }

  // Subscribe to category topic
  Future<void> subscribeToCategory(String category) async {
    await subscribeToTopic('category_$category');
  }

  // Subscribe to shop topic
  Future<void> subscribeToShop(String shopId) async {
    await subscribeToTopic('shop_$shopId');
  }

  // Unsubscribe from shop topic
  Future<void> unsubscribeFromShop(String shopId) async {
    await unsubscribeFromTopic('shop_$shopId');
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}


