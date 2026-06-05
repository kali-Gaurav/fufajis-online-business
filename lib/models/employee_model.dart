class Employee {
  final String employeeId;
  final String uid;
  final String name;
  final String email;
  final String role;
  final String branchId;
  final bool isActive;

  Employee({
    required this.employeeId,
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.branchId,
    required this.isActive,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      employeeId: json['employeeId'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'branchId': branchId,
      'isActive': isActive,
    };
  }

  Employee copyWith({
    String? employeeId,
    String? uid,
    String? name,
    String? email,
    String? role,
    String? branchId,
    bool? isActive,
  }) {
    return Employee(
      employeeId: employeeId ?? this.employeeId,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      branchId: branchId ?? this.branchId,
      isActive: isActive ?? this.isActive,
    );
  }
}
