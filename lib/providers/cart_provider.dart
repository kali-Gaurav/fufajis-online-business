import 'dart:async';
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
import '../exceptions/cart_exception.dart';
import '../models/cart_merge_warning.dart';

class CartProvider with ChangeNotifier {
  final CartSyncService _cartSyncService = CartSyncService();
  List<CartItem> _cartItems = [];
  List<CartItem> _saveForLaterItems = [];
  Coupon? _appliedCoupon;
  double _walletAmountUsed = 0.0;
  double _tipAmount = 0.0; // Feature 24: Rider Tipping
  bool _isLoading = false;
  DeliveryType _deliveryType = DeliveryType.standard;

  // FIX #8: Cart freezing during checkout
  bool _cartFrozen = false;
  bool get isCartFrozen => _cartFrozen;

  // FIX #10: Auto-unfreeze timeout (15 mins) to prevent permanent locks
  Timer? _cartFreezeTimeout;
  static const Duration _cartFreezeDuration = Duration(minutes: 15);

  // FIX #11: Track cart merge warnings (items capped due to insufficient stock)
  List<CartMergeWarning> _mergeWarnings = [];
  List<CartMergeWarning> get mergeWarnings => _mergeWarnings;

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

  // FIX #8: Freeze/unfreeze cart during checkout
  // FIX #10: Auto-unfreeze with timeout to prevent permanent locks
  void freezeCart() {
    _cartFrozen = true;

    // Cancel any existing timeout
    _cartFreezeTimeout?.cancel();

    // Set auto-unfreeze timeout (15 mins)
    _cartFreezeTimeout = Timer(_cartFreezeDuration, () {
      debugPrint('[CartProvider] EMERGENCY AUTO-UNFREEZE: Cart was frozen for 15 mins');
      unfreezeCart();
    });

    notifyListeners();
  }

  void unfreezeCart() {
    // Cancel timeout when manually unfreezing
    _cartFreezeTimeout?.cancel();
    _cartFreezeTimeout = null;

    _cartFrozen = false;
    notifyListeners();
  }

  // FIX #11: Track merge warnings for items capped due to insufficient stock
  void addMergeWarning(CartMergeWarning warning) {
    _mergeWarnings.add(warning);
    notifyListeners();

    // Log warning to diagnostics
    DiagnosticsService().log(
      'CartProvider',
      '⚠️  Merge Warning: ${warning.message}',
      level: AppLogSeverity.warning,
    );
  }

  void clearMergeWarnings() {
    _mergeWarnings.clear();
    notifyListeners();
  }

  // FIX #12: Cross-Device Cart Conflict Resolution
  /// Merge two cart states with explicit conflict resolution strategy:
  /// - Cloud cart takes priority (authoritative)
  /// - Local device cart is merged additively only if no conflict
  /// - On conflict: Cloud item quantity + capped by inventory limit
  ///
  /// Strategy: "Cloud Wins" to prevent lost purchases across devices
  /// Example:
  ///   Device A: milk ×2 → syncs
  ///   Device B: milk ×3 → syncs
  ///   Device C (new): sees milk ×3 (cloud version wins)
  ///   Device A later adds: sees milk ×3, can still modify independently
  Future<List<CartItem>> resolveCartConflict(
    List<CartItem> localCart,
    List<CartItem> cloudCart,
  ) async {
    debugPrint('[CartProvider] Resolving cross-device cart conflict...');
    debugPrint('  Local items: ${localCart.length}, Cloud items: ${cloudCart.length}');

    // Strategy: Cloud cart is source of truth (authoritative state)
    // Local changes are merged only where they don't conflict
    final Map<String, CartItem> resolved = {
      for (var item in cloudCart) '${item.productId}_${item.selectedVariant}': item,
    };

    int mergedCount = 0;
    for (final localItem in localCart) {
      final key = '${localItem.productId}_${localItem.selectedVariant}';

      if (resolved.containsKey(key)) {
        // CONFLICT: Same product exists in both carts
        // Cloud wins (preserve cloud state)
        debugPrint('[CartProvider] Conflict for ${localItem.productName}: '
            'local=${localItem.quantity}, cloud=${resolved[key]!.quantity} → keeping cloud');
      } else {
        // NO CONFLICT: Local item not in cloud
        // Add local item to resolved cart
        resolved[key] = localItem;
        mergedCount++;
        debugPrint('[CartProvider] Merged local item: ${localItem.productName}');
      }
    }

    final result = resolved.values.toList();
    debugPrint('[CartProvider] Conflict resolved: $mergedCount new items merged, '
        '${localCart.length - mergedCount} local items skipped (cloud priority)');

    return result;
  }

  // Add item to cart
  // FIX #8: Check if cart is frozen during checkout
  void addToCart(ProductModel product, {int quantity = 1, ProductUnitOption? selectedUnit}) {
    if (_cartFrozen) {
      throw CartException('Cart is locked during checkout. Please wait.');
    }

    try {
      // Validate product has a price
      final price = selectedUnit?.price ?? product.price;

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
  // FIX #8: Check if cart is frozen during checkout
  void updateQuantity(String cartItemId, int quantity) {
    if (_cartFrozen) {
      throw CartException('Cannot modify cart during checkout. Please wait.');
    }

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
  /// FIX #7: Now validates coupon rules (expiry, usage limits, applicable products)
  /// FIX #8: Checks if cart is frozen during checkout
  Future<bool> applyCouponDynamic(String couponCode, {dynamic supabase, String? userId}) async {
    if (couponCode.isEmpty) return false;

    // FIX #8: Prevent coupon application during checkout
    if (_cartFrozen) {
      throw CartException('Cannot modify coupon during checkout. Please wait.');
    }

    final code = couponCode.trim().toUpperCase();

    try {
      // FIX #7: Validate against PostgreSQL (source of truth) — not Firestore
      if (supabase != null) {
        final { data: coupon, error: couponError } = await supabase
          .from("coupons")
          .select("*")
          .eq("code", code)
          .single();

        if (couponError != null || coupon == null) {
          throw Exception('Coupon $code not found');
        }

        // VALIDATE COUPON RULES
        final now = DateTime.now();

        // Check expiry
        if (coupon['expires_at'] != null) {
          final expiresAt = DateTime.parse(coupon['expires_at'] as String);
          if (now.isAfter(expiresAt)) {
            throw Exception('Coupon $code has expired');
          }
        }

        // Check usage limits
        if (userId != null && coupon['max_uses_per_user'] != null) {
          final { data: userUsageCount } = await supabase
            .from("coupon_usage_log")
            .select("id", count: CountOption.exact)
            .eq("coupon_id", coupon['id'])
            .eq("user_id", userId);

          if (userUsageCount >= coupon['max_uses_per_user']) {
            throw Exception(
              'Coupon $code can only be used ${coupon['max_uses_per_user']} times'
            );
          }
        }

        // Check applicable products/categories
        if (coupon['applicable_product_ids'] != null &&
            (coupon['applicable_product_ids'] as List).isNotEmpty) {
          final applicableIds = List<String>.from(coupon['applicable_product_ids'] as List);
          final allItemsApplicable = _cartItems.every((item) =>
            applicableIds.contains(item.productId)
          );
          if (!allItemsApplicable) {
            throw Exception('Coupon $code not applicable to some items in cart');
          }
        }

        // Check minimum order
        final minimumOrder = (coupon['minimum_order_amount'] as num? ?? 0.0).toDouble();
        if (subtotal < minimumOrder) {
          throw Exception(
            'Minimum order of ₹${minimumOrder.toStringAsFixed(0)} required for this coupon.',
          );
        }

        _appliedCoupon = Coupon(
          id: coupon['id'] as String? ?? code,
          code: code,
          name: coupon['name'] as String? ?? code,
          description: coupon['description'] as String? ?? '',
          discountType: coupon['discount_type'] as String? ?? 'percentage',
          discountValue: MonetaryValue((coupon['discount_value'] as num? ?? 0).toDouble()),
          minimumOrderAmount: minimumOrder,
          maximumDiscountAmount: (coupon['maximum_discount_amount'] as num? ?? 0.0).toDouble(),
          startDate: coupon['starts_at'] != null ? DateTime.parse(coupon['starts_at'] as String) : DateTime.now().subtract(const Duration(days: 1)),
          endDate: coupon['expires_at'] != null ? DateTime.parse(coupon['expires_at'] as String) : DateTime.now().add(const Duration(days: 365)),
        );
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('coupon')) rethrow;
      debugPrint('[CartProvider] PostgreSQL coupon fetch failed, trying Firestore fallback: $e');
    }

    // Fallback: Try Firestore (read-only cache)
    try {
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
      debugPrint('[CartProvider] Firestore fallback also failed: $e');
    }

    throw Exception('Coupon $code not found');
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

  // Non-blocking load in post-frame (Deployment Readiness feature)
  void loadCartAsync() {
    _isLoading = true;
    notifyListeners(); // Immediate synchronous loading state

    // Defer the heavy async work until after the current frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
    });
  }

  // Load cart from local storage (Legacy blocking async)
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
  Future<void> mergeCartOnLogin(String uid, {dynamic supabase}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _cartItems = await _cartSyncService.mergeCarts(uid, supabase: supabase);
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
  ///  • If the product is already in cart → add quantities (FIX #12: Cloud wins in conflict)
  ///  • If not → insert as new item
  /// Saves locally and syncs to Firestore under the verified [userId].
  /// FIX #6: Now idempotent — uses idempotency key to prevent duplicate migrations
  /// FIX #12: Cross-device conflict resolution: Cloud cart takes priority (last-write-wins anti-pattern avoided)
  Future<void> migrateGuestCart(List<CartItemModel> guestItems, String userId, {dynamic supabase}) async {
    if (guestItems.isEmpty) return;

    final migrationIdempotencyKey = 'cart_migrate_${userId}_${DateTime.now().year}${DateTime.now().month}${DateTime.now().day}';

    // FIX #6: Check if migration already done via idempotency log
    if (supabase != null) {
      try {
        final { data: existing, error: existingError } = await supabase
          .from("idempotency_log")
          .select("result")
          .eq("idempotency_key", migrationIdempotencyKey)
          .single();

        if (existing != null && existing['result'] != null) {
          // Already migrated — use cached result
          try {
            final cachedCartJson = json.decode(existing['result'] as String) as List;
            _cartItems = cachedCartJson
                .map((item) => CartItem.fromMap(item as Map<String, dynamic>))
                .toList();
            notifyListeners();
            debugPrint('[CartProvider] Recovered from idempotency log: migration already done');
            return;
          } catch (e) {
            debugPrint('[CartProvider] Failed to restore from idempotency log: $e');
          }
        }
      } catch (e) {
        // Not found or error — proceed with fresh migration
        debugPrint('[CartProvider] No idempotency record found, proceeding with migration');
      }
    }

    // NEW MIGRATION
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

    // FIX #6: PERSIST THE RESULT WITH IDEMPOTENCY KEY before syncing
    if (supabase != null) {
      try {
        await supabase.from("idempotency_log").insert({
          "idempotency_key": migrationIdempotencyKey,
          "result": json.encode(_cartItems.map((c) => c.toMap()).toList()),
          "created_at": DateTime.now().toIso8601String()
        });
      } catch (e) {
        debugPrint('[CartProvider] Failed to log idempotency: $e');
      }
    }

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
  // FIX #5: Now transactional — syncs to cloud BEFORE clearing local cart
  Future<void> clearCart(String? userId) async {
    final cartItemsBackup = List<CartItem>.from(_cartItems);

    try {
      // First sync to cloud (transactional)
      if (userId != null) {
        await _cartSyncService.clearCloudCart(userId);
      }

      // Only clear locally AFTER cloud is confirmed cleared
      _cartItems = [];
      _appliedCoupon = null;
      _walletAmountUsed = 0.0;
      _deliveryType = DeliveryType.standard;
      await _saveCart();
      notifyListeners();

    } catch (e) {
      // Restore from backup if sync fails
      _cartItems = cartItemsBackup;
      debugPrint('[CartProvider] Failed to clear cart, restored backup: $e');
      notifyListeners();
      rethrow;
    }
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

  Future<void> moveToCart(String savedItemId, String? userId, {dynamic supabase, String? shopId}) async {
    final index = _saveForLaterItems.indexWhere((item) => item.id == savedItemId);
    if (index >= 0) {
      final item = _saveForLaterItems.removeAt(index);

      // FIX #4: Check inventory before moving to cart
      if (supabase != null && shopId != null) {
        final { data: inventory, error: inventoryError } = await supabase
          .rpc("check_available_stock", {
            "p_product_id": item.productId,
            "p_shop_id": shopId
          })
          .single();

        if (inventoryError != null || inventory == null || (inventory['available'] as int?) ?? 0 < item.quantity) {
          // Stock unavailable — return to saved list
          _saveForLaterItems.insert(index, item);
          notifyListeners();

          throw CartException(
            'Product ${item.productId} no longer has ${item.quantity} units. '
            'Only ${inventory?['available'] ?? 0} available.'
          );
        }
      }

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
