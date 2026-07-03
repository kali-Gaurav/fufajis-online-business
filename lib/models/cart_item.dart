import '../utils/monetary_value.dart';

class CartItem {
  final String id;

  final String productId;
  final String productName;
  final String productImage;
  final String unit;
  final int quantity;
  final MonetaryValue price;
  final MonetaryValue? originalPrice;
  final MonetaryValue? discountPercentage;
  final int stockQuantity;
  final String shopId;
  final String shopName;
  final String? selectedVariant;
  final String? selectedSize;
  final String? selectedColor;
  final String? itemNotes; // Added for Step 16
  final DateTime addedAt;

  CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.unit,
    required this.quantity,
    required this.price,
    this.originalPrice,
    this.discountPercentage,
    required this.stockQuantity,
    required this.shopId,
    required this.shopName,
    this.selectedVariant,
    this.selectedSize,
    this.selectedColor,
    this.itemNotes,
    required this.addedAt,
  });

  MonetaryValue get totalPrice => price * quantity;

  CartItem copyWith({int? quantity, String? itemNotes}) {
    return CartItem(
      id: id,
      productId: productId,
      productName: productName,
      productImage: productImage,
      unit: unit,
      quantity: quantity ?? this.quantity,
      price: price,
      originalPrice: originalPrice,
      discountPercentage: discountPercentage,
      stockQuantity: stockQuantity,
      shopId: shopId,
      shopName: shopName,
      selectedVariant: selectedVariant,
      selectedSize: selectedSize,
      selectedColor: selectedColor,
      itemNotes: itemNotes ?? this.itemNotes,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'unit': unit,
      'quantity': quantity,
      'price': price,
      'originalPrice': originalPrice,
      'discountPercentage': discountPercentage,
      'stockQuantity': stockQuantity,
      'shopId': shopId,
      'shopName': shopName,
      'selectedVariant': selectedVariant,
      'selectedSize': selectedSize,
      'selectedColor': selectedColor,
      'itemNotes': itemNotes,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      productImage: map['productImage'] as String? ?? '',
      unit: map['unit'] as String? ?? 'piece',
      quantity: map['quantity'] as int? ?? 1,
      price: MonetaryValue(map['price'] ?? 0.0),
      originalPrice: map['originalPrice'] != null ? MonetaryValue(map['originalPrice']) : null,
      discountPercentage: map['discountPercentage'] != null
          ? MonetaryValue(map['discountPercentage'])
          : null,
      stockQuantity: map['stockQuantity'] as int? ?? 0,
      shopId: map['shopId'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      selectedVariant: map['selectedVariant'] as String?,
      selectedSize: map['selectedSize'] as String?,
      selectedColor: map['selectedColor'] as String?,
      itemNotes: map['itemNotes'] as String?,
      addedAt: map['addedAt'] != null ? DateTime.parse(map['addedAt'] as String) : DateTime.now(),
    );
  }
}
