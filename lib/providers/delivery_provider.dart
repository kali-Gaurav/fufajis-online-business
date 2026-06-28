import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../models/delivery_model.dart';
import '../services/order_service.dart';
import '../services/delivery_service.dart';

import 'package:geolocator/geolocator.dart';

class DeliveryProvider with ChangeNotifier {
  final OrderService _orderService = OrderService();
  final DeliveryService _deliveryService = DeliveryService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<OrderModel> _assignedOrders = [];
  List<OrderModel> _availableOrders = [];
  List<OrderModel> _completedOrders = [];

  // New delivery task management
  List<DeliveryTask> _assignedDeliveries = [];
  DeliveryTask? _currentDelivery;
  LatLng? _currentLocation;
  DeliveryStats? _todayStats;

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

  // New delivery task getters
  List<DeliveryTask> get assignedDeliveries => _assignedDeliveries;
  DeliveryTask? get currentDelivery => _currentDelivery;
  LatLng? get currentLocation => _currentLocation;
  DeliveryStats? get todayStats => _todayStats;

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
    // Consolidated into DeliveryTrackingService (Background)
    // We only keep a minimal UI-bound check for distance accumulation if needed
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
        // FIX (Module 9 P0): live packing writes the qualified 'OrderStatus.packed'
        // form, not bare 'packed' — this filter never matched anything in production.
        .where('status', isEqualTo: 'OrderStatus.packed')
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
        // FIX (Module 9 P0): match the qualified status strings the live order
        // pipeline actually writes.
        .where('status', whereIn: ['OrderStatus.outForDelivery', 'OrderStatus.packed'])
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
        // FIX (Module 9 P0): qualified form, see above.
        .where('status', isEqualTo: 'OrderStatus.delivered')
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
    }).fold(0.0, (total, order) => total + (order.deliveryFee?.toDouble() ?? 0.0));
  }

  Future<bool> acceptOrder(String orderId, UserModel rider) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.collection('orders').doc(orderId).update({
        'deliveryAgentId': rider.id,
        'deliveryAgentName': rider.name,
        'deliveryAgentPhone': rider.phoneNumber,
        // FIX (Module 9 P0): write the qualified form so OrderModel.fromMap (and
        // the queries above) parse this status correctly everywhere else.
        'status': 'OrderStatus.outForDelivery',
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
      // FIX (Module 9 P0): defensively qualify so a caller passing a bare enum
      // name (e.g. 'outForDelivery', as markPickedUp does below) doesn't write
      // an unparseable status string — same bug class as the queries above.
      final qualifiedStatus = newStatus.startsWith('OrderStatus.')
          ? newStatus
          : 'OrderStatus.$newStatus';
      await _db.collection('orders').doc(orderId).update({
        'status': qualifiedStatus,
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
      String orderId, String inputOtp, {Position? currentPosition}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _orderService.verifyAndDeliverOrder(
        orderId: orderId,
        otp: inputOtp,
        riderLatitude: currentPosition?.latitude ?? 0.0,
        riderLongitude: currentPosition?.longitude ?? 0.0,
      );

      if (success) {
        // Feature 43: Reward points and stats update
        // (Note: stats are refreshed via streams automatically)
        _isLoading = false;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
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

    // Feature 56: Trip Distance Tracking
    final newPosition = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );

    if (_lastPosition != null) {
      // Calculate distance using Haversine formula
      const double earthRadius = 6371; // km
      final dLat = _deg2rad(lat - _lastPosition!.latitude);
      final dLon = _deg2rad(lng - _lastPosition!.longitude);
      
      final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(_deg2rad(_lastPosition!.latitude)) * cos(_deg2rad(lat)) *
          sin(dLon / 2) * sin(dLon / 2);
      final c = 2 * atan2(sqrt(a), sqrt(1 - a));
      final distance = earthRadius * c;
      
      _todayDistance += distance;
      notifyListeners();
    }
    
    _lastPosition = newPosition;
  }

  double _deg2rad(double deg) {
    return deg * (pi / 180);
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

  // ==================== DELIVERY TASK MANAGEMENT ====================

  /// Load today's delivery tasks for an agent
  Future<void> loadTodayDeliveryTasks(String agentId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final deliveries = await _deliveryService.getAgentDeliveries(agentId);
      _assignedDeliveries = deliveries;

      // Load stats
      _todayStats = await _deliveryService.getDeliveryStats(agentId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set current delivery
  void setCurrentDelivery(DeliveryTask delivery) {
    _currentDelivery = delivery;
    notifyListeners();
  }

  /// Start delivery
  Future<void> startDeliveryTask(String deliveryId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _deliveryService.startDelivery(deliveryId);

      final updated = await _deliveryService.getDeliveryById(deliveryId);
      if (updated != null) {
        _currentDelivery = updated;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update current location
  Future<void> updateCurrentLocation(double latitude, double longitude) async {
    try {
      _currentLocation = LatLng(latitude, longitude);

      if (_currentDelivery != null) {
        await _deliveryService.updateLocation(
          _currentDelivery!.id,
          latitude,
          longitude,
        );
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Verify OTP
  Future<bool> verifyDeliveryOTP(String deliveryId, String otp) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _deliveryService.verifyOTP(deliveryId, otp);

      if (result && _currentDelivery?.id == deliveryId) {
        _currentDelivery = _currentDelivery?.copyWith(otpVerified: true);
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Upload proof of delivery
  Future<void> uploadDeliveryProof(
    String deliveryId, {
    required String photoUrl,
    String? signatureUrl,
    String? notes,
    String? customerName,
    String? customerSignature,
    required GeoPoint location,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _deliveryService.uploadProofOfDelivery(
        deliveryId,
        photoUrl: photoUrl,
        signatureUrl: signatureUrl,
        notes: notes,
        customerName: customerName,
        customerSignature: customerSignature,
        location: location,
      );

      final updated = await _deliveryService.getDeliveryById(deliveryId);
      if (updated != null) {
        _currentDelivery = updated;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Complete delivery
  Future<void> completeDeliveryTask(String deliveryId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _deliveryService.completeDelivery(deliveryId);

      _assignedDeliveries.removeWhere((d) => d.id == deliveryId);
      _currentDelivery = null;

      if (_todayStats != null) {
        final agentId = _todayStats!.agentId;
        _todayStats = await _deliveryService.getDeliveryStats(agentId);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fail delivery
  Future<void> failDeliveryTask(String deliveryId, String reason) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _deliveryService.failDelivery(deliveryId, reason);

      final updated = await _deliveryService.getDeliveryById(deliveryId);
      if (updated != null) {
        _currentDelivery = updated;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reschedule delivery
  Future<void> rescheduleDeliveryTask(
    String deliveryId,
    DateTime newDate,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _deliveryService.rescheduleDelivery(deliveryId, newDate);

      _assignedDeliveries.removeWhere((d) => d.id == deliveryId);
      _currentDelivery = null;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Rate delivery
  Future<void> rateDeliveryTask(
    String deliveryId,
    double rating,
    String? feedback,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _deliveryService.rateDelivery(deliveryId, rating, feedback);

      final updated = await _deliveryService.getDeliveryById(deliveryId);
      if (updated != null) {
        _currentDelivery = updated;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Stream deliveries (real-time)
  Stream<List<DeliveryTask>> streamDeliveryTasks(String agentId) {
    return _deliveryService.streamAgentDeliveries(agentId);
  }

  /// Stream single delivery (real-time)
  Stream<DeliveryTask?> streamDeliveryTask(String deliveryId) {
    return _deliveryService.streamDelivery(deliveryId);
  }

  /// Clear current delivery
  void clearCurrentDelivery() {
    _currentDelivery = null;
    notifyListeners();
  }

  /// Sort deliveries by nearest first
  void sortDeliveriesByNearest(LatLng currentLoc) {
    _assignedDeliveries.sort((a, b) {
      final distA = _calculateDistance(
        currentLoc.latitude,
        currentLoc.longitude,
        a.deliveryLocation.latitude,
        a.deliveryLocation.longitude,
      );
      final distB = _calculateDistance(
        currentLoc.latitude,
        currentLoc.longitude,
        b.deliveryLocation.latitude,
        b.deliveryLocation.longitude,
      );
      return distA.compareTo(distB);
    });
    notifyListeners();
  }

  /// Sort deliveries by time
  void sortDeliveriesByTime() {
    _assignedDeliveries.sort((a, b) =>
        a.estimatedDeliveryTime.compareTo(b.estimatedDeliveryTime));
    notifyListeners();
  }

  /// Filter deliveries by status
  List<DeliveryTask> getDeliveriesByStatus(DeliveryStatus status) {
    return _assignedDeliveries.where((d) => d.status == status).toList();
  }

  /// Helper: Calculate distance using Haversine formula
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double R = 6371; // Earth radius in km
    final double dLat = (lat2 - lat1) * pi / 180;
    final double dLng = (lng2 - lng1) * pi / 180;

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}
