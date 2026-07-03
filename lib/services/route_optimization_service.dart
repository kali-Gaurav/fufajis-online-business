import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/app_config.dart';

/// Delivery Agent Route Optimization Service
///
/// Algorithm stack:
/// 1. Nearest-Neighbour greedy heuristic (O(n²)) — instant local result
/// 2. Google Directions API waypoint optimization — cloud-optimized result
/// 3. 2-opt improvement pass — refines the greedy result when API unavailable
///
/// Usage:
///   final optimized = await RouteOptimizationService().getOptimizedRoute(
///     origin: riderLocation,
///     destinations: deliveryPoints,
///   );
class RouteOptimizationService {
  static final RouteOptimizationService _instance = RouteOptimizationService._internal();
  factory RouteOptimizationService() => _instance;
  RouteOptimizationService._internal();

  final Dio _dio = Dio();

  static String get _apiKey {
    return AppConfig.googleMapsKey;
  }

  /// Returns optimized ordered list of waypoints.
  /// Falls back to Nearest-Neighbour + 2-opt if no API key.
  Future<RouteResult> getOptimizedRoute({
    required LatLng origin,
    required List<DeliveryWaypoint> destinations,
  }) async {
    if (destinations.isEmpty) {
      return const RouteResult(orderedWaypoints: [], estimatedMinutes: 0, totalDistanceKm: 0);
    }
    if (destinations.length == 1) {
      return RouteResult(
        orderedWaypoints: destinations,
        estimatedMinutes: _estimateMinutes(origin, destinations[0].location),
        totalDistanceKm: _haversineKm(origin, destinations[0].location),
      );
    }

    // Try Google Directions API first (cloud-optimized TSP)
    if (_apiKey.isNotEmpty) {
      try {
        return await _googleOptimizedRoute(origin: origin, destinations: destinations);
      } catch (e) {
        debugPrint('[RouteOpt] Google API failed, falling back to greedy TSP: $e');
      }
    }

    // Fallback: Nearest-Neighbour + 2-opt
    return _localOptimize(origin: origin, destinations: destinations);
  }

  // ─── Google Directions API (waypoint optimization) ───────────────────────────
  Future<RouteResult> _googleOptimizedRoute({
    required LatLng origin,
    required List<DeliveryWaypoint> destinations,
  }) async {
    final String originStr = '${origin.latitude},${origin.longitude}';
    final String destStr =
        '${destinations.last.location.latitude},${destinations.last.location.longitude}';

    // Build intermediate waypoints
    final waypoints = destinations
        .take(destinations.length - 1)
        .map((d) => '${d.location.latitude},${d.location.longitude}')
        .join('|');

    const url = 'https://maps.googleapis.com/maps/api/directions/json';
    final resp = await _dio.get(
      url,
      queryParameters: {
        'origin': originStr,
        'destination': destStr,
        'waypoints': 'optimize:true|$waypoints',
        'key': _apiKey,
      },
    );

    final data = resp.data as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      throw Exception('Directions API: ${data['status']}');
    }

    final route = (data['routes'] as List).first as Map<String, dynamic>;
    final waypointOrder = (route['waypoint_order'] as List).map((e) => e as int).toList();

    // Reorder destinations as Google suggests
    final reordered = <DeliveryWaypoint>[];
    for (final idx in waypointOrder) {
      if (idx < destinations.length - 1) reordered.add(destinations[idx]);
    }
    reordered.add(destinations.last); // final destination stays last

    // Extract duration & distance
    final legs = (route['legs'] as List).cast<Map<String, dynamic>>();
    final totalMinutes = legs.fold<int>(
      0,
      (sum, leg) => sum + ((leg['duration']['value'] as int) ~/ 60),
    );
    final totalMeters = legs.fold<int>(0, (sum, leg) => sum + (leg['distance']['value'] as int));

    return RouteResult(
      orderedWaypoints: reordered,
      estimatedMinutes: totalMinutes,
      totalDistanceKm: totalMeters / 1000,
      polylinePoints: _extractPolyline(route),
    );
  }

  List<LatLng> _extractPolyline(Map<String, dynamic> route) {
    final encoded = route['overview_polyline']['points'] as String;
    return _decodePolyline(encoded);
  }

  // ─── Local Nearest-Neighbour + 2-opt ─────────────────────────────────────────
  RouteResult _localOptimize({
    required LatLng origin,
    required List<DeliveryWaypoint> destinations,
  }) {
    // Nearest-Neighbour greedy
    final unvisited = List<DeliveryWaypoint>.from(destinations);
    final ordered = <DeliveryWaypoint>[];
    LatLng current = origin;

    while (unvisited.isNotEmpty) {
      DeliveryWaypoint nearest = unvisited.first;
      double minDist = _haversineKm(current, nearest.location);

      for (final wp in unvisited.skip(1)) {
        final d = _haversineKm(current, wp.location);
        if (d < minDist) {
          minDist = d;
          nearest = wp;
        }
      }
      ordered.add(nearest);
      unvisited.remove(nearest);
      current = nearest.location;
    }

    // 2-opt improvement
    final improved = _twoOpt(origin, ordered);

    // Estimate totals
    double totalKm = _haversineKm(origin, improved.first.location);
    for (int i = 0; i < improved.length - 1; i++) {
      totalKm += _haversineKm(improved[i].location, improved[i + 1].location);
    }

    return RouteResult(
      orderedWaypoints: improved,
      estimatedMinutes: (totalKm / 25 * 60).round(), // assume avg 25 km/h urban
      totalDistanceKm: totalKm,
    );
  }

  List<DeliveryWaypoint> _twoOpt(LatLng origin, List<DeliveryWaypoint> route) {
    var best = List<DeliveryWaypoint>.from(route);
    bool improved = true;
    while (improved) {
      improved = false;
      for (int i = 0; i < best.length - 1; i++) {
        for (int j = i + 2; j < best.length; j++) {
          final newRoute = [
            ...best.sublist(0, i + 1),
            ...best.sublist(i + 1, j + 1).reversed,
            ...best.sublist(j + 1),
          ];
          if (_routeLength(origin, newRoute) < _routeLength(origin, best)) {
            best = newRoute;
            improved = true;
          }
        }
      }
    }
    return best;
  }

  double _routeLength(LatLng origin, List<DeliveryWaypoint> route) {
    if (route.isEmpty) return 0;
    double total = _haversineKm(origin, route.first.location);
    for (int i = 0; i < route.length - 1; i++) {
      total += _haversineKm(route[i].location, route[i + 1].location);
    }
    return total;
  }

  // ─── Haversine distance ───────────────────────────────────────────────────────
  double _haversineKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final sinLat = sin(dLat / 2);
    final sinLon = sin(dLon / 2);
    final h = sinLat * sinLat + cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) * sinLon * sinLon;
    return 2 * R * asin(sqrt(h));
  }

  double _toRad(double deg) => deg * pi / 180;

  int _estimateMinutes(LatLng a, LatLng b) => (_haversineKm(a, b) / 25 * 60).round();

  // ─── Google Polyline decoder ──────────────────────────────────────────────────
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0;
    int lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lat += dLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lng += dLng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────
class DeliveryWaypoint {
  final String orderId;
  final String customerName;
  final LatLng location;
  final String address;
  final double? codAmount;
  final bool requiresOtp;

  const DeliveryWaypoint({
    required this.orderId,
    required this.customerName,
    required this.location,
    required this.address,
    this.codAmount,
    this.requiresOtp = true,
  });
}

class RouteResult {
  final List<DeliveryWaypoint> orderedWaypoints;
  final int estimatedMinutes;
  final double totalDistanceKm;
  final List<LatLng> polylinePoints;

  const RouteResult({
    required this.orderedWaypoints,
    required this.estimatedMinutes,
    required this.totalDistanceKm,
    this.polylinePoints = const [],
  });
}
