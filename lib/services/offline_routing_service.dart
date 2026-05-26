import 'dart:convert';
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
  /// Starts at [startLat], [startLon] and returns a sorted copy of the orders list.
  List<OrderModel> optimizeRoute(
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
