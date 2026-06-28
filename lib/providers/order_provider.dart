import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../constants/order_status.dart';
import '../models/order_model.dart';
import '../models/business_transaction.dart';
import '../models/payment_method.dart';
import '../services/order_service.dart';
import '../services/notification_service.dart';
import '../utils/order_number_generator.dart';
import '../services/razorpay_service.dart';
import '../services/offline_manager.dart';
import '../services/offline_order_queue_service.dart';

/// Return request model for handling customer returns
class ReturnRequest {
  final String id;
  final String orderId;
  final String customerId;
  final String reason;
  final List<String> itemIds;
  final DateTime createdAt;
  final String status;
  final String? shopResponse;
  final DateTime? processedAt;

  const ReturnRequest({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.reason,
    required this.itemIds,
    required this.createdAt,
    this.status = 'pending',
    this.shopResponse,
    this.processedAt,
  });

  factory ReturnRequest.fromMap(Map<String, dynamic> map) {
    return ReturnRequest(
      id: map['id'] ?? '',
      orderId: map['orderId'] ?? '',
      customerId: map['customerId'] ?? '',
      reason: map['reason'] ?? '',
      itemIds: List<String>.from(map['itemIds'] ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is DateTime
              ? map['createdAt']
              : (map['createdAt'] as Timestamp).toDate())
          : DateTime.now(),
      status: map['status'] ?? 'pending',
      shopResponse: map['shopResponse'],
      processedAt: map['processedAt'] != null
          ? (map['processedAt'] is DateTime
              ? map['processedAt']
              : (map['processedAt'] as Timestamp).toDate())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'customerId': customerId,
      'reason': reason,
      'itemIds': itemIds,
      'createdAt': createdAt,
      'status': status,
      'shopResponse': shopResponse,
      'processedAt': processedAt,
    };
  }
}

class OrderProvider with ChangeNotifier {
  final OrderService _orderService = OrderService();
  final NotificationService _notificationService = NotificationService();
  final RazorpayService _razorpayService = RazorpayService();
  final Connectivity _connectivity = Connectivity();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  OrderProvider() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    await OfflineManager().initialize();
    _connectivity.onConnectivityChanged.listen((dynamic result) {
      bool isOnline = false;
      if (result is List) {
        isOnline = !result.contains(ConnectivityResult.none);
      } else {
        isOnline = result != ConnectivityResult.none;
      }
      if (isOnline) {
        syncOfflineOrders();
      }
    });
  }

  List<OrderModel> _orders = [];
  OrderModel? _currentOrder;
  bool _isLoading = false;
  String? _errorMessage;
  int _ordersPage = 1;
  bool _hasMoreOrders = true;
  final List<ReturnRequest> _returnRequests = [];
  final Map<String, bool> _processingOrders = {};
  DocumentSnapshot? _lastOrderDoc;
  final List<StreamSubscription> _subscriptions = [];
  bool _isRazorpayActive = false;

  double _walletBalance = 500.0;

  List<OrderModel> get orders => _orders;
  OrderModel? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get ordersPage => _ordersPage;
  bool get hasMoreOrders => _hasMoreOrders;
  List<ReturnRequest> get returnRequests => _returnRequests;
  double get walletBalance => _walletBalance;
  int get queuedOrderCount => OfflineOrderQueueService().queuedCount.value;

  Future<void> _recordTransaction({
    required String orderId,
    required String orderNumber,
    required String customerId,
    required double amount,
    required TransactionType type,
    required String method,
    String? gatewayId,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('transactions').doc();
      final transaction = BusinessTransaction(
        id: docRef.id,
        orderId: orderId,
        orderNumber: orderNumber,
        customerId: customerId,
        amount: amount,
        type: type,
        status: TransactionStatus.completed,
        paymentMethod: method,
        gatewayTransactionId: gatewayId,
        createdAt: DateTime.now(),
      );
      await docRef.set(transaction.toMap());
    } catch (e) {
      debugPrint('Error recording transaction: $e');
    }
  }

  Future<OrderModel?> createOrder(OrderModel order) async {
    final idempotencyKey = '${order.customerId}_${DateTime.now().millisecondsSinceEpoch ~/ 5000}';
    if (_processingOrders[idempotencyKey] == true) return null;
    _processingOrders[idempotencyKey] = true;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final existingDoc = await FirebaseFirestore.instance.collection('orders').doc(order.id).get();
      if (existingDoc.exists) {
        _isLoading = false;
        _processingOrders.remove(idempotencyKey);
        notifyListeners();
        return OrderModel.fromMap(existingDoc.data()!);
      }

      final orderNumber = OrderNumberGenerator.generate();
      final newOrder = order.copyWith(
        orderNumber: orderNumber,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final dynamic connRes = await _connectivity.checkConnectivity();
      bool isOffline = (connRes is List) ? connRes.contains(ConnectivityResult.none) : connRes == ConnectivityResult.none;

      if (isOffline) {
        await OfflineManager().queueOrder(newOrder);
        _orders.insert(0, newOrder);
        _isLoading = false;
        notifyListeners();
        _notificationService.triggerLocalOrderStatusNotification(orderNumber, 'Order Queued (Offline)');
        return newOrder;
      }

      await _orderService.createOrder(newOrder);
      if (newOrder.paymentStatus == 'paid') {
        await _recordTransaction(
          orderId: newOrder.id,
          orderNumber: newOrder.orderNumber,
          customerId: newOrder.customerId,
          amount: newOrder.totalAmount.toDouble(),
          type: TransactionType.payment,
          method: newOrder.paymentMethod.toString().split('.').last,
          gatewayId: newOrder.paymentId,
        );
      }

      _orders.insert(0, newOrder);
      _isLoading = false;
      notifyListeners();
      _notificationService.triggerLocalOrderStatusNotification(orderNumber, 'Order Placed');
      
      // In-App Notification
      if (newOrder.customerId.isNotEmpty) {
        _notificationService.sendNotificationToUser(
          userId: newOrder.customerId,
          title: 'Order Placed',
          body: 'We have received your order #$orderNumber!',
          data: {'type': 'orderUpdate', 'orderId': newOrder.id},
        );
      }
      
      return newOrder;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    } finally {
      _processingOrders.remove(idempotencyKey);
    }
  }

  Future<OrderModel?> checkoutOnline({
    required OrderModel order,
    required String email,
    required VoidCallback onPaymentStarted,
    required Function(String) onPaymentError,
  }) async {
    if (_isRazorpayActive) {
      _errorMessage = "Another payment is already in progress.";
      notifyListeners();
      return null;
    }
    _isRazorpayActive = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    Completer<OrderModel?> completer = Completer();

    _razorpayService.initialize(
      onSuccess: (PaymentSuccessResponse response) async {
        try {
          final finalizedOrder = order.copyWith(
            paymentId: response.paymentId,
            paymentStatus: 'paid',
            status: OrderStatus.confirmed,
          );
          final created = await createOrder(finalizedOrder);
          completer.complete(created);
        } catch (e) {
          completer.completeError(e);
        }
      },
      onFailure: (PaymentFailureResponse response) {
        onPaymentError(response.message ?? 'Payment failed');
        completer.complete(null);
      },
    );

    try {
      onPaymentStarted();
      await _razorpayService.createOrder(
        amount: order.totalAmount.toDouble(),
        orderId: order.id,
        customerId: order.customerId,
        customerName: order.customerName,
        customerEmail: email,
        customerPhone: order.customerPhone,
      );

      final result = await completer.future;
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isRazorpayActive = false;
    }
  }

  Future<bool> convertToOnlinePayment({
    required OrderModel order,
    required String email,
    required VoidCallback onPaymentStarted,
    required Function(String) onPaymentError,
  }) async {
    if (_isRazorpayActive) {
      _errorMessage = "Another payment is already in progress.";
      notifyListeners();
      return false;
    }
    _isRazorpayActive = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    Completer<bool> completer = Completer();

    _razorpayService.initialize(
      onSuccess: (PaymentSuccessResponse response) async {
        try {
          final updatedOrder = order.copyWith(
            paymentMethod: PaymentMethod.razorpay,
            paymentId: response.paymentId,
            paymentStatus: 'paid',
            paymentConvertedFrom: order.paymentMethod.toString().split('.').last,
            status: order.status == OrderStatus.pending ? OrderStatus.confirmed : order.status,
          );
          
          await _orderService.updateOrder(order.id, {
            'paymentMethod': updatedOrder.paymentMethod.toString(),
            'paymentId': updatedOrder.paymentId,
            'paymentStatus': updatedOrder.paymentStatus,
            'paymentConvertedFrom': updatedOrder.paymentConvertedFrom,
            'status': updatedOrder.status.toString(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final index = _orders.indexWhere((o) => o.id == order.id);
          if (index >= 0) _orders[index] = updatedOrder;
          if (_currentOrder?.id == order.id) _currentOrder = updatedOrder;

          await _recordTransaction(
            orderId: order.id,
            orderNumber: order.orderNumber,
            customerId: order.customerId,
            amount: order.totalAmount.toDouble(),
            type: TransactionType.payment,
            method: 'razorpay',
            gatewayId: response.paymentId,
          );

          _isLoading = false;
          notifyListeners();
          completer.complete(true);
        } catch (e) {
          _isLoading = false;
          _errorMessage = e.toString();
          notifyListeners();
          completer.complete(false);
        }
      },
      onFailure: (PaymentFailureResponse response) {
        onPaymentError(response.message ?? 'Payment failed');
        _isLoading = false;
        notifyListeners();
        completer.complete(false);
      },
    );

    try {
      onPaymentStarted();
      await _razorpayService.createOrder(
        amount: order.totalAmount.toDouble(),
        orderId: order.id,
        customerId: order.customerId,
        customerName: order.customerName,
        customerEmail: email,
        customerPhone: order.customerPhone,
      );

      final result = await completer.future;
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isRazorpayActive = false;
    }
  }

  Future<bool> verifyAndDeliverOrder({
    required String orderId,
    required String otp,
    required double riderLatitude,
    required double riderLongitude,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _orderService.verifyAndDeliverOrder(
        orderId: orderId,
        otp: otp,
        riderLatitude: riderLatitude,
        riderLongitude: riderLongitude,
      );

      if (success) {
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index >= 0) {
          _orders[index] = _orders[index].copyWith(
            status: OrderStatus.delivered,
            otpVerified: true,
            updatedAt: DateTime.now(),
            deliveredAt: DateTime.now(),
          );
          if (_currentOrder?.id == orderId) _currentOrder = _orders[index];
          await _syncOrderToRDS(_orders[index]);

          // Award cashback on delivery (not placement) — anti-abuse
          final deliveredOrder = _orders[index];
          try {
            await _firestore
                .collection('cashback_triggers')
                .doc(orderId)
                .set({
              'orderId': orderId,
              'customerId': deliveredOrder.customerId,
              'orderTotal': deliveredOrder.totalAmount,
              'paymentMethod': deliveredOrder.paymentMethod.toString(),
              'deliveredAt': FieldValue.serverTimestamp(),
              'cashbackStatus': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('[OrderProvider] cashback_trigger write failed: \$e');
          }
        }
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> approveOrderAndPayment(String orderId, {String? method}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index < 0) return false;

      final order = _orders[index];
      final actualMethod = method ?? order.paymentMethod.toString().split('.').last;

      final OrderModel updatedOrder = order.updateStatus(
        OrderStatus.confirmed, 
        note: 'Payment and Order Approved',
      ).copyWith(
        paymentStatus: 'paid',
        paymentMethod: method != null ? PaymentMethod.values.firstWhere((e) => e.toString().contains(method)) : order.paymentMethod,
      );

      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': updatedOrder.status.toString(),
        'paymentStatus': 'paid',
        'paymentMethod': updatedOrder.paymentMethod.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _recordTransaction(
        orderId: orderId,
        orderNumber: order.orderNumber,
        customerId: order.customerId,
        amount: order.totalAmount.toDouble(),
        type: TransactionType.payment,
        method: actualMethod,
      );

      _orders[index] = updatedOrder;
      if (_currentOrder?.id == orderId) _currentOrder = updatedOrder;
      _isLoading = false;
      notifyListeners();
      
      if (updatedOrder.customerId.isNotEmpty) {
        _notificationService.sendNotificationToUser(
          userId: updatedOrder.customerId,
          title: 'Order Confirmed',
          body: 'Your order #${updatedOrder.orderNumber} has been confirmed.',
          data: {'type': 'orderUpdate', 'orderId': orderId},
        );
      }
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchOrders({String? customerId, int page = 1, int limit = 10}) async {
    if (page == 1) {
      _isLoading = true;
      _ordersPage = 1;
      _hasMoreOrders = true;
      _orders = [];
      _lastOrderDoc = null;
      notifyListeners();
    }

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true);
      if (customerId != null) query = query.where('customerId', isEqualTo: customerId);
      if (_lastOrderDoc != null) query = query.startAfterDocument(_lastOrderDoc!);
      
      final snapshot = await query.limit(limit).get();
      if (snapshot.docs.isNotEmpty) {
        _lastOrderDoc = snapshot.docs.last;
        final fetched = snapshot.docs.map((d) => OrderModel.fromMap(d.data())).toList();
        _orders.addAll(fetched);
        _hasMoreOrders = fetched.length == limit;
      } else {
        _hasMoreOrders = false;
      }
      _isLoading = false;
      _ordersPage = page;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<OrderModel?> getOrderById(String id) async {
    final idx = _orders.indexWhere((o) => o.id == id);
    if (idx != -1) return _orders[idx];
    final doc = await FirebaseFirestore.instance.collection('orders').doc(id).get();
    return doc.exists ? OrderModel.fromMap(doc.data()!) : null;
  }

  Future<bool> cancelOrder(String orderId, String reason) async {
    _isLoading = true;
    notifyListeners();
    try {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        // This will throw StateError if transition is invalid
        final cancelledOrder = _orders[index].updateStatus(
          OrderStatus.cancelled, 
          note: reason,
        ).copyWith(cancellationReason: reason);
        
        await _orderService.updateOrderStatus(orderId, 'cancelled');
        _orders[index] = cancelledOrder;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Safely update an order's status enforcing state machine rules
  Future<bool> updateOrderStatusSafe(String orderId, OrderStatus newStatus, {String? note, bool force = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index == -1) return false;

      final currentOrder = _orders[index];
      
      // 1. Enforce State Machine Validation
      final updatedOrder = currentOrder.updateStatus(newStatus, note: note, force: force);

      // 2. Persist to Firestore
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': updatedOrder.status.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': updatedOrder.statusHistory.map((e) => e.toMap()).toList(),
      });

      // 3. Update Local State
      _orders[index] = updatedOrder;
      if (_currentOrder?.id == orderId) _currentOrder = updatedOrder;
      
      _isLoading = false;
      notifyListeners();
      
      // Send In-App notification for status change
      if (updatedOrder.customerId.isNotEmpty) {
        if (newStatus == OrderStatus.cancelled) {
          _notificationService.sendNotificationToUser(
            userId: updatedOrder.customerId,
            title: 'Order Cancelled',
            body: 'Your order #${updatedOrder.orderNumber} has been cancelled.',
            data: {'type': 'orderUpdate', 'orderId': orderId},
          );
        } else {
          _notificationService.sendNotificationToUser(
            userId: updatedOrder.customerId,
            title: 'Order Update',
            body: 'Your order #${updatedOrder.orderNumber} is now ${newStatus.name}.',
            data: {'type': 'orderUpdate', 'orderId': orderId},
          );
        }
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createReturnRequest({
    required String orderId,
    required List<String> itemIds,
    required String reason,
    List<String>? proofImages,
  }) async {
    try {
      final order = await getOrderById(orderId);
      if (order == null) return false;
      final request = {
        'id': 'RET_${DateTime.now().millisecondsSinceEpoch}',
        'orderId': orderId,
        'customerId': order.customerId,
        'itemIds': itemIds,
        'reason': reason,
        'proofImages': proofImages ?? [],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _orderService.createReturnRequest(request);
      return true;
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> getShopStats() {
    return {
      'todayOrderCount': _orders.length,
      'todayRevenue': _orders.fold(0.0, (acc, o) => acc + o.totalAmount.toDouble()),
      'pendingOrderCount': _orders.where((o) => o.status == OrderStatus.pending).length,
    };
  }

  bool hasPurchasedProduct(String productId) {
    return _orders.any((o) => o.status == OrderStatus.delivered && o.items.any((i) => i.productId == productId));
  }

  List<String> getFrequentlyBoughtProductIds() {
    final Map<String, int> freq = {};
    for (var o in _orders) {
      for (var i in o.items) {
        freq[i.productId] = (freq[i.productId] ?? 0) + i.quantity;
      }
    }
    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).take(10).toList();
  }

  List<String> getWeeklyEssentials() => getFrequentlyBoughtProductIds();

  Future<void> syncOfflineOrders() async {
    final queued = await OfflineManager().getQueuedOrders();
    for (var o in queued) {
      await _orderService.createOrder(o);
      await OfflineManager().removeQueuedOrder(o.id);
    }
    notifyListeners();
  }

  Future<void> loadOrders(String userId) async {
    await fetchOrders(customerId: userId);
  }

  void listenToOrders(String userId) {
    _cancelSubscriptions();
    final sub = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _orders = snapshot.docs.map((d) => OrderModel.fromMap(d.data())).toList();
      notifyListeners();
    });
    _subscriptions.add(sub);
  }

  void listenToAllOrders() {
    _cancelSubscriptions();
    final sub = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _orders = snapshot.docs.map((d) => OrderModel.fromMap(d.data())).toList();
      notifyListeners();
    });
    _subscriptions.add(sub);
  }

  void _cancelSubscriptions() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  Future<OrderModel?> getOrderByParcelId(String parcelId) async {
    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .where('parcelId', isEqualTo: parcelId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return OrderModel.fromMap(snap.docs.first.data());
  }

  Future<void> addToWallet(double amount) async {
    _walletBalance += amount;
    // In a real app, update this in Firestore
    notifyListeners();
  }

  Future<void> _syncOrderToRDS(OrderModel order) async {
    debugPrint('[OrderProvider] Stub: RDS sync for order ${order.id} is deprecated.');
  }
}
