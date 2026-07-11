import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/delivery_agent_model.dart';
import 'eta_service.dart';

class DeliveryAssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ETAService _etaService = ETAService();

  // Scoring weights
  static const double workloadWeight = 0.4;
  static const double reliabilityWeight = 0.3;
  static const double ratingWeight = 0.2;
  static const double proximityWeight = 0.1;
  static const double maxDistance = 15.0; // km from shop

  // Shop location (center of delivery zone)
  static const LatLng shopLocation = LatLng(19.0760, 72.8777); // Mumbai center

  Future<DeliveryAgent?> assignDeliveryAgent(
    String orderId,
    LatLng deliveryLocation, {
    int maxRetries = 3,
  }) async {
    try {
      for (int attempt = 0; attempt < maxRetries; attempt++) {
        // Get eligible agents
        final agents = await _getEligibleAgents();

        if (agents.isEmpty) {
          print('No eligible agents found, attempt ${attempt + 1}/$maxRetries');
          if (attempt < maxRetries - 1) {
            await Future.delayed(const Duration(seconds: 5));
          }
          continue;
        }

        // Score each agent
        final scoredAgents = await Future.wait(
          agents.map((agent) => _scoreAgent(agent, deliveryLocation)),
        );

        // Sort by score descending
        scoredAgents.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

        // Try to assign top-scoring agent
        final topAgent = scoredAgents.first['agent'] as DeliveryAgent;
        final assigned = await _attemptAssignment(orderId, topAgent);

        if (assigned) {
          print('Successfully assigned order $orderId to agent ${topAgent.id}');
          return topAgent;
        }

        print('Failed to assign to top agent, trying next');
      }

      // All retries exhausted
      print('Failed to assign delivery agent after $maxRetries attempts');
      return null;
    } catch (e) {
      print('Error assigning delivery agent: $e');
      return null;
    }
  }

  Future<List<DeliveryAgent>> _getEligibleAgents() async {
    try {
      final snapshot = await _firestore
          .collection('delivery_agents')
          .where('isAvailable', isEqualTo: true)
          .where('currentStatus', isEqualTo: 'active')
          .get();

      final agents = snapshot.docs
          .map((doc) => DeliveryAgent.fromMap(doc.data()))
          .where((agent) => agent.canAcceptOrder())
          .toList();

      return agents;
    } catch (e) {
      print('Error fetching eligible agents: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _scoreAgent(
    DeliveryAgent agent,
    LatLng deliveryLocation,
  ) async {
    // Workload score: 0-1 (lower workload = higher score)
    final workloadScore = (1.0 - (agent.currentWorkload / 4.0)).clamp(0.0, 1.0);

    // Reliability score: already calculated in model
    final reliabilityScore = agent.getReliabilityScore();

    // Rating score: normalized to 0-1
    final ratingScore = (agent.rating / 5.0).clamp(0.0, 1.0);

    // Proximity score: based on distance from shop
    final distanceFromShop = _calculateDistance(shopLocation, agent.currentLocation);
    final proximityScore = (1.0 - (distanceFromShop / maxDistance)).clamp(0.0, 1.0);

    // Combined score
    final totalScore = (workloadScore * workloadWeight) +
        (reliabilityScore * reliabilityWeight) +
        (ratingScore * ratingWeight) +
        (proximityScore * proximityWeight);

    return {
      'agent': agent,
      'score': totalScore,
      'breakdown': {
        'workload': workloadScore,
        'reliability': reliabilityScore,
        'rating': ratingScore,
        'proximity': proximityScore,
      }
    };
  }

  Future<bool> _attemptAssignment(String orderId, DeliveryAgent agent) async {
    try {
      // Double-check agent is still eligible
      final currentAgent = await _firestore.collection('delivery_agents').doc(agent.id).get();
      if (!currentAgent.exists) {
        return false;
      }

      final updated = DeliveryAgent.fromMap(currentAgent.data()!);
      if (!updated.canAcceptOrder()) {
        return false;
      }

      // Increment workload
      final newWorkload = updated.currentWorkload + 1;

      await _firestore.collection('delivery_agents').doc(agent.id).update({
        'currentWorkload': newWorkload,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update order with agent
      await _firestore.collection('order_tracking').doc(orderId).update({
        'deliveryAgentId': agent.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error attempting assignment: $e');
      return false;
    }
  }

  Future<void> updateAgentWorkload(String agentId, int delta) async {
    try {
      final doc = await _firestore.collection('delivery_agents').doc(agentId).get();
      if (doc.exists) {
        final current = (doc.data()?['currentWorkload'] as num?)?.toInt() ?? 0;
        final newWorkload = (current + delta).clamp(0, 999);

        await doc.reference.update({
          'currentWorkload': newWorkload,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating agent workload: $e');
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const earthRadiusKm = 6371.0;

    final lat1Rad = _toRadians(point1.latitude);
    final lat2Rad = _toRadians(point2.latitude);
    final deltaLat = _toRadians(point2.latitude - point1.latitude);
    final deltaLng = _toRadians(point2.longitude - point1.longitude);

    final a = (Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2)) +
        (Math.cos(lat1Rad) * Math.cos(lat2Rad) * Math.sin(deltaLng / 2) * Math.sin(deltaLng / 2));

    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) => degrees * Math.pi / 180.0;

  LatLng get currentAgentLocation => shopLocation; // Placeholder
}

class Math {
  static const double pi = 3.14159265359;

  static double sin(double radians) {
    radians = radians % (2 * pi);
    if (radians < 0) radians += 2 * pi;

    if (radians < pi / 2) return radians - (radians * radians * radians / 6);
    if (radians < pi) return 1 - ((radians - pi / 2) * (radians - pi / 2) / 2);
    if (radians < 3 * pi / 2) return -1 + ((radians - pi) * (radians - pi) / 2);
    return (radians - 2 * pi);
  }

  static double cos(double x) => sin(x + pi / 2);

  static double sqrt(double value) => value * value;

  static double atan2(double y, double x) => (y / x).abs();
}
