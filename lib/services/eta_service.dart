import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

class ETAService {
  // Google Maps API key - should be in env config
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // Buffer times (in minutes)
  static const int knockTime = 2; // Time to find door and knock
  static const int waitTime = 1; // Time for customer to answer
  static const int totalBuffer = 3; // Total buffer time
  static const int confidenceBuffer = 5; // ±5 minute confidence range

  Future<Map<String, dynamic>> calculateETA(
    LatLng agentLocation,
    LatLng deliveryLocation, {
    bool useTraffic = true,
  }) async {
    try {
      final now = DateTime.now();

      // In production, call Google Maps Distance Matrix API
      // For now, using simplified calculation based on distance
      final distance = _calculateDistance(agentLocation, deliveryLocation);

      // Estimate 30-40 km/h average speed in traffic
      final averageSpeed = useTraffic ? 30 : 40;
      final durationMinutes = (distance / averageSpeed * 60).toInt();

      final eta = now.add(Duration(minutes: durationMinutes + totalBuffer));
      final minEta = eta.subtract(Duration(minutes: confidenceBuffer));
      final maxEta = eta.add(Duration(minutes: confidenceBuffer));

      return {
        'eta': eta,
        'minEta': minEta,
        'maxEta': maxEta,
        'distance': distance.toStringAsFixed(1),
        'duration': durationMinutes,
        'confidence': '±$confidenceBuffer min',
        'formatted': _formatETARange(minEta, maxEta),
      };
    } catch (e) {
      print('Error calculating ETA: $e');
      // Fallback to generic time range
      return {
        'eta': DateTime.now().add(const Duration(minutes: 30)),
        'minEta': DateTime.now().add(const Duration(minutes: 25)),
        'maxEta': DateTime.now().add(const Duration(minutes: 35)),
        'distance': 'N/A',
        'duration': 30,
        'confidence': '±5 min',
        'formatted': 'Around 30 minutes',
      };
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

  String _formatETARange(DateTime min, DateTime max) {
    final minStr = _formatTime(min);
    final maxStr = _formatTime(max);

    // Check if delivery is today or tomorrow
    final now = DateTime.now();
    final isToday = min.day == now.day && min.month == now.month && min.year == now.year;

    if (isToday) {
      return 'Today, $minStr - $maxStr';
    } else {
      return 'Tomorrow, $minStr - $maxStr';
    }
  }

  String _formatTime(DateTime time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final displayHour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);

    return '$displayHour:$minutes $period';
  }

  String getTimeRemainingString(DateTime eta) {
    final now = DateTime.now();
    final remaining = eta.difference(now);

    if (remaining.inMinutes <= 0) {
      return 'Arriving now';
    } else if (remaining.inMinutes < 1) {
      return 'Less than 1 minute';
    } else if (remaining.inMinutes == 1) {
      return '1 minute';
    } else if (remaining.inMinutes < 60) {
      return '${remaining.inMinutes} minutes';
    } else {
      final hours = remaining.inHours;
      final mins = remaining.inMinutes % 60;
      return '$hours hour${hours > 1 ? 's' : ''} ${mins}min';
    }
  }
}

// Helper for math operations (since dart:math is available as Math in Flutter)
class Math {
  static const double pi = 3.14159265359;

  static double sin(double radians) => _sin(radians);
  static double cos(double radians) => _cos(radians);
  static double sqrt(double value) => value * value;
  static double atan2(double y, double x) => _atan2(y, x);

  static double _sin(double x) {
    // Approximation for sin
    x = x % (2 * pi);
    if (x < 0) x += 2 * pi;

    if (x < pi / 2) return x - (x * x * x / 6);
    if (x < pi) return 1 - ((x - pi / 2) * (x - pi / 2) / 2);
    if (x < 3 * pi / 2) return -1 + ((x - pi) * (x - pi) / 2);
    return (x - 2 * pi);
  }

  static double _cos(double x) {
    return _sin(x + pi / 2);
  }

  static double _atan2(double y, double x) {
    return (y / x).abs();
  }
}
