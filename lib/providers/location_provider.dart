import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import '../services/shop_config_service.dart';
import '../services/diagnostics_service.dart';
import '../services/google_places_service.dart';

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  String _currentAddress = '';
  String _district = '';
  String _village = '';
  String _pincode = '';
  double _latitude = 0.0;
  double _longitude = 0.0;
  Address? _selectedAddress;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Position? get currentPosition => _currentPosition;
  String get currentAddress => _currentAddress;
  String get district => _district;
  String get village => _village;
  String get pincode => _pincode;
  double get latitude => _latitude;
  double get longitude => _longitude;
  Address? get selectedAddress => _selectedAddress;

  void setSelectedAddress(Address? address) {
    _selectedAddress = address;
    notifyListeners();
  }

  double get deliveryRadiusKm {
    final config = ShopConfigService().cachedConfig;
    return config?.maxDeliveryRadiusKm ?? AppConfig.deliveryRadiusKm;
  }

  // Check if location service is enabled
  Future<bool> checkLocationService() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    return serviceEnabled;
  }

  // Check location permission
  Future<LocationPermission> checkLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission;
  }

  // Request location permission
  Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  // Get current location
  Future<void> getCurrentLocation() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = 'Location services are disabled';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          _errorMessage = 'Location permission denied';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _errorMessage = 'Location permission permanently denied';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      _latitude = _currentPosition!.latitude;
      _longitude = _currentPosition!.longitude;

      await _getAddressFromCoordinates();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get address from coordinates
  Future<void> _getAddressFromCoordinates() async {
    try {
      final placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        _currentAddress =
            '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}';
        _district = place.subAdministrativeArea ?? '';
        _village = place.locality ?? '';
        _pincode = place.postalCode ?? '';
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  // Get address from text
  Future<List<Location>> getLocationsFromQuery(String query) async {
    try {
      if (query.isEmpty) return [];
      return await locationFromAddress(query);
    } catch (e) {
      return [];
    }
  }

  // Set location manually
  void setLocation({
    required double latitude,
    required double longitude,
    String address = '',
    String district = '',
    String village = '',
    String pincode = '',
  }) {
    _latitude = latitude;
    _longitude = longitude;
    _currentAddress = address;
    _district = district;
    _village = village;
    _pincode = pincode;
    notifyListeners();
  }

  // Calculate distance between two points
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Validate coordinates are within reasonable ranges
    if (!_isValidLatitude(lat1) || !_isValidLongitude(lon1) ||
        !_isValidLatitude(lat2) || !_isValidLongitude(lon2)) {
      debugPrint(
        '[LocationProvider] Invalid coordinates: shop($lat1, $lon1) → address($lat2, $lon2)',
      );
      return 0.0;
    }

    try {
      final distance = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
      // Sanity check: distance shouldn't exceed ~2000 km (earth's circumference/20)
      if (distance > 2000000) {
        debugPrint('[LocationProvider] Unrealistic distance: ${distance}m. Likely coordinate error.');
        return 0.0;
      }
      return distance;
    } catch (e) {
      debugPrint('[LocationProvider] Error calculating distance: $e');
      return 0.0;
    }
  }

  bool _isValidLatitude(double lat) => lat >= -90 && lat <= 90 && lat != 0;
  bool _isValidLongitude(double lon) => lon >= -180 && lon <= 180 && lon != 0;

  double distanceFromShopInMeters({required double latitude, required double longitude}) {
    final config = ShopConfigService().cachedConfig;
    final shopLat = config?.shopLatitude ?? AppConfig.shopLatitude;
    final shopLng = config?.shopLongitude ?? AppConfig.shopLongitude;

    // Validate input address coordinates
    if (!_isValidLatitude(latitude) || !_isValidLongitude(longitude)) {
      DiagnosticsService().log('Distance',
        '🚨 Invalid address coordinates: ($latitude, $longitude)',
        level: AppLogSeverity.error);
      debugPrint('[LocationProvider] Invalid address coordinates: ($latitude, $longitude)');
      return double.maxFinite;
    }

    final distance = calculateDistance(shopLat, shopLng, latitude, longitude);

    // DIAGNOSTIC: Log all distance calculations
    DiagnosticsService().logDistance(
      shopLat: shopLat,
      shopLng: shopLng,
      userLat: latitude,
      userLng: longitude,
      distanceMeters: distance,
    );

    return distance;
  }

  bool isWithinDeliveryRadius({required double latitude, required double longitude}) {
    final service = ShopConfigService();
    final config = service.cachedConfig;
    if (config == null) {
      return distanceFromShopInMeters(latitude: latitude, longitude: longitude) <=
          AppConfig.deliveryRadiusMeters;
    }
    return service.isWithinDeliveryArea(latitude, longitude, config, service.cachedBranches);
  }

  bool isAddressWithinDeliveryRadius(Address address) {
    return isWithinDeliveryRadius(latitude: address.latitude, longitude: address.longitude);
  }

  String deliveryZoneMessageFor(Address address) {
    final distanceKm =
        distanceFromShopInMeters(latitude: address.latitude, longitude: address.longitude) / 1000;
    final limit = deliveryRadiusKm;

    if (isAddressWithinDeliveryRadius(address)) {
      return 'Delivery available: ${distanceKm.toStringAsFixed(1)} km from shop/branch.';
    }

    return 'Delivery not available: this address is ${distanceKm.toStringAsFixed(1)} km away. We currently deliver within ${limit.toStringAsFixed(0)} km.';
  }

  // Get estimated delivery time based on distance
  String getEstimatedDeliveryTime(double distanceInMeters) {
    if (distanceInMeters < 2000) {
      return '30 minutes';
    } else if (distanceInMeters < 5000) {
      return '1 hour';
    } else if (distanceInMeters < 10000) {
      return '2 hours';
    } else {
      return 'Same day delivery';
    }
  }

  // Check if delivery is available in area
  bool isDeliveryAvailable(String area) {
    // Add your district/village list here
    final availableAreas = [
      'Baran',
      'Jaipur',
      'Jodhpur',
      'Udaipur',
      'Kota',
      'Bikaner',
      'Ajmer',
      'Pilani',
      'Jhunjhunu',
    ];
    return availableAreas.any(
      (a) =>
          area.toLowerCase().contains(a.toLowerCase()) ||
          a.toLowerCase().contains(area.toLowerCase()),
    );
  }
}
