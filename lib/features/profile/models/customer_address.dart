class CustomerAddress {
  final String id;
  final String? label;
  final String recipientName;
  final String phone;
  final String? houseNumber;
  final String? street;
  final String? landmark;
  final String? village;
  final String city;
  final String? district;
  final String? state;
  final String? postalCode;
  final String country;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final String? deliveryNotes;
  final String? addressType;
  final bool isVerified;

  CustomerAddress({
    required this.id,
    this.label,
    required this.recipientName,
    required this.phone,
    this.houseNumber,
    this.street,
    this.landmark,
    this.village,
    required this.city,
    this.district,
    this.state,
    this.postalCode,
    this.country = 'India',
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.deliveryNotes,
    this.addressType,
    this.isVerified = false,
  });

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      id: json['id'] as String? ?? '',
      label: json['label'] as String?,
      recipientName: json['recipient_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      houseNumber: json['house_number'] as String?,
      street: json['street'] as String?,
      landmark: json['landmark'] as String?,
      village: json['village'] as String?,
      city: json['city'] as String? ?? '',
      district: json['district'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String? ?? 'India',
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      isDefault: json['is_default'] as bool? ?? false,
      deliveryNotes: json['delivery_notes'] as String?,
      addressType: json['address_type'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'recipient_name': recipientName,
      'phone': phone,
      'house_number': houseNumber,
      'street': street,
      'landmark': landmark,
      'village': village,
      'city': city,
      'district': district,
      'state': state,
      'postal_code': postalCode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
      'delivery_notes': deliveryNotes,
      'address_type': addressType,
    };
  }

  String get formattedAddress {
    final parts = [
      houseNumber,
      street,
      landmark,
      village,
      city,
      state,
      postalCode,
    ].where((part) => part != null && part.isNotEmpty).toList();
    return parts.join(', ');
  }
}
