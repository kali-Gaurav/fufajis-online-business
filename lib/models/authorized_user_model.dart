import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class AuthorizedUserModel {
  final String phoneNumber;
  final UserRole role;
  final String name;
  final DateTime createdAt;
  final String authorizedBy;

  AuthorizedUserModel({
    required this.phoneNumber,
    required this.role,
    required this.name,
    required this.createdAt,
    required this.authorizedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'role': role.toString(),
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'authorizedBy': authorizedBy,
    };
  }

  factory AuthorizedUserModel.fromMap(Map<String, dynamic> map) {
    return AuthorizedUserModel(
      phoneNumber: map['phoneNumber'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == map['role'],
        orElse: () => UserRole.customer,
      ),
      name: map['name'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      authorizedBy: map['authorizedBy'] ?? 'admin',
    );
  }
}
