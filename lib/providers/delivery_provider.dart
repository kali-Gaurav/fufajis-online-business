import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/order_service.dart';
import '../services/delivery_charge_calculator.dart';

import 'package:geolocator/geolocator.dart';

class DeliveryProvider with ChangeNotifier {
  final OrderService _orderService = OrderService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<OrderModel> _assignedOrders = [];
  List<OrderModel> _availableOrders = [];
  List<OrderModel> _completedOrders = [];
  bool _isLoading = false;
  String? _errorMessage;
  double _todayEarnings = 0.0;
  double _todayDistance = 0.0; // Feature 56: Trip Distance Tracking
  int _completedToday = 0;
  int _failedToday = 0;
  double _totalEarnings = 0.0;
  double _averageRating = 0.0;
  int _totalDeliveries = 0;
  Timer? _locationTimer;
  String _vehicleMode = 'Bike'; // Feature 60: Vehicle Mode Selector
  Position? _lastPosition;

  List<OrderModel> get assignedOrders => _assignedOrders;
  List<OrderModel> get availableOrders => _availableOrders;
  List<OrderModel> get completedOrders => _completedOrders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get todayEarnings => _todayEarnings;
  double get todayDistance => _todayDistance;
  String get vehicleMode => _vehicleMode;
  int get completedToday => _completedToday;
  int get failedToday => _failedToday;
  double get totalEarnings => _totalEarnings;
  double get averageRating => _averageRating;
  int get totalDeliveries => _totalDeliveries;

  StreamSubscription? _availableOrdersSub;
  StreamSubscription? _assignedOrdersSub;
  StreamSubscription? _completedOrdersSub;

  void setVehicleMode(String mode) {
    _vehicleMode = mode;
    notifyListeners();
  }

  void init(String riderId) {
    _listenToAvailableOrders();
    _listenToAssignedOrders(riderId);
    _listenToCompletedOrders(riderId);
    _startLocationUpdates(riderId);
    _loadEarningsData(riderId);
  }

  void _startLocationUpdates(String riderId) {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        final Position position = kDebugMode
            ? Position(
                latitude: 26.9124 + (Random().nextDouble() - 0.5) * 0.005, // Smaller jitter
                longitude: 75.7873 + (Random().nextDouble() - 0.5) * 0.005,
                timestamp: DateTime.now(),
                accuracy: 10,
                altitude: 0,
                heading: 0,
                speed: 0,
                speedAccuracy: 0,
                altitudeAccuracy: 0,
                headingAccuracy: 0,
              )
            : await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
              );

        // Feature 56: Accumulate distance
        if (_lastPosition != null) {
          final double distance = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          _todayDistance += (distance / 1000.0); // Convert to km
        }
        _lastPosition = position;

        // Update rider's global location
        await _db.collection('users').doc(riderId).update({
          'lastKnownLocation': GeoPoint(position.latitude, position.longitude),
          'lastLocationUpdate': FieldValue.serverTimestamp(),
          'todayDistance': _todayDistance,
        });

        // Update active orders
        for (var order in _assignedOrders) {
          if (order.status == OrderStatus.outForDelivery) {
            await updateRiderLocation(order.id, position.latitude, position.longitude);
          }
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Location update error: $e');
      }
    });
  }

  @override
  void dispose() {
    _availableOrdersSub?.cancel();
    _assignedOrdersSub?.cancel();
    _completedOrdersSub?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  void _listenToAvailableOrders() {
    _availableOrdersSub?.cancel();
    _availableOrdersSub = _db
        .collection('orders')
        .where('status', isEqualTo: 'packed')
        .where('deliveryAgentId', isNull: true)
        .snapshots()
        .listen((snapshot) {
      _availableOrders =
          snapshot.docs.map((doc) => OrderModel.fromMap(doc.data())).toList();
      notifyListeners();
    });
  }

  void _listenToAssignedOrders(String riderId) {
    _assignedOrdersSub?.cancel();
    _assignedOrdersSub = _db
        .collection('orders')
        .where('deliveryAgentId', isEqualTo: riderId)
        .where('status', whereIn: ['outForDelivery', 'packed'])
        .snapshots()
        .listen((snapshot) {
          _assignedOrders = snapshot.docs
              .map((doc) => OrderModel.fromMap(doc.data()))
              .toList();
          notifyListeners();
        });
  }

  void _listenToCompletedOrders(String riderId) {
    _completedOrdersSub?.cancel();
    _completedOrdersSub = _db
        .collection('orders')
        .where('deliveryAgentId', isEqualTo: riderId)
        .where('status', isEqualTo: 'delivered')
        .orderBy('deliveredAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      _completedOrders =
          snapshot.docs.map((doc) => OrderModel.fromMap(doc.data())).toList();
      _calculateStats();
      notifyListeners();
    });
  }

  Future<void> _loadEarningsData(String riderId) async {
    try {
      // Load total earnings from Firestore
      final doc = await _db.collection('deliveryAgents').doc(riderId).get();
      if (doc.exists) {
        _totalEarnings =
            (doc.data()?['totalEarnings'] as num?)?.toDouble() ?? 0.0;
        _averageRating =
            (doc.data()?['averageRating'] as num?)?.toDouble() ?? 0.0;
        _totalDeliveries =
            (doc.data()?['totalDeliveries'] as num?)?.toInt() ?? 0;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading earnings data: $e');
    }
  }

  void _calculateStats() {
    // Calculate today's stats
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _completedToday = _completedOrders.where((order) {
      if (order.deliveredAt == null) return false;
      final deliveredDate = DateTime(
        order.deliveredAt!.year,
        order.deliveredAt!.month,
        order.deliveredAt!.day,
      );
      return deliveredDate == today;
    }).length;

    // Calculate today's earnings
    _todayEarnings = _completedOrders.where((order) {
      if (order.deliveredAt == null) return false;
      final deliveredDate = DateTime(
        order.deliveredAt!.year,
        order.deliveredAt!.month,
        order.deliveredAt!.day,
      );
      return deliveredDate == today;
    }).fold(0.0, (total, order) => total + (order.deliveryFee ?? 0.0));
  }

  Future<bool> acceptOrder(String orderId, UserModel rider) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.collection('orders').doc(orderId).update({
        'deliveryAgentId': rider.id,
        'deliveryAgentName': rider.name,
        'deliveryAgentPhone': rider.phoneNumber,
        'status': 'outForDelivery',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local state is handled by stream
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Task 9.3: Update delivery status
  Future<bool> updateDeliveryStatus(String orderId, String newStatus) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Task 9.3: Mark order as picked up
  Future<bool> markPickedUp(String orderId) async {
    return updateDeliveryStatus(orderId, 'outForDelivery');
  }

  /// Task 9.3: Verify OTP and complete delivery
  Future<bool> verifyAndCompleteDelivery(
      String orderId, String inputOtp) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists) throw Exception("Order not found");

        final order = OrderModel.fromMap(doc.data()!);
        if (order.otp == inputOtp) {
          // Feature 43: Calculate reward points (1 point per ₹100)
          final earnedPoints = (order.totalAmount / 100).floor();

          // Calculate delivery fee
          final deliveryFee = DeliveryChargeCalculator.calculateDeliveryCharge(
            order.deliveryType,
            order.subtotal,
          );

          final Map<String, dynamic> updates = {
            'status': 'delivered',
            'otpVerified': true,
            'deliveredAt': FieldValue.serverTimestamp(),
            'deliveryFee': deliveryFee,
            'rewardPointsEarned': earnedPoints, // Save earned points to order
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (order.paymentMethod.toString().toLowerCase().contains('cod')) {
            updates['cashCollectedAmount'] = order.totalAmount;
            updates['cashCollectedAt'] = FieldValue.serverTimestamp();

            await _db
                .collection('orders')
                .doc(orderId)
                .collection('cashCollection')
                .doc('log')
                .set({
              'amount': order.totalAmount,
              'collectedBy': order.deliveryAgentId ?? 'demo_rider',
              'collectedAt': FieldValue.serverTimestamp(),
              'status': 'collected',
            });
          }

          await _db.collection('orders').doc(orderId).update(updates);

          // Award points to Customer
          await _db.collection('users').doc(order.customerId).update({
            'rewardPoints': FieldValue.increment(earnedPoints),
          });

          // Update agent earnings
          _todayEarnings += deliveryFee;
          _completedToday += 1;
          _totalEarnings += deliveryFee;
          _totalDeliveries += 1;

        // Update agent profile
        await _db
            .collection('deliveryAgents')
            .doc(order.deliveryAgentId)
            .update({
          'totalEarnings': _totalEarnings,
          'totalDeliveries': _totalDeliveries,
        });

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = "Invalid OTP. Please check with customer.";
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Task 9.3: Mark delivery as failed
  Future<bool> markDeliveryFailed(String orderId, String reason) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.collection('orders').doc(orderId).update({
        'status': 'failedDelivery',
        'failureReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _failedToday += 1;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateRiderLocation(
      String orderId, double lat, double lng) async {
    await _orderService.updateOrderLiveLocation(orderId, lat, lng);
  }

  /// Task 9.6: Get earnings history with pagination
  Future<List<OrderModel>> getEarningsHistory(String riderId,
      {int limit = 10, DocumentSnapshot? startAfter}) async {
    try {
      Query query = _db
          .collection('orders')
          .where('deliveryAgentId', isEqualTo: riderId)
          .where('status', isEqualTo: 'delivered')
          .orderBy('deliveredAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _errorMessage = e.toString();
      return [];
    }
  }
}
