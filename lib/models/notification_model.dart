import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Notification type enum for categorization
enum NotificationType {
  orderCreated,
  orderStatusChanged,
  orderPacked,
  outForDelivery,
  delivered,
  paymentFailed,
  lowStockAlert,
  orderStuck,
  employeePerformance,
  deliveryPerformance,
  newCustomerReview,
  fraudDetection,
  systemAlert,
  promotion,
  priceDrop,
  shopUpdate,
}

/// Comprehensive notification data model
class NotificationData {
  final String notificationId;
  final String userId;
  final String? orderId;
  final String? productId;
  final String? shopId;
  final String? deliveryAgentId;
  final NotificationType type;
  final String title;
  final String body;
  final String? imageUrl;
  final String? deepLink;
  final Map<String, dynamic>? data;
  final bool read;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? priority; // 1-5, higher = more important

  NotificationData({
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.orderId,
    this.productId,
    this.shopId,
    this.deliveryAgentId,
    this.imageUrl,
    this.deepLink,
    this.data,
    this.read = false,
    required this.createdAt,
    this.expiresAt,
    this.priority = 3,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'orderId': orderId,
      'productId': productId,
      'shopId': shopId,
      'deliveryAgentId': deliveryAgentId,
      'type': type.toString().split('.').last,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'deepLink': deepLink,
      'data': data,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'priority': priority,
    };
  }

  /// Create from Firestore document
  factory NotificationData.fromMap(Map<String, dynamic> map) {
    return NotificationData(
      notificationId: (map['notificationId'] as String?) ?? (map['id'] as String?) ?? '',
      userId: map['userId'] as String? ?? '',
      orderId: map['orderId'] as String?,
      productId: map['productId'] as String?,
      shopId: map['shopId'] as String?,
      deliveryAgentId: map['deliveryAgentId'] as String?,
      type: _parseNotificationType(map['type'] as String?),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      deepLink: map['deepLink'] as String?,
      data: map['data'] != null ? Map<String, dynamic>.from(map['data'] as Map) : null,
      read: map['read'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      priority: map['priority'] as int? ?? 3,
    );
  }

  /// Parse notification type from string
  static NotificationType _parseNotificationType(String? typeStr) {
    if (typeStr == null) return NotificationType.systemAlert;
    try {
      return NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == typeStr,
        orElse: () => NotificationType.systemAlert,
      );
    } catch (e) {
      return NotificationType.systemAlert;
    }
  }

  /// Get readable notification type label
  String get typeLabel {
    switch (type) {
      case NotificationType.orderCreated:
        return 'Order Created';
      case NotificationType.orderStatusChanged:
        return 'Order Status';
      case NotificationType.orderPacked:
        return 'Order Packed';
      case NotificationType.outForDelivery:
        return 'Out for Delivery';
      case NotificationType.delivered:
        return 'Delivered';
      case NotificationType.paymentFailed:
        return 'Payment Failed';
      case NotificationType.lowStockAlert:
        return 'Low Stock';
      case NotificationType.orderStuck:
        return 'Order Stuck';
      case NotificationType.employeePerformance:
        return 'Performance';
      case NotificationType.deliveryPerformance:
        return 'Delivery Rating';
      case NotificationType.newCustomerReview:
        return 'New Review';
      case NotificationType.fraudDetection:
        return 'Security Alert';
      case NotificationType.systemAlert:
        return 'System Alert';
      case NotificationType.promotion:
        return 'Promotion';
      case NotificationType.priceDrop:
        return 'Price Drop';
      case NotificationType.shopUpdate:
        return 'Shop Update';
    }
  }

  /// Get notification icon emoji
  String get icon {
    switch (type) {
      case NotificationType.orderCreated:
        return '📦';
      case NotificationType.orderStatusChanged:
        return '📝';
      case NotificationType.orderPacked:
        return '✓';
      case NotificationType.outForDelivery:
        return '🚚';
      case NotificationType.delivered:
        return '✓✓';
      case NotificationType.paymentFailed:
        return '❌';
      case NotificationType.lowStockAlert:
        return '⚠️';
      case NotificationType.orderStuck:
        return '⏸️';
      case NotificationType.employeePerformance:
        return '⭐';
      case NotificationType.deliveryPerformance:
        return '⭐';
      case NotificationType.newCustomerReview:
        return '💬';
      case NotificationType.fraudDetection:
        return '🔒';
      case NotificationType.systemAlert:
        return 'ℹ️';
      case NotificationType.promotion:
        return '🎉';
      case NotificationType.priceDrop:
        return '💰';
      case NotificationType.shopUpdate:
        return '🏪';
    }
  }

  /// Check if notification is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Create a copy with modifications
  NotificationData copyWith({
    String? notificationId,
    String? userId,
    String? orderId,
    String? productId,
    String? shopId,
    String? deliveryAgentId,
    NotificationType? type,
    String? title,
    String? body,
    String? imageUrl,
    String? deepLink,
    Map<String, dynamic>? data,
    bool? read,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? priority,
  }) {
    return NotificationData(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      shopId: shopId ?? this.shopId,
      deliveryAgentId: deliveryAgentId ?? this.deliveryAgentId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      deepLink: deepLink ?? this.deepLink,
      data: data ?? this.data,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      priority: priority ?? this.priority,
    );
  }

  @override
  String toString() =>
      'NotificationData(id: $notificationId, type: ${type.toString()}, title: $title)';
}

/// Notification preferences for user
class NotificationPreferences {
  bool orderUpdates;
  bool paymentNotifications;
  bool promotions;
  bool systemAlerts;
  bool emailNotifications;
  bool smsNotifications;
  bool pushNotifications;

  // Quiet hours (no notifications)
  TimeOfDay quietHoursStart;
  TimeOfDay quietHoursEnd;

  // Frequency control
  int maxNotificationsPerHour;

  NotificationPreferences({
    this.orderUpdates = true,
    this.paymentNotifications = true,
    this.promotions = true,
    this.systemAlerts = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.pushNotifications = true,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    this.maxNotificationsPerHour = 20,
  })  : quietHoursStart = quietHoursStart ?? const TimeOfDay(hour: 22, minute: 0),
        quietHoursEnd = quietHoursEnd ?? const TimeOfDay(hour: 8, minute: 0);

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'orderUpdates': orderUpdates,
      'paymentNotifications': paymentNotifications,
      'promotions': promotions,
      'systemAlerts': systemAlerts,
      'emailNotifications': emailNotifications,
      'smsNotifications': smsNotifications,
      'pushNotifications': pushNotifications,
      'quietHoursStart': '${quietHoursStart.hour}:${quietHoursStart.minute}',
      'quietHoursEnd': '${quietHoursEnd.hour}:${quietHoursEnd.minute}',
      'maxNotificationsPerHour': maxNotificationsPerHour,
    };
  }

  /// Create from Firestore document
  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      orderUpdates: map['orderUpdates'] as bool? ?? true,
      paymentNotifications: map['paymentNotifications'] as bool? ?? true,
      promotions: map['promotions'] as bool? ?? true,
      systemAlerts: map['systemAlerts'] as bool? ?? true,
      emailNotifications: map['emailNotifications'] as bool? ?? true,
      smsNotifications: map['smsNotifications'] as bool? ?? false,
      pushNotifications: map['pushNotifications'] as bool? ?? true,
      quietHoursStart: _parseTimeOfDay(map['quietHoursStart'] as String?),
      quietHoursEnd: _parseTimeOfDay(map['quietHoursEnd'] as String?),
      maxNotificationsPerHour: map['maxNotificationsPerHour'] as int? ?? 20,
    );
  }

  /// Parse time string to TimeOfDay
  static TimeOfDay _parseTimeOfDay(String? timeStr) {
    if (timeStr == null) return const TimeOfDay(hour: 22, minute: 0);
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return const TimeOfDay(hour: 22, minute: 0);
    }
  }

  /// Check if currently in quiet hours
  bool isInQuietHours() {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = quietHoursStart.hour * 60 + quietHoursStart.minute;
    final endMinutes = quietHoursEnd.hour * 60 + quietHoursEnd.minute;

    if (startMinutes < endMinutes) {
      // Quiet hours don't cross midnight (e.g., 22:00 to 08:00)
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      // Quiet hours cross midnight (e.g., 23:00 to 08:00)
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
  }
}
