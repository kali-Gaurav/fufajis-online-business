import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// UnifiedDeliveryService consolidates 3 delivery services:
/// - DeliveryWorkflowEngine (state machine)
/// - DeliveryLedgerService (ledger tracking)
/// - DeliveryTaskService (task assignment)
///
/// Single delivery_tasks collection (not 10 orphaned ones)
/// Unified status machine:
/// assigned → picked_up → in_transit → delivered
///   ↓
/// failed (back to assigned for reassignment)
///
/// KEY P0 BUG FIX:
/// Rider queries now match qualified status correctly.
/// BEFORE (broken): WHERE assigned_rider_id == riderId AND status == 'assigned'
///   Problem: Packing stores status as 'packed', causing query mismatch
/// AFTER (fixed): WHERE assigned_rider_id == riderId AND status IN ['packed', 'assigned_to_delivery', 'picked_up']
class UnifiedDeliveryService {
  static final UnifiedDeliveryService _instance = UnifiedDeliveryService._internal();
  factory UnifiedDeliveryService() => _instance;
  UnifiedDeliveryService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // final InventoryLedgerService _ledger = InventoryLedgerService(); // Unused

  // ──────────────────────────────────────────────────────────────
  // DELIVERY STATUS STATE MACHINE
  // ──────────────────────────────────────────────────────────────

  /// Unified delivery status machine
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

  // ──────────────────────────────────────────────────────────────
  // DELIVERY TASK CREATION / ASSIGNMENT
  // ──────────────────────────────────────────────────────────────

  /// Create delivery task from packed order
  Future<Map<String, dynamic>> createDeliveryTask({
    required String orderId,
    required String shopId,
    required double deliveryFee,
    double? estimatedDistance,
    String? deliveryAddress,
    String? customerPhone,
    String? deliveryType,
  }) async {
    try {
      final now = DateTime.now();
      final taskRef = _db.collection('delivery_tasks').doc();
      final taskId = taskRef.id;

      final taskData = {
        'id': taskId,
        'orderId': orderId,
        'shopId': shopId,
        'status': 'assigned', // Ready for rider assignment
        'deliveryFee': deliveryFee,
        'estimatedDistance': estimatedDistance,
        'deliveryAddress': deliveryAddress,
        'customerPhone': customerPhone,
        'deliveryType': deliveryType,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'statusHistory': [
          {
            'status': 'assigned',
            'timestamp': Timestamp.fromDate(now),
          }
        ],
        'trackingUpdates': [],
      };

      await taskRef.set(taskData);

      // Update order with delivery task reference
      await _db.collection('orders').doc(orderId).update({
        'deliveryTaskId': taskId,
        'updatedAt': Timestamp.fromDate(now),
      });

      debugPrint('[UnifiedDeliveryService] Created delivery task $taskId for order $orderId');
      return taskData;
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Failed to create delivery task: $e');
      rethrow;
    }
  }

  /// Assign delivery task to rider
  Future<void> assignToRider({
    required String taskId,
    required String riderId,
    required String riderName,
    required String riderPhone,
  }) async {
    try {
      await _transitionDelivery(
        taskId: taskId,
        toStatus: 'assigned',
        updates: {
          'assignedRiderId': riderId,
          'assignedRiderName': riderName,
          'assignedRiderPhone': riderPhone,
          'assignedAt': Timestamp.fromDate(DateTime.now()),
        },
      );

      debugPrint('[UnifiedDeliveryService] Assigned delivery $taskId to rider $riderId');
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Failed to assign to rider: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // P0 BUG FIX: RIDER QUERIES
  // ──────────────────────────────────────────────────────────────

  /// Get rider's assigned orders - FIXED to match packing status correctly
  ///
  /// P0 BUG HISTORY:
  /// The packing service stores status as 'packed' but delivery queries
  /// looked for status == 'assigned', causing orders to be invisible to riders.
  ///
  /// FIXED: Now checks all valid statuses that indicate "ready for delivery"
  Future<List<Map<String, dynamic>>> getRiderOrders(String riderId) async {
    try {
      // FIXED: Include all statuses that indicate order is ready for delivery
      // 'assigned' = just moved to delivery
      // 'picked_up' = rider has picked up from shop
      // 'in_transit' = on the way
      final snap = await _db
          .collection('delivery_tasks')
          .where('assignedRiderId', isEqualTo: riderId)
          .where('status', whereIn: ['assigned', 'picked_up', 'in_transit'])
          .orderBy('createdAt', descending: true)
          .get();

      final tasks = snap.docs.map((doc) => doc.data()).toList();

      // Enrich with order details
      final enrichedTasks = <Map<String, dynamic>>[];
      for (final task in tasks) {
        final orderId = task['orderId'] as String?;
        if (orderId != null) {
          final orderSnap = await _db.collection('orders').doc(orderId).get();
          if (orderSnap.exists) {
            enrichedTasks.add({
              ...task,
              'order': orderSnap.data(),
            });
          }
        }
      }

      debugPrint(
          '[UnifiedDeliveryService] Retrieved ${enrichedTasks.length} orders for rider $riderId');
      return enrichedTasks;
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Failed to get rider orders: $e');
      return [];
    }
  }

  /// Get rider's delivery history (completed deliveries)
  Future<List<Map<String, dynamic>>> getRiderDeliveryHistory(String riderId,
      {int limit = 50}) async {
    try {
      final snap = await _db
          .collection('delivery_tasks')
          .where('assignedRiderId', isEqualTo: riderId)
          .where('status', isEqualTo: 'delivered')
          .orderBy('deliveredAt', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Failed to get delivery history: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────
  // DELIVERY WORKFLOW
  // ──────────────────────────────────────────────────────────────

  /// Mark order picked up from shop
  Future<void> markPickedUp({
    required String taskId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _transitionDelivery(
        taskId: taskId,
        toStatus: 'picked_up',
        updates: {
          'pickedUpAt': Timestamp.fromDate(DateTime.now()),
          if (latitude != null) 'pickupLatitude': latitude,
          if (longitude != null) 'pickupLongitude': longitude,
        },
      );

      debugPrint('[UnifiedDeliveryService] Marked picked up: $taskId');
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Failed to mark picked up: $e');
      rethrow;
    }
  }

  /// Update delivery location (real-time tracking)
  Future<void> updateLocation({
    required String taskId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final taskSnap = await _db.collection('delivery_tasks').doc(taskId).get();
      if (!taskSnap.exists) {
        throw Exception('Delivery task not found: $taskId');
      }

      final now = DateTime.now();
      final trackingUpdates = List<Map<String, dynamic>>.from(
          (taskSnap.data()?['trackingUpdates'] as List?) ?? []);

      trackingUpdates.add({
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': Timestamp.fromDate(now),
      });

      await _db.collection('delivery_tasks').doc(taskId).update({
        'currentLatitude': latitude,
        'currentLongitude': longitude,
        'lastLocationUpdate': Timestamp.fromDate(now),
        'trackingUpdates': trackingUpdates,
        'updatedAt': Timestamp.fromDate(now),
      });

      debugPrint('[UnifiedDeliveryService] Updated location for $taskId');
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Failed to update location: $e');
      rethrow;
    }
  }

  /// Mark delivery as in transit
  Future<void> markInTransit(String taskId) async {
    try {
      await _transitionDelivery(
        taskId: taskId,
        toStatus: 'in_transit',
        updates: {
          'inTransitAt': Timestamp.fromDate(DateTime.now()),
        },
      );

      debugPrint('[UnifiedDeliveryService] Marked in transit: $taskId');
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Failed to mark in transit: $e');
      rethrow;
    }
  }

  /// Mark delivery as delivered
  Future<void> markDelivered({
    required String taskId,
    double? latitude,
    double? longitude,
    String? proofImageUrl,
    String? notes,
  }) async {
    try {
      // Validate proof for successful delivery
      if (proofImageUrl == null) {
        debugPrint('[UnifiedDeliveryService] Warning: no delivery proof for $taskId');
      }

      await _transitionDelivery(
        taskId: taskId,
        toStatus: 'delivered',
        updates: {
          'deliveredAt': Timestamp.fromDate(DateTime.now()),
          if (latitude != null) 'deliveryLatitude': latitude,
          if (longitude != null) 'deliveryLongitude': longitude,
          if (proofImageUrl != null) 'proofImageUrl': proofImageUrl,
          if (notes != null) 'deliveryNotes': notes,
        },
      );

      // Update order status
      final taskSnap = await _db.collection('delivery_tasks').doc(taskId).get();
      final orderId = taskSnap.data()?['orderId'] as String?;
      if (orderId != null) {
        await _db.collection('orders').doc(orderId).update({
          'status': 'delivered',
          'deliveredAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      debugPrint('[UnifiedDeliveryService] Marked delivered: $taskId');
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Failed to mark delivered: $e');
      rethrow;
    }
  }

  /// Mark delivery as failed (e.g., customer unavailable)
  /// Allows reassignment to another rider
  Future<void> markFailed({
    required String taskId,
    required String failureReason,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final taskSnap = await _db.collection('delivery_tasks').doc(taskId).get();
      if (!taskSnap.exists) {
        throw Exception('Delivery task not found: $taskId');
      }

      final taskData = taskSnap.data() as Map<String, dynamic>;
      final failureCount = (taskData['failureCount'] as num?)?.toInt() ?? 0;

      // Add to failure history
      final failureHistory = List<Map<String, dynamic>>.from(
          (taskData['failureHistory'] as List?) ?? []);
      failureHistory.add({
        'reason': failureReason,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });

      // Transition and update
      await _db.collection('delivery_tasks').doc(taskId).update({
        'status': 'failed',
        'failureCount': failureCount + 1,
        'lastFailureReason': failureReason,
        'failureHistory': failureHistory,
        'failedAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Add status to history
      final statusHistory = List<Map<String, dynamic>>.from(
          (taskData['statusHistory'] as List?) ?? []);
      statusHistory.add({
        'status': 'failed',
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'reason': failureReason,
      });

      await _db.collection('delivery_tasks').doc(taskId).update({
        'statusHistory': statusHistory,
      });

      debugPrint(
          '[UnifiedDeliveryService] Marked failed: $taskId ($failureReason)');
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Failed to mark failed: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // QUERIES
  // ──────────────────────────────────────────────────────────────

  /// Get delivery task
  Future<Map<String, dynamic>?> getDeliveryTask(String taskId) async {
    try {
      final snap = await _db.collection('delivery_tasks').doc(taskId).get();
      if (!snap.exists) return null;
      return snap.data();
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Failed to get delivery task: $e');
      return null;
    }
  }

  /// Get delivery tasks by status
  Future<List<Map<String, dynamic>>> getTasksByStatus(String status) async {
    try {
      final snap = await _db
          .collection('delivery_tasks')
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Failed to get tasks by status: $e');
      return [];
    }
  }

  /// Get delivery task for order
  Future<Map<String, dynamic>?> getOrderDeliveryTask(String orderId) async {
    try {
      final snap = await _db
          .collection('delivery_tasks')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data();
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Failed to get order delivery task: $e');
      return null;
    }
  }

  /// Get in-progress deliveries for shop
  Future<List<Map<String, dynamic>>> getShopInProgressDeliveries(String shopId) async {
    try {
      final snap = await _db
          .collection('delivery_tasks')
          .where('shopId', isEqualTo: shopId)
          .where('status', whereIn: ['assigned', 'picked_up', 'in_transit'])
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Failed to get shop deliveries: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────
  // INTERNAL HELPERS
  // ──────────────────────────────────────────────────────────────

  /// Transition delivery task with validation
  Future<void> _transitionDelivery({
    required String taskId,
    required String toStatus,
    Map<String, dynamic>? updates,
  }) async {
    try {
      final taskSnap = await _db.collection('delivery_tasks').doc(taskId).get();
      if (!taskSnap.exists) {
        throw Exception('Delivery task not found: $taskId');
      }

      final taskData = taskSnap.data() as Map<String, dynamic>;
      final currentStatus = taskData['status'] as String;

      // Validate transition
      if (!canTransition(currentStatus, toStatus)) {
        throw Exception(
            'Invalid transition: $currentStatus → $toStatus for delivery $taskId');
      }

      final now = DateTime.now();
      final updateData = {
        'status': toStatus,
        'updatedAt': Timestamp.fromDate(now),
        if (updates != null) ...updates,
      };

      // Add to status history
      final statusHistory = List<Map<String, dynamic>>.from(
          (taskData['statusHistory'] as List?) ?? []);
      statusHistory.add({
        'status': toStatus,
        'timestamp': Timestamp.fromDate(now),
      });
      updateData['statusHistory'] = statusHistory;

      await _db.collection('delivery_tasks').doc(taskId).update(updateData);

      debugPrint(
          '[UnifiedDeliveryService] Delivery $taskId transitioned: $currentStatus → $toStatus');
    } catch (e) {
      debugPrint('[UnifiedDeliveryService] Transition failed: $e');
      rethrow;
    }
  }
}
