enum EmployeeRole { superOwner, franchiseOwner, branchManager, employee }

extension EmployeeRoleExtension on EmployeeRole {
  String get displayName {
    switch (this) {
      case EmployeeRole.superOwner:
        return 'Super Owner';
      case EmployeeRole.franchiseOwner:
        return 'Franchise Owner';
      case EmployeeRole.branchManager:
        return 'Branch Manager';
      case EmployeeRole.employee:
        return 'Employee';
    }
  }

  String get apiValue {
    return toString().split('.').last;
  }
}

class Employee {
  final String employeeId;
  final String uid;
  final String name;
  final String email;
  final EmployeeRole role;
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
      role: EmployeeRole.values.firstWhere(
        (e) => e.apiValue == json['role'],
        orElse: () => EmployeeRole.employee,
      ),
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
      'role': role.apiValue,
      'branchId': branchId,
      'isActive': isActive,
    };
  }

  Employee copyWith({
    String? employeeId,
    String? uid,
    String? name,
    String? email,
    EmployeeRole? role,
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
