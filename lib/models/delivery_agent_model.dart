import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a delivery agent (rider/delivery person)
class DeliveryAgent {
  final String id;
  final String name;
  final String phone;
  final double currentLat;
  final double currentLng;
  final bool isAvailable;
  final String currentStatus; // 'active', 'inactive', 'on_break'
  final double rating;
  final int totalDeliveries;
  final String? currentOrderId;
  final int currentOrderCount;
  final DateTime? lastLocationUpdate;
  final DateTime createdAt;
  final String? branchId;

  // Iteration 6: Order Tracking
  final String? photoUrl;
  final double onTimeRate; // percentage 0-100
  final String? vehicleType; // "motorcycle", "scooter", "van"
  final String? vehiclePlate;
  final int currentWorkload; // number of active deliveries

  DeliveryAgent({
    required this.id,
    required this.name,
    required this.phone,
    required this.currentLat,
    required this.currentLng,
    required this.isAvailable,
    required this.currentStatus,
    this.rating = 4.5,
    this.totalDeliveries = 0,
    this.currentOrderId,
    this.currentOrderCount = 0,
    this.lastLocationUpdate,
    required this.createdAt,
    this.branchId,
    this.photoUrl,
    this.onTimeRate = 95.0,
    this.vehicleType,
    this.vehiclePlate,
    this.currentWorkload = 0,
  });

  /// Convert DeliveryAgent to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'isAvailable': isAvailable,
      'currentStatus': currentStatus,
      'rating': rating,
      'totalDeliveries': totalDeliveries,
      'currentOrderId': currentOrderId,
      'currentOrderCount': currentOrderCount,
      'lastLocationUpdate': lastLocationUpdate != null
          ? Timestamp.fromDate(lastLocationUpdate!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'branchId': branchId,
      'photoUrl': photoUrl,
      'onTimeRate': onTimeRate,
      'vehicleType': vehicleType,
      'vehiclePlate': vehiclePlate,
      'currentWorkload': currentWorkload,
    };
  }

  /// Create DeliveryAgent from Firestore Map
  factory DeliveryAgent.fromMap(Map<String, dynamic> map) {
    return DeliveryAgent(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown',
      phone: map['phone'] as String? ?? '',
      currentLat: (map['currentLat'] as num?)?.toDouble() ?? 0.0,
      currentLng: (map['currentLng'] as num?)?.toDouble() ?? 0.0,
      isAvailable: map['isAvailable'] as bool? ?? true,
      currentStatus: map['currentStatus'] as String? ?? 'inactive',
      rating: (map['rating'] as num?)?.toDouble() ?? 4.5,
      totalDeliveries: (map['totalDeliveries'] as num?)?.toInt() ?? 0,
      currentOrderId: map['currentOrderId'] as String?,
      currentOrderCount: (map['currentOrderCount'] as num?)?.toInt() ?? 0,
      lastLocationUpdate: map['lastLocationUpdate'] != null
          ? (map['lastLocationUpdate'] as Timestamp).toDate()
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      branchId: map['branchId'] as String?,
      photoUrl: map['photoUrl'] as String?,
      onTimeRate: (map['onTimeRate'] as num?)?.toDouble() ?? 95.0,
      vehicleType: map['vehicleType'] as String?,
      vehiclePlate: map['vehiclePlate'] as String?,
      currentWorkload: (map['currentWorkload'] as num?)?.toInt() ?? 0,
    );
  }

  /// Create a copy with modified fields
  DeliveryAgent copyWith({
    String? id,
    String? name,
    String? phone,
    double? currentLat,
    double? currentLng,
    bool? isAvailable,
    String? currentStatus,
    double? rating,
    int? totalDeliveries,
    String? currentOrderId,
    int? currentOrderCount,
    DateTime? lastLocationUpdate,
    DateTime? createdAt,
    String? branchId,
    String? photoUrl,
    double? onTimeRate,
    String? vehicleType,
    String? vehiclePlate,
    int? currentWorkload,
  }) {
    return DeliveryAgent(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      isAvailable: isAvailable ?? this.isAvailable,
      currentStatus: currentStatus ?? this.currentStatus,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      currentOrderCount: currentOrderCount ?? this.currentOrderCount,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      createdAt: createdAt ?? this.createdAt,
      branchId: branchId ?? this.branchId,
      photoUrl: photoUrl ?? this.photoUrl,
      onTimeRate: onTimeRate ?? this.onTimeRate,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      currentWorkload: currentWorkload ?? this.currentWorkload,
    );
  }

  bool canAcceptOrder() => isAvailable && currentWorkload < 4;

  double getReliabilityScore() => (rating / 5.0 * 0.6) + (onTimeRate / 100.0 * 0.4);
}
