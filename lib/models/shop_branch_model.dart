import 'shop_config_model.dart';

class ShopBranchModel {
  final String id;
  final String branchName;
  String get name => branchName;
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

  ShopBranchModel({
    required this.id,
    required this.branchName,
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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branchName': branchName,
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
    };
  }

  factory ShopBranchModel.fromMap(Map<String, dynamic> map) {
    return ShopBranchModel(
      id: map['id'] ?? '',
      branchName: map['branchName'] ?? '',
      branchAddress: map['branchAddress'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      deliveryRadiusKm: (map['deliveryRadiusKm'] ?? 8.0).toDouble(),
      deliveryZones:
          (map['deliveryZones'] as List<dynamic>?)
              ?.map(
                (z) =>
                    DeliveryZone.fromMap(Map<String, dynamic>.from(z as Map)),
              )
              .toList() ??
          [],
      isPrimary: map['isPrimary'] ?? false,
      isActive: map['isActive'] ?? true,
      operatingHours:
          (map['operatingHours'] as Map<dynamic, dynamic>?)?.map(
            (k, v) => MapEntry(
              k.toString(),
              OperatingHours.fromMap(Map<String, dynamic>.from(v as Map)),
            ),
          ) ??
          {},
      contactPhone: map['contactPhone'],
      managerId: map['managerId'],
    );
  }

  ShopBranchModel copyWith({
    String? id,
    String? branchName,
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
  }) {
    return ShopBranchModel(
      id: id ?? this.id,
      branchName: branchName ?? this.branchName,
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
    );
  }
}
