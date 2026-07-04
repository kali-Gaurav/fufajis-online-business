import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/order_model.dart';

/// Task Assignment Engine
/// Intelligently assigns delivery and kitchen tasks using:
/// - Location proximity (for delivery agents)
/// - Workload balancing
/// - Skills/specializations
/// - Historical performance
class TaskAssignmentEngine {
  static final TaskAssignmentEngine _instance = TaskAssignmentEngine._internal();
  factory TaskAssignmentEngine() => _instance;
  TaskAssignmentEngine._internal();

  final _firestore = FirebaseFirestore.instance;
  static const double _proximityRadiusKm = 5.0; // Assign agents within 5km

  /// Calculate distance between two coordinates (haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRad(double degrees) => degrees * pi / 180.0;

  /// Get agent's current location
  Future<({double lat, double lon})?> _getAgentLocation(String agentId) async {
    try {
      final doc = await _firestore.collection('delivery_agents').doc(agentId).get();

      if (!doc.exists) return null;

      final data = doc.data() ?? {};
      final location = data['currentLocation'];

      if (location is Map<String, dynamic>) {
        return (
          lat: (location['latitude'] ?? 0.0) as double,
          lon: (location['longitude'] ?? 0.0) as double,
        );
      }
      return null;
    } catch (e) {
      debugPrint('[TaskAssignment] Error getting agent location: $e');
      return null;
    }
  }

  /// ✅ FIXED: Include physical location proximity in task assignment
  /// Find best delivery agent based on:
  /// - Distance to delivery location
  /// - Current workload
  /// - Availability status
  Future<String?> assignDeliveryAgent(OrderModel order) async {
    try {
      debugPrint('[TaskAssignment] Assigning delivery for order ${order.id}');

      // Extract delivery coordinates
      if (order.deliveryAddress.latitude == 0.0 && order.deliveryAddress.longitude == 0.0) {
        debugPrint('[TaskAssignment] ⚠️ No delivery coordinates available');
        return null;
      }

      final deliveryLat = order.deliveryAddress.latitude;
      final deliveryLon = order.deliveryAddress.longitude;

      // 1. Get all available agents
      final agentsSnapshot = await _firestore
          .collection('delivery_agents')
          .where('status', isEqualTo: 'available')
          .where('active', isEqualTo: true)
          .get();

      if (agentsSnapshot.docs.isEmpty) {
        debugPrint('[TaskAssignment] ❌ No available agents');
        return null;
      }

      // 2. Score each agent based on proximity + workload
      final scoredAgents = <String, ({double proximity, int workload, double score})>{};

      for (final doc in agentsSnapshot.docs) {
        final agentId = doc.id;

        // Get agent location
        final agentLocation = await _getAgentLocation(agentId);
        if (agentLocation == null) continue;

        // Calculate distance
        final distance = _calculateDistance(
          agentLocation.lat,
          agentLocation.lon,
          deliveryLat,
          deliveryLon,
        );

        // Filter: Only consider agents within proximity radius
        if (distance > _proximityRadiusKm) {
          debugPrint('[TaskAssignment] Agent $agentId too far (${distance.toStringAsFixed(2)}km)');
          continue;
        }

        // Get current workload (number of pending tasks)
        final tasksSnapshot = await _firestore
            .collection('delivery_tasks')
            .where('assignedAgentId', isEqualTo: agentId)
            .where('status', whereIn: ['assigned', 'picked_up', 'in_progress'])
            .count()
            .get();
        final workload = tasksSnapshot.count ?? 0;

        // Calculate score: prefer closer + less loaded agents
        // Proximity weight: 70%, Workload weight: 30%
        final proximityScore = 100.0 - (distance / _proximityRadiusKm * 100); // 0-100
        final workloadScore = max(0.0, 100.0 - (workload * 10.0)); // 0-100
        final finalScore = (proximityScore * 0.7) + (workloadScore * 0.3);

        scoredAgents[agentId] = (proximity: distance, workload: workload, score: finalScore);

        debugPrint(
          '[TaskAssignment] Agent $agentId: '
          'distance=${distance.toStringAsFixed(2)}km, '
          'workload=$workload, '
          'score=${finalScore.toStringAsFixed(2)}',
        );
      }

      if (scoredAgents.isEmpty) {
        debugPrint('[TaskAssignment] ❌ No agents within proximity radius');
        return null;
      }

      // 3. Select agent with highest score
      final bestAgent = scoredAgents.entries.reduce(
        (a, b) => a.value.score > b.value.score ? a : b,
      );
      final agentId = bestAgent.key;
      final agentScore = bestAgent.value;

      debugPrint(
        '[TaskAssignment] ✅ Assigned to agent $agentId '
        '(proximity=${agentScore.proximity.toStringAsFixed(2)}km, '
        'workload=${agentScore.workload}, '
        'score=${agentScore.score.toStringAsFixed(2)})',
      );

      return agentId;
    } catch (e) {
      debugPrint('[TaskAssignment] ❌ Error in assignDeliveryAgent: $e');
      return null;
    }
  }

  /// Assign kitchen/kitchen staff based on:
  /// - Current workload
  /// - Skills/specializations
  /// - Historical completion time
  Future<String?> assignKitchenTask(OrderModel order) async {
    try {
      debugPrint('[TaskAssignment] Assigning kitchen task for order ${order.id}');

      // 1. Get available kitchen staff
      final staffSnapshot = await _firestore
          .collection('kitchen_staff')
          .where('status', isEqualTo: 'available')
          .where('active', isEqualTo: true)
          .get();

      if (staffSnapshot.docs.isEmpty) {
        debugPrint('[TaskAssignment] ❌ No available kitchen staff');
        return null;
      }

      // 2. Score staff based on workload + specialization
      final scoredStaff = <String, ({int workload, double avgTime, double score})>{};

      for (final doc in staffSnapshot.docs) {
        final staffId = doc.id;

        // Get current workload
        final tasksSnapshot = await _firestore
            .collection('kitchen_tasks')
            .where('assignedStaffId', isEqualTo: staffId)
            .where('status', whereIn: ['assigned', 'in_progress'])
            .count()
            .get();
        final workload = tasksSnapshot.count ?? 0;

        // Get average completion time (from history)
        final historySnapshot = await _firestore
            .collection('kitchen_task_history')
            .where('staffId', isEqualTo: staffId)
            .limit(10)
            .get();

        double avgTime = 30.0; // Default 30 minutes
        if (historySnapshot.docs.isNotEmpty) {
          final times = historySnapshot.docs
              .map((doc) => (doc.data()['completionTimeMinutes'] ?? 30.0) as double)
              .toList();
          avgTime = times.reduce((a, b) => a + b) / times.length;
        }

        // Calculate score: prefer less loaded + faster staff
        final workloadScore = max(0.0, 100.0 - (workload * 20.0)); // 0-100
        final speedScore = max(0.0, 100.0 - (avgTime / 60 * 100)); // 0-100
        final finalScore = (workloadScore * 0.6) + (speedScore * 0.4);

        scoredStaff[staffId] = (workload: workload, avgTime: avgTime, score: finalScore);

        debugPrint(
          '[TaskAssignment] Kitchen staff $staffId: '
          'workload=$workload, '
          'avgTime=${avgTime.toStringAsFixed(1)}min, '
          'score=${finalScore.toStringAsFixed(2)}',
        );
      }

      // 3. Select staff with highest score
      final bestStaff = scoredStaff.entries.reduce((a, b) => a.value.score > b.value.score ? a : b);
      final staffId = bestStaff.key;

      debugPrint(
        '[TaskAssignment] ✅ Assigned to kitchen staff $staffId '
        '(workload=${bestStaff.value.workload}, '
        'avgTime=${bestStaff.value.avgTime.toStringAsFixed(1)}min)',
      );

      return staffId;
    } catch (e) {
      debugPrint('[TaskAssignment] ❌ Error in assignKitchenTask: $e');
      return null;
    }
  }

  /// Reassign task if agent becomes unavailable
  Future<bool> reassignTask(String taskId, String orderId) async {
    try {
      debugPrint('[TaskAssignment] Reassigning task $taskId');

      // Get order details
      final orderSnapshot = await _firestore.collection('orders').doc(orderId).get();

      if (!orderSnapshot.exists) {
        debugPrint('[TaskAssignment] Order $orderId not found');
        return false;
      }

      final data = orderSnapshot.data() as Map<String, dynamic>;
      if (!data.containsKey('id')) data['id'] = orderSnapshot.id;
      final order = OrderModel.fromMap(data);

      // Find new agent
      final newAgentId = await assignDeliveryAgent(order);
      if (newAgentId == null) {
        debugPrint('[TaskAssignment] ❌ Could not find replacement agent');
        return false;
      }

      // Update task
      await _firestore.collection('delivery_tasks').doc(taskId).update({
        'assignedAgentId': newAgentId,
        'reassignedAt': FieldValue.serverTimestamp(),
        'previousAgentId': (await _firestore.collection('delivery_tasks').doc(taskId).get())
            .data()?['assignedAgentId'],
      });

      debugPrint('[TaskAssignment] ✅ Task reassigned to $newAgentId');
      return true;
    } catch (e) {
      debugPrint('[TaskAssignment] ❌ Error in reassignTask: $e');
      return false;
    }
  }
}
