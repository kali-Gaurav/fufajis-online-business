import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import 'offline_routing_service.dart';
import '../constants/order_status.dart';

/// A logical grouping of nearby delivery orders
class DeliveryCluster {
  final String id;
  final List<OrderModel> orders;
  final double centerLat;
  final double centerLng;
  final double totalDistanceKm;
  final Duration estimatedTime;

  const DeliveryCluster({
    required this.id,
    required this.orders,
    required this.centerLat,
    required this.centerLng,
    required this.totalDistanceKm,
    required this.estimatedTime,
  });

  int get orderCount => orders.length;

  /// Label based on approximate area relative to cluster centre
  String get areaLabel {
    if (orders.isEmpty) return 'Unknown Area';
    final addr = orders.first.deliveryAddress;
    final parts = <String>[];
    if (addr.landmark.isNotEmpty) parts.add(addr.landmark);
    if (addr.village.isNotEmpty) parts.add(addr.village);
    if (parts.isEmpty && addr.fullAddress.isNotEmpty) {
      parts.add(addr.fullAddress.split(',').first.trim());
    }
    return parts.take(2).join(', ');
  }

  double get codTotal => orders.fold(0.0, (sum, o) => sum + o.totalAmount.toDouble());

  /// Earnings estimate for delivery agent (₹15 per order)
  double get agentEarnings => orders.length * 15.0;
}

/// Core service: clusters pending orders and optimises delivery routes.
class DeliveryClusteringService {
  static const double shopLat = 25.1006;
  static const double shopLng = 76.5156;
  static const double clusterRadiusKm = 1.5;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Groups a flat list of orders into geographic and weight-aware clusters.
  ///
  /// Uses Greedy Clustering + Weight Constraint (from FastAPI backend logic)
  List<DeliveryCluster> clusterOrders(List<OrderModel> orders, {double maxWeightKg = 25.0}) {
    if (orders.isEmpty) return [];

    // Separate located and unlocated orders
    final located = orders.where(_hasLocation).toList();
    final unlocated = orders.where((o) => !_hasLocation(o)).toList();

    final clusters = <DeliveryCluster>[];

    // Simple greedy clustering: pick an unclustered order, sweep all others
    // within clusterRadiusKm from its centre, respecting maxWeightKg.
    final assigned = <String>{};
    int clusterIndex = 0;

    for (final seed in located) {
      if (assigned.contains(seed.id)) continue;

      final seedLat = _lat(seed);
      final seedLng = _lng(seed);

      final List<OrderModel> group = [];
      double currentWeight = 0.0;

      for (final o in located) {
        if (assigned.contains(o.id)) continue;

        final d = _distanceBetween(seedLat, seedLng, _lat(o), _lng(o));
        final orderWeight = _estimateOrderWeight(o);

        if (d <= clusterRadiusKm && (currentWeight + orderWeight) <= maxWeightKg) {
          group.add(o);
          assigned.add(o.id);
          currentWeight += orderWeight;
        }
      }

      if (group.isNotEmpty) {
        final optimised = optimizeRoute(group);
        final centre = _computeCentre(group);
        final totalDist = _routeDistance(optimised);

        clusters.add(
          DeliveryCluster(
            id: 'cluster_${++clusterIndex}',
            orders: optimised,
            centerLat: centre.$1,
            centerLng: centre.$2,
            totalDistanceKm: totalDist,
            estimatedTime: estimateClusterTime(
              DeliveryCluster(
                id: '',
                orders: optimised,
                centerLat: centre.$1,
                centerLng: centre.$2,
                totalDistanceKm: totalDist,
                estimatedTime: Duration.zero,
              ),
            ),
          ),
        );
      }
    }

    // Unlocated orders form their own clusters (respecting weight)
    for (final o in unlocated) {
      if (assigned.contains(o.id)) continue;

      clusters.add(
        DeliveryCluster(
          id: 'cluster_${++clusterIndex}_unloc',
          orders: [o],
          centerLat: shopLat,
          centerLng: shopLng,
          totalDistanceKm: 0,
          estimatedTime: const Duration(minutes: 15),
        ),
      );
    }

    return clusters;
  }

  double _estimateOrderWeight(OrderModel o) {
    // Basic heuristic: count items * 0.5kg if weight not explicitly set
    // Or use the weight fields if available in OrderModel/OrderItem
    double weight = 0.0;
    for (var item in o.items) {
      // In a real system, we'd pull from product metadata.
      // For now, heuristic fallback.
      weight += (item.quantity * 0.5);
    }
    return weight;
  }

  /// Returns orders sorted by nearest-neighbour heuristic starting from shop.
  List<OrderModel> optimizeRoute(List<OrderModel> orders) {
    if (orders.isEmpty) return [];
    return OfflineRoutingService().optimizeRoute(orders, shopLat, shopLng);
  }

  /// Estimates total time for a cluster:
  ///   • 3 min / km travel  +  7 min per stop
  Duration estimateClusterTime(DeliveryCluster cluster) {
    final travelMinutes = (cluster.totalDistanceKm * 3).round();
    final stopMinutes = cluster.orders.length * 7;
    return Duration(minutes: travelMinutes + stopMinutes);
  }

  /// Returns true if the customer has ≥5 successful past deliveries.
  Future<bool> isOtplessEligible(String customerId) async {
    try {
      final snap = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .where('status', isEqualTo: OrderStatus.delivered.toString())
          .count()
          .get();
      return (snap.count ?? 0) >= 5;
    } catch (_) {
      return false;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Haversine distance in kilometres between two lat/lng points.
  double _distanceBetween(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0; // Earth radius km
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  bool _hasLocation(OrderModel o) =>
      o.deliveryAddress.latitude != 0.0 || o.deliveryAddress.longitude != 0.0;

  double _lat(OrderModel o) => o.deliveryAddress.latitude;
  double _lng(OrderModel o) => o.deliveryAddress.longitude;

  (double, double) _computeCentre(List<OrderModel> orders) {
    if (orders.isEmpty) return (shopLat, shopLng);
    final avgLat = orders.map(_lat).reduce((a, b) => a + b) / orders.length;
    final avgLng = orders.map(_lng).reduce((a, b) => a + b) / orders.length;
    return (avgLat, avgLng);
  }

  /// Total route distance from shop → stop1 → stop2 … → last stop.
  double _routeDistance(List<OrderModel> orders) {
    if (orders.isEmpty) return 0;
    double total = _distanceBetween(shopLat, shopLng, _lat(orders.first), _lng(orders.first));
    for (int i = 0; i < orders.length - 1; i++) {
      total += _distanceBetween(
        _lat(orders[i]),
        _lng(orders[i]),
        _lat(orders[i + 1]),
        _lng(orders[i + 1]),
      );
    }
    return total;
  }
}
