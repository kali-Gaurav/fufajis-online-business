import 'package:cloud_firestore/cloud_firestore.dart';

enum AddressType { home, work, other }

class AddressModel {
  final String id;
  final String street;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final double latitude;
  final double longitude;
  final bool isDefault;
  final AddressType addressType;
  final String? landmark;
  final String? deliveryInstructions;
  final DateTime createdAt;
  final DateTime updatedAt;

  AddressModel({
    required this.id,
    required this.street,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
    this.addressType = AddressType.home,
    this.landmark,
    this.deliveryInstructions,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Parse DateTime from various sources (Firestore Timestamp, String, DateTime, or null)
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  factory AddressModel.fromFirestore(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id'] as String? ?? '',
      street: map['street'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      postalCode: map['postalCode'] as String? ?? '',
      country: map['country'] as String? ?? 'India',
      latitude: (map['latitude'] as num? ?? 0.0).toDouble(),
      longitude: (map['longitude'] as num? ?? 0.0).toDouble(),
      isDefault: map['isDefault'] as bool? ?? false,
      addressType: AddressType.values.firstWhere(
        (e) => e.toString() == map['addressType'] as String?,
        orElse: () => AddressType.home,
      ),
      landmark: map['landmark'] as String?,
      deliveryInstructions: map['deliveryInstructions'] as String?,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel.fromFirestore(map);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'street': street,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
      'addressType': addressType.toString(),
      'landmark': landmark,
      'deliveryInstructions': deliveryInstructions,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toMap() {
    return toFirestore();
  }

  AddressModel copyWith({
    String? id,
    String? street,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    double? latitude,
    double? longitude,
    bool? isDefault,
    AddressType? addressType,
    String? landmark,
    String? deliveryInstructions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      addressType: addressType ?? this.addressType,
      landmark: landmark ?? this.landmark,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return '$street, $city, $state $postalCode, $country';
  }
}
