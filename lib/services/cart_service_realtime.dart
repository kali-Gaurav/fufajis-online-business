import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Cart service with real-time Firestore listeners
///
/// Provides multi-device sync by listening to cart changes:
/// - If cart edited on web admin, mobile app sees it in real-time
/// - Useful for shop owners managing inventory across devices
/// - Supports StreamBuilder for UI auto-refresh
///
/// Usage:
///   Stream<CartData> stream = CartService().watchCart(userId);
class CartServiceRealtime {
  static final CartServiceRealtime _instance =
      CartServiceRealtime._internal();
  factory CartServiceRealtime() => _instance;
  CartServiceRealtime._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream cart updates for a specific user
  ///
  /// Returns a Stream<DocumentSnapshot> that emits whenever
  /// the cart document changes in Firestore.
  ///
  /// Use with StreamBuilder:
  ///   StreamBuilder<DocumentSnapshot>(
  ///     stream: CartService().watchCart(userId),
  ///     builder: (context, snapshot) {
  ///       if (snapshot.hasData) {
  ///         final cartData = snapshot.data!.data();
  ///         // Update UI with cart data
  ///       }
  ///     }
  ///   )
  Stream<DocumentSnapshot> watchCart(String userId) {
    return _firestore
        .collection('customers')
        .doc(userId)
        .collection('cart')
        .doc('current')
        .snapshots();
  }

  /// Stream all cart items for a user
  ///
  /// Returns list of cart items that auto-updates when:
  /// - Items added/removed on another device
  /// - Item quantities changed on another device
  /// - Cart cleared on another device
  Stream<List<CartItem>> watchCartItems(String userId) {
    return _firestore
        .collection('customers')
        .doc(userId)
        .collection('cart')
        .doc('current')
        .collection('items')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CartItem.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Add item to cart (syncs across devices)
  Future<void> addToCart({
    required String userId,
    required String productId,
    required String productName,
    required String productImage,
    required num price,
    required int quantity,
  }) async {
    try {
      final cartRef = _firestore
          .collection('customers')
          .doc(userId)
          .collection('cart')
          .doc('current');

      // Ensure cart document exists
      await cartRef.set(
        {
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Add or update item in cart
      await cartRef.collection('items').doc(productId).set(
        {
          'productId': productId,
          'productName': productName,
          'productImage': productImage,
          'price': price,
          'quantity': quantity,
          'addedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      debugPrint('[CartService] Item added to cart: $productId');
    } catch (e) {
      debugPrint('[CartService] Error adding to cart: $e');
      rethrow;
    }
  }

  /// Remove item from cart (syncs across devices)
  Future<void> removeFromCart({
    required String userId,
    required String productId,
  }) async {
    try {
      await _firestore
          .collection('customers')
          .doc(userId)
          .collection('cart')
          .doc('current')
          .collection('items')
          .doc(productId)
          .delete();

      debugPrint('[CartService] Item removed from cart: $productId');
    } catch (e) {
      debugPrint('[CartService] Error removing from cart: $e');
      rethrow;
    }
  }

  /// Update item quantity (syncs across devices)
  Future<void> updateQuantity({
    required String userId,
    required String productId,
    required int quantity,
  }) async {
    try {
      if (quantity <= 0) {
        // Delete if quantity is 0 or negative
        await removeFromCart(userId: userId, productId: productId);
        return;
      }

      await _firestore
          .collection('customers')
          .doc(userId)
          .collection('cart')
          .doc('current')
          .collection('items')
          .doc(productId)
          .update({
        'quantity': quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[CartService] Quantity updated: $productId → $quantity');
    } catch (e) {
      debugPrint('[CartService] Error updating quantity: $e');
      rethrow;
    }
  }

  /// Clear entire cart (syncs across devices)
  Future<void> clearCart(String userId) async {
    try {
      final cartItemsRef = _firestore
          .collection('customers')
          .doc(userId)
          .collection('cart')
          .doc('current')
          .collection('items');

      // Get all items and delete them
      final snapshot = await cartItemsRef.get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // Clear cart metadata
      await _firestore
          .collection('customers')
          .doc(userId)
          .collection('cart')
          .doc('current')
          .delete();

      debugPrint('[CartService] Cart cleared');
    } catch (e) {
      debugPrint('[CartService] Error clearing cart: $e');
      rethrow;
    }
  }

  /// Get cart summary (total items, total price)
  ///
  /// Automatically updates as cart changes on any device
  Stream<CartSummary> watchCartSummary(String userId) {
    return watchCartItems(userId).map((items) {
      int totalItems = 0;
      double totalPrice = 0;

      for (final item in items) {
        totalItems += item.quantity;
        totalPrice += (item.price.toDouble() * item.quantity);
      }

      return CartSummary(
        totalItems: totalItems,
        totalPrice: totalPrice,
        itemCount: items.length,
      );
    });
  }

  /// Check if product is in cart
  Future<bool> isInCart({
    required String userId,
    required String productId,
  }) async {
    try {
      final doc = await _firestore
          .collection('customers')
          .doc(userId)
          .collection('cart')
          .doc('current')
          .collection('items')
          .doc(productId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('[CartService] Error checking if in cart: $e');
      return false;
    }
  }

  /// Get current quantity of item in cart
  Future<int> getQuantity({
    required String userId,
    required String productId,
  }) async {
    try {
      final doc = await _firestore
          .collection('customers')
          .doc(userId)
          .collection('cart')
          .doc('current')
          .collection('items')
          .doc(productId)
          .get();

      if (doc.exists) {
        return (doc.data()?['quantity'] as int?) ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('[CartService] Error getting quantity: $e');
      return 0;
    }
  }
}

/// Represents a single cart item
class CartItem {
  final String id;
  final String productId;
  final String productName;
  final String productImage;
  final num price;
  final int quantity;
  final DateTime? addedAt;

  CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.price,
    required this.quantity,
    this.addedAt,
  });

  factory CartItem.fromMap(String id, Map<String, dynamic> map) {
    return CartItem(
      id: id,
      productId: map['productId'] as String? ?? id,
      productName: map['productName'] as String? ?? 'Unknown',
      productImage: map['productImage'] as String? ?? '',
      price: map['price'] as num? ?? 0,
      quantity: map['quantity'] as int? ?? 1,
      addedAt: (map['addedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'productImage': productImage,
    'price': price,
    'quantity': quantity,
    'addedAt': addedAt,
  };
}

/// Cart summary with totals
class CartSummary {
  final int totalItems;
  final double totalPrice;
  final int itemCount; // Distinct items

  CartSummary({
    required this.totalItems,
    required this.totalPrice,
    required this.itemCount,
  });
}
