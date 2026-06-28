import 'package:flutter/material.dart';

/// Delivery type options for order delivery
enum DeliveryType {
  standard,
  express,
  sameDay,
  villageDelivery,
  scheduled, // New feature
}

/// Extension on DeliveryType for display properties
extension DeliveryTypeExtension on DeliveryType {
  String get displayName {
    switch (this) {
      case DeliveryType.standard:
        return 'Standard Delivery';
      case DeliveryType.express:
        return 'Express Delivery';
      case DeliveryType.sameDay:
        return 'Same Day Delivery';
      case DeliveryType.villageDelivery:
        return 'Village Delivery';
      case DeliveryType.scheduled:
        return 'Scheduled Delivery';
    }
  }
}

/// Model representing a delivery type option with pricing and timing details
class DeliveryTypeOption {
  final DeliveryType type;
  final String name;
  final String description;
  final double price;
  final int estimatedDays;
  final String? estimatedTime;
  final bool isAvailable;
  final bool isEcoFriendly; // New feature

  const DeliveryTypeOption({
    required this.type,
    required this.name,
    required this.description,
    required this.price,
    required this.estimatedDays,
    this.estimatedTime,
    this.isAvailable = true,
    this.isEcoFriendly = false,
  });

  /// Get formatted price string
  String get priceString => price == 0 ? 'FREE' : '₹${price.round()}';

  /// Get estimated delivery date based on current date
  DateTime getEstimatedDeliveryDate() {
    final now = DateTime.now();
    return now.add(Duration(days: estimatedDays));
  }

  /// Get formatted delivery estimate
  String get deliveryEstimate {
    if (estimatedTime != null && estimatedTime!.isNotEmpty) {
      return estimatedTime!;
    }
    if (estimatedDays == 0) {
      return 'Today';
    } else if (estimatedDays == 1) {
      return 'Tomorrow';
    } else {
      return '$estimatedDays days';
    }
  }

  /// Standard delivery option
  static const DeliveryTypeOption standard = DeliveryTypeOption(
    type: DeliveryType.standard,
    name: 'Standard Delivery',
    description: 'Regular delivery within 2-3 business days',
    price: 0,
    estimatedDays: 2,
    estimatedTime: '2-3 days',
    isEcoFriendly: true,
  );

  /// Express delivery option (next day)
  static const DeliveryTypeOption express = DeliveryTypeOption(
    type: DeliveryType.express,
    name: 'Express Delivery',
    description: 'Fast delivery by next day',
    price: 50,
    estimatedDays: 1,
    estimatedTime: 'Next day',
  );

  /// Same day delivery option (within 8 hours)
  static const DeliveryTypeOption sameDay = DeliveryTypeOption(
    type: DeliveryType.sameDay,
    name: 'Same Day Delivery',
    description: 'Delivery within 8 hours',
    price: 100,
    estimatedDays: 0,
    estimatedTime: 'Within 8 hours',
  );

  /// Village delivery option (3-5 days based on distance)
  static const DeliveryTypeOption villageDelivery = DeliveryTypeOption(
    type: DeliveryType.villageDelivery,
    name: 'Village Delivery',
    description: 'Delivery to village areas (3-5 days based on distance)',
    price: 30,
    estimatedDays: 4,
    estimatedTime: '3-5 days',
  );

  /// Scheduled delivery option
  static const DeliveryTypeOption scheduled = DeliveryTypeOption(
    type: DeliveryType.scheduled,
    name: 'Scheduled Delivery',
    description: 'Choose your preferred date and time',
    price: 20,
    estimatedDays: 0,
    estimatedTime: 'Your chosen time',
  );

  /// Get all available delivery type options
  static List<DeliveryTypeOption> get allOptions {
    return [standard, express, sameDay, villageDelivery, scheduled];
  }

  /// Get delivery type option by type
  static DeliveryTypeOption fromType(DeliveryType type) {
    switch (type) {
      case DeliveryType.standard:
        return standard;
      case DeliveryType.express:
        return express;
      case DeliveryType.sameDay:
        return sameDay;
      case DeliveryType.villageDelivery:
        return villageDelivery;
      case DeliveryType.scheduled:
        return scheduled;
    }
  }

  /// Get icon for delivery type
  static IconData getIcon(DeliveryType type) {
    switch (type) {
      case DeliveryType.standard:
        return Icons.local_shipping_outlined;
      case DeliveryType.express:
        return Icons.flash_on;
      case DeliveryType.sameDay:
        return Icons.today;
      case DeliveryType.villageDelivery:
        return Icons.location_on;
      case DeliveryType.scheduled:
        return Icons.event_available;
    }
  }

  /// Get color for delivery type
  static Color getColor(DeliveryType type) {
    switch (type) {
      case DeliveryType.standard:
        return const Color(0xFF4CAF50);
      case DeliveryType.express:
        return const Color(0xFFFF9800);
      case DeliveryType.sameDay:
        return const Color(0xFFF44336);
      case DeliveryType.villageDelivery:
        return const Color(0xFF2196F3);
      case DeliveryType.scheduled:
        return const Color(0xFF9C27B0);
    }
  }

  factory DeliveryTypeOption.fromMap(Map<String, dynamic> map) {
    return DeliveryTypeOption(
      type: DeliveryType.values.firstWhere(
        (e) => e.toString() == map['type'] as String?,
        orElse: () => DeliveryType.standard,
      ),
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num? ?? 0).toDouble(),
      estimatedDays: map['estimatedDays'] as int? ?? 2,
      estimatedTime: map['estimatedTime'] as String?,
      isAvailable: map['isAvailable'] as bool? ?? true,
      isEcoFriendly: map['isEcoFriendly'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'name': name,
      'description': description,
      'price': price,
      'estimatedDays': estimatedDays,
      'estimatedTime': estimatedTime,
      'isAvailable': isAvailable,
      'isEcoFriendly': isEcoFriendly,
    };
  }

  DeliveryTypeOption copyWith({
    DeliveryType? type,
    String? name,
    String? description,
    double? price,
    int? estimatedDays,
    String? estimatedTime,
    bool? isAvailable,
    bool? isEcoFriendly,
  }) {
    return DeliveryTypeOption(
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      isAvailable: isAvailable ?? this.isAvailable,
      isEcoFriendly: isEcoFriendly ?? this.isEcoFriendly,
    );
  }
}
