import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  customer,
  shopOwner,
  deliveryAgent,
  admin,
  employee,
  owner,
  superAdmin,
  rider,
  dispatcher,
  branchManager,
  supplier,
  franchiseOwner
}

enum MembershipTier { bronze, silver, gold, platinum }

class UserModel {
  final String id;
  String get uid => id;
  final String phoneNumber;
  final String? email;
  final String? name;
  final String? profileImage;
  final UserRole role;
  final List<UserRole> roles;
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
  final double creditBalance;
  final double creditLimit;
  final double codLimit;
  final bool isBlocked;
  final String? pinHash;
  final bool biometricEnabled;
  final List<DeviceFingerprint> approvedDevices;
  final bool guestMigrated;
  final bool profileCompleted;
  final String? lastPhoneNumber;
  final List<String> linkedProviders;
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool mfaEnabled;
  final String? referralCode;
  final int referralCount;
  final double referralEarnings;
  final double maxCashInHand;
  final String? branchId;

  UserModel({
    required this.id,
    required this.phoneNumber,
    this.email,
    this.name,
    this.profileImage,
    this.role = UserRole.customer,
    this.roles = const [UserRole.customer],
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
    this.isBlocked = false,
    this.pinHash,
    this.biometricEnabled = false,
    this.approvedDevices = const [],
    this.guestMigrated = false,
    this.profileCompleted = false,
    this.lastPhoneNumber,
    this.linkedProviders = const ['phone'],
    required this.createdAt,
    required this.lastLogin,
    this.mfaEnabled = false,
    this.referralCode,
    this.referralCount = 0,
    this.referralEarnings = 0.0,
    this.maxCashInHand = 10000.0,
    this.branchId,
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
      roles: (map['roles'] as List<dynamic>?)
              ?.map(
                (r) => UserRole.values.firstWhere(
                  (e) => e.toString() == r,
                  orElse: () => UserRole.customer,
                ),
              )
              .toList() ??
          [UserRole.customer],
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
      isBlocked: map['isBlocked'] ?? false,
      pinHash: map['pinHash'],
      biometricEnabled: map['biometricEnabled'] ?? false,
      approvedDevices: (map['approvedDevices'] as List<dynamic>?)
              ?.map((d) => DeviceFingerprint.fromMap(d))
              .toList() ??
          [],
      guestMigrated: map['guestMigrated'] ?? false,
      profileCompleted: map['profileCompleted'] ?? false,
      lastPhoneNumber: map['lastPhoneNumber'],
      linkedProviders: List<String>.from(map['linkedProviders'] ?? ['phone']),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastLogin: map['lastLogin'] is Timestamp
          ? (map['lastLogin'] as Timestamp).toDate()
          : DateTime.now(),
      mfaEnabled: map['mfaEnabled'] ?? false,
      referralCode: map['referralCode'],
      referralCount: map['referralCount'] ?? 0,
      referralEarnings: (map['referralEarnings'] ?? 0.0).toDouble(),
      maxCashInHand: (map['maxCashInHand'] ?? 10000.0).toDouble(),
      branchId: map['branchId'],
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
      'roles': roles.map((r) => r.toString()).toList(),
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
      'isBlocked': isBlocked,
      'pinHash': pinHash,
      'biometricEnabled': biometricEnabled,
      'approvedDevices': approvedDevices.map((d) => d.toMap()).toList(),
      'guestMigrated': guestMigrated,
      'profileCompleted': profileCompleted,
      'lastPhoneNumber': lastPhoneNumber,
      'linkedProviders': linkedProviders,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
      'mfaEnabled': mfaEnabled,
      'referralCode': referralCode,
      'referralCount': referralCount,
      'referralEarnings': referralEarnings,
      'maxCashInHand': maxCashInHand,
      'branchId': branchId,
    };
  }

  UserModel copyWith({
    String? id,
    String? phoneNumber,
    String? email,
    String? name,
    String? profileImage,
    UserRole? role,
    List<UserRole>? roles,
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
    bool? isBlocked,
    String? pinHash,
    bool? biometricEnabled,
    List<DeviceFingerprint>? approvedDevices,
    bool? guestMigrated,
    bool? profileCompleted,
    String? lastPhoneNumber,
    List<String>? linkedProviders,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? mfaEnabled,
    String? referralCode,
    int? referralCount,
    double? referralEarnings,
    double? maxCashInHand,
    String? branchId,
  }) {
    return UserModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImage: profileImage ?? this.profileImage,
      role: role ?? this.role,
      roles: roles ?? this.roles,
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
      isBlocked: isBlocked ?? this.isBlocked,
      pinHash: pinHash ?? this.pinHash,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      approvedDevices: approvedDevices ?? this.approvedDevices,
      guestMigrated: guestMigrated ?? this.guestMigrated,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      lastPhoneNumber: lastPhoneNumber ?? this.lastPhoneNumber,
      linkedProviders: linkedProviders ?? this.linkedProviders,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      mfaEnabled: mfaEnabled ?? this.mfaEnabled,
      referralCode: referralCode ?? this.referralCode,
      referralCount: referralCount ?? this.referralCount,
      referralEarnings: referralEarnings ?? this.referralEarnings,
      maxCashInHand: maxCashInHand ?? this.maxCashInHand,
      branchId: branchId ?? this.branchId,
    );
  }
}

class DeviceFingerprint {
  final String deviceId;
  final String deviceName;
  final bool approved;
  final DateTime registeredAt;

  DeviceFingerprint({
    required this.deviceId,
    required this.deviceName,
    this.approved = false,
    required this.registeredAt,
  });

  factory DeviceFingerprint.fromMap(Map<String, dynamic> map) {
    return DeviceFingerprint(
      deviceId: map['deviceId'] ?? '',
      deviceName: map['deviceName'] ?? 'Unknown Device',
      approved: map['approved'] ?? false,
      registeredAt: (map['registeredAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'approved': approved,
      'registeredAt': Timestamp.fromDate(registeredAt),
    };
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

  // New fields for broader compatibility
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final String district;

  Address({
    required this.id,
    required this.label,
    this.fullAddress = '',
    this.village = '',
    this.landmark = '',
    this.pincode = '',
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
    this.deliveryInstructions,
    this.street = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.district = '',
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
      street: map['street'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      zipCode: map['zipCode'] ?? map['pincode'] ?? '',
      district: map['district'] ?? '',
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
      'street': street,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'district': district,
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
    String? street,
    String? city,
    String? state,
    String? zipCode,
    String? district,
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
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      district: district ?? this.district,
    );
  }
}
