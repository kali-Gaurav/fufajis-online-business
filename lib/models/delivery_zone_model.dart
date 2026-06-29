import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DeliveryZoneModel {
  final String id;
  final String name;
  final String branchId;
  final List<LatLng> polygonCoordinates;
  final double baseFee;
  final double surgeMultiplier;
  final bool isActive;
  final DateTime createdAt;

  DeliveryZoneModel({
    required this.id,
    required this.name,
    required this.branchId,
    required this.polygonCoordinates,
    this.baseFee = 30.0,
    this.surgeMultiplier = 1.0,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'branchId': branchId,
      'polygonCoordinates': polygonCoordinates.map((latLng) => {
        'latitude': latLng.latitude,
        'longitude': latLng.longitude,
      }).toList(),
      'baseFee': baseFee,
      'surgeMultiplier': surgeMultiplier,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory DeliveryZoneModel.fromMap(Map<String, dynamic> map, String docId) {
    var coordsRaw = map['polygonCoordinates'] as List<dynamic>? ?? [];
    List<LatLng> coords = coordsRaw.map((e) {
      final lat = (e['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (e['longitude'] as num?)?.toDouble() ?? 0.0;
      return LatLng(lat, lng);
    }).toList();

    return DeliveryZoneModel(
      id: docId,
      name: map['name'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      polygonCoordinates: coords,
      baseFee: (map['baseFee'] as num? ?? 30.0).toDouble(),
      surgeMultiplier: (map['surgeMultiplier'] as num? ?? 1.0).toDouble(),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
