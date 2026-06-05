import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';

class OfflineRoutingService {
  static const String _routeCacheKey = 'cached_optimized_route';

  /// Calculates the geographical distance between two points using the Haversine formula.
  /// Returns distance in kilometers.
  double calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// Solves the Traveling Salesperson Problem (TSP) using a greedy nearest-neighbor heuristic.
  List<OrderModel> optimizeRouteGreedy(
    List<OrderModel> orders,
    double startLat,
    double startLon,
  ) {
    if (orders.isEmpty) return [];

    final List<OrderModel> unvisited = List.from(orders);
    final List<OrderModel> optimizedRoute = [];

    double currentLat = startLat;
    double currentLon = startLon;

    while (unvisited.isNotEmpty) {
      int nearestIndex = 0;
      double minDistance = double.infinity;

      for (int i = 0; i < unvisited.length; i++) {
        final double orderLat = unvisited[i].deliveryAddress.latitude;
        final double orderLon = unvisited[i].deliveryAddress.longitude;

        final double distance = calculateHaversineDistance(
          currentLat,
          currentLon,
          orderLat,
          orderLon,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearestIndex = i;
        }
      }

      final OrderModel nearestOrder = unvisited.removeAt(nearestIndex);
      optimizedRoute.add(nearestOrder);

      // Update current position to the recently visited waypoint
      currentLat = nearestOrder.deliveryAddress.latitude;
      currentLon = nearestOrder.deliveryAddress.longitude;
    }

    return optimizedRoute;
  }

  /// Solves the Traveling Salesperson Problem (TSP) exactly using the dynamic programming
  /// Held-Karp algorithm (O(2^N * N^2)). Suitable for N <= 15.
  List<OrderModel> _optimizeRouteHeldKarp(
    List<OrderModel> orders,
    double startLat,
    double startLon,
  ) {
    final int n = orders.length;
    final int numNodes = n + 1; // depot is index 0, orders are 1..n

    // 1. Build distance matrix
    final List<List<double>> dist = List.generate(numNodes, (_) => List.filled(numNodes, 0.0));
    
    // Distance to depot
    for (int i = 0; i < n; i++) {
      final double d = calculateHaversineDistance(
        startLat,
        startLon,
        orders[i].deliveryAddress.latitude,
        orders[i].deliveryAddress.longitude,
      );
      dist[0][i + 1] = d;
      dist[i + 1][0] = d;
    }

    // Distance between orders
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        final double d = calculateHaversineDistance(
          orders[i].deliveryAddress.latitude,
          orders[i].deliveryAddress.longitude,
          orders[j].deliveryAddress.latitude,
          orders[j].deliveryAddress.longitude,
        );
        dist[i + 1][j + 1] = d;
        dist[j + 1][i + 1] = d;
      }
    }

    // 2. DP Table
    // dp[mask][i] where mask represents subset of orders and i is ending node index
    final int numStates = 1 << n;
    final List<List<double>> dp = List.generate(numStates, (_) => List.filled(n, double.infinity));
    final List<List<int>> parent = List.generate(numStates, (_) => List.filled(n, -1));

    // Base cases: mask with single bit set
    for (int i = 0; i < n; i++) {
      dp[1 << i][i] = dist[0][i + 1];
    }

    // DP transitions
    for (int mask = 1; mask < numStates; mask++) {
      for (int i = 0; i < n; i++) {
        if ((mask & (1 << i)) == 0) continue;

        final double currentDist = dp[mask][i];
        if (currentDist == double.infinity) continue;

        for (int j = 0; j < n; j++) {
          if ((mask & (1 << j)) != 0) continue;

          final int nextMask = mask | (1 << j);
          final double newDist = currentDist + dist[i + 1][j + 1];
          if (newDist < dp[nextMask][j]) {
            dp[nextMask][j] = newDist;
            parent[nextMask][j] = i;
          }
        }
      }
    }

    // 3. Find ending node of optimal path
    final int fullMask = numStates - 1;
    double minTotalDist = double.infinity;
    int lastOrderIndex = -1;

    for (int i = 0; i < n; i++) {
      if (dp[fullMask][i] < minTotalDist) {
        minTotalDist = dp[fullMask][i];
        lastOrderIndex = i;
      }
    }

    if (lastOrderIndex == -1) {
      return optimizeRouteGreedy(orders, startLat, startLon);
    }

    // 4. Reconstruct path
    final List<int> orderPath = [];
    int currentMask = fullMask;
    int currentOrder = lastOrderIndex;

    while (currentOrder != -1) {
      orderPath.add(currentOrder);
      final int prevOrder = parent[currentMask][currentOrder];
      currentMask = currentMask ^ (1 << currentOrder);
      currentOrder = prevOrder;
    }

    final List<OrderModel> optimizedRoute = [];
    for (final idx in orderPath.reversed) {
      optimizedRoute.add(orders[idx]);
    }

    return optimizedRoute;
  }

  /// Solves the Traveling Salesperson Problem (TSP) using Held-Karp exact DP
  /// for small sets (N <= 15) and a greedy heuristic for larger sets.
  List<OrderModel> optimizeRoute(
    List<OrderModel> orders,
    double startLat,
    double startLon,
  ) {
    if (orders.isEmpty) return [];
    if (orders.length <= 15) {
      return _optimizeRouteHeldKarp(orders, startLat, startLon);
    } else {
      return optimizeRouteGreedy(orders, startLat, startLon);
    }
  }

  /// Caches the optimized route order IDs to local SharedPreferences.
  Future<void> cacheRoute(List<OrderModel> optimizedRoute) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> orderIds = optimizedRoute.map((o) => o.id).toList();
      await prefs.setStringList(_routeCacheKey, orderIds);
    } catch (e) {
      print('Failed to cache optimized route: $e');
    }
  }

  /// Gets cached order ID sequence.
  Future<List<String>> getCachedRouteIds() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_routeCacheKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Generates human-readable, step-by-step direction list for the optimized route.
  List<String> generateDirections(
    List<OrderModel> route,
    double startLat,
    double startLon,
  ) {
    final List<String> directions = [];
    if (route.isEmpty) return ['No active deliveries in the route.'];

    double prevLat = startLat;
    double prevLon = startLon;

    for (int i = 0; i < route.length; i++) {
      final order = route[i];
      final address = order.deliveryAddress;
      final double distance = calculateHaversineDistance(
        prevLat,
        prevLon,
        address.latitude,
        address.longitude,
      );

      final String locationName = address.label;
      final String villageOrStreet = address.street.isNotEmpty ? address.street : address.village;
      final String landmark = address.landmark.isNotEmpty ? ' near ${address.landmark}' : '';

      if (i == 0) {
        directions.add(
          '📍 Stop 1: Head to $locationName ($villageOrStreet$landmark). \n   Distance: ${distance.toStringAsFixed(1)} km from start.',
        );
      } else {
        directions.add(
          '📍 Stop ${i + 1}: Proceed to $locationName ($villageOrStreet$landmark). \n   Distance: ${distance.toStringAsFixed(1)} km from last stop.',
        );
      }

      prevLat = address.latitude;
      prevLon = address.longitude;
    }

    directions.add('✅ All deliveries completed. Return to home shop.');
    return directions;
  }

  /// Generates a Google Maps URL with multiple waypoints
  String getMapsMultiStopUrl(List<OrderModel> route, double startLat, double startLon) {
    if (route.isEmpty) return '';
    
    // Format: https://www.google.com/maps/dir/StartLat,StartLon/Stop1Lat,Stop1Lon/Stop2Lat,Stop2Lon/...
    final StringBuffer url = StringBuffer('https://www.google.com/maps/dir/');
    url.write('$startLat,$startLon/');
    
    for (var order in route) {
      url.write('${order.deliveryAddress.latitude},${order.deliveryAddress.longitude}/');
    }
    
    return url.toString();
  }
}
