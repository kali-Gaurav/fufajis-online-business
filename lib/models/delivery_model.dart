import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/monetary_value.dart';

enum DeliveryStatus {
  assigned,
  pickedUp,
  outForDelivery,
  delivered,
  failed,
  cancelled,
  rescheduled,
}

extension DeliveryStatusExtension on DeliveryStatus {
  String get displayName {
    switch (this) {
      case DeliveryStatus.assigned:
        return 'Assigned';
      case DeliveryStatus.pickedUp:
        return 'Picked Up';
      case DeliveryStatus.outForDelivery:
        return 'Out for Delivery';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.failed:
        return 'Failed';
      case DeliveryStatus.cancelled:
        return 'Cancelled';
      case DeliveryStatus.rescheduled:
        return 'Rescheduled';
    }
  }

  String get description {
    switch (this) {
      case DeliveryStatus.assigned:
        return 'Order assigned to delivery agent';
      case DeliveryStatus.pickedUp:
        return 'Order picked up from warehouse';
      case DeliveryStatus.outForDelivery:
        return 'Order is on the way to customer';
      case DeliveryStatus.delivered:
        return 'Order delivered successfully';
      case DeliveryStatus.failed:
        return 'Delivery attempt failed';
      case DeliveryStatus.cancelled:
        return 'Delivery cancelled';
      case DeliveryStatus.rescheduled:
        return 'Delivery rescheduled';
    }
  }

  Color get color {
    switch (this) {
      case DeliveryStatus.assigned:
        return AppTheme.info;
      case DeliveryStatus.pickedUp:
        return Colors.purple;
      case DeliveryStatus.outForDelivery:
        return Colors.cyan;
      case DeliveryStatus.delivered:
        return AppTheme.success;
      case DeliveryStatus.failed:
        return AppTheme.error;
      case DeliveryStatus.cancelled:
        return Colors.grey;
      case DeliveryStatus.rescheduled:
        return AppTheme.warning;
    }
  }

  IconData get icon {
    switch (this) {
      case DeliveryStatus.assigned:
        return Icons.assignment;
      case DeliveryStatus.pickedUp:
        return Icons.inventory_2;
      case DeliveryStatus.outForDelivery:
        return Icons.local_shipping;
      case DeliveryStatus.delivered:
        return Icons.check_circle;
      case DeliveryStatus.failed:
        return Icons.cancel;
      case DeliveryStatus.cancelled:
        return Icons.block;
      case DeliveryStatus.rescheduled:
        return Icons.schedule;
    }
  }

  bool get isActive {
    return this != DeliveryStatus.delivered &&
        this != DeliveryStatus.failed &&
        this != DeliveryStatus.cancelled;
  }

  bool get isTerminal {
    return this == DeliveryStatus.delivered ||
        this == DeliveryStatus.failed ||
        this == DeliveryStatus.cancelled;
  }

  int get priority {
    switch (this) {
      case DeliveryStatus.outForDelivery:
        return 1;
      case DeliveryStatus.assigned:
      case DeliveryStatus.rescheduled:
        return 2;
      case DeliveryStatus.pickedUp:
        return 3;
      default:
        return 0;
    }
  }
}

/// Represents proof of delivery with photo, signature, and timestamp
class ProofOfDelivery {
  final String photoUrl;
  final String? signatureUrl;
  final DateTime timestamp;
  final GeoPoint location;
  final String? notes;
  final String? customerName;
  final String? customerSignature;

  ProofOfDelivery({
    required this.photoUrl,
    this.signatureUrl,
    required this.timestamp,
    required this.location,
    this.notes,
    this.customerName,
    this.customerSignature,
  });

  factory ProofOfDelivery.fromMap(Map<String, dynamic> map) {
    return ProofOfDelivery(
      photoUrl: map['photoUrl'] as String? ?? '',
      signatureUrl: map['signatureUrl'] as String?,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is Timestamp
              ? (map['timestamp'] as Timestamp).toDate()
              : DateTime.parse(map['timestamp'].toString()))
          : DateTime.now(),
      location: map['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      notes: map['notes'] as String?,
      customerName: map['customerName'] as String?,
      customerSignature: map['customerSignature'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photoUrl': photoUrl,
      'signatureUrl': signatureUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'location': location,
      'notes': notes,
      'customerName': customerName,
      'customerSignature': customerSignature,
    };
  }

  ProofOfDelivery copyWith({
    String? photoUrl,
    String? signatureUrl,
    DateTime? timestamp,
    GeoPoint? location,
    String? notes,
    String? customerName,
    String? customerSignature,
  }) {
    return ProofOfDelivery(
      photoUrl: photoUrl ?? this.photoUrl,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      customerName: customerName ?? this.customerName,
      customerSignature: customerSignature ?? this.customerSignature,
    );
  }
}

/// Daily delivery statistics for an agent
class DeliveryStats {
  final String agentId;
  final String date;
  final int totalDeliveries;
  final int successfulDeliveries;
  final int failedDeliveries;
  final double averageCustomerRating;
  final double totalDistance;
  final double totalTime;
  final int onTimeDeliveries;
  final double onTimePercentage;
  final MonetaryValue totalEarnings;
  final double acceptanceRate;

  int get completedDeliveries => successfulDeliveries;

  DeliveryStats({
    required this.agentId,
    required this.date,
    this.totalDeliveries = 0,
    this.successfulDeliveries = 0,
    this.failedDeliveries = 0,
    this.averageCustomerRating = 0.0,
    this.totalDistance = 0.0,
    this.totalTime = 0.0,
    this.onTimeDeliveries = 0,
    this.onTimePercentage = 0.0,
    MonetaryValue? totalEarnings,
    this.acceptanceRate = 0.0,
  }) : totalEarnings = totalEarnings ?? MonetaryValue(0.0);

  factory DeliveryStats.fromMap(Map<String, dynamic> map) {
    return DeliveryStats(
      agentId: map['agentId'] as String? ?? '',
      date: map['date'] as String? ?? '',
      totalDeliveries: map['totalDeliveries'] as int? ?? 0,
      successfulDeliveries: map['successfulDeliveries'] as int? ?? 0,
      failedDeliveries: map['failedDeliveries'] as int? ?? 0,
      averageCustomerRating:
          (map['averageCustomerRating'] as num?)?.toDouble() ?? 0.0,
      totalDistance: (map['totalDistance'] as num?)?.toDouble() ?? 0.0,
      totalTime: (map['totalTime'] as num?)?.toDouble() ?? 0.0,
      onTimeDeliveries: map['onTimeDeliveries'] as int? ?? 0,
      onTimePercentage: (map['onTimePercentage'] as num?)?.toDouble() ?? 0.0,
      totalEarnings: MonetaryValue(map['totalEarnings'] ?? 0.0),
      acceptanceRate: (map['acceptanceRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'agentId': agentId,
      'date': date,
      'totalDeliveries': totalDeliveries,
      'successfulDeliveries': successfulDeliveries,
      'failedDeliveries': failedDeliveries,
      'averageCustomerRating': averageCustomerRating,
      'totalDistance': totalDistance,
      'totalTime': totalTime,
      'onTimeDeliveries': onTimeDeliveries,
      'onTimePercentage': onTimePercentage,
      'totalEarnings': totalEarnings,
      'acceptanceRate': acceptanceRate,
    };
  }

  double get successRate =>
      totalDeliveries == 0 ? 0.0 : (successfulDeliveries / totalDeliveries) * 100;

  DeliveryStats copyWith({
    String? agentId,
    String? date,
    int? totalDeliveries,
    int? successfulDeliveries,
    int? failedDeliveries,
    double? averageCustomerRating,
    double? totalDistance,
    double? totalTime,
    int? onTimeDeliveries,
    double? onTimePercentage,
  }) {
    return DeliveryStats(
      agentId: agentId ?? this.agentId,
      date: date ?? this.date,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      successfulDeliveries: successfulDeliveries ?? this.successfulDeliveries,
      failedDeliveries: failedDeliveries ?? this.failedDeliveries,
      averageCustomerRating:
          averageCustomerRating ?? this.averageCustomerRating,
      totalDistance: totalDistance ?? this.totalDistance,
      totalTime: totalTime ?? this.totalTime,
      onTimeDeliveries: onTimeDeliveries ?? this.onTimeDeliveries,
      onTimePercentage: onTimePercentage ?? this.onTimePercentage,
    );
  }
}

/// Main delivery task model
class DeliveryTask {
  final String id;
  final String orderId;
  final String deliveryAgentId;
  final String? deliveryAgentName;
  final String? deliveryAgentPhone;
  final DeliveryStatus status;
  final GeoPoint pickupLocation;
  final GeoPoint deliveryLocation;
  final String deliveryAddress;
  final double currentLatitude;
  final double currentLongitude;
  final DateTime? estimatedArrival;
  final double? distanceRemaining;
  final double? estimatedDistance;
  final String? customerName;
  final String? customerPhone;
  final DateTime estimatedDeliveryTime;
  final DateTime? actualDeliveryTime;
  final String otpGenerated;
  final bool otpVerified;
  final DateTime otpGeneratedAt;
  final DateTime otpExpiresAt;
  final int otpAttempts;
  final ProofOfDelivery? proofOfDelivery;
  final double? customerRating;
  final String? customerFeedback;
  final List<LatLng>? route;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? failureReason;
  final int attemptNumber;
  final bool isRescheduled;
  final DateTime? rescheduledDate;
  final Map<String, double>? deliveryMetrics;
  final String? shopId;
  final String? shopName;

  DeliveryTask({
    required this.id,
    required this.orderId,
    required this.deliveryAgentId,
    this.deliveryAgentName,
    this.deliveryAgentPhone,
    this.status = DeliveryStatus.assigned,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.deliveryAddress,
    this.currentLatitude = 0.0,
    this.currentLongitude = 0.0,
    this.estimatedArrival,
    this.distanceRemaining,
    this.estimatedDistance,
    this.customerName,
    this.customerPhone,
    required this.estimatedDeliveryTime,
    this.actualDeliveryTime,
    required this.otpGenerated,
    this.otpVerified = false,
    required this.otpGeneratedAt,
    required this.otpExpiresAt,
    this.otpAttempts = 0,
    this.proofOfDelivery,
    this.customerRating,
    this.customerFeedback,
    this.route,
    required this.createdAt,
    required this.updatedAt,
    this.failureReason,
    this.attemptNumber = 1,
    this.isRescheduled = false,
    this.rescheduledDate,
    this.deliveryMetrics,
    this.shopId,
    this.shopName,
  });

  factory DeliveryTask.fromMap(Map<String, dynamic> map) {
    return DeliveryTask(
      id: map['id'] as String? ?? '',
      orderId: map['orderId'] as String? ?? '',
      deliveryAgentId: map['deliveryAgentId'] as String? ?? '',
      deliveryAgentName: map['deliveryAgentName'] as String?,
      deliveryAgentPhone: map['deliveryAgentPhone'] as String?,
      status: DeliveryStatus.values.firstWhere(
        (e) => e.toString() == map['status'] as String?,
        orElse: () => DeliveryStatus.assigned,
      ),
      pickupLocation: map['pickupLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      deliveryLocation: map['deliveryLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      deliveryAddress: map['deliveryAddress'] as String? ?? '',
      currentLatitude: (map['currentLatitude'] as num? ?? 0.0).toDouble(),
      currentLongitude: (map['currentLongitude'] as num? ?? 0.0).toDouble(),
      estimatedArrival: map['estimatedArrival'] != null
          ? (map['estimatedArrival'] is Timestamp
              ? (map['estimatedArrival'] as Timestamp).toDate()
              : DateTime.tryParse(map['estimatedArrival'].toString()))
          : null,
      distanceRemaining: (map['distanceRemaining'] as num?)?.toDouble(),
      estimatedDistance: (map['estimatedDistance'] as num?)?.toDouble(),
      customerName: map['customerName'] as String?,
      customerPhone: map['customerPhone'] as String?,
      estimatedDeliveryTime: map['estimatedDeliveryTime'] != null
          ? (map['estimatedDeliveryTime'] is Timestamp
              ? (map['estimatedDeliveryTime'] as Timestamp).toDate()
              : DateTime.parse(map['estimatedDeliveryTime'].toString()))
          : DateTime.now().add(const Duration(hours: 2)),
      actualDeliveryTime: map['actualDeliveryTime'] != null
          ? (map['actualDeliveryTime'] is Timestamp
              ? (map['actualDeliveryTime'] as Timestamp).toDate()
              : DateTime.tryParse(map['actualDeliveryTime'].toString()))
          : null,
      otpGenerated: map['otpGenerated'] as String? ?? '',
      otpVerified: map['otpVerified'] as bool? ?? false,
      otpGeneratedAt: map['otpGeneratedAt'] != null
          ? (map['otpGeneratedAt'] is Timestamp
              ? (map['otpGeneratedAt'] as Timestamp).toDate()
              : DateTime.parse(map['otpGeneratedAt'].toString()))
          : DateTime.now(),
      otpExpiresAt: map['otpExpiresAt'] != null
          ? (map['otpExpiresAt'] is Timestamp
              ? (map['otpExpiresAt'] as Timestamp).toDate()
              : DateTime.parse(map['otpExpiresAt'].toString()))
          : DateTime.now().add(const Duration(minutes: 15)),
      otpAttempts: map['otpAttempts'] as int? ?? 0,
      proofOfDelivery: map['proofOfDelivery'] != null
          ? ProofOfDelivery.fromMap(map['proofOfDelivery'] as Map<String, dynamic>)
          : null,
      customerRating: (map['customerRating'] as num?)?.toDouble(),
      customerFeedback: map['customerFeedback'] as String?,
      route: (map['route'] as List?)
          ?.map((item) => LatLng((item['latitude'] as num).toDouble(), (item['longitude'] as num).toDouble()))
          .toList(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.parse(map['createdAt'].toString()))
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(map['updatedAt'].toString()))
          : DateTime.now(),
      failureReason: map['failureReason'] as String?,
      attemptNumber: map['attemptNumber'] as int? ?? 1,
      isRescheduled: map['isRescheduled'] as bool? ?? false,
      rescheduledDate: map['rescheduledDate'] != null
          ? (map['rescheduledDate'] is Timestamp
              ? (map['rescheduledDate'] as Timestamp).toDate()
              : DateTime.tryParse(map['rescheduledDate'].toString()))
          : null,
      deliveryMetrics: map['deliveryMetrics'] != null
          ? Map<String, double>.from(
              (map['deliveryMetrics'] as Map)
                  .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))
          : null,
      shopId: map['shopId'] as String?,
      shopName: map['shopName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'deliveryAgentId': deliveryAgentId,
      'deliveryAgentName': deliveryAgentName,
      'deliveryAgentPhone': deliveryAgentPhone,
      'status': status.toString(),
      'pickupLocation': pickupLocation,
      'deliveryLocation': deliveryLocation,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'estimatedArrival': estimatedArrival != null ? Timestamp.fromDate(estimatedArrival!) : null,
      'distanceRemaining': distanceRemaining,
      'estimatedDistance': estimatedDistance,
      'deliveryAddress': deliveryAddress,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'estimatedDeliveryTime': Timestamp.fromDate(estimatedDeliveryTime),
      'actualDeliveryTime': actualDeliveryTime != null
          ? Timestamp.fromDate(actualDeliveryTime!)
          : null,
      'otpGenerated': otpGenerated,
      'otpVerified': otpVerified,
      'otpGeneratedAt': Timestamp.fromDate(otpGeneratedAt),
      'otpExpiresAt': Timestamp.fromDate(otpExpiresAt),
      'otpAttempts': otpAttempts,
      'proofOfDelivery': proofOfDelivery?.toMap(),
      'customerRating': customerRating,
      'customerFeedback': customerFeedback,
      'route': route
          ?.map((point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
              })
          .toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'failureReason': failureReason,
      'attemptNumber': attemptNumber,
      'isRescheduled': isRescheduled,
      'rescheduledDate': rescheduledDate != null
          ? Timestamp.fromDate(rescheduledDate!)
          : null,
      'deliveryMetrics': deliveryMetrics,
      'shopId': shopId,
      'shopName': shopName,
    };
  }

  bool get isOtpExpired => DateTime.now().isAfter(otpExpiresAt);

  bool get isOtpValid => !isOtpExpired && otpAttempts < 3;

  Duration get estimatedTimeRemaining =>
      estimatedDeliveryTime.difference(DateTime.now());

  bool get isLate =>
      DateTime.now().isAfter(estimatedDeliveryTime) &&
      status == DeliveryStatus.outForDelivery;

  GeoPoint get destinationLocation => deliveryLocation;

  DeliveryTask copyWith({
    String? id,
    String? orderId,
    String? deliveryAgentId,
    String? deliveryAgentName,
    String? deliveryAgentPhone,
    DeliveryStatus? status,
    GeoPoint? pickupLocation,
    GeoPoint? deliveryLocation,
    String? deliveryAddress,
    double? currentLatitude,
    double? currentLongitude,
    DateTime? estimatedArrival,
    double? distanceRemaining,
    String? customerName,
    String? customerPhone,
    DateTime? estimatedDeliveryTime,
    DateTime? actualDeliveryTime,
    String? otpGenerated,
    bool? otpVerified,
    DateTime? otpGeneratedAt,
    DateTime? otpExpiresAt,
    int? otpAttempts,
    ProofOfDelivery? proofOfDelivery,
    double? customerRating,
    String? customerFeedback,
    List<LatLng>? route,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? failureReason,
    int? attemptNumber,
    bool? isRescheduled,
    DateTime? rescheduledDate,
    Map<String, double>? deliveryMetrics,
    String? shopId,
    String? shopName,
  }) {
    return DeliveryTask(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      deliveryAgentId: deliveryAgentId ?? this.deliveryAgentId,
      deliveryAgentName: deliveryAgentName ?? this.deliveryAgentName,
      deliveryAgentPhone: deliveryAgentPhone ?? this.deliveryAgentPhone,
      status: status ?? this.status,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      distanceRemaining: distanceRemaining ?? this.distanceRemaining,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      actualDeliveryTime: actualDeliveryTime ?? this.actualDeliveryTime,
      otpGenerated: otpGenerated ?? this.otpGenerated,
      otpVerified: otpVerified ?? this.otpVerified,
      otpGeneratedAt: otpGeneratedAt ?? this.otpGeneratedAt,
      otpExpiresAt: otpExpiresAt ?? this.otpExpiresAt,
      otpAttempts: otpAttempts ?? this.otpAttempts,
      proofOfDelivery: proofOfDelivery ?? this.proofOfDelivery,
      customerRating: customerRating ?? this.customerRating,
      customerFeedback: customerFeedback ?? this.customerFeedback,
      route: route ?? this.route,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      failureReason: failureReason ?? this.failureReason,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      isRescheduled: isRescheduled ?? this.isRescheduled,
      rescheduledDate: rescheduledDate ?? this.rescheduledDate,
      deliveryMetrics: deliveryMetrics ?? this.deliveryMetrics,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
    );
  }
}

/// Backward compatibility alias
typedef DeliveryModel = DeliveryTask;
