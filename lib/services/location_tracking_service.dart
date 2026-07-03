import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../models/delivery_location_model.dart';
import 'sqlite_service.dart';
import 'offline_sync_service.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  final Map<String, StreamSubscription> _activeTracking = {};
  final Map<String, List<DeliveryLocationModel>> _locationHistory = {};

  /// Start continuous location tracking for a delivery
  Future<void> startTracking({
    required String deliveryId,
    required Function(double lat, double lng) onLocationUpdate,
    int updateIntervalSeconds = 30,
  }) async {
    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      // Check if already tracking
      if (_activeTracking.containsKey(deliveryId)) {
        debugPrint('Already tracking delivery: $deliveryId');
        return;
      }

      Position? lastPos;

      // Start periodic location updates
      final subscription =
          Geolocator.getPositionStream(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 10, // Only update if moved 10+ meters
              timeLimit: Duration(seconds: updateIntervalSeconds),
            ),
          ).listen(
            (Position position) async {
              // GPS Spoofing check 1: Android mock check
              if (position.isMocked) {
                debugPrint(
                  '[LocationTracking] Rejecting spoofed/mocked GPS coordinate (isMocked = true).',
                );
                return;
              }

              // GPS Spoofing check 2: Velocity check
              if (lastPos != null) {
                final double dist = Geolocator.distanceBetween(
                  lastPos!.latitude,
                  lastPos!.longitude,
                  position.latitude,
                  position.longitude,
                );
                final double timeDiffSeconds = position.timestamp
                    .difference(lastPos!.timestamp)
                    .inSeconds
                    .toDouble();
                if (timeDiffSeconds > 0) {
                  final double speedMps = dist / timeDiffSeconds;
                  if (speedMps > 45.0) {
                    // Velocity limit of ~162 km/h
                    debugPrint(
                      '[LocationTracking] Rejecting suspicious coordinates: Velocity spike detected ($speedMps m/s).',
                    );
                    return;
                  }
                }
              }

              lastPos = position;

              // Store location history
              final location = DeliveryLocationModel(
                locationId: '${deliveryId}_${DateTime.now().millisecondsSinceEpoch}',
                deliveryId: deliveryId,
                latitude: position.latitude,
                longitude: position.longitude,
                timestamp: DateTime.now(),
                accuracy: position.accuracy,
                speed: position.speed,
              );

              _locationHistory.update(deliveryId, (list) {
                list.add(location);
                // Keep last 500 locations to avoid memory bloat
                if (list.length > 500) {
                  list.removeAt(0);
                }
                return list;
              }, ifAbsent: () => [location]);

              // Caching location if offline
              final bool online = OfflineSyncService().isOnline.value;
              if (online) {
                onLocationUpdate(position.latitude, position.longitude);
              } else {
                debugPrint('[LocationTracking] Offline: Caching location path in SQLite.');
                try {
                  await SqliteService().saveRiderLocation({
                    'deliveryId': deliveryId,
                    'latitude': position.latitude,
                    'longitude': position.longitude,
                    'speed': position.speed,
                    'accuracy': position.accuracy,
                    'timestamp': position.timestamp.millisecondsSinceEpoch,
                  });
                } catch (e) {
                  debugPrint('[LocationTracking] Failed to write offline location: $e');
                }
              }

              debugPrint(
                'Location update: $deliveryId - Lat: ${position.latitude}, Lng: ${position.longitude}, Acc: ${position.accuracy}m',
              );
            },
            onError: (error) {
              debugPrint('Location tracking error for $deliveryId: $error');
            },
          );

      _activeTracking[deliveryId] = subscription;
      debugPrint('Started tracking delivery: $deliveryId');
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
      rethrow;
    }
  }

  /// Stop tracking a specific delivery
  Future<void> stopTracking(String deliveryId) async {
    try {
      _activeTracking[deliveryId]?.cancel();
      _activeTracking.remove(deliveryId);
      debugPrint('Stopped tracking delivery: $deliveryId');
    } catch (e) {
      debugPrint('Error stopping location tracking: $e');
    }
  }

  /// Stop all tracking
  Future<void> stopAllTracking() async {
    try {
      for (final subscription in _activeTracking.values) {
        await subscription.cancel();
      }
      _activeTracking.clear();
      debugPrint('Stopped all location tracking');
    } catch (e) {
      debugPrint('Error stopping all tracking: $e');
    }
  }

  /// Get current location (one-time fetch)
  Future<LatLng?> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 10));

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  /// Calculate ETA to destination using Haversine formula
  /// Note: In production, use Google Maps Distance Matrix API
  Future<int> calculateETA({
    required double currentLat,
    required double currentLng,
    required double destLat,
    required double destLng,
    double avgSpeedKmh = 30.0, // Default 30 km/h in city traffic
  }) async {
    try {
      final distance = _calculateDistance(currentLat, currentLng, destLat, destLng);

      // Calculate ETA in minutes
      final etaMinutes = (distance / avgSpeedKmh * 60).ceil();
      return etaMinutes;
    } catch (e) {
      debugPrint('Error calculating ETA: $e');
      return 0;
    }
  }

  /// Get location history for a delivery
  List<DeliveryLocationModel> getLocationHistory(String deliveryId) {
    return _locationHistory[deliveryId] ?? [];
  }

  /// Clear location history for a delivery
  void clearLocationHistory(String deliveryId) {
    _locationHistory.remove(deliveryId);
  }

  /// Check if agent is near delivery address
  bool isNearAddress({
    required double currentLat,
    required double currentLng,
    required double destLat,
    required double destLng,
    double radiusMeters = 500,
  }) {
    final distance = _calculateDistance(currentLat, currentLng, destLat, destLng);
    final distanceInMeters = distance * 1000;
    return distanceInMeters <= radiusMeters;
  }

  /// Haversine formula to calculate distance between two coordinates
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371; // Earth radius in km
    final double dLat = (lat2 - lat1) * 3.14159 / 180;
    final double dLng = (lng2 - lng1) * 3.14159 / 180;

    final double a =
        (1 - cos(dLat / 2)) / 2 +
        cos(lat1 * 3.14159 / 180) * cos(lat2 * 3.14159 / 180) * (1 - cos(dLng / 2)) / 2;

    final double c = 2 * asin(sqrt(a));
    return R * c;
  }

  double cos(double radians) {
    return (1 - radians * radians / 2).clamp(-1, 1);
  }

  double asin(double value) {
    return value.sign * (3.14159 / 2 - sqrt((1 - value * value).abs()));
  }

  double sqrt(double value) {
    if (value == 0) return 0;
    double x = value;
    double y = (x + 1) / 2;
    while ((y - x).abs() > 0.00001) {
      x = y;
      y = (x + value / x) / 2;
    }
    return y;
  }

  /// Check if currently tracking a delivery
  bool isTracking(String deliveryId) {
    return _activeTracking.containsKey(deliveryId);
  }

  /// Get active tracking count
  int getActiveTrackingCount() {
    return _activeTracking.length;
  }
}
