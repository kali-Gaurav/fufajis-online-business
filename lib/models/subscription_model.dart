enum SubscriptionFrequency { daily, weekly, alternateDays, custom }
enum SubscriptionStatus { active, paused, cancelled }

class SubscriptionModel {
  final String id;
  final String customerId;
  final String productId;
  final String productName;
  final String productImage;
  final String unit;
  final double price;
  final SubscriptionFrequency frequency;
  final int quantity;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime? pauseUntil; // Feature 14: Vacation Mode support
  final List<DateTime> deliveryDates; // Feature 14: Specific dates for custom frequency
  final String timeSlot;
  final DateTime createdAt;
  
  bool get isActive => status == SubscriptionStatus.active && (pauseUntil == null || DateTime.now().isAfter(pauseUntil!));
  bool get isPaused => status == SubscriptionStatus.paused || (pauseUntil != null && DateTime.now().isBefore(pauseUntil!));

  SubscriptionModel({
    required this.id,
    required this.customerId,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.unit,
    required this.price,
    required this.frequency,
    required this.quantity,
    required this.status,
    required this.startDate,
    this.pauseUntil,
    this.deliveryDates = const [],
    required this.timeSlot,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'unit': unit,
      'price': price,
      'frequency': frequency.toString(),
      'quantity': quantity,
      'status': status.toString(),
      'startDate': startDate.toIso8601String(),
      'pauseUntil': pauseUntil?.toIso8601String(),
      'deliveryDates': deliveryDates.map((d) => d.toIso8601String()).toList(),
      'timeSlot': timeSlot,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    return SubscriptionModel(
      id: map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productImage: map['productImage'] ?? '',
      unit: map['unit'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      frequency: SubscriptionFrequency.values.firstWhere(
        (e) => e.toString() == map['frequency'],
        orElse: () => SubscriptionFrequency.daily,
      ),
      quantity: map['quantity'] ?? 1,
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => SubscriptionStatus.active,
      ),
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : DateTime.now(),
      pauseUntil: map['pauseUntil'] != null ? DateTime.parse(map['pauseUntil']) : null,
      deliveryDates: (map['deliveryDates'] as List?)
              ?.map((d) => DateTime.parse(d as String))
              .toList() ??
          [],
      timeSlot: map['timeSlot'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }

  SubscriptionModel copyWith({
    String? id,
    String? customerId,
    String? productId,
    String? productName,
    String? productImage,
    String? unit,
    double? price,
    SubscriptionFrequency? frequency,
    int? quantity,
    SubscriptionStatus? status,
    DateTime? startDate,
    DateTime? pauseUntil,
    List<DateTime>? deliveryDates,
    String? timeSlot,
    DateTime? createdAt,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      frequency: frequency ?? this.frequency,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      pauseUntil: pauseUntil ?? this.pauseUntil,
      deliveryDates: deliveryDates ?? this.deliveryDates,
      timeSlot: timeSlot ?? this.timeSlot,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
