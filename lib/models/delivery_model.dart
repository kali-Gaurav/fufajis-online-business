import 'package:cloud_firestore/cloud_firestore.dart';

enum DeliveryStatus {
  assigned,
  accepted,
  picked_up,
  on_the_way,
  arrived,
  delivered,
  cancelled
}

extension DeliveryStatusExtension on DeliveryStatus {
  String get name => toString().split('.').last;
  
  String get displayName {
    switch (this) {
      case DeliveryStatus.assigned: return 'Assigned';
      case DeliveryStatus.accepted: return 'Accepted';
      case DeliveryStatus.picked_up: return 'Picked Up';
      case DeliveryStatus.on_the_way: return 'On the Way';
      case DeliveryStatus.arrived: return 'Arrived';
      case DeliveryStatus.delivered: return 'Delivered';
      case DeliveryStatus.cancelled: return 'Cancelled';
    }
  }
}

class DeliveryModel {
  final String deliveryId;
  final String orderId;
  final String employeeId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final GeoPoint destinationLocation;
  
  final DeliveryStatus status;
  
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  
  final double currentLatitude;
  final double currentLongitude;
  final DateTime? lastLocationUpdate;
  
  final double distanceRemaining;
  final String estimatedArrival;
  final String? otp;
  final bool otpVerified;

  DeliveryModel({
    required this.deliveryId,
    required this.orderId,
    required this.employeeId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.destinationLocation,
    this.status = DeliveryStatus.assigned,
    this.assignedAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.startedAt,
    this.completedAt,
    this.currentLatitude = 0,
    this.currentLongitude = 0,
    this.lastLocationUpdate,
    this.distanceRemaining = 0,
    this.estimatedArrival = '',
    this.otp,
    this.otpVerified = false,
  });

  factory DeliveryModel.fromMap(Map<String, dynamic> map) {
    return DeliveryModel(
      deliveryId: map['deliveryId'] ?? '',
      orderId: map['orderId'] ?? '',
      employeeId: map['employeeId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      deliveryAddress: map['deliveryAddress'] ?? '',
      destinationLocation: map['destinationLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      status: DeliveryStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DeliveryStatus.assigned,
      ),
      assignedAt: (map['assignedAt'] as Timestamp?)?.toDate(),
      acceptedAt: (map['acceptedAt'] as Timestamp?)?.toDate(),
      pickedUpAt: (map['pickedUpAt'] as Timestamp?)?.toDate(),
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      currentLatitude: (map['currentLatitude'] ?? 0.0).toDouble(),
      currentLongitude: (map['currentLongitude'] ?? 0.0).toDouble(),
      lastLocationUpdate: (map['lastLocationUpdate'] as Timestamp?)?.toDate(),
      distanceRemaining: (map['distanceRemaining'] ?? 0.0).toDouble(),
      estimatedArrival: map['estimatedArrival'] ?? '',
      otp: map['otp'],
      otpVerified: map['otpVerified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deliveryId': deliveryId,
      'orderId': orderId,
      'employeeId': employeeId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'destinationLocation': destinationLocation,
      'status': status.name,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'pickedUpAt': pickedUpAt != null ? Timestamp.fromDate(pickedUpAt!) : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'lastLocationUpdate': lastLocationUpdate != null ? Timestamp.fromDate(lastLocationUpdate!) : null,
      'distanceRemaining': distanceRemaining,
      'estimatedArrival': estimatedArrival,
      'otp': otp,
      'otpVerified': otpVerified,
    };
  }

  DeliveryModel copyWith({
    String? deliveryId,
    String? orderId,
    String? employeeId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    GeoPoint? destinationLocation,
    DeliveryStatus? status,
    DateTime? assignedAt,
    DateTime? acceptedAt,
    DateTime? pickedUpAt,
    DateTime? startedAt,
    DateTime? completedAt,
    double? currentLatitude,
    double? currentLongitude,
    DateTime? lastLocationUpdate,
    double? distanceRemaining,
    String? estimatedArrival,
    String? otp,
    bool? otpVerified,
  }) {
    return DeliveryModel(
      deliveryId: deliveryId ?? this.deliveryId,
      orderId: orderId ?? this.orderId,
      employeeId: employeeId ?? this.employeeId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      status: status ?? this.status,
      assignedAt: assignedAt ?? this.assignedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      distanceRemaining: distanceRemaining ?? this.distanceRemaining,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      otp: otp ?? this.otp,
      otpVerified: otpVerified ?? this.otpVerified,
    );
  }
}
