class ShopConfigModel {
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String shopEmail;
  final String? shopLogoUrl;
  final bool isOpen;

  final double shopLatitude;
  final double shopLongitude;

  final double maxDeliveryRadiusKm;
  final List<DeliveryZone> deliveryZones;

  final double minOrderAmount;
  final double minOrderForFreeDelivery;
  final double flatDeliveryFee;

  final Map<String, OperatingHours> operatingHours;
  final bool autoCloseOutsideHours;

  final double maxCodLimit;
  final double maxCreditLimit;
  final int maxOrdersPerSlot;
  final int sameDayCutoffHour;
  final bool enableCashback;
  final double cashbackPercentage;
  final bool enableLoyaltyPoints;
  final bool isAutoPilotEnabled;
  final bool isEmergencyMode;

  // Billing/Delivery Logic
  final double expressDeliveryFee;
  final double baseDeliveryRadiusKm;
  final double deliveryFeePerKm;
  final double freeDeliveryThreshold;
  final double standardDeliveryFee;

  ShopConfigModel({
    required this.shopName,
    required this.shopAddress,
    required this.shopPhone,
    required this.shopEmail,
    this.shopLogoUrl,
    required this.isOpen,
    required this.shopLatitude,
    required this.shopLongitude,
    required this.maxDeliveryRadiusKm,
    required this.deliveryZones,
    required this.minOrderAmount,
    required this.minOrderForFreeDelivery,
    required this.flatDeliveryFee,
    required this.operatingHours,
    required this.autoCloseOutsideHours,
    required this.maxCodLimit,
    required this.maxCreditLimit,
    required this.maxOrdersPerSlot,
    required this.sameDayCutoffHour,
    required this.enableCashback,
    required this.cashbackPercentage,
    required this.enableLoyaltyPoints,
    required this.isAutoPilotEnabled,
    this.isEmergencyMode = false,
    this.expressDeliveryFee = 50.0,
    this.baseDeliveryRadiusKm = 5.0,
    this.deliveryFeePerKm = 5.0,
    this.freeDeliveryThreshold = 500.0,
    this.standardDeliveryFee = 30.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'shopName': shopName,
      'shopAddress': shopAddress,
      'shopPhone': shopPhone,
      'shopEmail': shopEmail,
      'shopLogoUrl': shopLogoUrl,
      'isOpen': isOpen,
      'shopLatitude': shopLatitude,
      'shopLongitude': shopLongitude,
      'maxDeliveryRadiusKm': maxDeliveryRadiusKm,
      'deliveryZones': deliveryZones.map((z) => z.toMap()).toList(),
      'minOrderAmount': minOrderAmount,
      'minOrderForFreeDelivery': minOrderForFreeDelivery,
      'flatDeliveryFee': flatDeliveryFee,
      'operatingHours': operatingHours.map((k, v) => MapEntry(k, v.toMap())),
      'autoCloseOutsideHours': autoCloseOutsideHours,
      'maxCodLimit': maxCodLimit,
      'maxCreditLimit': maxCreditLimit,
      'maxOrdersPerSlot': maxOrdersPerSlot,
      'sameDayCutoffHour': sameDayCutoffHour,
      'enableCashback': enableCashback,
      'cashbackPercentage': cashbackPercentage,
      'enableLoyaltyPoints': enableLoyaltyPoints,
      'isAutoPilotEnabled': isAutoPilotEnabled,
      'isEmergencyMode': isEmergencyMode,
      'expressDeliveryFee': expressDeliveryFee,
      'baseDeliveryRadiusKm': baseDeliveryRadiusKm,
      'deliveryFeePerKm': deliveryFeePerKm,
      'freeDeliveryThreshold': freeDeliveryThreshold,
      'standardDeliveryFee': standardDeliveryFee,
    };
  }

  factory ShopConfigModel.fromMap(Map<String, dynamic> map) {
    return ShopConfigModel(
      shopName: map['shopName'] as String? ?? 'Fufaji Online Store',
      shopAddress: map['shopAddress'] as String? ?? '',
      shopPhone: map['shopPhone'] as String? ?? '',
      shopEmail: map['shopEmail'] as String? ?? '',
      shopLogoUrl: map['shopLogoUrl'] as String?,
      isOpen: map['isOpen'] as bool? ?? true,
      shopLatitude: (map['shopLatitude'] as num? ?? 26.9124).toDouble(),
      shopLongitude: (map['shopLongitude'] as num? ?? 75.7873).toDouble(),
      maxDeliveryRadiusKm: (map['maxDeliveryRadiusKm'] as num? ?? 8.0).toDouble(),
      deliveryZones:
          (map['deliveryZones'] as List?)
              ?.map((z) => DeliveryZone.fromMap(Map<String, dynamic>.from(z as Map)))
              .toList() ??
          [],
      minOrderAmount: (map['minOrderAmount'] as num? ?? 0.0).toDouble(),
      minOrderForFreeDelivery: (map['minOrderForFreeDelivery'] as num? ?? 500.0).toDouble(),
      flatDeliveryFee: (map['flatDeliveryFee'] as num? ?? 40.0).toDouble(),
      operatingHours:
          (map['operatingHours'] as Map?)?.map(
            (k, v) =>
                MapEntry(k.toString(), OperatingHours.fromMap(Map<String, dynamic>.from(v as Map))),
          ) ??
          {},
      autoCloseOutsideHours: map['autoCloseOutsideHours'] as bool? ?? false,
      maxCodLimit: (map['maxCodLimit'] as num? ?? 5000.0).toDouble(),
      maxCreditLimit: (map['maxCreditLimit'] as num? ?? 2000.0).toDouble(),
      maxOrdersPerSlot: map['maxOrdersPerSlot'] as int? ?? 10,
      sameDayCutoffHour: map['sameDayCutoffHour'] as int? ?? 18,
      enableCashback: map['enableCashback'] as bool? ?? false,
      cashbackPercentage: (map['cashbackPercentage'] as num? ?? 5.0).toDouble(),
      enableLoyaltyPoints: map['enableLoyaltyPoints'] as bool? ?? false,
      isAutoPilotEnabled: map['isAutoPilotEnabled'] as bool? ?? false,
      isEmergencyMode: map['isEmergencyMode'] as bool? ?? false,
      expressDeliveryFee: (map['expressDeliveryFee'] as num? ?? 50.0).toDouble(),
      baseDeliveryRadiusKm: (map['baseDeliveryRadiusKm'] as num? ?? 5.0).toDouble(),
      deliveryFeePerKm: (map['deliveryFeePerKm'] as num? ?? 5.0).toDouble(),
      freeDeliveryThreshold: (map['freeDeliveryThreshold'] as num? ?? 500.0).toDouble(),
      standardDeliveryFee: (map['standardDeliveryFee'] as num? ?? 30.0).toDouble(),
    );
  }

  ShopConfigModel copyWith({
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    String? shopEmail,
    String? shopLogoUrl,
    bool? isOpen,
    double? shopLatitude,
    double? shopLongitude,
    double? maxDeliveryRadiusKm,
    List<DeliveryZone>? deliveryZones,
    double? minOrderAmount,
    double? minOrderForFreeDelivery,
    double? flatDeliveryFee,
    Map<String, OperatingHours>? operatingHours,
    bool? autoCloseOutsideHours,
    double? maxCodLimit,
    double? maxCreditLimit,
    int? maxOrdersPerSlot,
    int? sameDayCutoffHour,
    bool? enableCashback,
    double? cashbackPercentage,
    bool? enableLoyaltyPoints,
    bool? isAutoPilotEnabled,
    bool? isEmergencyMode,
  }) {
    return ShopConfigModel(
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      shopPhone: shopPhone ?? this.shopPhone,
      shopEmail: shopEmail ?? this.shopEmail,
      shopLogoUrl: shopLogoUrl ?? this.shopLogoUrl,
      isOpen: isOpen ?? this.isOpen,
      shopLatitude: shopLatitude ?? this.shopLatitude,
      shopLongitude: shopLongitude ?? this.shopLongitude,
      maxDeliveryRadiusKm: maxDeliveryRadiusKm ?? this.maxDeliveryRadiusKm,
      deliveryZones: deliveryZones ?? this.deliveryZones,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      minOrderForFreeDelivery: minOrderForFreeDelivery ?? this.minOrderForFreeDelivery,
      flatDeliveryFee: flatDeliveryFee ?? this.flatDeliveryFee,
      operatingHours: operatingHours ?? this.operatingHours,
      autoCloseOutsideHours: autoCloseOutsideHours ?? this.autoCloseOutsideHours,
      maxCodLimit: maxCodLimit ?? this.maxCodLimit,
      maxCreditLimit: maxCreditLimit ?? this.maxCreditLimit,
      maxOrdersPerSlot: maxOrdersPerSlot ?? this.maxOrdersPerSlot,
      sameDayCutoffHour: sameDayCutoffHour ?? this.sameDayCutoffHour,
      enableCashback: enableCashback ?? this.enableCashback,
      cashbackPercentage: cashbackPercentage ?? this.cashbackPercentage,
      enableLoyaltyPoints: enableLoyaltyPoints ?? this.enableLoyaltyPoints,
      isAutoPilotEnabled: isAutoPilotEnabled ?? this.isAutoPilotEnabled,
      isEmergencyMode: isEmergencyMode ?? this.isEmergencyMode,
    );
  }
}

class DeliveryZone {
  final String id;
  final String label;
  final double fromRadiusKm;
  final double toRadiusKm;
  final double deliveryCharge;
  final double minOrderForFree;
  final bool isActive;

  DeliveryZone({
    required this.id,
    required this.label,
    required this.fromRadiusKm,
    required this.toRadiusKm,
    required this.deliveryCharge,
    required this.minOrderForFree,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'fromRadiusKm': fromRadiusKm,
      'toRadiusKm': toRadiusKm,
      'deliveryCharge': deliveryCharge,
      'minOrderForFree': minOrderForFree,
      'isActive': isActive,
    };
  }

  factory DeliveryZone.fromMap(Map<String, dynamic> map) {
    return DeliveryZone(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      fromRadiusKm: (map['fromRadiusKm'] as num? ?? 0.0).toDouble(),
      toRadiusKm: (map['toRadiusKm'] as num? ?? 0.0).toDouble(),
      deliveryCharge: (map['deliveryCharge'] as num? ?? 0.0).toDouble(),
      minOrderForFree: (map['minOrderForFree'] as num? ?? 0.0).toDouble(),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  DeliveryZone copyWith({
    String? id,
    String? label,
    double? fromRadiusKm,
    double? toRadiusKm,
    double? deliveryCharge,
    double? minOrderForFree,
    bool? isActive,
  }) {
    return DeliveryZone(
      id: id ?? this.id,
      label: label ?? this.label,
      fromRadiusKm: fromRadiusKm ?? this.fromRadiusKm,
      toRadiusKm: toRadiusKm ?? this.toRadiusKm,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      minOrderForFree: minOrderForFree ?? this.minOrderForFree,
      isActive: isActive ?? this.isActive,
    );
  }
}

class OperatingHours {
  final bool isOpen;
  final String openTime;
  final String closeTime;

  OperatingHours({required this.isOpen, required this.openTime, required this.closeTime});

  Map<String, dynamic> toMap() {
    return {'isOpen': isOpen, 'openTime': openTime, 'closeTime': closeTime};
  }

  factory OperatingHours.fromMap(Map<String, dynamic> map) {
    return OperatingHours(
      isOpen: map['isOpen'] as bool? ?? false,
      openTime: map['openTime'] as String? ?? '09:00',
      closeTime: map['closeTime'] as String? ?? '21:00',
    );
  }
}
