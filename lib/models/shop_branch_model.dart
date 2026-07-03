import 'shop_config_model.dart';

class ShopBranchModel {
  final String id;
  final String branchName;
  String get name => branchName;
  final String city;
  final String state;
  final String branchAddress;
  final double latitude;
  final double longitude;
  final double deliveryRadiusKm;
  final List<DeliveryZone> deliveryZones;
  final bool isPrimary;
  final bool isActive;
  final Map<String, OperatingHours> operatingHours;
  final String? contactPhone;
  final String? managerId;
  final double franchiseCommissionPercent;
  final double platformFeePercent;

  ShopBranchModel({
    required this.id,
    required this.branchName,
    this.city = '',
    this.state = '',
    required this.branchAddress,
    required this.latitude,
    required this.longitude,
    required this.deliveryRadiusKm,
    required this.deliveryZones,
    required this.isPrimary,
    required this.isActive,
    required this.operatingHours,
    this.contactPhone,
    this.managerId,
    this.franchiseCommissionPercent = 0.0,
    this.platformFeePercent = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branchName': branchName,
      'city': city,
      'state': state,
      'branchAddress': branchAddress,
      'latitude': latitude,
      'longitude': longitude,
      'deliveryRadiusKm': deliveryRadiusKm,
      'deliveryZones': deliveryZones.map((z) => z.toMap()).toList(),
      'isPrimary': isPrimary,
      'isActive': isActive,
      'operatingHours': operatingHours.map((k, v) => MapEntry(k, v.toMap())),
      'contactPhone': contactPhone,
      'managerId': managerId,
      'franchiseCommissionPercent': franchiseCommissionPercent,
      'platformFeePercent': platformFeePercent,
    };
  }

  factory ShopBranchModel.fromMap(Map<String, dynamic> map) {
    return ShopBranchModel(
      id: map['id'] as String? ?? '',
      branchName: map['branchName'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      branchAddress: map['branchAddress'] as String? ?? '',
      latitude: (map['latitude'] as num? ?? 0.0).toDouble(),
      longitude: (map['longitude'] as num? ?? 0.0).toDouble(),
      deliveryRadiusKm: (map['deliveryRadiusKm'] as num? ?? 8.0).toDouble(),
      deliveryZones:
          (map['deliveryZones'] as List?)
              ?.map((z) => DeliveryZone.fromMap(Map<String, dynamic>.from(z as Map)))
              .toList() ??
          [],
      isPrimary: map['isPrimary'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      operatingHours:
          (map['operatingHours'] as Map?)?.map(
            (k, v) =>
                MapEntry(k.toString(), OperatingHours.fromMap(Map<String, dynamic>.from(v as Map))),
          ) ??
          {},
      contactPhone: map['contactPhone'] as String?,
      managerId: map['managerId'] as String?,
      franchiseCommissionPercent: (map['franchiseCommissionPercent'] as num? ?? 0.0).toDouble(),
      platformFeePercent: (map['platformFeePercent'] as num? ?? 0.0).toDouble(),
    );
  }

  ShopBranchModel copyWith({
    String? id,
    String? branchName,
    String? city,
    String? state,
    String? branchAddress,
    double? latitude,
    double? longitude,
    double? deliveryRadiusKm,
    List<DeliveryZone>? deliveryZones,
    bool? isPrimary,
    bool? isActive,
    Map<String, OperatingHours>? operatingHours,
    String? contactPhone,
    String? managerId,
    double? franchiseCommissionPercent,
    double? platformFeePercent,
  }) {
    return ShopBranchModel(
      id: id ?? this.id,
      branchName: branchName ?? this.branchName,
      city: city ?? this.city,
      state: state ?? this.state,
      branchAddress: branchAddress ?? this.branchAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      deliveryRadiusKm: deliveryRadiusKm ?? this.deliveryRadiusKm,
      deliveryZones: deliveryZones ?? this.deliveryZones,
      isPrimary: isPrimary ?? this.isPrimary,
      isActive: isActive ?? this.isActive,
      operatingHours: operatingHours ?? this.operatingHours,
      contactPhone: contactPhone ?? this.contactPhone,
      managerId: managerId ?? this.managerId,
      franchiseCommissionPercent: franchiseCommissionPercent ?? this.franchiseCommissionPercent,
      platformFeePercent: platformFeePercent ?? this.platformFeePercent,
    );
  }
}
