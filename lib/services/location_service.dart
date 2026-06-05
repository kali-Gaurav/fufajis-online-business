import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Gets the current location of the device
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  /// Reverse geocodes the coordinates to get address details (District/Village)
  Future<Map<String, String>> getAddressFromCoords(
    double lat,
    double lng,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return {
          'district': place.subAdministrativeArea ?? place.locality ?? '',
          'village': place.subLocality ?? place.name ?? '',
          'state': place.administrativeArea ?? '',
          'pincode': place.postalCode ?? '',
        };
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
    return {};
  }

  /// Checks if a point is within a radius of another point (Step 1.5)
  /// Used for Cross-District visibility (e.g., show shops within 15km even if in next district)
  bool isWithinServiceRadius({
    required double userLat,
    required double userLng,
    required double targetLat,
    required double targetLng,
    double radiusKm = 15.0,
  }) {
    final distanceInMeters = Geolocator.distanceBetween(
      userLat,
      userLng,
      targetLat,
      targetLng,
    );
    return distanceInMeters <= (radiusKm * 1000);
  }
}
