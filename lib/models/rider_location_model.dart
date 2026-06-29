import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RiderLocationModel {
  final String riderId;
  final String branchId;
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  final double batteryLevel;
  final DateTime timestamp;
  final bool isOnline;

  RiderLocationModel({
    required this.riderId,
    required this.branchId,
    required this.latitude,
    required this.longitude,
    this.speed = 0.0,
    this.heading = 0.0,
    this.batteryLevel = 100.0,
    required this.timestamp,
    this.isOnline = true,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toMap() {
    return {
      'riderId': riderId,
      'branchId': branchId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'heading': heading,
      'batteryLevel': batteryLevel,
      'timestamp': Timestamp.fromDate(timestamp),
      'isOnline': isOnline,
    };
  }

  factory RiderLocationModel.fromMap(Map<String, dynamic> map, String docId) {
    return RiderLocationModel(
      riderId: docId,
      branchId: map['branchId'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      batteryLevel: (map['batteryLevel'] as num?)?.toDouble() ?? 100.0,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: map['isOnline'] as bool? ?? true,
    );
  }
}
