import '../utils/monetary_value.dart';

/// CartItem model for the shopping cart.
/// Note: A more feature-rich CartItem also exists at models/cart_item.dart (CartItem class).
/// This file provides the CartItemModel alias matching the requested spec field names.
class CartItemModel {
  final String id;
  final String productId;
  final String productName;
  final String imageUrl;
  final MonetaryValue price;
  final MonetaryValue? originalPrice;
  final int quantity;
  final String selectedUnit;
  final double unitPrice;
  final String shopId;

  CartItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.price,
    this.originalPrice,
    required this.quantity,
    required this.selectedUnit,
    required this.unitPrice,
    required this.shopId,
  });

  MonetaryValue get totalPrice => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'imageUrl': imageUrl,
      'price': price,
      'originalPrice': originalPrice,
      'quantity': quantity,
      'selectedUnit': selectedUnit,
      'unitPrice': unitPrice,
      'shopId': shopId,
    };
  }

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      id: map['id'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      imageUrl: (map['imageUrl'] as String?) ?? (map['productImage'] as String?) ?? '',
      price: MonetaryValue(map['price'] ?? 0.0),
      originalPrice: map['originalPrice'] != null ? MonetaryValue(map['originalPrice']) : null,
      quantity: map['quantity'] as int? ?? 1,
      selectedUnit: (map['selectedUnit'] as String?) ?? (map['unit'] as String?) ?? 'piece',
      unitPrice: (map['unitPrice'] as num? ?? map['price'] as num? ?? 0.0).toDouble(),
      shopId: map['shopId'] as String? ?? '',
    );
  }

  CartItemModel copyWith({
    String? id,
    String? productId,
    String? productName,
    String? imageUrl,
    MonetaryValue? price,
    MonetaryValue? originalPrice,
    int? quantity,
    String? selectedUnit,
    double? unitPrice,
    String? shopId,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      quantity: quantity ?? this.quantity,
      selectedUnit: selectedUnit ?? this.selectedUnit,
      unitPrice: unitPrice ?? this.unitPrice,
      shopId: shopId ?? this.shopId,
    );
  }
}
