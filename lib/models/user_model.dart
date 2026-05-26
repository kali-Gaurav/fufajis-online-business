enum UserRole { customer, shopOwner, deliveryAgent, admin }

enum MembershipTier { bronze, silver, gold, platinum }

class UserModel {
  final String id;
  final String phoneNumber;
  final String? email;
  final String? name;
  final String? profileImage;
  final UserRole role;
  final MembershipTier membershipTier;
  final double walletBalance;
  final int rewardPoints;
  final bool isVerified;
  final bool isActive;
  final String? fcmToken;
  final String? district;
  final String? village;
  final List<String> savedAddresses;
  final List<String> familyMemberIds;
  final List<String> savedPaymentMethods;
  final double creditBalance; // Total amount owed by customer (Khata)
  final double creditLimit; // Max credit allowed to customer
  final double codLimit;
  final DateTime createdAt;
  final DateTime lastLogin;

  UserModel({
    required this.id,
    required this.phoneNumber,
    this.email,
    this.name,
    this.profileImage,
    this.role = UserRole.customer,
    this.membershipTier = MembershipTier.bronze,
    this.walletBalance = 0.0,
    this.rewardPoints = 0,
    this.isVerified = false,
    this.isActive = true,
    this.fcmToken,
    this.district,
    this.village,
    this.savedAddresses = const [],
    this.familyMemberIds = const [],
    this.savedPaymentMethods = const [],
    this.creditBalance = 0.0,
    this.creditLimit = 5000.0,
    this.codLimit = 2000.0,
    required this.createdAt,
    required this.lastLogin,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'],
      name: map['name'],
      profileImage: map['profileImage'],
      role: UserRole.values.firstWhere(
        (e) => e.toString() == map['role'],
        orElse: () => UserRole.customer,
      ),
      membershipTier: MembershipTier.values.firstWhere(
        (e) => e.toString() == map['membershipTier'],
        orElse: () => MembershipTier.bronze,
      ),
      walletBalance: (map['walletBalance'] ?? 0.0).toDouble(),
      rewardPoints: map['rewardPoints'] ?? 0,
      isVerified: map['isVerified'] ?? false,
      isActive: map['isActive'] ?? true,
      fcmToken: map['fcmToken'],
      district: map['district'],
      village: map['village'],
      savedAddresses: List<String>.from(map['savedAddresses'] ?? []),
      familyMemberIds: List<String>.from(map['familyMemberIds'] ?? []),
      savedPaymentMethods: List<String>.from(map['savedPaymentMethods'] ?? []),
      creditBalance: (map['creditBalance'] ?? 0.0).toDouble(),
      creditLimit: (map['creditLimit'] ?? 5000.0).toDouble(),
      codLimit: (map['codLimit'] ?? 2000.0).toDouble(),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      lastLogin: map['lastLogin']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'email': email,
      'name': name,
      'profileImage': profileImage,
      'role': role.toString(),
      'membershipTier': membershipTier.toString(),
      'walletBalance': walletBalance,
      'rewardPoints': rewardPoints,
      'isVerified': isVerified,
      'isActive': isActive,
      'fcmToken': fcmToken,
      'district': district,
      'village': village,
      'savedAddresses': savedAddresses,
      'familyMemberIds': familyMemberIds,
      'savedPaymentMethods': savedPaymentMethods,
      'creditBalance': creditBalance,
      'creditLimit': creditLimit,
      'codLimit': codLimit,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
    };
  }

  UserModel copyWith({
    String? id,
    String? phoneNumber,
    String? email,
    String? name,
    String? profileImage,
    UserRole? role,
    MembershipTier? membershipTier,
    double? walletBalance,
    int? rewardPoints,
    bool? isVerified,
    bool? isActive,
    String? fcmToken,
    String? district,
    String? village,
    List<String>? savedAddresses,
    List<String>? familyMemberIds,
    List<String>? savedPaymentMethods,
    double? creditBalance,
    double? creditLimit,
    double? codLimit,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImage: profileImage ?? this.profileImage,
      role: role ?? this.role,
      membershipTier: membershipTier ?? this.membershipTier,
      walletBalance: walletBalance ?? this.walletBalance,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      fcmToken: fcmToken ?? this.fcmToken,
      district: district ?? this.district,
      village: village ?? this.village,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      familyMemberIds: familyMemberIds ?? this.familyMemberIds,
      savedPaymentMethods: savedPaymentMethods ?? this.savedPaymentMethods,
      creditBalance: creditBalance ?? this.creditBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      codLimit: codLimit ?? this.codLimit,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}

class Address {
  final String id;
  final String label;
  final String fullAddress;
  final String village;
  final String landmark;
  final String pincode;
  final double latitude;
  final double longitude;
  final bool isDefault;
  final String? deliveryInstructions;

  String get street => fullAddress;
  String get district => pincode;

  Address({
    required this.id,
    required this.label,
    required this.fullAddress,
    required this.village,
    required this.landmark,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
    this.deliveryInstructions,
  });

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: map['id'] ?? '',
      label: map['label'] ?? 'Home',
      fullAddress: map['fullAddress'] ?? '',
      village: map['village'] ?? '',
      landmark: map['landmark'] ?? '',
      pincode: map['pincode'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      isDefault: map['isDefault'] ?? false,
      deliveryInstructions: map['deliveryInstructions'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'fullAddress': fullAddress,
      'village': village,
      'landmark': landmark,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
      'deliveryInstructions': deliveryInstructions,
    };
  }

  Address copyWith({
    String? id,
    String? label,
    String? fullAddress,
    String? village,
    String? landmark,
    String? pincode,
    double? latitude,
    double? longitude,
    bool? isDefault,
    String? deliveryInstructions,
  }) {
    return Address(
      id: id ?? this.id,
      label: label ?? this.label,
      fullAddress: fullAddress ?? this.fullAddress,
      village: village ?? this.village,
      landmark: landmark ?? this.landmark,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      deliveryInstructions:
          deliveryInstructions ?? this.deliveryInstructions,
    );
  }
}
