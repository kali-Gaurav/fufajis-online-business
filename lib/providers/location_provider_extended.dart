import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_tracking_service.dart';

class LocationProviderExtended extends ChangeNotifier {
  final LocationTrackingService _locationService = LocationTrackingService();

  LatLng? currentLocation;
  int? eta; // Minutes
  bool isTracking = false;
  String? error;

  double? accuracy;
  double? speed;

  /// Start tracking a delivery
  Future<void> startTracking(String deliveryId, double destLat, double destLng) async {
    isTracking = true;
    error = null;
    notifyListeners();

    try {
      await _locationService.startTracking(
        deliveryId: deliveryId,
        onLocationUpdate: (lat, lng) {
          currentLocation = LatLng(lat, lng);
          _updateETA(lat, lng, destLat, destLng);
          notifyListeners();
        },
      );
    } catch (e) {
      error = 'Failed to start tracking: $e';
      debugPrint(error);
      isTracking = false;
      notifyListeners();
    }
  }

  /// Stop tracking
  Future<void> stopTracking(String deliveryId) async {
    try {
      await _locationService.stopTracking(deliveryId);
      isTracking = false;
      currentLocation = null;
      eta = null;
      notifyListeners();
    } catch (e) {
      error = 'Failed to stop tracking: $e';
      debugPrint(error);
      notifyListeners();
    }
  }

  /// Get current location one-time
  Future<LatLng?> getCurrentLocation() async {
    try {
      return await _locationService.getCurrentLocation();
    } catch (e) {
      error = 'Failed to get location: $e';
      debugPrint(error);
      notifyListeners();
      return null;
    }
  }

  /// Update ETA
  Future<void> _updateETA(
    double currentLat,
    double currentLng,
    double destLat,
    double destLng,
  ) async {
    try {
      eta = await _locationService.calculateETA(
        currentLat: currentLat,
        currentLng: currentLng,
        destLat: destLat,
        destLng: destLng,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error calculating ETA: $e');
    }
  }

  /// Check if near address
  bool isNearAddress({
    required double destLat,
    required double destLng,
    double radiusMeters = 500,
  }) {
    if (currentLocation == null) return false;

    return _locationService.isNearAddress(
      currentLat: currentLocation!.latitude,
      currentLng: currentLocation!.longitude,
      destLat: destLat,
      destLng: destLng,
      radiusMeters: radiusMeters,
    );
  }

  @override
  void dispose() {
    _locationService.stopAllTracking();
    super.dispose();
  }
}
