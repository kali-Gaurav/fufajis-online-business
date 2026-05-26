import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../models/delivery_type.dart';
import '../services/delivery_charge_calculator.dart';
import '../models/coupon.dart';
import '../models/cart_item.dart';
class CartProvider with ChangeNotifier {
  List<CartItem> _cartItems = [];
  Coupon? _appliedCoupon;
  double _walletAmountUsed = 0.0;
  double _tipAmount = 0.0; // Feature 24: Rider Tipping
  bool _isLoading = false;
  DeliveryType _deliveryType = DeliveryType.standard;

  bool get isLoading => _isLoading;
  List<CartItem> get cartItems => _cartItems;
  Coupon? get appliedCoupon => _appliedCoupon;
  double get walletAmountUsed => _walletAmountUsed;
  double get tipAmount => _tipAmount;
  DeliveryType get deliveryType => _deliveryType;

  int get totalItems => _cartItems.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get discount {
    double discount = 0.0;
    if (_appliedCoupon != null) {
      discount = _appliedCoupon!.calculateDiscount(subtotal);
    }
    return discount;
  }

  double get deliveryCharge {
    return DeliveryChargeCalculator.calculateDeliveryCharge(_deliveryType, subtotal);
  }

  /// Get the delivery charge for the current delivery type
  double getDeliveryChargeForType(DeliveryType type) {
    return DeliveryChargeCalculator.calculateDeliveryCharge(type, subtotal);
  }

  /// Get estimated delivery date for a delivery type
  DateTime getEstimatedDeliveryDate(DeliveryType type) {
    return DeliveryChargeCalculator.getEstimatedDeliveryDate(type);
  }

  /// Get formatted delivery date string
  String getFormattedDeliveryDate(DeliveryType type) {
    return DeliveryChargeCalculator.getFormattedDeliveryDate(type);
  }

  /// Set the delivery type
  void setDeliveryType(DeliveryType type) {
    _deliveryType = type;
    notifyListeners();
  }

  void setTipAmount(double amount) {
    _tipAmount = amount;
    notifyListeners();
  }

  double get total {
    final total = subtotal - discount + deliveryCharge + _tipAmount - _walletAmountUsed;
    return total.clamp(0, total);
  }

  int get rewardPointsUsed => (discount * 10).floor();

  // Add item to cart
  void addToCart(
    ProductModel product, {
    int quantity = 1,
    ProductUnitOption? selectedUnit,
  }) {
    final unitId = selectedUnit?.id ?? 'default';

    final existingIndex = _cartItems.indexWhere(
      (item) =>
          item.productId == product.id &&
          (item.selectedVariant ?? 'default') == unitId,
    );

    if (existingIndex >= 0) {
      final newQuantity = (_cartItems[existingIndex].quantity + quantity).clamp(
        1,
        selectedUnit?.stockQuantity ?? product.maxOrderQuantity,
      );
      _cartItems[existingIndex] = _cartItems[existingIndex].copyWith(
        quantity: newQuantity,
      );
    } else {
      final price = selectedUnit?.price ?? product.price;
      final originalPrice = selectedUnit?.originalPrice ?? product.originalPrice;
      final unitName = selectedUnit?.name ?? product.unit;

      final cartItem = CartItem(
        id: '${product.id}_${DateTime.now().millisecondsSinceEpoch}',
        productId: product.id,
        productName: product.name,
        productImage: product.imageUrl,
        unit: unitName,
        quantity: quantity,
        price: price,
        originalPrice: originalPrice,
        discountPercentage: product.discountPercentage,
        stockQuantity: selectedUnit?.stockQuantity ?? product.stockQuantity,
        shopId: product.shopId,
        shopName: product.shopName,
        selectedVariant: unitId,
        addedAt: DateTime.now(),
      );
      _cartItems.add(cartItem);
    }

    _saveCart();
    notifyListeners();
  }

  // Update item quantity
  void updateQuantity(String cartItemId, int quantity) {
    final index = _cartItems.indexWhere((item) => item.id == cartItemId);
    if (index >= 0) {
      if (quantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index] = _cartItems[index].copyWith(quantity: quantity);
      }
      _saveCart();
      notifyListeners();
    }
  }

  // Update item notes
  void updateItemNotes(String cartItemId, String notes) {
    final index = _cartItems.indexWhere((item) => item.id == cartItemId);
    if (index >= 0) {
      _cartItems[index] = _cartItems[index].copyWith(itemNotes: notes);
      _saveCart();
      notifyListeners();
    }
  }

  // Remove item from cart
  void removeFromCart(String cartItemId) {
    _cartItems.removeWhere((item) => item.id == cartItemId);
    _saveCart();
    notifyListeners();
  }

  // Apply coupon
  bool applyCoupon(String couponCode) {
    if (couponCode.toUpperCase() == 'SAVE10') {
      _appliedCoupon = Coupon(
        id: 'coupon_1',
        code: 'SAVE10',
        name: '10% Off',
        description: 'Get 10% off on your order',
        discountType: 'percentage',
        discountValue: 10,
        minimumOrderAmount: 200,
        maximumDiscountAmount: 100,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 30)),
      );
      notifyListeners();
      return true;
    }
    
    if (couponCode.toUpperCase() == 'FIRST20') {
      _appliedCoupon = Coupon(
        id: 'coupon_2',
        code: 'FIRST20',
        name: '20% Off First Order',
        description: 'Get 20% off on your first order',
        discountType: 'percentage',
        discountValue: 20,
        minimumOrderAmount: 300,
        maximumDiscountAmount: 150,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 90)),
      );
      notifyListeners();
      return true;
    }
    
    return false;
  }

  // Remove coupon
  void removeCoupon() {
    _appliedCoupon = null;
    notifyListeners();
  }

  // --- Feature 20: Smart Coupon Optimizer ---
  void autoOptimizeCoupons() {
    // In a real app, this would fetch available coupons from Firestore
    // For now, we compare our static ones
    final List<String> codes = ['SAVE10', 'FIRST20'];
    double maxDiscount = 0.0;
    String? bestCode;

    for (final code in codes) {
      // Temporary apply to check discount
      final oldCoupon = _appliedCoupon;
      if (applyCoupon(code)) {
        final currentDiscount = discount;
        if (currentDiscount > maxDiscount) {
          maxDiscount = currentDiscount;
          bestCode = code;
        }
      }
      _appliedCoupon = oldCoupon; // Restore
    }

    if (bestCode != null) {
      applyCoupon(bestCode);
    }
    notifyListeners();
  }

  // Use wallet amount
  void setWalletAmount(double amount, double walletBalance) {
    _walletAmountUsed = amount.clamp(0, walletBalance);
    notifyListeners();
  }

  // Save cart to local storage
  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = _cartItems.map((item) => item.toMap()).toList();
      await prefs.setString('cart_items', jsonEncode(cartData));
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  // Load cart from local storage
  Future<void> loadCart() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartString = prefs.getString('cart_items');
      if (cartString != null && cartString.isNotEmpty) {
        final List<dynamic> cartData = jsonDecode(cartString);
        _cartItems = cartData.map((item) => CartItem.fromMap(item)).toList();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear cart
  void clearCart() {
    _cartItems = [];
    _appliedCoupon = null;
    _walletAmountUsed = 0.0;
    _deliveryType = DeliveryType.standard;
    _saveCart();
    notifyListeners();
  }

  // Check if product is in cart
  bool isInCart(String productId) {
    return _cartItems.any((item) => item.productId == productId);
  }

  // Get quantity of product in cart
  int getQuantity(String productId) {
    try {
      return _cartItems.firstWhere((item) => item.productId == productId).quantity;
    } catch (e) {
      return 0;
    }
  }

  // Helper methods for ProductCard
  void addItem(ProductModel product, {ProductUnitOption? selectedUnit}) {
    addToCart(product, selectedUnit: selectedUnit);
  }

  void decrementQuantity(String productId) {
    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      final currentQty = _cartItems[index].quantity;
      updateQuantity(_cartItems[index].id, currentQty - 1);
    }
  }

  void incrementQuantity(String productId) {
    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      final currentQty = _cartItems[index].quantity;
      updateQuantity(_cartItems[index].id, currentQty + 1);
    }
  }

  // Variant/Option specific helpers for multi-unit selection
  int getQuantityForVariant(String productId, String? selectedVariant) {
    try {
      return _cartItems.firstWhere(
        (item) => item.productId == productId && item.selectedVariant == selectedVariant
      ).quantity;
    } catch (e) {
      return 0;
    }
  }

  void incrementQuantityForVariant(String productId, String? selectedVariant) {
    final index = _cartItems.indexWhere(
      (item) => item.productId == productId && item.selectedVariant == selectedVariant
    );
    if (index >= 0) {
      final currentQty = _cartItems[index].quantity;
      updateQuantity(_cartItems[index].id, currentQty + 1);
    }
  }

  void decrementQuantityForVariant(String productId, String? selectedVariant) {
    final index = _cartItems.indexWhere(
      (item) => item.productId == productId && item.selectedVariant == selectedVariant
    );
    if (index >= 0) {
      final currentQty = _cartItems[index].quantity;
      updateQuantity(_cartItems[index].id, currentQty - 1);
    }
  }

  /// Bulk add items from voice results (Feature: High-Speed One-Click Order)
  Future<void> bulkAddByVoice(List<Map<String, dynamic>> items, List<ProductModel> shopProducts) async {
    for (var item in items) {
      final String name = (item['name'] ?? '').toString().toLowerCase();
      final double qty = double.tryParse(item['quantity']?.toString() ?? '1.0') ?? 1.0;
      final String unit = (item['unit'] ?? '').toString().toLowerCase();

      // Find matching product in shop inventory
      ProductModel? match;
      
      // 1. Exact name match
      try {
        match = shopProducts.firstWhere((p) => p.name.toLowerCase() == name);
      } catch (_) {
        // 2. Contains match
        try {
          match = shopProducts.firstWhere((p) => p.name.toLowerCase().contains(name) || name.contains(p.name.toLowerCase()));
        } catch (_) {
          // 3. Tag match
          try {
            match = shopProducts.firstWhere((p) => p.tags.any((tag) => tag.toLowerCase().contains(name)));
          } catch (_) {
            match = null;
          }
        }
      }

      if (match != null) {
        // Check if there is a unit option that matches the requested unit
        ProductUnitOption? selectedUnit;
        if (match.unitOptions.isNotEmpty) {
          try {
            selectedUnit = match.unitOptions.firstWhere((u) => u.name.toLowerCase().contains(unit));
          } catch (_) {
            selectedUnit = null;
          }
        }

        // Add to cart with parsed quantity
        addToCart(match, quantity: qty.toInt(), selectedUnit: selectedUnit);
      }
    }
    _saveCart();
    notifyListeners();
  }
}
