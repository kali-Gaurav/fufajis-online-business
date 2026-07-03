class SupplierModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final List<String> products;

  SupplierModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.products = const [],
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'phone': phone, 'email': email, 'products': products};
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map, String docId) {
    return SupplierModel(
      id: docId,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      products: List<String>.from(map['products'] as Iterable? ?? []),
    );
  }
}
