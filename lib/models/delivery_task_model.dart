import 'package:google_maps_flutter/google_maps_flutter.dart';

enum DeliveryTaskStatus {
  created,
  assigned,
  accepted,
  picked_up,
  out_for_delivery,
  delivered,
  rejected,
  failed,
  returned,
  inTransit,
  arrived,
  completed,
}

extension DeliveryTaskStatusExtension on DeliveryTaskStatus {
  String get value => name;

  static DeliveryTaskStatus fromString(String val) {
    return DeliveryTaskStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => DeliveryTaskStatus.created,
    );
  }
}

class DeliveryTaskModel {
  final String deliveryId;
  final String orderId;
  final String customerId;
  final String? deliveryAgentId;
  final String branchId;
  final String? batchId;
  final DeliveryTaskStatus status;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final double addressLatitude;
  final double addressLongitude;
  final DateTime estimatedArrivalAt;
  final DateTime? assignedAt;
  final DateTime? actualArrivalAt;
  final DateTime? completedAt;
  final String? failureReason;
  final int? ratingFromCustomer;
  final String? customerFeedback;
  final DateTime createdAt;
  final String? deliveryNotes;

  // OTP Hardening fields
  final String? otpHash;
  final DateTime? otpExpiry;
  final int attemptCount;
  final DateTime? verifiedAt;

  DeliveryTaskModel({
    required this.deliveryId,
    required this.orderId,
    required this.customerId,
    this.deliveryAgentId,
    required this.branchId,
    this.batchId,
    this.status = DeliveryTaskStatus.created,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.addressLatitude,
    required this.addressLongitude,
    required this.estimatedArrivalAt,
    this.assignedAt,
    this.actualArrivalAt,
    this.completedAt,
    this.failureReason,
    this.ratingFromCustomer,
    this.customerFeedback,
    required this.createdAt,
    this.deliveryNotes,
    this.otpHash,
    this.otpExpiry,
    this.attemptCount = 0,
    this.verifiedAt,
  });

  String get orderNumber => orderId;
  String get id => deliveryId;

  LatLng get addressLatLng => LatLng(addressLatitude, addressLongitude);

  Map<String, dynamic> toJson() {
    return {
      'deliveryId': deliveryId,
      'orderId': orderId,
      'customerId': customerId,
      'deliveryAgentId': deliveryAgentId,
      'branchId': branchId,
      'batchId': batchId,
      'status': status.value,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'addressLatitude': addressLatitude,
      'addressLongitude': addressLongitude,
      'estimatedArrivalAt': estimatedArrivalAt.toIso8601String(),
      'assignedAt': assignedAt?.toIso8601String(),
      'actualArrivalAt': actualArrivalAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'failureReason': failureReason,
      'ratingFromCustomer': ratingFromCustomer,
      'customerFeedback': customerFeedback,
      'createdAt': createdAt.toIso8601String(),
      'deliveryNotes': deliveryNotes,
      'otpHash': otpHash,
      'otpExpiry': otpExpiry?.toIso8601String(),
      'attemptCount': attemptCount,
      'verifiedAt': verifiedAt?.toIso8601String(),
    };
  }

  factory DeliveryTaskModel.fromJson(Map<String, dynamic> json) {
    return DeliveryTaskModel(
      deliveryId: json['deliveryId'] as String,
      orderId: json['orderId'] as String,
      customerId: json['customerId'] as String,
      deliveryAgentId: json['deliveryAgentId'] as String?,
      branchId: json['branchId'] as String? ?? '',
      batchId: json['batchId'] as String?,
      status: DeliveryTaskStatusExtension.fromString(json['status'] as String),
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String,
      customerAddress: json['customerAddress'] as String,
      addressLatitude: (json['addressLatitude'] as num).toDouble(),
      addressLongitude: (json['addressLongitude'] as num).toDouble(),
      estimatedArrivalAt: DateTime.parse(json['estimatedArrivalAt'] as String),
      assignedAt: json['assignedAt'] != null ? DateTime.parse(json['assignedAt'] as String) : null,
      actualArrivalAt: json['actualArrivalAt'] != null
          ? DateTime.parse(json['actualArrivalAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      failureReason: json['failureReason'] as String?,
      ratingFromCustomer: json['ratingFromCustomer'] as int?,
      customerFeedback: json['customerFeedback'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      deliveryNotes: json['deliveryNotes'] as String?,
      otpHash: json['otpHash'] as String?,
      otpExpiry: json['otpExpiry'] != null ? DateTime.parse(json['otpExpiry'] as String) : null,
      attemptCount: json['attemptCount'] as int? ?? 0,
      verifiedAt: json['verifiedAt'] != null ? DateTime.parse(json['verifiedAt'] as String) : null,
    );
  }

  factory DeliveryTaskModel.fromMap(Map<String, dynamic> map) {
    return DeliveryTaskModel.fromJson(map);
  }

  DeliveryTaskModel copyWith({
    String? deliveryId,
    String? orderId,
    String? customerId,
    String? deliveryAgentId,
    String? branchId,
    String? batchId,
    DeliveryTaskStatus? status,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    double? addressLatitude,
    double? addressLongitude,
    DateTime? estimatedArrivalAt,
    DateTime? assignedAt,
    DateTime? actualArrivalAt,
    DateTime? completedAt,
    String? failureReason,
    int? ratingFromCustomer,
    String? customerFeedback,
    DateTime? createdAt,
    String? deliveryNotes,
    String? otpHash,
    DateTime? otpExpiry,
    int? attemptCount,
    DateTime? verifiedAt,
  }) {
    return DeliveryTaskModel(
      deliveryId: deliveryId ?? this.deliveryId,
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      deliveryAgentId: deliveryAgentId ?? this.deliveryAgentId,
      branchId: branchId ?? this.branchId,
      batchId: batchId ?? this.batchId,
      status: status ?? this.status,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      addressLatitude: addressLatitude ?? this.addressLatitude,
      addressLongitude: addressLongitude ?? this.addressLongitude,
      estimatedArrivalAt: estimatedArrivalAt ?? this.estimatedArrivalAt,
      assignedAt: assignedAt ?? this.assignedAt,
      actualArrivalAt: actualArrivalAt ?? this.actualArrivalAt,
      completedAt: completedAt ?? this.completedAt,
      failureReason: failureReason ?? this.failureReason,
      ratingFromCustomer: ratingFromCustomer ?? this.ratingFromCustomer,
      customerFeedback: customerFeedback ?? this.customerFeedback,
      createdAt: createdAt ?? this.createdAt,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      otpHash: otpHash ?? this.otpHash,
      otpExpiry: otpExpiry ?? this.otpExpiry,
      attemptCount: attemptCount ?? this.attemptCount,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }
}
