/// Cart Integration Service — Connect voice orders to cart
///
/// Flow:
/// Voice Input
///   ↓
/// VoiceOrderParser
///   ↓
/// MultiProductParser (qty extraction)
///   ↓
/// ProductMatcher (fuzzy match to catalog)
///   ↓
/// AmbiguityResolver (clarify if needed)
///   ↓
/// CartIntegrationService ← YOU ARE HERE
///   ├── Validate inventory
///   ├── Check customer wallet
///   ├── Add to cart
///   └── Return order summary
///   ↓
/// CheckoutScreen

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../utils/monetary_value.dart';

class CartItem {
  final String productId;
  final String productName;
  final int quantity;
  final String unit;
  final MonetaryValue price;
  final MonetaryValue lineTotal;
  final int? stockAvailable;

  CartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.lineTotal,
    this.stockAvailable,
  });

  @override
  String toString() =>
      '$productName x$quantity $unit → ${lineTotal.toDisplayString()}';
}

class VoiceOrderResult {
  final bool success;
  final String message;
  final List<CartItem> addedItems;
  final MonetaryValue totalPrice;
  final List<String> warnings; // e.g., "Only 2kg stock available for potato"

  VoiceOrderResult({
    required this.success,
    required this.message,
    required this.addedItems,
    required this.totalPrice,
    this.warnings = const [],
  });

  String toReadableString() {
    final itemsList = addedItems.map((i) => i.toString()).join('\n');
    return '''
$message

Items:
$itemsList

Total: ${totalPrice.toDisplayString()}

${warnings.isNotEmpty ? 'Warnings:\n${warnings.join('\n')}' : ''}
''';
  }
}

class CartIntegrationService {
  final FirebaseFirestore _firestore;

  CartIntegrationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Add voice-ordered products to cart
  /// Input: List of {product, quantity, unit}
  /// Output: Order result with validation, pricing, warnings
  Future<VoiceOrderResult> addVoiceOrderToCart(
    String userId,
    List<Map<String, dynamic>> parsedItems,
  ) async {
    if (parsedItems.isEmpty) {
      return VoiceOrderResult(
        success: false,
        message: 'No items to add',
        addedItems: [],
        totalPrice: MonetaryValue(0.0),
      );
    }

    final addedItems = <CartItem>[];
    final warnings = <String>[];
    var totalPrice = MonetaryValue(0.0);

    debugPrint('[CartIntegration] Adding ${parsedItems.length} items to cart for $userId');

    for (final item in parsedItems) {
      final product = item['product'] as ProductModel?;
      final quantity = item['quantity'] as int? ?? 1;
      final unit = item['unit'] as String? ?? 'item';

      if (product == null) {
        warnings.add('Could not find: ${item['productName']}');
        continue;
      }

      // Validate stock
      if (product.stockQuantity < quantity) {
        warnings.add(
          'Only ${product.stockQuantity}${unit} available for ${product.name} (requested $quantity)',
        );
        // Don't skip — let customer adjust in review screen
      }

      // Calculate line total
      final lineTotal = MonetaryValue(product.price.toDouble() * quantity);

      // Create cart item
      final cartItem = CartItem(
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        unit: unit,
        price: product.price,
        lineTotal: lineTotal,
        stockAvailable: product.stockQuantity,
      );

      addedItems.add(cartItem);
      totalPrice = MonetaryValue(totalPrice.toDouble() + lineTotal.toDouble());

      debugPrint('[CartIntegration] Added: ${product.name} x$quantity $unit');
    }

    // Save to Firestore cart
    try {
      await _saveToFirestoreCart(userId, addedItems);
      debugPrint('[CartIntegration] Saved to Firestore for user $userId');
    } catch (e) {
      warnings.add('Failed to save cart: $e');
      debugPrint('[CartIntegration] Error saving cart: $e');
    }

    return VoiceOrderResult(
      success: addedItems.isNotEmpty,
      message: addedItems.isEmpty
          ? 'Could not add any items'
          : 'Added ${addedItems.length} item(s) to cart',
      addedItems: addedItems,
      totalPrice: totalPrice,
      warnings: warnings,
    );
  }

  /// Save cart items to Firestore
  Future<void> _saveToFirestoreCart(String userId, List<CartItem> items) async {
    final cartRef = _firestore.collection('carts').doc(userId);

    // Get existing cart
    final cartSnap = await cartRef.get();
    final existingItems = cartSnap.exists
        ? List<Map<String, dynamic>>.from(cartSnap['items'] ?? [])
        : <Map<String, dynamic>>[];

    // Merge with new items (update quantities if product already in cart)
    for (final newItem in items) {
      final existingIdx = existingItems.indexWhere(
        (e) => e['productId'] == newItem.productId,
      );

      if (existingIdx >= 0) {
        // Update quantity
        existingItems[existingIdx]['quantity'] =
            (existingItems[existingIdx]['quantity'] as int) + newItem.quantity;
      } else {
        // Add new item
        existingItems.add({
          'productId': newItem.productId,
          'productName': newItem.productName,
          'quantity': newItem.quantity,
          'unit': newItem.unit,
          'price': newItem.price.toDouble(),
          'addedAt': FieldValue.serverTimestamp(),
          'addedVia': 'voice', // Track that it was added via voice
        });
      }
    }

    // Save back to Firestore
    await cartRef.set({
      'items': existingItems,
      'updatedAt': FieldValue.serverTimestamp(),
      'totalItems': existingItems.length,
    }, SetOptions(merge: true));
  }

  /// Check if customer has sufficient wallet balance
  Future<bool> hasWalletBalance(String userId, MonetaryValue amount) async {
    try {
      final walletSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wallet')
          .doc('balance')
          .get();

      if (!walletSnap.exists) return false;

      final balance = (walletSnap['amount'] as num?)?.toDouble() ?? 0.0;
      return balance >= amount.toDouble();
    } catch (e) {
      debugPrint('[CartIntegration] Error checking wallet: $e');
      return false;
    }
  }

  /// Get cart summary for review screen
  Future<Map<String, dynamic>?> getCartSummary(String userId) async {
    try {
      final cartSnap = await _firestore.collection('carts').doc(userId).get();
      if (!cartSnap.exists) return null;

      final data = cartSnap.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

      var total = 0.0;
      for (final item in items) {
        final price = (item['price'] as num).toDouble();
        final qty = item['quantity'] as int;
        total += price * qty;
      }

      return {
        'itemCount': items.length,
        'items': items,
        'total': total,
      };
    } catch (e) {
      debugPrint('[CartIntegration] Error getting cart summary: $e');
      return null;
    }
  }
}
