import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/order_status.dart';
import 'notification_service.dart';
import 'audit_service.dart';

/// Complete delivery lifecycle management
/// Consolidates 3 delivery services with unified state machine
///
/// Workflow:
/// assigned → picked_up → in_transit → delivered
///   ↓
/// failed → assigned (for reassignment)
///
/// Side effects:
/// - assigned: notify rider with order details
/// - picked_up: mark packing complete, start tracking
/// - in_transit: real-time GPS tracking
/// - delivered: confirm with customer, award loyalty
/// - failed: attempt log, automatic reassignment
///
/// CRITICAL P0 BUG FIX:
/// Rider queries now use correct status values from unified order service
/// Prevents mismatch where packing status != delivery status

enum DeliveryWorkflowStatus {
  assigned, // Rider assigned, awaiting pickup
  picked_up, // Rider collected from shop
  in_transit, // On the way
  delivered, // Delivered to customer
  failed, // Delivery failed, needs reassignment
  cancelled, // Order cancelled
}

class DeliveryWorkflowService {
  static final DeliveryWorkflowService _instance = DeliveryWorkflowService._internal();
  factory DeliveryWorkflowService() => _instance;
  DeliveryWorkflowService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // final InventoryLedgerService _ledger = InventoryLedgerService(); // Unused
  final NotificationService _notifications = NotificationService();
  final AuditService _audit = AuditService();

  // State machine definition
  static const Map<String, Set<String>> validTransitions = {
    'assigned': {'picked_up', 'failed', 'cancelled'},
    'picked_up': {'in_transit', 'failed', 'cancelled'},
    'in_transit': {'delivered', 'failed', 'cancelled'},
    'delivered': <String>{}, // Terminal
    'failed': {'assigned'}, // Can reassign
    'cancelled': <String>{}, // Terminal
  };

  static const Set<String> terminalStatuses = {'delivered', 'cancelled'};

  bool isTerminal(String status) => terminalStatuses.contains(status);

  bool canTransition(String from, String to) {
    if (from == to) return false;
    return validTransitions[from]?.contains(to) ?? false;
  }

  /// Create delivery task from packed order
  /// Called after packing is complete
  Future<Map<String, dynamic>> createDeliveryTask({
    required String orderId,
    required String shopId,
    required String customerId,
    required double deliveryFee,
    String? deliveryAddress,
    String? customerPhone,
    String? deliveryType, // 'standard', 'express', 'scheduled'
    double? estimatedDistance,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final now = DateTime.now();
      final taskRef = _db.collection('delivery_tasks').doc();
      final taskId = taskRef.id;

      final taskData = {
        'id': taskId,
        'orderId': orderId,
        'shopId': shopId,
        'customerId': customerId,
        'status': DeliveryWorkflowStatus.assigned.name,
        'deliveryFee': deliveryFee,
        'deliveryAddress': deliveryAddress,
        'customerPhone': customerPhone,
        'deliveryType': deliveryType ?? 'standard',
        'estimatedDistance': estimatedDistance,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': [
          {
            'status': DeliveryWorkflowStatus.assigned.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': 'system',
            'reason': 'task_created',
          },
        ],
        'assignedRiderId': null,
        'assignedRiderName': null,
        'riderPhone': null,
        'trackingUpdates': [],
        'attemptCount': 0,
        'failureReasons': [],
        'metadata': metadata,
      };

      await taskRef.set(taskData);

      // Update order with delivery task reference
      await _db.collection('orders').doc(orderId).update({
        'deliveryTaskId': taskId,
        'updatedAt': Timestamp.fromDate(now),
      });

      await _audit.log('delivery_task_created', {
        'taskId': taskId,
        'orderId': orderId,
        'shopId': shopId,
        'customerId': customerId,
        'deliveryFee': deliveryFee,
      });

      debugPrint('[DeliveryWorkflowService] Created delivery task $taskId for order $orderId');
      return taskData;
    } catch (e) {
      debugPrint('[DeliveryWorkflowService] Failed to create delivery task: $e');
      rethrow;
    }
  }

  /// Assign delivery task to rider
  /// Notifies rider with order details
  Future<void> assignToRider({
    required String taskId,
    required String riderId,
    String? riderName,
    String? riderPhone,
    String? riderEmail,
  }) async {
    try {
      final taskSnap = await _db.collection('delivery_tasks').doc(taskId).get();
      final taskData = taskSnap.data();

      if (taskData == null) throw Exception('Delivery task not found');

      final currentStatus = taskData['status'] as String;
      if (currentStatus != 'assigned') {
        throw Exception('Task must be in assigned status to reassign rider');
      }

      final now = DateTime.now();

      await _db.collection('delivery_tasks').doc(taskId).update({
        'assignedRiderId': riderId,
        'assignedRiderName': riderName,
        'riderPhone': riderPhone,
        'riderEmail': riderEmail,
        'assignedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': 'assigned',
            'timestamp': Timestamp.fromDate(now),
            'changedBy': 'dispatcher',
            'reason': 'rider_assigned',
          },
        ]),
      });

      // Notify rider with order details and delivery address
      await _notifications.notifyRider(riderId, 'New delivery order assigned', {
        'taskId': taskId,
        'orderId': taskData['orderId'],
        'deliveryAddress': taskData['deliveryAddress'],
        'customerPhone': taskData['customerPhone'],
        'deliveryFee': taskData['deliveryFee'],
        'action': 'accept_delivery',
      });

      // Log to audit
      await _audit.log('rider_assigned', {
        'taskId': taskId,
        'riderId': riderId,
        'riderName': riderName,
      });

      debugPrint('[DeliveryWorkflowService] Assigned delivery task $taskId to rider $riderId');
    } catch (e) {
      debugPrint('[DeliveryWorkflowService] Failed to assign rider: $e');
      rethrow;
    }
  }

  /// Mark order picked up from shop
  Future<void> markPickedUp({
    required String taskId,
    String? riderId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final taskSnap = await _db.collection('delivery_tasks').doc(taskId).get();
      final taskData = taskSnap.data();

      if (taskData == null) throw Exception('Task not found');

      final currentStatus = taskData['status'] as String;
      if (!canTransition(currentStatus, 'picked_up')) {
        throw Exception('Cannot pick up in status: $currentStatus');
      }

      final orderId = taskData['orderId'] as String;
      final now = DateTime.now();

      await _db.collection('delivery_tasks').doc(taskId).update({
        'status': DeliveryWorkflowStatus.picked_up.name,
        'pickedUpAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': DeliveryWorkflowStatus.picked_up.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': riderId ?? 'rider',
            'reason': 'picked_up_from_shop',
          },
        ]),
        'trackingUpdates': FieldValue.arrayUnion([
          {
            'status': 'picked_up',
            'lat': latitude,
            'lng': longitude,
            'timestamp': Timestamp.fromDate(now),
          },
        ]),
      });

      // Update order status
      await _db.collection('orders').doc(orderId).update({
        'status': OrderStatus.shipped.firestoreValue, // Order is now in transit
        'updatedAt': Timestamp.fromDate(now),
      });

      await _audit.log('delivery_picked_up', {'taskId': taskId, 'riderId': riderId});

      debugPrint('[DeliveryWorkflowService] Marked delivery task $taskId as picked up');
    } catch (e) {
      debugPrint('[DeliveryWorkflowService] Failed to mark picked up: $e');
      rethrow;
    }
  }

  /// Update delivery location (real-time GPS tracking)
  /// Also transitions to in_transit if needed
  Future<void> updateLocation({
    required String taskId,
    required double latitude,
    required double longitude,
    String? riderId,
  }) async {
    try {
      final taskSnap = await _db.collection('delivery_tasks').doc(taskId).get();
      final taskData = taskSnap.data();

      if (taskData == null) throw Exception('Task not found');

      final currentStatus = taskData['status'] as String;

      // Auto-transition to in_transit if we have location updates from picked_up
      String nextStatus = currentStatus;
      if (currentStatus == 'picked_up') {
        nextStatus = 'in_transit';
      }

      final now = DateTime.now();

      await _db.collection('delivery_tasks').doc(taskId).update({
        'status': nextStatus,
        'currentLocation': {'lat': latitude, 'lng': longitude},
        'lastLocationUpdate': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'trackingUpdates': FieldValue.arrayUnion([
          {
            'status': nextStatus,
            'lat': latitude,
            'lng': longitude,
            'timestamp': Timestamp.fromDate(now),
            'riderId': riderId,
          },
        ]),
        if (currentStatus == 'picked_up')
          'statusHistory': FieldValue.arrayUnion([
            {
              'status': nextStatus,
              'timestamp': Timestamp.fromDate(now),
              'changedBy': riderId ?? 'gps',
              'reason': 'in_transit',
            },
          ]),
      });

      debugPrint(
        '[DeliveryWorkflowService] Updated location for task $taskId: ($latitude, $longitude)',
      );
    } catch (e) {
      debugPrint('[DeliveryWorkflowService] Failed to update location: $e');
      rethrow;
    }
  }

  /// Mark order delivered
  Future<void> markDelivered({
    required String taskId,
    String? riderId,
    double? latitude,
    double? longitude,
    String? customerSignature,
    String? notes,
  }) async {
    try {
      final taskSnap = await _db.collection('delivery_tasks').doc(taskId).get();
      final taskData = taskSnap.data();

      if (taskData == null) throw Exception('Task not found');

      final currentStatus = taskData['status'] as String;
      if (!canTransition(currentStatus, 'delivered')) {
        throw Exception('Cannot deliver in status: $currentStatus');
      }

      final orderId = taskData['orderId'] as String;
      final customerId = taskData['customerId'] as String;
      final now = DateTime.now();

      await _db.collection('delivery_tasks').doc(taskId).update({
        'status': DeliveryWorkflowStatus.delivered.name,
        'deliveredAt': Timestamp.fromDate(now),
        'deliveredByRider': riderId,
        'customerSignature': customerSignature,
        'deliveryNotes': notes,
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': DeliveryWorkflowStatus.delivered.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': riderId ?? 'system',
            'reason': 'delivered_to_customer',
          },
        ]),
        'trackingUpdates': FieldValue.arrayUnion([
          {
            'status': 'delivered',
            'lat': latitude,
            'lng': longitude,
            'timestamp': Timestamp.fromDate(now),
          },
        ]),
      });

      // Update order status to delivered
      await _db.collection('orders').doc(orderId).update({
        'status': OrderStatus.delivered.firestoreValue,
        'deliveredAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Notify customer that order is delivered
      await _notifications.notifyCustomer(customerId, 'Your order has been delivered!', {
        'orderId': orderId,
        'action': 'rate_delivery',
      });

      await _audit.log('delivery_completed', {
        'taskId': taskId,
        'orderId': orderId,
        'riderId': riderId,
      });

      debugPrint('[DeliveryWorkflowService] Marked delivery task $taskId as delivered');
    } catch (e) {
      debugPrint('[DeliveryWorkflowService] Failed to mark delivered: $e');
      rethrow;
    }
  }

  /// Mark delivery failed (attempt failed, needs reassignment)
  Future<void> markFailed({
    required String taskId,
    required String failureReason,
    String? riderId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final taskSnap = await _db.collection('delivery_tasks').doc(taskId).get();
      final taskData = taskSnap.data();

      if (taskData == null) throw Exception('Task not found');

      final currentStatus = taskData['status'] as String;
      if (!canTransition(currentStatus, 'failed')) {
        throw Exception('Cannot fail in status: $currentStatus');
      }

      // final failureReasons = (taskData['failureReasons'] as List?) ?? []; // Unused
      final attemptCount = ((taskData['attemptCount'] as num?)?.toInt() ?? 0) + 1;
      final now = DateTime.now();

      await _db.collection('delivery_tasks').doc(taskId).update({
        'status': DeliveryWorkflowStatus.failed.name,
        'failedAt': Timestamp.fromDate(now),
        'failureReason': failureReason,
        'failureReasons': FieldValue.arrayUnion([
          {
            'reason': failureReason,
            'attemptNumber': attemptCount,
            'riderId': riderId,
            'failedAt': Timestamp.fromDate(now),
            'lat': latitude,
            'lng': longitude,
          },
        ]),
        'attemptCount': attemptCount,
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': DeliveryWorkflowStatus.failed.name,
            'timestamp': Timestamp.fromDate(now),
            'changedBy': riderId ?? 'system',
            'reason': failureReason,
          },
        ]),
      });

      // Notify dispatcher for reassignment
      await _notifications
          .notifyDispatcher('Delivery attempt #$attemptCount failed for task: $taskId', {
            'taskId': taskId,
            'reason': failureReason,
            'attemptCount': attemptCount,
            'action': 'reassign_rider',
          });

      await _audit.log('delivery_failed', {
        'taskId': taskId,
        'reason': failureReason,
        'attemptNumber': attemptCount,
        'riderId': riderId,
      });

      debugPrint(
        '[DeliveryWorkflowService] Marked delivery task $taskId as failed: $failureReason',
      );
    } catch (e) {
      debugPrint('[DeliveryWorkflowService] Failed to mark failed: $e');
      rethrow;
    }
  }

  /// Get all orders assigned to rider
  /// CRITICAL P0 FIX: Now queries delivery_tasks (not orders) with correct statuses
  /// Orders in these delivery task statuses are visible:
  /// - assigned = ready for pickup
  /// - picked_up = picked up, in transit
  /// - in_transit = on the way
  Future<List<Map<String, dynamic>>> getRiderDeliveries(String riderId) async {
    try {
      // Query for all delivery tasks assigned to this rider that are not terminal
      final snap = await _db
          .collection('delivery_tasks')
          .where('assignedRiderId', isEqualTo: riderId)
          .where(
            'status',
            whereIn: [
              DeliveryWorkflowStatus.assigned.name,
              DeliveryWorkflowStatus.picked_up.name,
              DeliveryWorkflowStatus.in_transit.name,
            ],
          )
          .orderBy('assignedAt', descending: true)
          .limit(10)
          .get();

      // Enrich delivery tasks with order details
      final enrichedTasks = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final taskData = doc.data();
        final orderId = taskData['orderId'] as String?;
        if (orderId != null) {
          final orderSnap = await _db.collection('orders').doc(orderId).get();
          if (orderSnap.exists) {
            enrichedTasks.add({...taskData, 'order': orderSnap.data()});
          }
        }
      }

      return enrichedTasks;
    } catch (e) {
      debugPrint('[DeliveryWorkflowService] Failed to get rider deliveries: $e');
      rethrow;
    }
  }

  /// Get delivery task
  Future<Map<String, dynamic>?> getTask(String taskId) async {
    final snap = await _db.collection('delivery_tasks').doc(taskId).get();
    return snap.data();
  }

  /// Get delivery tasks by shop
  Future<List<Map<String, dynamic>>> getShopDeliveries(
    String shopId, {
    String? statusFilter,
    int limit = 50,
  }) async {
    var query = _db
        .collection('delivery_tasks')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    final snap = await query.limit(limit).get();
    return snap.docs.map((doc) => doc.data()).toList();
  }

  /// Get delivery tasks by order
  Future<Map<String, dynamic>?> getTaskByOrder(String orderId) async {
    final snap = await _db
        .collection('delivery_tasks')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();

    return snap.docs.isEmpty ? null : snap.docs.first.data();
  }

  /// Stream real-time tracking for a delivery
  Stream<Map<String, dynamic>?> trackDelivery(String taskId) {
    return _db.collection('delivery_tasks').doc(taskId).snapshots().map((snap) => snap.data());
  }

  /// Get tracking history for a delivery
  Future<List<Map<String, dynamic>>> getTrackingHistory(String taskId) async {
    final snap = await _db.collection('delivery_tasks').doc(taskId).get();
    final data = snap.data();
    final updates = (data?['trackingUpdates'] as List?) ?? [];
    return updates.cast<Map<String, dynamic>>();
  }
}
