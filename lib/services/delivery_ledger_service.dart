import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service implementing Delivery Control Tower & Ledger.
/// Migrated from AWS RDS to Firestore for serverless, free database consolidation.
class DeliveryLedgerService {
  static final DeliveryLedgerService _instance = DeliveryLedgerService._internal();
  factory DeliveryLedgerService() => _instance;
  DeliveryLedgerService._internal();

  /// Fetch all unassigned orders that are 'ready_for_pickup' and have no active delivery tasks.
  Future<List<Map<String, dynamic>>> getUnassignedOrders() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('orderStatus', isEqualTo: 'OrderStatus.ready_for_pickup')
          .get();

      final activeTasksSnapshot = await FirebaseFirestore.instance
          .collection('delivery_tasks')
          .where('status', whereNotIn: ['failed', 'cancelled', 'delivered'])
          .get();

      final activeOrderIds = activeTasksSnapshot.docs
          .map((doc) => doc.data()['order_id'] as String?)
          .where((id) => id != null)
          .toSet();

      final List<Map<String, dynamic>> results = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final orderId = doc.id;
        if (activeOrderIds.contains(orderId)) continue;

        final userId = data['customerId'] ?? '';
        String customerName = 'Unknown';
        String customerPhone = '';
        if (userId.isNotEmpty) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (userDoc.exists) {
            customerName = userDoc.data()?['name'] ?? 'Unknown';
            customerPhone = userDoc.data()?['phoneNumber'] ?? '';
          }
        }

        final addr = data['deliveryAddress'] ?? {};
        final addressStr = '${addr['line1'] ?? ''} ${addr['line2'] ?? ''}'.trim();

        results.add({
          'id': orderId,
          'order_number': data['orderNumber'] ?? '',
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'address': addressStr,
          'latitude': addr['latitude'] ?? addr['lat'],
          'longitude': addr['longitude'] ?? addr['lng'],
        });
      }
      return results;
    } catch (e) {
      debugPrint('[DeliveryLedger] Error fetching unassigned orders: $e');
      return [];
    }
  }

  /// Fetch all delivery riders from users.
  Future<List<Map<String, dynamic>>> getAvailableRiders() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'UserRole.deliveryAgent')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'phone': data['phoneNumber'] ?? '',
          'is_online': data['isOnline'] ?? false,
        };
      }).toList();
    } catch (e) {
      debugPrint('[DeliveryLedger] Error fetching available riders: $e');
      return [];
    }
  }

  /// Create a route manifest and its tasks in a single transactional flow.
  Future<String?> createRouteManifest({
    required String routeName,
    String? riderId,
    required List<Map<String, dynamic>> tasks,
    double totalDistance = 0.0,
    int estimatedDurationMinutes = 0,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      final routeRef = db.collection('delivery_routes').doc();
      final routeId = routeRef.id;

      await routeRef.set({
        'id': routeId,
        'route_name': routeName,
        'rider_id': riderId,
        'status': riderId != null ? 'assigned' : 'draft',
        'total_distance': totalDistance,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];
        final taskRef = db.collection('delivery_tasks').doc();
        final taskId = taskRef.id;

        await taskRef.set({
          'id': taskId,
          'route_id': routeId,
          'order_id': task['orderId'],
          'stop_sequence': i + 1,
          'status': 'assigned',
          'customer_name': task['customerName'],
          'address': task['address'],
          'latitude': task['latitude'],
          'longitude': task['longitude'],
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        await db.collection('delivery_events').add({
          'route_id': routeId,
          'task_id': taskId,
          'from_status': null,
          'to_status': 'assigned',
          'notes': 'Route manifest generated and assigned',
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      return routeId;
    } catch (e) {
      debugPrint('[DeliveryLedger] Error creating route manifest: $e');
      return null;
    }
  }

  /// Get all route manifests with active/assigned statuses for a rider.
  Future<List<Map<String, dynamic>>> getRoutesForRider(String riderId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('delivery_routes')
          .where('rider_id', isEqualTo: riderId)
          .where('status', whereIn: ['assigned', 'active'])
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[DeliveryLedger] Error getting rider routes: $e');
      return [];
    }
  }

  /// Fetch all tasks for a specific route.
  Future<List<Map<String, dynamic>>> getRouteTasks(String routeId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('delivery_tasks')
          .where('route_id', isEqualTo: routeId)
          .orderBy('stop_sequence', descending: false)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[DeliveryLedger] Error getting route tasks: $e');
      return [];
    }
  }

  /// Transition a single task's status and insert an audit event.
  /// If this transition affects the route's overall status, update that as well.
  Future<bool> updateTaskStatus({
    required String taskId,
    required String routeId,
    required String fromStatus,
    required String toStatus,
    double? latitude,
    double? longitude,
    String? proofImageUrl,
    String? notes,
    String? actorId,
  }) async {
    try {
      final db = FirebaseFirestore.instance;

      // 1. Update the task
      await db.collection('delivery_tasks').doc(taskId).update({
        'status': toStatus,
        'proof_image_url': proofImageUrl,
        'notes': notes,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 2. Insert event to ledger
      await db.collection('delivery_events').add({
        'route_id': routeId,
        'task_id': taskId,
        'from_status': fromStatus,
        'to_status': toStatus,
        'latitude': latitude,
        'longitude': longitude,
        'proof_image_url': proofImageUrl,
        'notes': notes,
        'actor_id': actorId,
        'created_at': FieldValue.serverTimestamp(),
      });

      // 3. Update route status dynamically based on current task states
      await _updateRouteStatusIfNeeded(routeId);

      return true;
    } catch (e) {
      debugPrint('[DeliveryLedger] Error updating task status: $e');
      return false;
    }
  }

  /// Internal helper to evaluate route status based on task states
  Future<void> _updateRouteStatusIfNeeded(String routeId) async {
    try {
      final db = FirebaseFirestore.instance;
      final tasks = await getRouteTasks(routeId);
      if (tasks.isEmpty) return;

      bool anyActive = false;
      bool allTerminal = true;

      for (final t in tasks) {
        final status = t['status'] as String;
        if (status == 'picked_up' || status == 'out_for_delivery') {
          anyActive = true;
        }
        if (status != 'delivered' && status != 'failed' && status != 'cancelled') {
          allTerminal = false;
        }
      }

      String newRouteStatus = 'assigned';
      if (allTerminal) {
        newRouteStatus = 'completed';
      } else if (anyActive) {
        newRouteStatus = 'active';
      }

      await db.collection('delivery_routes').doc(routeId).update({
        'status': newRouteStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[DeliveryLedger] Error updating route state: $e');
    }
  }
}
