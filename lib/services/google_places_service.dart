import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../config/app_config.dart';

class PlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String description;

  PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.description,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] as String? ?? '',
      mainText: json['structured_formatting']?['main_text'] as String? ?? '',
      secondaryText: json['structured_formatting']?['secondary_text'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

class PlaceDetails {
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String district;
  final String village;
  final String pincode;

  PlaceDetails({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.district,
    required this.village,
    required this.pincode,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final components = json['address_components'] as List? ?? [];

    String district = '';
    String village = '';
    String pincode = '';

    for (final component in components) {
      final types = List<String>.from(component['types'] as List? ?? []);
      final longName = component['long_name'] as String? ?? '';

      if (types.contains('administrative_area_level_2')) {
        district = longName;
      } else if (types.contains('locality') || types.contains('administrative_area_level_3')) {
        village = longName;
      } else if (types.contains('postal_code')) {
        pincode = longName;
      }
    }

    final location = json['geometry']?['location'] as Map<String, dynamic>? ?? {};

    return PlaceDetails(
      latitude: (location['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (location['lng'] as num?)?.toDouble() ?? 0.0,
      formattedAddress: json['formatted_address'] as String? ?? '',
      district: district,
      village: village,
      pincode: pincode,
    );
  }
}

class GooglePlacesService {
  final String _apiKey = AppConfig.googleMapsKey;
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';

  /// Get autocomplete predictions for address input
  Future<List<PlacePrediction>> getAutocomplete(String query) async {
    if (query.isEmpty || _apiKey.isEmpty) {
      return [];
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/place/autocomplete/json?input=$query&key=$_apiKey&components=country:IN',
      );

      debugPrint('[GooglePlaces] Autocomplete request: $query');

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final predictions = (json['predictions'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map((p) => PlacePrediction.fromJson(p))
            .toList();

        debugPrint('[GooglePlaces] Got ${predictions.length} predictions');
        return predictions;
      } else {
        debugPrint('[GooglePlaces] ❌ Autocomplete failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[GooglePlaces] ❌ Autocomplete error: $e');
      return [];
    }
  }

  /// Get detailed place information including coordinates
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    if (placeId.isEmpty || _apiKey.isEmpty) {
      return null;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/place/details/json?place_id=$placeId&key=$_apiKey&fields=geometry,formatted_address,address_components',
      );

      debugPrint('[GooglePlaces] Details request for: $placeId');

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = json['result'] as Map<String, dynamic>?;

        if (result != null) {
          final details = PlaceDetails.fromJson(result);
          debugPrint('[GooglePlaces] ✅ Got details: ${details.formattedAddress}');
          debugPrint('[GooglePlaces] Coordinates: (${details.latitude}, ${details.longitude})');
          return details;
        }
      }

      debugPrint('[GooglePlaces] ❌ Details failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[GooglePlaces] ❌ Details error: $e');
      return null;
    }
  }
}
