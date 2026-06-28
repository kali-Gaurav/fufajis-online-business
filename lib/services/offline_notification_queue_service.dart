import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../models/offline_notification_queue_model.dart';

class OfflineNotificationQueueService {
  static final OfflineNotificationQueueService _instance =
      OfflineNotificationQueueService._internal();

  factory OfflineNotificationQueueService() => _instance;
  OfflineNotificationQueueService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Box<Map> _queueBox;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _queueBox = await Hive.openBox<Map>('offline_notification_queue');
      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing offline notification queue: $e');
    }
  }

  // Add notification to offline queue
  Future<void> queueNotification(
    String userId,
    String title,
    String body,
    String type, {
    Map<String, dynamic>? data,
    String? deepLink,
  }) async {
    try {
      final notification = OfflineNotificationQueueModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now(),
        data: data,
        deepLink: deepLink,
        isDelivered: false,
      );

      await _queueBox.put(notification.id, notification.toMap());
      debugPrint('Notification queued: ${notification.id}');
    } catch (e) {
      debugPrint('Error queuing notification: $e');
    }
  }

  // Get all queued notifications for a user
  Future<List<OfflineNotificationQueueModel>> getQueuedNotifications(
    String userId,
  ) async {
    try {
      final notifications = <OfflineNotificationQueueModel>[];
      for (var key in _queueBox.keys) {
        final data = _queueBox.get(key);
        if (data != null &&
            data['userId'] == userId &&
            !(data['isDelivered'] ?? false)) {
          notifications.add(
            OfflineNotificationQueueModel.fromMap(
              Map<String, dynamic>.from(data),
            ),
          );
        }
      }
      return notifications;
    } catch (e) {
      debugPrint('Error getting queued notifications: $e');
      return [];
    }
  }

  // Deliver queued notifications to Firestore
  Future<void> deliverQueuedNotifications(String userId) async {
    try {
      final queuedNotifications = await getQueuedNotifications(userId);

      for (var notification in queuedNotifications) {
        try {
          // Add to Firestore
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .add({
                'title': notification.title,
                'body': notification.body,
                'type': notification.type,
                'timestamp': Timestamp.fromDate(notification.createdAt),
                'isRead': false,
                'data': notification.data,
                'deepLink': notification.deepLink,
              });

          // Mark as delivered in local queue
          final updatedNotification = notification.copyWith(
            isDelivered: true,
            deliveredAt: DateTime.now(),
          );
          await _queueBox.put(notification.id, updatedNotification.toMap());
          debugPrint('Notification delivered: ${notification.id}');
        } catch (e) {
          debugPrint('Error delivering notification ${notification.id}: $e');
        }
      }

      // Clean up delivered notifications after 24 hours
      await _cleanupDeliveredNotifications();
    } catch (e) {
      debugPrint('Error delivering queued notifications: $e');
    }
  }

  // Clean up delivered notifications older than 24 hours
  Future<void> _cleanupDeliveredNotifications() async {
    try {
      final now = DateTime.now();
      final keysToDelete = <dynamic>[];

      for (var key in _queueBox.keys) {
        final data = _queueBox.get(key);
        if (data != null && (data['isDelivered'] ?? false)) {
          final rawDeliveredAt = data['deliveredAt'];
          DateTime? deliveredDate;
          if (rawDeliveredAt is int) {
            deliveredDate = DateTime.fromMillisecondsSinceEpoch(rawDeliveredAt);
          } else if (rawDeliveredAt is Timestamp) {
            deliveredDate = rawDeliveredAt.toDate();
          } else if (rawDeliveredAt is String) {
            deliveredDate = DateTime.parse(rawDeliveredAt);
          } else if (rawDeliveredAt is DateTime) {
            deliveredDate = rawDeliveredAt;
          }
          if (deliveredDate != null) {
            if (now.difference(deliveredDate).inHours > 24) {
              keysToDelete.add(key);
            }
          }
        }
      }

      for (var key in keysToDelete) {
        await _queueBox.delete(key);
      }

      debugPrint('Cleaned up ${keysToDelete.length} delivered notifications');
    } catch (e) {
      debugPrint('Error cleaning up delivered notifications: $e');
    }
  }

  // Clear all queued notifications for a user
  Future<void> clearQueuedNotifications(String userId) async {
    try {
      final keysToDelete = <dynamic>[];
      for (var key in _queueBox.keys) {
        final data = _queueBox.get(key);
        if (data != null && data['userId'] == userId) {
          keysToDelete.add(key);
        }
      }

      for (var key in keysToDelete) {
        await _queueBox.delete(key);
      }

      debugPrint(
        'Cleared ${keysToDelete.length} queued notifications for user $userId',
      );
    } catch (e) {
      debugPrint('Error clearing queued notifications: $e');
    }
  }

  // Get queue size
  int getQueueSize() {
    return _queueBox.length;
  }

  // Get undelivered count
  Future<int> getUndeliveredCount(String userId) async {
    try {
      int count = 0;
      for (var key in _queueBox.keys) {
        final data = _queueBox.get(key);
        if (data != null &&
            data['userId'] == userId &&
            !(data['isDelivered'] ?? false)) {
          count++;
        }
      }
      return count;
    } catch (e) {
      debugPrint('Error getting undelivered count: $e');
      return 0;
    }
  }
}
