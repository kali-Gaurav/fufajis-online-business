class Device {
  final String deviceId;
  final String deviceName;
  final bool approved;

  Device({required this.deviceId, required this.deviceName, required this.approved});

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      approved: json['approved'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'deviceId': deviceId, 'deviceName': deviceName, 'approved': approved};
  }
}

class Owner {
  final String email;
  final String role;
  final String pinHash;
  final bool biometricEnabled;
  final List<Device> approvedDevices;

  Owner({
    required this.email,
    required this.role,
    required this.pinHash,
    required this.biometricEnabled,
    required this.approvedDevices,
  });

  factory Owner.fromJson(Map<String, dynamic> json) {
    var deviceList = json['approvedDevices'] as List? ?? [];
    List<Device> devices = deviceList
        .map((e) => Device.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return Owner(
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'super_admin',
      pinHash: json['pinHash'] as String? ?? '',
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      approvedDevices: devices,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'role': role,
      'pinHash': pinHash,
      'biometricEnabled': biometricEnabled,
      'approvedDevices': approvedDevices.map((e) => e.toJson()).toList(),
    };
  }

  Owner copyWith({
    String? email,
    String? role,
    String? pinHash,
    bool? biometricEnabled,
    List<Device>? approvedDevices,
  }) {
    return Owner(
      email: email ?? this.email,
      role: role ?? this.role,
      pinHash: pinHash ?? this.pinHash,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      approvedDevices: approvedDevices ?? this.approvedDevices,
    );
  }
}
