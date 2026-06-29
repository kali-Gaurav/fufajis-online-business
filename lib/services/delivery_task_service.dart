import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/delivery_task_model.dart';
import '../models/customer_delivery_event_model.dart';
import '../models/delivery_exception_model.dart';
import 'rds_database_service.dart';

class DeliveryTaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  static final DeliveryTaskService _instance = DeliveryTaskService._internal();
  factory DeliveryTaskService() => _instance;
  DeliveryTaskService._internal();

  Future<void> createTask(DeliveryTaskModel task) async {
    final batch = _db.batch();
    
    // Create the task
    final taskRef = _db.collection('delivery_tasks').doc(task.id);
    batch.set(taskRef, task.toJson());

    // Create a customer event timeline entry
    final eventRef = _db.collection('customer_delivery_events').doc();
    final event = CustomerDeliveryEventModel(
      id: eventRef.id,
      deliveryTaskId: task.id,
      orderId: task.orderId,
      eventType: CustomerDeliveryEventType.confirmed,
      title: 'Order Confirmed',
      description: 'Your order has been received and is being prepared.',
      timestamp: DateTime.now(),
    );
    batch.set(eventRef, event.toMap());

    await batch.commit();
  }

  Future<void> updateTaskStatus(String taskId, String orderId, DeliveryTaskStatus newStatus, {String? riderId}) async {
    final batch = _db.batch();
    final taskRef = _db.collection('delivery_tasks').doc(taskId);

    final updates = <String, dynamic>{
      'status': newStatus.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newStatus == DeliveryTaskStatus.assigned && riderId != null) {
      updates['deliveryAgentId'] = riderId;
      updates['assignedAt'] = FieldValue.serverTimestamp();
    } else if (newStatus == DeliveryTaskStatus.delivered) {
      updates['completedAt'] = FieldValue.serverTimestamp();
    } else if (newStatus == DeliveryTaskStatus.picked_up) {
      updates['actualArrivalAt'] = FieldValue.serverTimestamp(); // representing pickup/arrival
    }

    batch.update(taskRef, updates);

    // Create Customer Timeline Event
    CustomerDeliveryEventType eventType;
    String title;
    String desc;

    switch (newStatus) {
      case DeliveryTaskStatus.assigned:
        eventType = CustomerDeliveryEventType.assigned;
        title = 'Rider Assigned';
        desc = 'A delivery rider has been assigned to your order.';
        break;
      case DeliveryTaskStatus.picked_up:
        eventType = CustomerDeliveryEventType.picked_up;
        title = 'Order Picked Up';
        desc = 'Your order is on the way.';
        break;
      case DeliveryTaskStatus.out_for_delivery:
        eventType = CustomerDeliveryEventType.approaching;
        title = 'Out for Delivery';
        desc = 'Rider is approaching your location.';
        break;
      case DeliveryTaskStatus.delivered:
        eventType = CustomerDeliveryEventType.delivered;
        title = 'Delivered';
        desc = 'Your order has been delivered successfully.';
        break;
      case DeliveryTaskStatus.failed:
      case DeliveryTaskStatus.rejected:
      case DeliveryTaskStatus.returned:
        eventType = CustomerDeliveryEventType.exception_occurred;
        title = 'Delivery Exception';
        desc = 'There was an issue with your delivery. We are looking into it.';
        break;
      default:
        eventType = CustomerDeliveryEventType.confirmed;
        title = 'Update';
        desc = 'Status updated to ${newStatus.name}';
    }

    final eventRef = _db.collection('customer_delivery_events').doc();
    final event = CustomerDeliveryEventModel(
      id: eventRef.id,
      deliveryTaskId: taskId,
      orderId: orderId,
      eventType: eventType,
      title: title,
      description: desc,
      timestamp: DateTime.now(),
    );
    
    batch.set(eventRef, event.toMap());
    
    try {
      await batch.commit();
      debugPrint('[DeliveryTaskService] Task $taskId updated to ${newStatus.name}');
    } catch (e) {
      debugPrint('[DeliveryTaskService] ERROR updating task status: $e');
      // Here is where offline queue logic would catch errors
      _queueOfflineStatusUpdate(taskId, newStatus.name);
    }
  }

  Future<void> logException(DeliveryExceptionModel exception) async {
    final batch = _db.batch();
    
    final exRef = _db.collection('delivery_exceptions').doc(exception.id);
    batch.set(exRef, exception.toMap());

    // Automatically transition the task state to failed if the exception is critical
    final bool isCritical = exception.type == ExceptionType.customer_unreachable ||
        exception.type == ExceptionType.vehicle_breakdown ||
        exception.type == ExceptionType.wrong_address;

    if (isCritical) {
      final taskRef = _db.collection('delivery_tasks').doc(exception.deliveryTaskId);
      batch.update(taskRef, {
        'status': DeliveryTaskStatus.failed.value,
        'failureReason': exception.type.name,
      });

      // Auto-retry recovery: Reset the order back to 'packed' status for re-dispatch
      try {
        final taskSnap = await _db.collection('deliveries').doc(exception.deliveryTaskId).get();
        if (taskSnap.exists) {
          final taskData = taskSnap.data()!;
          final orderId = taskData['orderId'] as String?;
          final shopId = taskData['shopId'] as String? ?? 'shop_001';

          if (orderId != null && orderId.isNotEmpty) {
            final orderRef = _db.collection('shops').doc(shopId).collection('orders').doc(orderId);
            batch.update(orderRef, {
              'status': 'OrderStatus.packed',
              'deliveryAgentId': FieldValue.delete(),
              'deliveryAgentName': FieldValue.delete(),
              'deliveryAgentPhone': FieldValue.delete(),
              'assignedAt': FieldValue.delete(),
              'assignmentTime': FieldValue.delete(),
              'failureReason': exception.type.name,
            });

            // Also mark failed status on the deliveries collection
            final deliveryRef = _db.collection('deliveries').doc(exception.deliveryTaskId);
            batch.update(deliveryRef, {
              'status': 'failed',
              'failureReason': exception.type.name,
            });
          }
        }
      } catch (e) {
        debugPrint('[DeliveryTaskService] Auto-retry recovery error: $e');
      }
    }

    await batch.commit();

    // Mirror to SQL RDS
    try {
      final rds = RDSDatabaseService();
      await rds.query(
        '''
        INSERT INTO delivery_exceptions (id, delivery_id, rider_id, branch_id, type, description, status, created_at)
        VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8)
        ''',
        params: [
          exception.id,
          exception.deliveryTaskId,
          exception.riderId,
          exception.branchId,
          exception.type.name,
          exception.description,
          exception.status.name,
          exception.createdAt.toIso8601String(),
        ],
        allowWrite: true,
      );

      if (isCritical) {
        await rds.query(
          '''
          INSERT INTO delivery_status_logs (delivery_id, order_id, rider_id, from_status, to_status, notes)
          VALUES (\$1, \$2, \$3, \$4, \$5, \$6)
          ''',
          params: [
            exception.deliveryTaskId,
            exception.deliveryTaskId,
            exception.riderId,
            'in_transit',
            'failed',
            'Critical exception logged: ${exception.type.name} - ${exception.description}',
          ],
          allowWrite: true,
        );
      }
    } catch (e) {
      debugPrint('[DeliveryTaskService] RDS exception log sync failed: $e');
    }
  }

  void _queueOfflineStatusUpdate(String taskId, String status) {
    // In a real implementation using Hive/SharedPreferences:
    // 1. Load offline queue
    // 2. Add {'action': 'UPDATE_STATUS', 'taskId': taskId, 'status': status, 'timestamp': now}
    // 3. Save queue
    // 4. Background service attempts to sync when online
    debugPrint('[DeliveryTaskService] Task update queued offline for $taskId -> $status');
  }

  Stream<List<DeliveryTaskModel>> getTasksForRider(String riderId) {
    return _db
        .collection('delivery_tasks')
        .where('deliveryAgentId', isEqualTo: riderId)
        .where('status', whereIn: [
          DeliveryTaskStatus.assigned.value,
          DeliveryTaskStatus.accepted.value,
          DeliveryTaskStatus.picked_up.value,
          DeliveryTaskStatus.out_for_delivery.value,
        ])
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => DeliveryTaskModel.fromJson(doc.data())).toList());
  }
}
