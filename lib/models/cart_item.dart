import 'package:flutter/foundation.dart';
import '../utils/monetary_value.dart';

class CartItem {
  final String id;

  final String productId;
  final String productName;
  final String productImage;
  final String unit;
  int quantity;
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

  // FIX #2: Request versioning for idempotent quantity updates
  int requestVersion = 0;  // Track the version of the request
  int lastSavedVersion = 0;  // Track the last saved version

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

  bool get hasUnsavedChanges => requestVersion != lastSavedVersion;

  CartItem copyWith({int? quantity, String? itemNotes, MonetaryValue? price}) {
    final newItem = CartItem(
      id: id,
      productId: productId,
      productName: productName,
      productImage: productImage,
      unit: unit,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
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
    // FIX: Preserve version tracking across copyWith
    newItem.requestVersion = requestVersion;
    newItem.lastSavedVersion = lastSavedVersion;
    return newItem;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'unit': unit,
      'quantity': quantity,
      'price': price.toDouble(),
      'originalPrice': originalPrice?.toDouble(),
      'discountPercentage': discountPercentage?.toDouble(),
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
    // DIAGNOSTIC: Trace data corruption sources
    final priceValue = map['price'];
    final quantityValue = map['quantity'];

    if (priceValue == null || (priceValue is num && priceValue <= 0)) {
      debugPrint('[CartItem.fromMap] 🚨 CORRUPTED PRICE:');
      debugPrint('  productId: ${map['productId']}');
      debugPrint('  price: $priceValue (type: ${priceValue.runtimeType})');
      debugPrint('  full map keys: ${map.keys.toList()}');
    }

    if (quantityValue == null || (quantityValue is num && quantityValue <= 0)) {
      debugPrint('[CartItem.fromMap] 🚨 CORRUPTED QUANTITY:');
      debugPrint('  productId: ${map['productId']}');
      debugPrint('  quantity: $quantityValue (type: ${quantityValue.runtimeType})');
    }

    return CartItem(
      id: map['id'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      productImage: map['productImage'] as String? ?? '',
      unit: map['unit'] as String? ?? 'piece',
      quantity: (quantityValue is int ? quantityValue : (quantityValue is num ? quantityValue.toInt() : 1)).clamp(1, 999),
      price: MonetaryValue(priceValue ?? 0.0),
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
