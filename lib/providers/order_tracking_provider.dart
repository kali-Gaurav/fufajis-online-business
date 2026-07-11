import 'package:flutter/foundation.dart';
import '../models/order_tracking_model.dart';
import '../models/delivery_agent_model.dart';
import '../services/order_tracking_service.dart';
import '../services/delivery_assignment_service.dart';

class OrderTrackingProvider extends ChangeNotifier {
  final OrderTrackingService _orderTrackingService = OrderTrackingService();
  final DeliveryAssignmentService _assignmentService = DeliveryAssignmentService();

  List<OrderTracking> _orderHistory = [];
  OrderTracking? _currentOrder;
  bool _loading = false;
  String? _error;

  List<OrderTracking> get orderHistory => _orderHistory;
  OrderTracking? get currentOrder => _currentOrder;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadOrderHistory() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Get customer ID from auth
      // final customerId = authProvider.customerId;
      // _orderHistory = await _orderTrackingService.getOrderHistoryForCustomer(customerId);

      _orderHistory = [];
    } catch (e) {
      _error = e.toString();
      print('Error loading order history: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Stream<OrderTracking?> watchOrderTracking(String orderId) {
    return _orderTrackingService.watchOrderTracking(orderId);
  }

  Stream<List<OrderTracking>> watchOrderHistory(String customerId) {
    return _orderTrackingService.watchOrderHistory(customerId);
  }

  Future<void> updateOrderStatus(String orderId, String newStatus, String description) async {
    try {
      await _orderTrackingService.updateOrderStatus(orderId, newStatus, description);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateAgentLocation(String orderId, String agentId, double latitude, double longitude) async {
    try {
      await _orderTrackingService.updateAgentLocation(orderId, agentId, latitude, longitude);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateETA(String orderId, DateTime eta) async {
    try {
      await _orderTrackingService.updateETA(orderId, eta);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<DeliveryAgent?> getAgent(String agentId) async {
    try {
      // TODO: Fetch agent from Firestore
      return null;
    } catch (e) {
      print('Error fetching agent: $e');
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
