class ContactModel {
  final String id;
  final String userId;
  final String name;
  final String phoneNumber;
  final String? email;
  final String relationship; // e.g., 'primary', 'emergency', 'family'
  final String? address;
  final DateTime createdAt;

  ContactModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.relationship = 'primary',
    this.address,
    required this.createdAt,
  });

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      name: map['name'] as String? ?? '',
      phoneNumber: map['phone_number'] as String? ?? '',
      email: map['email'] as String?,
      relationship: map['relationship'] as String? ?? 'primary',
      address: map['address'] as String?,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone_number': phoneNumber,
      'email': email,
      'relationship': relationship,
      'address': address,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
