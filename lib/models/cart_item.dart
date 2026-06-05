class CartItem {
  final String id;
  final String productId;
  final String productName;
  final String productImage;
  final String unit;
  final int quantity;
  final double price;
  final double? originalPrice;
  final double? discountPercentage;
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

  double get totalPrice => price * quantity;

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
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productImage: map['productImage'] ?? '',
      unit: map['unit'] ?? 'piece',
      quantity: map['quantity'] ?? 1,
      price: (map['price'] ?? 0.0).toDouble(),
      originalPrice: (map['originalPrice'] as num?)?.toDouble(),
      discountPercentage: (map['discountPercentage'] as num?)?.toDouble(),
      stockQuantity: map['stockQuantity'] ?? 0,
      shopId: map['shopId'] ?? '',
      shopName: map['shopName'] ?? '',
      selectedVariant: map['selectedVariant'],
      selectedSize: map['selectedSize'],
      selectedColor: map['selectedColor'],
      itemNotes: map['itemNotes'],
      addedAt: map['addedAt'] != null
          ? DateTime.parse(map['addedAt'])
          : DateTime.now(),
    );
  }
}
