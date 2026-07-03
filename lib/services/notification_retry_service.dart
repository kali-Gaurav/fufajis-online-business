import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'whatsapp_notification_service.dart';
import 'sms_service.dart';
import 'rds_database_service.dart';

class NotificationRetryService {
  static final NotificationRetryService _instance = NotificationRetryService._internal();
  factory NotificationRetryService() => _instance;
  NotificationRetryService._internal();

  FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  set db(FirebaseFirestore database) => _customDb = database;

  /// Logs a notification failure and schedules a retry or sends to DLQ
  Future<void> handleFailure({
    required String notificationId,
    required String recipientId,
    required String channel,
    required String errorMessage,
    required Map<String, dynamic> originalPayload,
  }) async {
    try {
      final docRef = _db.collection('notification_failures').doc(notificationId);
      final doc = await docRef.get();

      int currentRetryCount = 0;
      if (doc.exists && doc.data() != null) {
        currentRetryCount = doc.data()?['retryCount'] ?? 0;
      }

      final nextRetryCount = currentRetryCount + 1;
      final isDlq = nextRetryCount > 3;

      // Exponential backoff: 2, 4, 8 minutes
      final backoffMinutes = isDlq ? 0 : (1 << nextRetryCount);
      final nextRetryAt = isDlq ? null : DateTime.now().add(Duration(minutes: backoffMinutes));

      final existingData = doc.exists ? doc.data() : null;
      final createdAt = existingData != null
          ? existingData['createdAt']
          : FieldValue.serverTimestamp();

      final failureData = {
        'id': notificationId,
        'notificationId': notificationId,
        'recipientId': recipientId,
        'channel': channel,
        'errorMessage': errorMessage,
        'retryCount': nextRetryCount,
        'lastTriedAt': FieldValue.serverTimestamp(),
        'nextRetryAt': nextRetryAt != null ? Timestamp.fromDate(nextRetryAt) : null,
        'isDlq': isDlq,
        'originalPayload': originalPayload,
        'createdAt': createdAt,
      };

      await docRef.set(failureData);

      // Replicate to RDS
      final rds = RDSDatabaseService();
      try {
        await rds.query(
          '''
          INSERT INTO notification_failures (id, notification_id, recipient_id, channel, error_message, retry_count, last_tried_at, next_retry_at, is_dlq)
          VALUES (\$1, \$2, \$3, \$4, \$5, \$6, now(), \$7, \$8)
          ON CONFLICT (id) DO UPDATE SET
            retry_count = EXCLUDED.retry_count,
            last_tried_at = now(),
            next_retry_at = EXCLUDED.next_retry_at,
            is_dlq = EXCLUDED.is_dlq,
            error_message = EXCLUDED.error_message
          ''',
          params: [
            notificationId,
            notificationId,
            recipientId,
            channel,
            errorMessage,
            nextRetryCount,
            nextRetryAt?.toIso8601String(),
            isDlq,
          ],
          allowWrite: true,
        );
      } catch (rdsError) {
        debugPrint('[NotificationRetryService] RDS replication failed: $rdsError');
      }

      if (isDlq) {
        debugPrint('[NotificationRetryService] Notification $notificationId moved to DLQ.');
        // Trigger Admin Alert log
        await triggerAdminAlert(
          type: 'delivery_failure',
          severity: 'high',
          title: 'Notification Delivery Failed (DLQ)',
          description:
              'Failed to deliver notification $notificationId to $recipientId via $channel after 3 retries. Error: $errorMessage',
        );
      } else {
        debugPrint(
          '[NotificationRetryService] Scheduled retry #$nextRetryCount in $backoffMinutes min for notification $notificationId',
        );

        // Schedule local retry timer in Flutter client (accelerated for verification: 5 seconds per backoff minute)
        Timer(Duration(seconds: backoffMinutes * 5), () async {
          await processRetry(notificationId);
        });
      }
    } catch (e) {
      debugPrint('[NotificationRetryService] Error logging failure: $e');
    }
  }

  /// Processes a scheduled retry
  Future<void> processRetry(String failureId) async {
    try {
      final docRef = _db.collection('notification_failures').doc(failureId);
      final doc = await docRef.get();
      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;
      if (data['isDlq'] == true) return;

      final String channel = data['channel'];
      final String recipientId = data['recipientId'];
      final Map<String, dynamic> payload = Map<String, dynamic>.from(data['originalPayload'] ?? {});
      final String title = payload['title'] ?? '';
      final String body = payload['body'] ?? '';
      final String phone = payload['phoneNumber'] ?? '';

      debugPrint('[NotificationRetryService] Retrying delivery for $failureId via $channel...');

      bool success = false;
      String error = 'Unknown retry error';

      if (channel == 'whatsapp') {
        success = await WhatsAppNotificationService.sendOrderUpdate(
          phoneNumber: phone,
          message: '$title\n\n$body',
        );
        if (!success) error = 'WhatsApp API rejected';
      } else if (channel == 'sms') {
        success = await SMSService().sendOrderStatusUpdateSMS(
          phoneNumber: phone,
          orderNumber: payload['orderNumber'] ?? 'FufajiOrder',
          status: payload['status'] ?? 'update',
        );
        if (!success) error = 'SMS gateway returned error';
      } else if (channel == 'fcm') {
        final userDoc = await _db.collection('users').doc(recipientId).get();
        final token = userDoc.data()?['fcmToken'];
        success = token != null && token.toString().isNotEmpty;
        if (!success) error = 'No FCM token on file';
      }

      if (success) {
        debugPrint('[NotificationRetryService] Retry succeeded for $failureId!');
        await docRef.delete();
        final rds = RDSDatabaseService();
        try {
          await rds.query(
            'DELETE FROM notification_failures WHERE id = \$1',
            params: [failureId],
            allowWrite: true,
          );
        } catch (_) {}
      } else {
        await handleFailure(
          notificationId: failureId,
          recipientId: recipientId,
          channel: channel,
          errorMessage: 'Retry attempt failed: $error',
          originalPayload: payload,
        );
      }
    } catch (e) {
      debugPrint('[NotificationRetryService] Error processing retry: $e');
    }
  }

  /// Logs a system alert (Admin Alert)
  Future<void> triggerAdminAlert({
    required String type,
    required String severity,
    required String title,
    required String description,
  }) async {
    try {
      final alertId = 'alert_${DateTime.now().millisecondsSinceEpoch}';
      final alertData = {
        'id': alertId,
        'type': type,
        'severity': severity,
        'title': title,
        'description': description,
        'resolved': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('alert_logs').doc(alertId).set(alertData);

      // Replicate to RDS
      final rds = RDSDatabaseService();
      try {
        await rds.query(
          '''
          INSERT INTO alert_logs (id, type, severity, title, description, resolved)
          VALUES (\$1, \$2, \$3, \$4, \$5, false)
          ''',
          params: [alertId, type, severity, title, description],
          allowWrite: true,
        );
      } catch (rdsError) {
        debugPrint('[NotificationRetryService] Alert RDS replication failed: $rdsError');
      }

      debugPrint('[NotificationRetryService] ADMIN ALERT LOGGED: $title - Severity: $severity');
    } catch (e) {
      debugPrint('[NotificationRetryService] Error logging admin alert: $e');
    }
  }
}
