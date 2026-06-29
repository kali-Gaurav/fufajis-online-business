import 'package:google_maps_flutter/google_maps_flutter.dart';

class DeliveryLocationModel {
  final String locationId;
  final String deliveryId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final double? speed;

  DeliveryLocationModel({
    required this.locationId,
    required this.deliveryId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.speed,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() {
    return {
      'locationId': locationId,
      'deliveryId': deliveryId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'accuracy': accuracy,
      'speed': speed,
    };
  }

  factory DeliveryLocationModel.fromJson(Map<String, dynamic> json) {
    return DeliveryLocationModel(
      locationId: json['locationId'] as String,
      deliveryId: json['deliveryId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
    );
  }

  factory DeliveryLocationModel.fromMap(Map<String, dynamic> map) {
    return DeliveryLocationModel.fromJson(map);
  }

  DeliveryLocationModel copyWith({
    String? locationId,
    String? deliveryId,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    double? accuracy,
    double? speed,
  }) {
    return DeliveryLocationModel(
      locationId: locationId ?? this.locationId,
      deliveryId: deliveryId ?? this.deliveryId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
    );
  }

  @override
  String toString() =>
      'DeliveryLocationModel(deliveryId: $deliveryId, lat: $latitude, lng: $longitude, time: $timestamp)';
}
