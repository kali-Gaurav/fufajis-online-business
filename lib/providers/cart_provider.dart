import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/delivery_type.dart';
import '../services/delivery_charge_calculator.dart';
import '../models/coupon.dart';
import '../models/cart_item.dart';
import '../models/cart_item_model.dart';
import '../services/cart_sync_service.dart';
import '../utils/monetary_value.dart';
import '../services/cart_validator.dart';
import '../services/diagnostics_service.dart';

class CartProvider with ChangeNotifier {
  final CartSyncService _cartSyncService = CartSyncService();
  List<CartItem> _cartItems = [];
  List<CartItem> _saveForLaterItems = [];
  Coupon? _appliedCoupon;
  double _walletAmountUsed = 0.0;
  double _tipAmount = 0.0; // Feature 24: Rider Tipping
  bool _isLoading = false;
  DeliveryType _deliveryType = DeliveryType.standard;

  bool get isLoading => _isLoading;
  List<CartItem> get cartItems => _cartItems;
  List<CartItem> get saveForLaterItems => _saveForLaterItems;
  Coupon? get appliedCoupon => _appliedCoupon;
  double get walletAmountUsed => _walletAmountUsed;
  double get tipAmount => _tipAmount;
  DeliveryType get deliveryType => _deliveryType;

  int get totalItems => _cartItems.fold(0, (total, item) => total + item.quantity);

  double get subtotal {
    try {
      return _cartItems.fold<double>(0.0, (total, item) {
        final itemPrice = item.totalPrice.toDouble();
        return total + (itemPrice.isNaN ? 0.0 : itemPrice);
      });
    } catch (e) {
      debugPrint('[CartProvider] Error calculating subtotal: $e');
      return 0.0;
    }
  }

  double get discount {
    try {
      double discount = 0.0;
      if (_appliedCoupon != null) {
        final calculated = _appliedCoupon!.calculateDiscount(MonetaryValue(subtotal)).toDouble();
        discount = (calculated.isNaN || calculated.isInfinite) ? 0.0 : calculated;
      }
      return discount.clamp(0.0, subtotal); // Discount can't exceed subtotal
    } catch (e) {
      debugPrint('[CartProvider] Error calculating discount: $e');
      return 0.0;
    }
  }

  double get deliveryCharge {
    try {
      final charge = DeliveryChargeCalculator.calculateDeliveryCharge(_deliveryType, subtotal);
      return (charge.isNaN || charge.isInfinite) ? 0.0 : charge.clamp(0.0, 10000.0);
    } catch (e) {
      debugPrint('[CartProvider] Error calculating delivery charge: $e');
      return 0.0;
    }
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
    _savePreferences();
    notifyListeners();
  }

  void setTipAmount(double amount) {
    _tipAmount = amount;
    _savePreferences();
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsMap = {'delivery_type': _deliveryType.toString(), 'tip_amount': _tipAmount};
    await prefs.setString('cart_preferences', jsonEncode(prefsMap));
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsStr = prefs.getString('cart_preferences');
    if (prefsStr != null) {
      try {
        final prefsMap = jsonDecode(prefsStr) as Map<String, dynamic>;
        final typeStr = prefsMap['delivery_type'] as String?;
        if (typeStr != null) {
          _deliveryType = DeliveryType.values.firstWhere(
            (e) => e.toString() == typeStr,
            orElse: () => DeliveryType.standard,
          );
        }
        _tipAmount = (prefsMap['tip_amount'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        debugPrint('Error decoding cart prefs: $e');
      }
    }
    notifyListeners();
  }

  double get total {
    try {
      final subtotalVal = subtotal.clamp(0.0, double.maxFinite);
      final discountVal = discount.clamp(0.0, subtotalVal);
      final deliveryVal = deliveryCharge.clamp(0.0, 10000.0);
      final tipVal = _tipAmount.clamp(0.0, 10000.0);
      final walletVal = _walletAmountUsed.clamp(0.0, subtotalVal);

      final total = subtotalVal - discountVal + deliveryVal + tipVal - walletVal;
      return total.clamp(0.0, double.maxFinite);
    } catch (e) {
      debugPrint('[CartProvider] Error calculating total: $e');
      return 0.0;
    }
  }

  int get rewardPointsUsed {
    try {
      final points = (discount * 10).floor();
      return points.clamp(0, 999999);
    } catch (e) {
      debugPrint('[CartProvider] Error calculating reward points: $e');
      return 0;
    }
  }

  // Add item to cart
  void addToCart(ProductModel product, {int quantity = 1, ProductUnitOption? selectedUnit}) {
    try {
      // Validate product has a price
      final price = selectedUnit?.price ?? product.price;
      if (price == null) {
        debugPrint('[CartProvider] Cannot add ${product.name}: invalid price (null)');
        return;
      }

      // Validate price is a valid positive number
      try {
        final priceVal = price.toDouble();
        if (!priceVal.isFinite || priceVal <= 0) {
          debugPrint('[CartProvider] Cannot add ${product.name}: invalid price ($priceVal)');
          return;
        }
      } catch (e) {
        debugPrint('[CartProvider] Cannot add ${product.name}: price conversion error: $e');
        return;
      }

      final unitId = selectedUnit?.id ?? 'default';

      final existingIndex = _cartItems.indexWhere(
        (item) => item.productId == product.id && (item.selectedVariant ?? 'default') == unitId,
      );

      if (existingIndex >= 0) {
        final newQuantity = (_cartItems[existingIndex].quantity + quantity).clamp(
          1,
          selectedUnit?.stockQuantity ?? product.maxOrderQuantity,
        );
        _cartItems[existingIndex] = _cartItems[existingIndex].copyWith(quantity: newQuantity);
      } else {
        final originalPrice = selectedUnit?.originalPrice != null
            ? MonetaryValue(selectedUnit!.originalPrice)
            : product.originalPrice;
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

        // Validate cart item before adding
        try {
          CartValidator.validateItemOrThrow(cartItem);
          _cartItems.add(cartItem);
        } catch (e) {
          DiagnosticsService().log('Cart', '🚨 Invalid item not added: $e', level: AppLogSeverity.error);
          debugPrint('[CartProvider] Item validation failed: $e');
          return;
        }
      }

      _saveCart();
      notifyListeners();
    } catch (e) {
      debugPrint('[CartProvider] Error adding ${product.name} to cart: $e');
    }
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

  // ── Dynamic coupon validation via Firestore ──
  /// Returns the applied coupon on success, or throws an Exception with a user-friendly message.
  Future<bool> applyCouponDynamic(String couponCode) async {
    if (couponCode.isEmpty) return false;
    final code = couponCode.trim().toUpperCase();

    try {
      // 1. Try Firestore first
      final snapshot = await FirebaseFirestore.instance
          .collection('coupons')
          .where('code', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final now = DateTime.now();
        final endDate = (data['endDate'] as dynamic)?.toDate() as DateTime?;
        final startDate = (data['startDate'] as dynamic)?.toDate() as DateTime?;

        if (startDate != null && now.isBefore(startDate)) {
          throw Exception('This coupon is not active yet.');
        }
        if (endDate != null && now.isAfter(endDate)) {
          throw Exception('This coupon has expired.');
        }

        final minimumOrder = (data['minimumOrderAmount'] as num? ?? 0.0).toDouble();
        if (subtotal < minimumOrder) {
          throw Exception(
            'Minimum order of ₹${minimumOrder.toStringAsFixed(0)} required for this coupon.',
          );
        }

        _appliedCoupon = Coupon(
          id: snapshot.docs.first.id,
          code: code,
          name: data['name'] as String? ?? code,
          description: data['description'] as String? ?? '',
          discountType: data['discountType'] as String? ?? 'percentage',
          discountValue: MonetaryValue((data['discountValue'] as num? ?? 0).toDouble()),
          minimumOrderAmount: minimumOrder,
          maximumDiscountAmount: (data['maximumDiscountAmount'] as num? ?? 0.0).toDouble(),
          startDate: startDate ?? DateTime.now().subtract(const Duration(days: 1)),
          endDate: endDate ?? DateTime.now().add(const Duration(days: 365)),
        );
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('coupon')) rethrow;
      debugPrint('[CartProvider] Firestore coupon fetch failed, trying fallback: $e');
    }

    // 2. Fallback to hardcoded coupons (offline/demo mode)
    return applyCoupon(code);
  }

  // Hardcoded fallback coupons (used when Firestore is unavailable)
  bool applyCoupon(String couponCode) {
    if (couponCode.toUpperCase() == 'SAVE10') {
      _appliedCoupon = Coupon(
        id: 'coupon_1',
        code: 'SAVE10',
        name: '10% Off',
        description: 'Get 10% off on your order',
        discountType: 'percentage',
        discountValue: MonetaryValue(10),
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
        discountValue: MonetaryValue(20),
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
      await _cartSyncService.saveLocalCart(_cartItems);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  // Load cart from local storage
  Future<void> loadCart() async {
    _isLoading = true;
    notifyListeners();
    try {
      await loadPreferences();
      final loaded = await _cartSyncService.loadLocalCart();
      // Use CartValidator for comprehensive validation and filtering
      _cartItems = CartValidator.validateAndFilterCart(loaded);

      final loadedLater = await _cartSyncService.loadLocalSaveForLater();
      _saveForLaterItems = CartValidator.validateAndFilterCart(loadedLater);
    } catch (e) {
      DiagnosticsService().log('Cart', 'Error loading cart: $e', level: AppLogSeverity.error, error: e);
      debugPrint('Error loading cart: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sync to cloud
  Future<void> syncToCloud(String uid) async {
    await _cartSyncService.syncToCloud(uid, _cartItems);
  }

  // Load from cloud
  Future<void> loadFromCloud(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      _cartItems = await _cartSyncService.loadCloudCart(uid);
      _saveForLaterItems = await _cartSyncService.loadCloudSaveForLater(uid);
      await _saveCart();
      await _saveSaveForLater();
    } catch (e) {
      debugPrint('Error loading cloud cart: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Merge carts on login
  Future<void> mergeCartOnLogin(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      _cartItems = await _cartSyncService.mergeCarts(uid);
    } catch (e) {
      debugPrint('Error merging cart on login: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Guest cart migration ───────────────────────────────────
  /// Called after a guest verifies their identity (OTP or Google).
  ///
  /// Converts each [CartItemModel] (local guest format) to a [CartItem]
  /// (CartProvider format) and merges into the existing verified cart:
  ///  • If the product is already in cart → add quantities
  ///  • If not → insert as new item
  /// Saves locally and syncs to Firestore under the verified [userId].
  Future<void> migrateGuestCart(List<CartItemModel> guestItems, String userId) async {
    if (guestItems.isEmpty) return;

    for (final guest in guestItems) {
      final existingIdx = _cartItems.indexWhere((c) => c.productId == guest.productId);

      if (existingIdx >= 0) {
        // Merge quantity — cap at 99 to avoid insane quantities
        final merged = (_cartItems[existingIdx].quantity + guest.quantity).clamp(1, 99);
        _cartItems[existingIdx] = _cartItems[existingIdx].copyWith(quantity: merged);
      } else {
        // Convert CartItemModel → CartItem
        _cartItems.add(
          CartItem(
            id: '${guest.productId}_${DateTime.now().millisecondsSinceEpoch}',
            productId: guest.productId,
            productName: guest.productName,
            productImage: guest.imageUrl,
            unit: guest.selectedUnit,
            quantity: guest.quantity,
            price: guest.price,
            originalPrice: guest.originalPrice,
            stockQuantity: 999, // unknown at migration time; refreshed on next load
            shopId: guest.shopId,
            shopName: '', // refreshed from Firestore on next product load
            addedAt: DateTime.now(),
          ),
        );
      }
    }

    // Persist locally first (works offline)
    await _saveCart();

    // Then sync to Firestore (background — failure is non-fatal)
    try {
      await _cartSyncService.syncToCloud(userId, _cartItems);
    } catch (e) {
      debugPrint('[CartProvider] Guest cart cloud sync failed (non-fatal): $e');
    }

    notifyListeners();
    debugPrint('[CartProvider] Migrated ${guestItems.length} guest item(s) into verified cart.');
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

  // ── Save for Later Features ──
  Future<void> saveForLater(String cartItemId, String? userId) async {
    final index = _cartItems.indexWhere((item) => item.id == cartItemId);
    if (index >= 0) {
      final item = _cartItems.removeAt(index);
      _saveForLaterItems.add(item);

      await _saveCart();
      await _saveSaveForLater();

      if (userId != null) {
        await syncToCloud(userId);
        await syncSaveForLaterToCloud(userId);
      }
      notifyListeners();
    }
  }

  Future<void> moveToCart(String savedItemId, String? userId) async {
    final index = _saveForLaterItems.indexWhere((item) => item.id == savedItemId);
    if (index >= 0) {
      final item = _saveForLaterItems.removeAt(index);
      _cartItems.add(item);

      await _saveCart();
      await _saveSaveForLater();

      if (userId != null) {
        await syncToCloud(userId);
        await syncSaveForLaterToCloud(userId);
      }
      notifyListeners();
    }
  }

  Future<void> _saveSaveForLater() async {
    try {
      await _cartSyncService.saveLocalSaveForLater(_saveForLaterItems);
    } catch (e) {
      debugPrint('Error saving save for later items: $e');
    }
  }

  Future<void> syncSaveForLaterToCloud(String uid) async {
    await _cartSyncService.syncSaveForLaterToCloud(uid, _saveForLaterItems);
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
      return _cartItems
          .firstWhere(
            (item) => item.productId == productId && item.selectedVariant == selectedVariant,
          )
          .quantity;
    } catch (e) {
      return 0;
    }
  }

  void incrementQuantityForVariant(String productId, String? selectedVariant) {
    final index = _cartItems.indexWhere(
      (item) => item.productId == productId && item.selectedVariant == selectedVariant,
    );
    if (index >= 0) {
      final currentQty = _cartItems[index].quantity;
      updateQuantity(_cartItems[index].id, currentQty + 1);
    }
  }

  void decrementQuantityForVariant(String productId, String? selectedVariant) {
    final index = _cartItems.indexWhere(
      (item) => item.productId == productId && item.selectedVariant == selectedVariant,
    );
    if (index >= 0) {
      final currentQty = _cartItems[index].quantity;
      updateQuantity(_cartItems[index].id, currentQty - 1);
    }
  }

  /// Bulk add items from voice results (Feature: High-Speed One-Click Order)
  Future<void> bulkAddByVoice(
    List<Map<String, dynamic>> items,
    List<ProductModel> shopProducts,
  ) async {
    for (var item in items) {
      final String name = (item['name'] ?? '').toString().toLowerCase();
      final double qty = double.tryParse(item['quantity']?.toString() ?? '1.0') ?? 1.0;
      String unit = (item['unit'] ?? '').toString().toLowerCase();

      // Normalize Hindi voice quantities/units
      if (unit.contains('kilo') ||
          unit.contains('kilogram') ||
          unit == 'किलो' ||
          unit == 'किग्रा') {
        unit = 'kg';
      } else if (unit.contains('gram') || unit == 'ग्राम' || unit == 'जी' || unit == 'g') {
        unit = 'g';
      } else if (unit.contains('liter') || unit.contains('litre') || unit == 'लीटर') {
        unit = 'l';
      }

      // Find matching product in shop inventory
      ProductModel? match;

      // 1. Exact name match
      try {
        match = shopProducts.firstWhere((p) => p.name.toLowerCase() == name);
      } catch (_) {
        // 2. Contains match
        try {
          match = shopProducts.firstWhere(
            (p) => p.name.toLowerCase().contains(name) || name.contains(p.name.toLowerCase()),
          );
        } catch (_) {
          // 3. Tag match
          try {
            match = shopProducts.firstWhere(
              (p) => p.tags.any((tag) => tag.toLowerCase().contains(name)),
            );
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
