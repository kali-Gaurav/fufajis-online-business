import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/inventory_alert_service.dart';
import '../utils/order_number_generator.dart';
import '../models/payment_method.dart';
import '../models/delivery_type.dart';
import '../models/user_model.dart';
import '../services/razorpay_service.dart';
import '../models/payment_result.dart';

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
              : map['createdAt'].toDate())
          : DateTime.now(),
      status: map['status'] ?? 'pending',
      shopResponse: map['shopResponse'],
      processedAt: map['processedAt'] != null
          ? (map['processedAt'] is DateTime
              ? map['processedAt']
              : map['processedAt'].toDate())
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

/// OrderProvider manages the complete order lifecycle including:
class OrderProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();
  final InventoryAlertService _inventoryAlertService = InventoryAlertService();
  final RazorpayService _razorpayService = RazorpayService();

  // State variables
  List<OrderModel> _orders = [];
  OrderModel? _currentOrder;
  bool _isLoading = false;
  String? _errorMessage;
  int _ordersPage = 1;
  bool _hasMoreOrders = true;
  List<ReturnRequest> _returnRequests = [];

  // Pagination settings
  static const int _defaultPageLimit = 10;

  // Getters
  List<OrderModel> get orders => _orders;
  OrderModel? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get ordersPage => _ordersPage;
  bool get hasMoreOrders => _hasMoreOrders;
  List<ReturnRequest> get returnRequests => _returnRequests;

  String generateOrderNumber() {
    return OrderNumberGenerator.generate();
  }

  /// Initiates a professional checkout flow with Razorpay integration
  Future<OrderModel?> checkoutOnline({
    required OrderModel order,
    required String email,
    required VoidCallback onPaymentStarted,
    required Function(String) onPaymentError,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    Completer<OrderModel?> completer = Completer();

    _razorpayService.initialize(
      onSuccess: (PaymentResult result) async {
        try {
          final finalizedOrder = order.copyWith(
            paymentId: result.paymentId,
            paymentStatus: 'awaiting_verification',
            status: OrderStatus.pending,
          );
          final created = await createOrder(finalizedOrder);
          completer.complete(created);
        } catch (e) {
          completer.completeError(e);
        }
      },
      onFailure: (PaymentResult result) {
        onPaymentError(result.errorMessage ?? 'Payment failed');
        completer.complete(null);
      },
    );

    onPaymentStarted();
    
    final opened = _razorpayService.checkout(
      amount: order.totalAmount,
      orderId: 'txn_${DateTime.now().millisecondsSinceEpoch}',
      customerName: order.customerName,
      customerEmail: email,
      customerPhone: order.customerPhone,
    );

    if (!opened) {
      _isLoading = false;
      notifyListeners();
      return null;
    }

    return completer.future;
  }

  bool verifyDeliveryOTP(String orderId, String otp) {
    try {
      final order = _orders.firstWhere((o) => o.id == orderId);
      return order.otp == otp;
    } catch (e) {
      return false;
    }
  }

  Future<OrderModel?> getOrderById(String id) async {
    try {
      return _orders.firstWhere((o) => o.id == id);
    } catch (_) {
      try {
        final doc = await FirebaseFirestore.instance.collection('orders').doc(id).get();
        if (doc.exists) {
          return OrderModel.fromMap(doc.data()!);
        }
      } catch (e) {
        debugPrint('Error getting order by id: $e');
      }
    }
    return null;
  }

  // Wallet and reward points state
  double _walletBalance = 500.0;
  int _rewardPoints = 1250;

  double get walletBalance => _walletBalance;
  int get rewardPoints => _rewardPoints;

  List<StreamSubscription> _subscriptions = [];
  final Map<String, bool> _processingOrders = {};

  DocumentSnapshot? _lastOrderDoc;
  
  void listenToOrders(String userId) {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    if (_orders.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    // Paginating orders stream is complex with snapshots, 
    // we use a simplified paginated query for the list view
    // and a listener for the current active orders.
    final sub = _firestoreService.getOrdersStream(userId).listen((orders) {
      // For real-time updates of current orders
      // In production, we'd only listen to 'active' orders.
      _orders = orders; 
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      debugPrint('Error listening to orders: $error');
      _isLoading = false;
      notifyListeners();
    });

    _subscriptions.add(sub);
  }

  Future<void> fetchOrdersPaged({String? customerId, int limit = 10, bool isRefresh = false}) async {
    if (_isLoading) return;
    
    _isLoading = true;
    if (isRefresh) {
      _orders = [];
      _lastOrderDoc = null;
      _hasMoreOrders = true;
    }
    notifyListeners();

    try {
      Query query = FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).limit(limit);
      
      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customerId', isEqualTo: customerId);
      }

      if (_lastOrderDoc != null) {
        query = query.startAfterDocument(_lastOrderDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastOrderDoc = snapshot.docs.last;
        final newOrders = snapshot.docs.map((doc) => OrderModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
        _orders.addAll(newOrders);
        _hasMoreOrders = newOrders.length == limit;
      } else {
        _hasMoreOrders = false;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching paged orders: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void listenToAllOrders() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    if (_orders.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    final sub = _firestoreService.getAllOrdersStream().listen((orders) {
      _orders = orders;
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      debugPrint('Error listening to all orders: $error');
      _isLoading = false;
      notifyListeners();
    });

    _subscriptions.add(sub);
  }

  Future<OrderModel?> createOrder(OrderModel order) async {
    final idempotencyKey = '${order.customerId}_${DateTime.now().millisecondsSinceEpoch ~/ 5000}';
    if (_processingOrders[idempotencyKey] == true) {
      return null;
    }
    _processingOrders[idempotencyKey] = true;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final orderNumber = OrderNumberGenerator.generate();
      final newOrder = order.copyWith(
        orderNumber: orderNumber,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestoreService.createOrder(newOrder);

      _orders.insert(0, newOrder);
      
      _isLoading = false;
      notifyListeners();

      _notificationService.triggerLocalOrderStatusNotification(
        orderNumber,
        'Order Placed',
      );

      return newOrder;
    } catch (e) {
      debugPrint('Error creating order: $e');
      _errorMessage = 'Failed to create order: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    } finally {
      _processingOrders.remove(idempotencyKey);
    }
  }

  Future<void> fetchOrders({
    String? customerId,
    int page = 1,
    int limit = _defaultPageLimit,
  }) async {
    if (page == 1) {
      _isLoading = true;
      _ordersPage = 1;
      _hasMoreOrders = true;
      notifyListeners();
    }

    try {
      final FirebaseFirestore db = FirebaseFirestore.instance;
      Query<Map<String, dynamic>> query = db.collection('orders');

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('customerId', isEqualTo: customerId);
      }

      query = query.orderBy('createdAt', descending: true);
      query = query.limit(limit);

      if (page > 1 && _orders.isNotEmpty) {
        final lastOrder = _orders.last;
        final lastDoc = await db.collection('orders').doc(lastOrder.id).get();
        if (lastDoc.exists) {
          query = query.startAfterDocument(lastDoc);
        }
      }

      final snapshot = await query.get();

      final List<OrderModel> fetchedOrders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data()))
          .toList();

      if (page == 1) {
        _orders = fetchedOrders;
      } else {
        _orders.addAll(fetchedOrders);
      }

      _ordersPage = page;
      _hasMoreOrders = fetchedOrders.length == limit;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      _errorMessage = 'Failed to fetch orders: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOrders(String customerId) async {
    return fetchOrders(customerId: customerId);
  }

  Future<bool> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String? note,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index < 0) {
        _errorMessage = 'Order not found';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final order = _orders[index];

      final newHistoryEntry = StatusHistoryEntry(
        status: newStatus,
        timestamp: DateTime.now(),
        note: note ?? 'Status updated to ${newStatus.displayName}',
      );

      final updatedOrder = order.copyWith(
        status: newStatus,
        statusHistory: [...order.statusHistory, newHistoryEntry],
        updatedAt: DateTime.now(),
      );

      _orders[index] = updatedOrder;
      if (_currentOrder?.id == orderId) {
        _currentOrder = updatedOrder;
      }

      await _firestoreService.updateOrderStatus(
        orderId,
        newStatus.toString().split('.').last,
      );

      _notificationService.triggerLocalOrderStatusNotification(
        order.orderNumber,
        newStatus.displayName,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      _errorMessage = 'Failed to update order status: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Explicitly verify and approve payment and confirm order (Owner Flow)
  Future<bool> approveOrderAndPayment(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index < 0) {
        _errorMessage = 'Order not found';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final order = _orders[index];

      final newHistoryEntry = StatusHistoryEntry(
        status: OrderStatus.confirmed,
        timestamp: DateTime.now(),
        note: 'Order and Payment approved by owner.',
      );

      final updatedOrder = order.copyWith(
        status: OrderStatus.confirmed,
        paymentStatus: 'paid',
        statusHistory: [...order.statusHistory, newHistoryEntry],
        updatedAt: DateTime.now(),
      );

      _orders[index] = updatedOrder;
      if (_currentOrder?.id == orderId) {
        _currentOrder = updatedOrder;
      }

      // Update in Firestore
      final FirebaseFirestore db = FirebaseFirestore.instance;
      final batch = db.batch();

      final orderRef = db.collection('orders').doc(orderId);
      batch.update(orderRef, {
        'status': OrderStatus.confirmed.toString(),
        'paymentStatus': 'paid',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': updatedOrder.statusHistory.map((e) => e.toMap()).toList(),
      });

      if (order.paymentId != null && order.paymentId!.isNotEmpty) {
        final paymentRef = db.collection('payments').doc(order.paymentId);
        batch.set(paymentRef, {
          'verified': true,
          'status': 'captured',
          'verifiedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      _notificationService.triggerLocalOrderStatusNotification(
        order.orderNumber,
        'Order & Payment Approved',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error approving order and payment: $e');
      _errorMessage = 'Failed to approve order: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelOrder(String orderId, String reason) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index < 0) return false;

      final order = _orders[index];

      if (order.walletAmountUsed > 0) {
        _walletBalance += order.walletAmountUsed;
      }

      await _restoreStock(order.items);

      final newHistoryEntry = StatusHistoryEntry(
        status: OrderStatus.cancelled,
        timestamp: DateTime.now(),
        note: 'Order cancelled: $reason',
      );

      final updatedOrder = order.copyWith(
        status: OrderStatus.cancelled,
        cancellationReason: reason,
        statusHistory: [...order.statusHistory, newHistoryEntry],
        updatedAt: DateTime.now(),
      );

      _orders[index] = updatedOrder;
      if (_currentOrder?.id == orderId) {
        _currentOrder = updatedOrder;
      }

      await _firestoreService.updateOrderStatus(orderId, 'cancelled');

      _notificationService.triggerLocalOrderStatusNotification(
        order.orderNumber,
        'Cancelled',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      _errorMessage = 'Failed to cancel order: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> rateAndTipOrder(String orderId, double rating, {double? tip}) async {
    try {
      await _firestoreService.updateOrder(orderId, {
        'rating': rating,
        if (tip != null) 'tipAmount': FieldValue.increment(tip),
        'updatedAt': DateTime.now(),
      });
      
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index >= 0) {
        _orders[index] = _orders[index].copyWith(
          rating: rating,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error rating/tipping order: $e');
    }
  }

  Future<void> updateOrderItems(String orderId, List<OrderItem> items) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'items': items.map((i) => i.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void clearState() {
    _orders = [];
    _currentOrder = null;
    _errorMessage = null;
    _ordersPage = 1;
    _hasMoreOrders = true;
    _returnRequests = [];

    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    notifyListeners();
  }

  Future<void> _restoreStock(List<OrderItem> items) async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      for (var item in items) {
        final productRef = db.collection('products').doc(item.productId);
        batch.update(productRef, {
          'stockQuantity': FieldValue.increment(item.quantity),
          'isAvailable': true,
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error restoring stock: $e');
    }
  }

  Future<void> loadDemoOrders() async {}
  
  List<OrderModel> getOrdersByStatus(OrderStatus status) {
    return _orders.where((o) => o.status == status).toList();
  }

  List<OrderModel> searchOrders(String query) {
    return _orders.where((o) => o.orderNumber.contains(query)).toList();
  }

  String getMembershipTier() => 'Bronze';

  List<String> getFrequentlyBoughtProductIds() => [];

  bool isValidStatusTransition(OrderStatus current, OrderStatus next) => true;

  Future<void> addToWallet(double amount) async {
    _walletBalance += amount;
    notifyListeners();
  }

  Future<bool> createReturnRequest({
    required String orderId,
    required List<String> itemIds,
    required String reason,
    List<String>? proofImages,
  }) async {
    try {
      final order = await getOrderById(orderId);
      if (order == null) {
        _errorMessage = 'Order not found';
        return false;
      }

      final returnedItemsNames = order.items
          .where((item) => itemIds.contains(item.productId) || itemIds.contains(item.id))
          .map((item) => '${item.quantity}x ${item.productName}')
          .join(', ');

      final request = {
        'id': 'RET_${DateTime.now().millisecondsSinceEpoch}',
        'orderId': orderId,
        'orderNumber': order.orderNumber,
        'customerId': order.customerId,
        'customerName': order.customerName,
        'customerPhone': order.customerPhone,
        'itemIds': itemIds,
        'items': returnedItemsNames,
        'reason': reason,
        'status': 'pending',
        'amount': order.totalAmount, // Simplified
        'proofImages': proofImages ?? [],
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _firestoreService.createReturnRequest(request);
      return true;
    } catch (e) {
      debugPrint('Error creating return request: $e');
      _errorMessage = e.toString();
      return false;
    }
  }

  String getStatusTransitionNote(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Order placed and awaiting confirmation';
      case OrderStatus.confirmed:
        return 'Order confirmed by the shop';
      case OrderStatus.processing:
        return 'Order is being prepared';
      case OrderStatus.packed:
        return 'Order has been packed';
      case OrderStatus.outForDelivery:
        return 'Order is out for delivery';
      case OrderStatus.delivered:
        return 'Order has been delivered';
      case OrderStatus.cancelled:
        return 'Order has been cancelled';
      case OrderStatus.returned:
        return 'Return request processed';
      case OrderStatus.refunded:
        return 'Refund has been processed';
    }
  }

  Map<String, dynamic> getShopStats() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    final todayOrders = _orders.where((o) => o.createdAt.isAfter(todayStart)).toList();
    final todayOrderCount = todayOrders.length;
    final todayRevenue = todayOrders
        .where((o) => o.status != OrderStatus.cancelled)
        .fold(0.0, (total, o) => total + o.totalAmount);
        
    final pendingOrderCount = _orders.where((o) => o.status == OrderStatus.pending).length;
    
    return {
      'todayOrderCount': todayOrderCount,
      'todayRevenue': todayRevenue,
      'pendingOrderCount': pendingOrderCount,
    };
  }
}
