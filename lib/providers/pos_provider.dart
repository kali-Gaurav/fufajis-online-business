import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../models/payment_method.dart';
import '../services/storage_service.dart';
import '../services/logging_service.dart';
import '../services/analytics_service.dart';
import '../utils/monetary_value.dart';
import '../constants/order_status.dart';

/// Exception for POS-specific errors (stock, validation, etc.)
class PosException implements Exception {
  final String message;
  PosException(this.message);

  @override
  String toString() => message;
}

class PosBillItem {
  final ProductModel product;
  int quantity;
  double? customPrice;

  PosBillItem({required this.product, this.quantity = 1, this.customPrice});

  double get price => customPrice ?? product.productPrice;
  double get lineTotal => price * quantity;

  Map<String, dynamic> toMap() {
    return {'product': product.toMap(), 'quantity': quantity, 'customPrice': customPrice};
  }

  factory PosBillItem.fromMap(Map<String, dynamic> map) {
    return PosBillItem(
      product: ProductModel.fromMap(Map<String, dynamic>.from(map['product'] as Map)),
      quantity: (map['quantity'] as num? ?? 1).toInt(),
      customPrice: (map['customPrice'] as num?)?.toDouble(),
    );
  }
}

extension ProductPriceExt on ProductModel {
  double get productPrice => price.toDouble(); // Helper for consistency
}

class PosProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StorageService _storage = StorageService();
  final Connectivity _connectivity = Connectivity();

  List<ProductModel> _products = [];
  final List<PosBillItem> _cart = [];
  bool _isLoading = false;
  bool _isOnline = true;
  bool _isSyncing = false;
  double _manualDiscount = 0.0;
  String _discountReason = '';

  String? _customerPhone;
  String? _customerName;
  String? _customerId;

  List<ProductModel> get products => _products;
  List<PosBillItem> get cart => _cart;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  double get manualDiscount => _manualDiscount;
  String? get customerName => _customerName;

  PosProvider() {
    _init();
  }

  void setCustomer(String? id, String? name, String? phone) {
    _customerId = id;
    _customerName = name;
    _customerPhone = phone;
    notifyListeners();
  }

  void clearCustomer() {
    _customerId = null;
    _customerName = null;
    _customerPhone = null;
    notifyListeners();
  }

  Future<void> _init() async {
    await _storage.init();
    _checkConnectivity();
    _connectivity.onConnectivityChanged.listen((results) {
      _isOnline = !results.contains(ConnectivityResult.none);
      if (_isOnline) {
        syncOfflineOrders();
      }
      notifyListeners();
    });
    loadProducts();
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    notifyListeners();
  }

  // ── Product Management ──────────────────────────────────────────────

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Load from Cache
      final cached = _storage.get('pos_products_cache');
      if (cached != null && cached is List) {
        _products = cached
            .map((e) => ProductModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      // 2. If online, fetch fresh
      if (_isOnline) {
        final snap = await _db.collection('products').where('isAvailable', isEqualTo: true).get();
        _products = snap.docs.map((d) => ProductModel.fromMap(d.data())).toList();

        await _storage.put('pos_products_cache', _products.map((p) => p.toMap()).toList());
      }
    } catch (e, stack) {
      LoggingService().error('Error loading POS products', e, stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Cart Actions ────────────────────────────────────────────────────

  void addToCart(ProductModel product) {
    // Validate stock before adding
    if (product.stockQuantity < 1) {
      throw PosException('Out of stock: ${product.name}');
    }

    final idx = _cart.indexWhere((item) => item.product.id == product.id);
    if (idx >= 0) {
      // Check stock for increment
      if (_cart[idx].quantity >= product.stockQuantity) {
        throw PosException('Insufficient stock. Available: ${product.stockQuantity}');
      }
      _cart[idx].quantity++;
    } else {
      _cart.add(PosBillItem(product: product));
    }
    notifyListeners();
  }

  void incrementQty(int index) {
    final item = _cart[index];
    if (item.quantity >= item.product.stockQuantity) {
      throw PosException('Insufficient stock. Available: ${item.product.stockQuantity}');
    }
    item.quantity++;
    notifyListeners();
  }

  void decrementQty(int index) {
    if (_cart[index].quantity > 1) {
      _cart[index].quantity--;
    } else {
      _cart.removeAt(index);
    }
    notifyListeners();
  }

  void updatePrice(int index, double newPrice) {
    if (newPrice == _cart[index].product.price) {
      _cart[index].customPrice = null;
    } else {
      _cart[index].customPrice = newPrice;
    }
    notifyListeners();
  }

  void setDiscount(double amount, String reason) {
    // Validate discount: must be non-negative and not exceed subtotal
    if (amount < 0) {
      throw PosException('Discount cannot be negative');
    }
    if (amount > subtotal) {
      throw PosException('Discount cannot exceed subtotal (₹${subtotal.round()})');
    }

    _manualDiscount = amount;
    _discountReason = reason;
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _manualDiscount = 0.0;
    _discountReason = '';
    notifyListeners();
  }

  double get subtotal =>
      _cart.fold(0.0, (subtotalAccumulator, item) => subtotalAccumulator + item.lineTotal);
  double get taxAmount => subtotal * 0.18; // 18% GST (standard rate for India)
  double get total => (subtotal - _manualDiscount) + taxAmount;
  String get discountReason => _discountReason;

  // ── Checkout & Offline Sync ──────────────────────────────────────────

  Future<OrderModel?> checkout({
    required String paymentMethod,
    required String shopId,
    required String shopName,
    String? employeeId,
    String? employeeName,
    Map<String, double>? splitPayment,
  }) async {
    if (_cart.isEmpty) return null;

    final now = DateTime.now();
    final orderId = 'pos_${now.millisecondsSinceEpoch}';
    final orderNumber = 'POS-${now.millisecondsSinceEpoch.toString().substring(6)}';

    final orderItems = _cart
        .map(
          (bi) => OrderItem(
            id: bi.product.id,
            productId: bi.product.id,
            productName: bi.product.name,
            productImage: bi.product.imageUrl,
            unit: bi.product.unit,
            quantity: bi.quantity,
            price: MonetaryValue(bi.price),
            totalPrice: MonetaryValue(bi.lineTotal),
          ),
        )
        .toList();

    final order = OrderModel(
      id: orderId,
      orderNumber: orderNumber,
      customerId: _customerId ?? 'walk_in',
      customerName: _customerName ?? 'Walk-in Customer',
      customerPhone: _customerPhone ?? '',
      items: orderItems,
      subtotal: MonetaryValue(subtotal),
      deliveryCharge: MonetaryValue(0),
      discount: MonetaryValue(_manualDiscount),
      totalAmount: MonetaryValue(total),
      paymentMethod: _parsePaymentMethod(paymentMethod),
      paymentStatus: 'paid',
      status: OrderStatus.delivered,
      createdAt: now,
      updatedAt: now,
      deliveredAt: now,
      shopId: shopId,
      shopName: shopName,
      splitPayment: splitPayment?.map((key, value) => MapEntry(key, MonetaryValue(value))),
      deliveryAddress: Address(
        id: 'pos',
        label: 'In-store',
        fullAddress: 'POS Transaction',
        village: 'Store',
        landmark: 'Counter',
        pincode: '',
        latitude: 0,
        longitude: 0,
      ),
    );

    // 1. Instant local deduction (optimistic UI)
    for (var item in _cart) {
      final pIdx = _products.indexWhere((p) => p.id == item.product.id);
      if (pIdx >= 0) {
        final p = _products[pIdx];
        _products[pIdx] = p.copyWith(stockQuantity: p.stockQuantity - item.quantity);
      }
    }

    // 2. Save/Sync
    if (_isOnline) {
      await _db.runTransaction((transaction) async {
        for (var item in _cart) {
          final prodRef = _db.collection('products').doc(item.product.id);
          transaction.update(prodRef, {
            'stockQuantity': FieldValue.increment(-item.quantity),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final orderRef = _db.collection('orders').doc(order.id);
        transaction.set(orderRef, order.toMap());
      });
    } else {
      final pending = (_storage.get('pending_pos_orders') as List?) ?? [];
      pending.add(order.toMap());
      await _storage.put('pending_pos_orders', pending);
    }

    // 3. Register Balance
    if (paymentMethod == 'Cash') {
      final bal = (_storage.get('register_cash_balance') ?? 0.0) as double;
      await _storage.put('register_cash_balance', bal + total);
    } else if (paymentMethod == 'Split') {
      final cashPart = splitPayment?['Cash'] ?? 0.0;
      final bal = (_storage.get('register_cash_balance') ?? 0.0) as double;
      await _storage.put('register_cash_balance', bal + cashPart);
    }

    // Log POS-specific analytics event
    await AnalyticsService.instance.logCustomEvent(
      eventName: 'pos_bill_created',
      parameters: {
        'bill_id': order.id,
        'order_number': order.orderNumber,
        'total_amount': total,
        'items_count': _cart.length,
        'payment_method': paymentMethod,
        'has_discount': _manualDiscount > 0 ? 1 : 0,
        'discount_amount': _manualDiscount,
        'tax_amount': taxAmount,
        'subtotal': subtotal,
      },
    );

    // [MOD] Return order instead of auto-printing inside provider
    // This allows UI to show success dialog first.

    clearCart();
    clearCustomer();
    notifyListeners();
    return order;
  }

  Future<void> syncOfflineOrders() async {
    if (_isSyncing || !_isOnline) return;
    final pending = _storage.get('pending_pos_orders') as List?;
    if (pending == null || pending.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> toSync = List<Map<String, dynamic>>.from(pending);
      final List<Map<String, dynamic>> failed = [];

      for (var orderMap in toSync) {
        try {
          await _db.collection('orders').doc(orderMap['id'] as String?).set(orderMap);
        } catch (e) {
          failed.add(orderMap);
        }
      }

      await _storage.put('pending_pos_orders', failed);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  PaymentMethod _parsePaymentMethod(String m) {
    if (m == 'UPI') return PaymentMethod.upi;
    if (m == 'Card') return PaymentMethod.card;
    if (m == 'Split') return PaymentMethod.upi; // Represent split as mixed for now
    return PaymentMethod.cod; // Cash
  }
}
