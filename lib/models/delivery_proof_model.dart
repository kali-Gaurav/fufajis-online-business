import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DeliveryProofModel {
  final String id;
  final String deliveryTaskId;
  final String customerName;
  final String? photoUrl;
  final String? signatureUrl;
  final double gpsLatitude;
  final double gpsLongitude;
  final DateTime timestamp;
  final bool otpVerified;

  DeliveryProofModel({
    required this.id,
    required this.deliveryTaskId,
    required this.customerName,
    this.photoUrl,
    this.signatureUrl,
    required this.gpsLatitude,
    required this.gpsLongitude,
    required this.timestamp,
    this.otpVerified = false,
  });

  LatLng get gpsLocation => LatLng(gpsLatitude, gpsLongitude);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deliveryTaskId': deliveryTaskId,
      'customerName': customerName,
      'photoUrl': photoUrl,
      'signatureUrl': signatureUrl,
      'gpsLatitude': gpsLatitude,
      'gpsLongitude': gpsLongitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'otpVerified': otpVerified,
    };
  }

  factory DeliveryProofModel.fromMap(Map<String, dynamic> map, String docId) {
    return DeliveryProofModel(
      id: docId,
      deliveryTaskId: map['deliveryTaskId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      signatureUrl: map['signatureUrl'] as String?,
      gpsLatitude: (map['gpsLatitude'] as num? ?? 0.0).toDouble(),
      gpsLongitude: (map['gpsLongitude'] as num? ?? 0.0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      otpVerified: map['otpVerified'] as bool? ?? false,
    );
  }
}
