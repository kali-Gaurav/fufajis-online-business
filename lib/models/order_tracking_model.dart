import 'package:google_maps_flutter/google_maps_flutter.dart';

class OrderTracking {
  final String orderId;
  final String orderNumber;
  final String status; // confirmed, processing, packed, shipped, arrived, delivered, cancelled
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final String? deliveryAgentId;
  final LatLng? currentLocation;
  final DateTime? estimatedDeliveryTime;
  final List<StatusEvent> statusHistory;
  final String? proofOfDeliveryPhotoUrl;
  final String? notes;
  final String? deliveryAddressStreet;
  final String? deliveryAddressCity;
  final String? deliveryAddressPostalCode;
  final String? deliveryLandmark;
  final String? deliveryInstructions;

  OrderTracking({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.createdAt,
    this.deliveredAt,
    this.deliveryAgentId,
    this.currentLocation,
    this.estimatedDeliveryTime,
    required this.statusHistory,
    this.proofOfDeliveryPhotoUrl,
    this.notes,
    this.deliveryAddressStreet,
    this.deliveryAddressCity,
    this.deliveryAddressPostalCode,
    this.deliveryLandmark,
    this.deliveryInstructions,
  });

  factory OrderTracking.fromFirestore(Map<String, dynamic> data) {
    return OrderTracking(
      orderId: data['orderId'] as String,
      orderNumber: data['orderNumber'] as String,
      status: data['status'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      deliveredAt: data['deliveredAt'] != null ? DateTime.parse(data['deliveredAt'] as String) : null,
      deliveryAgentId: data['deliveryAgentId'] as String?,
      currentLocation: data['currentLocation'] != null
          ? LatLng(
              (data['currentLocation']['latitude'] as num).toDouble(),
              (data['currentLocation']['longitude'] as num).toDouble(),
            )
          : null,
      estimatedDeliveryTime: data['estimatedDeliveryTime'] != null ? DateTime.parse(data['estimatedDeliveryTime'] as String) : null,
      statusHistory: (data['statusHistory'] as List<dynamic>?)?.map((e) => StatusEvent.fromMap(e as Map<String, dynamic>)).toList() ?? [],
      proofOfDeliveryPhotoUrl: data['proofOfDeliveryPhotoUrl'] as String?,
      notes: data['notes'] as String?,
      deliveryAddressStreet: data['deliveryAddressStreet'] as String?,
      deliveryAddressCity: data['deliveryAddressCity'] as String?,
      deliveryAddressPostalCode: data['deliveryAddressPostalCode'] as String?,
      deliveryLandmark: data['deliveryLandmark'] as String?,
      deliveryInstructions: data['deliveryInstructions'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'orderId': orderId,
    'orderNumber': orderNumber,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'deliveredAt': deliveredAt?.toIso8601String(),
    'deliveryAgentId': deliveryAgentId,
    'currentLocation': currentLocation != null
        ? {
            'latitude': currentLocation!.latitude,
            'longitude': currentLocation!.longitude,
          }
        : null,
    'estimatedDeliveryTime': estimatedDeliveryTime?.toIso8601String(),
    'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
    'proofOfDeliveryPhotoUrl': proofOfDeliveryPhotoUrl,
    'notes': notes,
    'deliveryAddressStreet': deliveryAddressStreet,
    'deliveryAddressCity': deliveryAddressCity,
    'deliveryAddressPostalCode': deliveryAddressPostalCode,
    'deliveryLandmark': deliveryLandmark,
    'deliveryInstructions': deliveryInstructions,
  };

  bool get isDelivered => status == 'delivered';
  bool get isOutForDelivery => status == 'shipped';
  bool get isCancelled => status == 'cancelled';
  Duration get timeUntilDelivery => estimatedDeliveryTime?.difference(DateTime.now()) ?? Duration.zero;

  OrderTracking copyWith({
    String? status,
    LatLng? currentLocation,
    DateTime? estimatedDeliveryTime,
    List<StatusEvent>? statusHistory,
    DateTime? deliveredAt,
  }) {
    return OrderTracking(
      orderId: orderId,
      orderNumber: orderNumber,
      status: status ?? this.status,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      deliveryAgentId: deliveryAgentId,
      currentLocation: currentLocation ?? this.currentLocation,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      statusHistory: statusHistory ?? this.statusHistory,
      proofOfDeliveryPhotoUrl: proofOfDeliveryPhotoUrl,
      notes: notes,
      deliveryAddressStreet: deliveryAddressStreet,
      deliveryAddressCity: deliveryAddressCity,
      deliveryAddressPostalCode: deliveryAddressPostalCode,
      deliveryLandmark: deliveryLandmark,
      deliveryInstructions: deliveryInstructions,
    );
  }
}

class StatusEvent {
  final String status;
  final DateTime timestamp;
  final String description;
  final String? notes;

  StatusEvent({
    required this.status,
    required this.timestamp,
    required this.description,
    this.notes,
  });

  factory StatusEvent.fromMap(Map<String, dynamic> map) => StatusEvent(
    status: map['status'] as String,
    timestamp: DateTime.parse(map['timestamp'] as String),
    description: map['description'] as String,
    notes: map['notes'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'status': status,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'notes': notes,
  };
}
