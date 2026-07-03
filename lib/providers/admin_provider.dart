import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/coupon.dart';
import '../models/user_model.dart';

class AdminProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _totalUsers = 0;
  int get totalUsers => _totalUsers;

  int _totalShops = 0;
  int get totalShops => _totalShops;

  int _totalActiveOrders = 0;
  int get totalActiveOrders => _totalActiveOrders;

  double _totalRevenue = 0.0;
  double get totalRevenue => _totalRevenue;

  String _error = '';
  String get error => _error;

  List<UserModel> _users = [];
  List<UserModel> get users => _users;

  List<Map<String, dynamic>> _shops = [];
  List<Map<String, dynamic>> get shops => _shops;

  List<ProductModel> _pendingProducts = [];
  List<ProductModel> get pendingProducts => _pendingProducts;

  List<OrderModel> _orders = [];
  List<OrderModel> get orders => _orders;

  List<Coupon> _coupons = [];
  List<Coupon> get coupons => _coupons;

  /// Fetch high-level metrics for the Admin Dashboard
  Future<void> fetchDashboardMetrics() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Fetch Users Count
      final usersSnapshot = await _firestore.collection('users').count().get();
      _totalUsers = usersSnapshot.count ?? 0;

      // Fetch Shops Count
      final shopsSnapshot = await _firestore.collection('shops').count().get();
      _totalShops = shopsSnapshot.count ?? 0;

      // Fetch Active Orders (Assuming status 'pending', 'accepted', 'out_for_delivery')
      final activeOrdersSnapshot = await _firestore
          .collection('orders')
          .where('status', whereIn: ['pending', 'accepted', 'out_for_delivery'])
          .count()
          .get();
      _totalActiveOrders = activeOrdersSnapshot.count ?? 0;

      // Calculate Total Revenue from completed orders
      final completedOrdersSnapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .get();

      double revenue = 0.0;
      for (var doc in completedOrdersSnapshot.docs) {
        final data = doc.data();
        revenue += ((data['totalAmount'] as num?) ?? 0.0).toDouble();
      }
      _totalRevenue = revenue;
    } catch (e) {
      _error = 'Failed to load metrics: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch all users
  Future<void> fetchUsers() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('users').get();
      _users = snapshot.docs
          .map((doc) => UserModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      _error = 'Failed to fetch users: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle block status of user
  Future<void> toggleBlockUser(String userId, bool isBlocked) async {
    try {
      await _firestore.collection('users').doc(userId).update({'isBlocked': isBlocked});
      final index = _users.indexWhere((u) => u.id == userId);
      if (index >= 0) {
        _users[index] = _users[index].copyWith(isBlocked: isBlocked);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to update user status: $e';
      notifyListeners();
    }
  }

  /// Fetch all shops
  Future<void> fetchShops() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('shops').get();
      _shops = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      _error = 'Failed to fetch shops: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update shop verification / approval status
  Future<void> updateShopStatus(String shopId, String status) async {
    try {
      await _firestore.collection('shops').doc(shopId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await fetchShops();
    } catch (e) {
      _error = 'Failed to update shop status: $e';
      notifyListeners();
    }
  }

  /// Fetch all pending products across all shops for moderation
  Future<void> fetchPendingProducts() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Fetch products marked as pending approval from root collection
      final snapshot = await _firestore
          .collection('products')
          .where('isApproved', isEqualTo: false)
          .get();

      _pendingProducts = snapshot.docs
          .map((doc) => ProductModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      _error = 'Failed to fetch pending products: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Approve product
  Future<void> approveProduct(String shopId, String productId) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'isApproved': true,
        'isAvailable': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _pendingProducts.removeWhere((p) => p.id == productId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to approve product: $e';
      notifyListeners();
    }
  }

  /// Reject product
  Future<void> rejectProduct(String shopId, String productId, String reason) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'isApproved': false,
        'isAvailable': false,
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _pendingProducts.removeWhere((p) => p.id == productId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to reject product: $e';
      notifyListeners();
    }
  }

  /// Fetch global orders
  Future<void> fetchOrders() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get();
      _orders = snapshot.docs
          .map((doc) => OrderModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      _error = 'Failed to fetch orders: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancel Order (Admin Intervention)
  Future<void> cancelOrder(String orderId, String reason) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await fetchOrders();
    } catch (e) {
      _error = 'Failed to cancel order: $e';
      notifyListeners();
    }
  }

  /// Fetch all coupons
  Future<void> fetchCoupons() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('coupons').get();
      _coupons = snapshot.docs.map((doc) => Coupon.fromMap({...doc.data(), 'id': doc.id})).toList();
    } catch (e) {
      _error = 'Failed to fetch coupons: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create new coupon
  Future<void> createCoupon(Coupon coupon) async {
    try {
      await _firestore.collection('coupons').add(coupon.toMap());
      await fetchCoupons();
    } catch (e) {
      _error = 'Failed to create coupon: $e';
      notifyListeners();
    }
  }

  /// Delete coupon
  Future<void> deleteCoupon(String couponId) async {
    try {
      await _firestore.collection('coupons').doc(couponId).delete();
      _coupons.removeWhere((c) => c.id == couponId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete coupon: $e';
      notifyListeners();
    }
  }
}
