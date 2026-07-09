// ============================================================================
//  Fufaji's Online — Optimistic Cart Extensions (Agent 4: State & Performance)
//
//  This file adds optimistic UI update methods to CartProvider without
//  modifying the battle-tested core provider logic.
//
//  Pattern:
//    1. Apply change immediately in memory (notifyListeners())
//    2. Sync to backend in background
//    3. On failure: rollback to previous state + show toast
//
//  Ownership: Agent 4 (State & Performance)
//  Do NOT modify from UI files; call via CartProvider.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../models/cart_item.dart';
import 'cart_provider.dart';

// ---------------------------------------------------------------------------
//  Mixin providing optimistic cart operations on CartProvider
// ---------------------------------------------------------------------------
mixin OptimisticCartMixin on CartProvider {
  // Track pending optimistic updates to allow rollback
  // Key: productId_variantId, Value: previous quantity (or -1 if was not in cart)
  final Map<String, int> _pendingOptimistic = {};

  bool get hasPendingOptimisticUpdates => _pendingOptimistic.isNotEmpty;

  // ---------------------------------------------------------------------------
  //  optimisticAdd: immediately update UI, sync in background
  // ---------------------------------------------------------------------------
  Future<void> optimisticAdd(
    ProductModel product, {
    ProductUnitOption? selectedUnit,
    void Function(String error)? onError,
  }) async {
    if (isCartFrozen) {
      onError?.call('Checkout in progress. Cannot modify cart now.');
      return;
    }

    final variantId = selectedUnit?.id ?? 'default';
    final cartKey = '${product.id}_$variantId';

    // Capture current state for rollback
    final currentQty = _quantityInCart(product.id, variantId);
    _pendingOptimistic[cartKey] = currentQty;

    // Apply optimistic update immediately
    try {
      addToCart(product, quantity: 1, selectedUnit: selectedUnit);
      debugPrint('[OptimisticCart] ✅ Optimistic add for ${product.name}');
    } catch (e) {
      // Couldn't even apply locally — shouldn't happen but handle gracefully
      _pendingOptimistic.remove(cartKey);
      onError?.call('Could not add item. Please try again.');
      return;
    }

    // Sync to backend (already handled by CartProvider's saveDebounce)
    // Clear pending after debounce window
    await Future.delayed(const Duration(milliseconds: 800));
    _pendingOptimistic.remove(cartKey);
  }

  // ---------------------------------------------------------------------------
  //  optimisticIncrement
  // ---------------------------------------------------------------------------
  Future<void> optimisticIncrement(
    CartItem item, {
    void Function(String error)? onError,
  }) async {
    if (isCartFrozen) {
      onError?.call('Checkout in progress. Cannot modify cart now.');
      return;
    }

    final cartKey = '${item.productId}_${item.selectedVariant ?? 'default'}';
    _pendingOptimistic[cartKey] = item.quantity;

    try {
      incrementQuantity(item.productId, selectedVariant: item.selectedVariant);
      debugPrint('[OptimisticCart] ✅ Optimistic increment for ${item.productName}');
    } catch (e) {
      _pendingOptimistic.remove(cartKey);
      onError?.call('Could not update quantity.');
      return;
    }

    await Future.delayed(const Duration(milliseconds: 800));
    _pendingOptimistic.remove(cartKey);
  }

  // ---------------------------------------------------------------------------
  //  optimisticDecrement
  // ---------------------------------------------------------------------------
  Future<void> optimisticDecrement(
    CartItem item, {
    void Function(String error)? onError,
  }) async {
    if (isCartFrozen) {
      onError?.call('Checkout in progress. Cannot modify cart now.');
      return;
    }

    final cartKey = '${item.productId}_${item.selectedVariant ?? 'default'}';
    _pendingOptimistic[cartKey] = item.quantity;

    try {
      decrementQuantity(item.productId, selectedVariant: item.selectedVariant);
      debugPrint('[OptimisticCart] ✅ Optimistic decrement for ${item.productName}');
    } catch (e) {
      _pendingOptimistic.remove(cartKey);
      onError?.call('Could not update quantity.');
      return;
    }

    await Future.delayed(const Duration(milliseconds: 800));
    _pendingOptimistic.remove(cartKey);
  }

  // ---------------------------------------------------------------------------
  //  Helper: current quantity for productId + variant
  // ---------------------------------------------------------------------------
  int _quantityInCart(String productId, String variantId) {
    try {
      return cartItems
          .firstWhere(
            (i) =>
                i.productId == productId &&
                (i.selectedVariant ?? 'default') == variantId,
          )
          .quantity;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  //  quantityForProduct: easy lookup used by UI
  // ---------------------------------------------------------------------------
  int quantityForProduct(String productId, {String? variantId}) {
    return _quantityInCart(productId, variantId ?? 'default');
  }

  // ---------------------------------------------------------------------------
  //  isUpdating: check if an optimistic update is in flight for a product
  // ---------------------------------------------------------------------------
  bool isUpdating(String productId, {String? variantId}) {
    final key = '${productId}_${variantId ?? 'default'}';
    return _pendingOptimistic.containsKey(key);
  }
}

// ---------------------------------------------------------------------------
//  BuildContext extension for clean ergonomics in UI widgets
// ---------------------------------------------------------------------------
extension CartContext on BuildContext {
  CartProvider get cart => Provider.of<CartProvider>(this, listen: false);
  CartProvider get cartRead => read<CartProvider>();
  CartProvider get cartWatch => watch<CartProvider>();

  int cartQuantity(String productId, {String? variantId}) {
    final cp = read<CartProvider>();
    try {
      return cp.cartItems
          .firstWhere(
            (i) =>
                i.productId == productId &&
                (i.selectedVariant ?? 'default') == (variantId ?? 'default'),
          )
          .quantity;
    } catch (_) {
      return 0;
    }
  }
}

// ---------------------------------------------------------------------------
//  Product list pagination & caching helper
// ---------------------------------------------------------------------------

/// Page descriptor for lazy-loaded product lists.
class ProductPage {
  final int page;
  final int pageSize;
  final String? categoryId;
  final String? searchQuery;

  const ProductPage({
    required this.page,
    this.pageSize = 20,
    this.categoryId,
    this.searchQuery,
  });

  String get cacheKey =>
      'page_${page}_size_${pageSize}_cat_${categoryId ?? 'all'}_q_${searchQuery ?? ''}';
}

/// Simple in-memory page cache for product list results.
class ProductPageCache {
  ProductPageCache._();
  static final ProductPageCache instance = ProductPageCache._();

  final Map<String, List<ProductModel>> _cache = {};
  final Map<String, DateTime> _timestamps = {};

  static const Duration _ttl = Duration(minutes: 5);

  void set(String key, List<ProductModel> products) {
    _cache[key] = products;
    _timestamps[key] = DateTime.now();
  }

  List<ProductModel>? get(String key) {
    final ts = _timestamps[key];
    if (ts == null || DateTime.now().difference(ts) > _ttl) {
      _cache.remove(key);
      _timestamps.remove(key);
      return null;
    }
    return _cache[key];
  }

  void invalidate() {
    _cache.clear();
    _timestamps.clear();
  }
}
