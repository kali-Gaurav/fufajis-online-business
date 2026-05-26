import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      // For large-scale apps, this should be a cloud function aggregation!
      // Doing a client-side sum is okay for MVP/Beta
      final completedOrdersSnapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .get();
      
      double revenue = 0.0;
      for (var doc in completedOrdersSnapshot.docs) {
        final data = doc.data();
        revenue += (data['totalAmount'] ?? 0.0).toDouble();
      }
      _totalRevenue = revenue;

    } catch (e) {
      _error = 'Failed to load metrics: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
