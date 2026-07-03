import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math';
import '../models/cod_settlement_model.dart';
import '../models/attendance_model.dart';
import '../models/delivery_model.dart';
import '../models/order_model.dart';
import 'order_service.dart';
import 'delivery_service.dart';
import 'delivery_verification_service.dart';
import 'shop_config_service.dart';
import '../models/rider_shift_model.dart';
import 'sqlite_service.dart';
import 'offline_sync_service.dart';

class FleetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final FleetService _instance = FleetService._internal();
  factory FleetService() => _instance;
  FleetService._internal();

  Future<void> submitCodSettlement(CodSettlementModel settlement) async {
    await _db.collection('cod_settlements').doc(settlement.id).set(settlement.toMap());
  }

  Stream<List<CodSettlementModel>> getCodSettlementsStream(String riderId) {
    return _db
        .collection('cod_settlements')
        .where('riderId', isEqualTo: riderId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => CodSettlementModel.fromMap(doc.data())).toList();
        });
  }

  Stream<List<CodSettlementModel>> getAllCodSettlementsStream() {
    return _db
        .collection('cod_settlements')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => CodSettlementModel.fromMap(doc.data())).toList();
        });
  }

  Future<void> updateCodSettlementStatus(
    String settlementId,
    String status, {
    String? notes,
  }) async {
    final docRef = _db.collection('cod_settlements').doc(settlementId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Settlement record not found.');
      }

      final data = snapshot.data()!;
      final currentStatus = data['status'];

      // Prevent duplicate approval/rejection
      if (currentStatus != 'pending') {
        throw Exception('Settlement already $currentStatus');
      }

      final Map<String, dynamic> updates = {
        'status': status,
        'resolvedAt': FieldValue.serverTimestamp(),
      };
      if (notes != null) {
        updates['notes'] = notes;
      }

      transaction.update(docRef, updates);

      // If approved, decrement rider's cash balance
      if (status == 'approved') {
        final riderId = data['riderId'] as String?;
        final amount = (data['amount'] as num).toDouble();
        final riderRef = _db.collection('users').doc(riderId);
        transaction.update(riderRef, {
          'currentCashBalance': FieldValue.increment(-amount),
          'lastSettlementAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> clockInRider(AttendanceModel attendance) async {
    // 1. Geofence Check (1km from store)
    final config = await ShopConfigService().getShopConfig();
    final distance = _calculateHaversine(
      config.shopLatitude,
      config.shopLongitude,
      attendance.clockInLatitude,
      attendance.clockInLongitude,
    );

    if (distance > 1.0) {
      // 1.0 km
      throw Exception(
        'Clock-in failed. You must be within 1km of the store. Current distance: ${distance.toStringAsFixed(1)}km.',
      );
    }

    await _db.collection('attendance').doc(attendance.id).set(attendance.toMap());

    // Fetch rider branchId from profile
    final riderDoc = await _db.collection('users').doc(attendance.riderId).get();
    final branchId = (riderDoc.exists && riderDoc.data() != null)
        ? (riderDoc.data()!['branchId'] as String? ?? 'system')
        : 'system';

    // Create and save RiderShiftModel
    final shiftId = 'shift_${attendance.id}';
    final shift = RiderShiftModel(
      id: shiftId,
      riderId: attendance.riderId,
      branchId: branchId,
      currentState: RiderShiftState.available,
      startedAt: DateTime.now(),
    );

    // Save locally
    try {
      await SqliteService().saveRiderShift({
        'id': shift.id,
        'riderId': shift.riderId,
        'branchId': shift.branchId,
        'currentState': shift.currentState.name,
        'startedAt': shift.startedAt.millisecondsSinceEpoch,
        'isSynced': 0,
      });
    } catch (e) {
      debugPrint('[FleetService] SQLite shift clock-in save failed: $e');
    }

    // Attempt online sync
    final bool online = OfflineSyncService().isOnline.value;
    if (online) {
      await _db.collection('rider_shifts').doc(shiftId).set(shift.toMap());
      await SqliteService().markRiderShiftSynced(shiftId);
    }
  }

  Future<void> clockOutRider(String attendanceId, double latitude, double longitude) async {
    // 1. Fetch attendance
    final attendanceDoc = await _db.collection('attendance').doc(attendanceId).get();
    if (!attendanceDoc.exists) throw Exception('Attendance record not found');
    final attendance = AttendanceModel.fromMap(attendanceDoc.data()!);

    // 2. Guard check: Cash balance limit
    final double cashBalance = await getRiderCashBalance(attendance.riderId);
    if (cashBalance > 500.0) {
      throw Exception(
        'Clock-out blocked. You have outstanding cash balance of ₹${cashBalance.round()}. Minimum limit for clock-out is ₹500. Please settle with the owner first.',
      );
    }

    // 3. Guard check: Active deliveries
    final activeDeliveriesQuery = await _db
        .collection('deliveries')
        .where('employeeId', isEqualTo: attendance.riderId)
        .where('status', whereIn: ['assigned', 'accepted', 'picked_up', 'on_the_way', 'arrived'])
        .get();

    if (activeDeliveriesQuery.docs.isNotEmpty) {
      throw Exception(
        'Clock-out blocked. You have ${activeDeliveriesQuery.docs.length} active deliveries in progress.',
      );
    }

    // Fetch rider branchId from profile
    final riderDoc = await _db.collection('users').doc(attendance.riderId).get();
    final branchId = (riderDoc.exists && riderDoc.data() != null)
        ? (riderDoc.data()!['branchId'] as String? ?? 'system')
        : 'system';

    // 4. Mark shift ended
    final shiftId = 'shift_$attendanceId';
    try {
      await SqliteService().saveRiderShift({
        'id': shiftId,
        'riderId': attendance.riderId,
        'branchId': branchId,
        'currentState': RiderShiftState.offline.name,
        'endedAt': DateTime.now().millisecondsSinceEpoch,
        'isSynced': 0,
      });
    } catch (e) {
      debugPrint('[FleetService] SQLite shift clock-out save failed: $e');
    }

    await _db.collection('attendance').doc(attendanceId).update({
      'clockOutTime': Timestamp.now(),
      'clockOutLatitude': latitude,
      'clockOutLongitude': longitude,
      'status': 'completed',
    });

    final bool online = OfflineSyncService().isOnline.value;
    if (online) {
      await _db.collection('rider_shifts').doc(shiftId).update({
        'currentState': RiderShiftState.offline.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
      await SqliteService().markRiderShiftSynced(shiftId);
    }
  }

  Stream<List<AttendanceModel>> getRiderAttendanceStream(String riderId) {
    return _db
        .collection('attendance')
        .where('riderId', isEqualTo: riderId)
        .orderBy('clockInTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => AttendanceModel.fromMap(doc.data())).toList();
        });
  }

  Stream<List<AttendanceModel>> getAllAttendanceStream() {
    return _db.collection('attendance').orderBy('clockInTime', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => AttendanceModel.fromMap(doc.data())).toList();
    });
  }

  /// Step 30.1: Auto-dispatch to nearest active agent
  Future<String?> findNearestActiveRider({
    required double shopLat,
    required double shopLng,
    required String district,
  }) async {
    try {
      // 1. Get all riders clocked-in (active) in the district
      final activeRidersQuery = await _db
          .collection('attendance')
          .where('status', isEqualTo: 'active')
          .where('district', isEqualTo: district)
          .get();

      if (activeRidersQuery.docs.isEmpty) return null;

      String? nearestRiderId;
      double minDistance = double.infinity;

      // 2. Simple distance comparison (in production, use GeoFlutterFire or similar)
      for (var doc in activeRidersQuery.docs) {
        final data = doc.data();
        final double? riderLat = data['lastLatitude'] as double?;
        final double? riderLng = data['lastLongitude'] as double?;

        if (riderLat != null && riderLng != null) {
          final distance = _calculateDistance(shopLat, shopLng, riderLat, riderLng);
          if (distance < minDistance) {
            minDistance = distance;
            nearestRiderId = data['riderId'] as String?;
          }
        }
      }

      return nearestRiderId;
    } catch (e) {
      debugPrint('Error finding nearest rider: $e');
      return null;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Basic Pythagorean distance for demo (not for global usage, but okay for hyperlocal)
    return (lat1 - lat2) * (lat1 - lat2) + (lon1 - lon2) * (lon1 - lon2);
  }

  /// Assigns order to rider and creates a delivery record
  Future<void> assignOrderToRider(String orderId, String riderId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final riderRef = _db.collection('users').doc(riderId);

    await _db.runTransaction((transaction) async {
      final orderSnap = await transaction.get(orderRef);
      final riderSnap = await transaction.get(riderRef);

      if (!orderSnap.exists) throw Exception('Order not found');
      if (!riderSnap.exists) throw Exception('Rider profile not found');

      final orderData = orderSnap.data()!;
      final riderData = riderSnap.data()!;

      // 1. Rider Cash Limit Check (₹5,000)
      final double currentCash = ((riderData['currentCashBalance'] as num?) ?? 0.0).toDouble();
      if (currentCash > 5000) {
        throw Exception(
          'Rider ${_getSafeName(riderData)} has ₹${currentCash.round()} un-settled cash. Limit is ₹5,000.',
        );
      }

      // 2. Order Stacking Check (Max 3 active orders)
      final activeDeliveriesQuery = await _db
          .collection('deliveries')
          .where('employeeId', isEqualTo: riderId)
          .where('status', whereIn: ['assigned', 'accepted', 'picked_up', 'on_the_way', 'arrived'])
          .get();

      if (activeDeliveriesQuery.docs.length >= 3) {
        throw Exception(
          'Rider ${_getSafeName(riderData)} already has 3 active deliveries. Complete them before assigning more.',
        );
      }

      // 3. State Machine Check (Must be packed/ready)
      final status = orderData['status']?.toString() ?? '';
      if (!status.contains('packed') && !status.contains('confirmed')) {
        throw Exception('Order must be in Packed or Confirmed status to assign.');
      }

      final customerId = orderData['customerId'] ?? '';
      final customerName = orderData['customerName'] ?? '';
      final customerPhone = orderData['customerPhone'] ?? '';
      final deliveryAddress = orderData['deliveryAddress']?['fullAddress'] ?? '';
      final lat = (orderData['deliveryAddress']?['latitude'] as num? ?? 0.0).toDouble();
      final lng = (orderData['deliveryAddress']?['longitude'] as num? ?? 0.0).toDouble();

      transaction.update(orderRef, {
        'deliveryAgentId': riderId,
        'deliveryAgentName': (riderData['name'] as String?) ?? 'Rider',
        'deliveryAgentPhone': (riderData['phoneNumber'] as String?) ?? '',
        'assignmentTime': FieldValue.serverTimestamp(),
        'status':
            'OrderStatus.processing', // Moving from packed to processing (preparing for delivery)
      });

      // 3. Create a delivery job record
      final deliveryId = 'DEL-${DateTime.now().millisecondsSinceEpoch}';
      final deliveryRef = _db.collection('deliveries').doc(deliveryId);

      transaction.set(deliveryRef, {
        'deliveryId': deliveryId,
        'orderId': orderId,
        'employeeId': riderId,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'deliveryAddress': deliveryAddress,
        'destinationLocation': GeoPoint(lat, lng),
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
        'otp': orderData['otp'], // Sync OTP if already generated
      });
    });
  }

  String _getSafeName(Map<String, dynamic> data) =>
      (data['name'] as String?) ?? (data['phoneNumber'] as String?) ?? 'Unknown';

  /// Rider accepts the delivery
  Future<void> acceptDelivery(String deliveryId) async {
    await _db.collection('deliveries').doc(deliveryId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Rider rejects/unassigns the delivery
  Future<void> rejectDelivery(String deliveryId, String reason) async {
    final deliveryDoc = await _db.collection('deliveries').doc(deliveryId).get();
    if (!deliveryDoc.exists) return;

    final data = deliveryDoc.data()!;
    final orderId = data['orderId'] as String?;

    // Move order back to packed status
    if (orderId != null) {
      await _db.collection('orders').doc(orderId).update({
        'deliveryAgentId': FieldValue.delete(),
        'status': 'OrderStatus.packed',
        'rejectionReason': reason,
      });
    }

    // Mark delivery as cancelled
    await _db.collection('deliveries').doc(deliveryId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });
  }

  /// Rider picks up the order from the shop
  Future<void> pickupOrder(String deliveryId) async {
    final deliveryDoc = await _db.collection('deliveries').doc(deliveryId).get();
    if (!deliveryDoc.exists) return;

    final data = deliveryDoc.data()!;
    final orderId = data['orderId'] as String?;
    final riderId = data['employeeId'] as String?;
    if (orderId == null || riderId == null) return;

    // 1. Cash Limit Check again before pickup
    final riderDoc = await _db.collection('users').doc(riderId).get();
    final double currentCash = ((riderDoc.data()?['currentCashBalance'] as num?) ?? 0.0).toDouble();
    if (currentCash > 5000) {
      throw Exception(
        'Cash limit exceeded (₹${currentCash.round()}). Please settle cash before picking up new orders.',
      );
    }

    // Use OrderService to update status so OTP is generated and WhatsApp is sent
    await OrderService().updateOrderStatus(orderId, 'outForDelivery', employeeId: riderId);

    // Get the generated OTP to sync it to the delivery record
    final secureOtpDoc = await _db
        .collection('orders')
        .doc(orderId)
        .collection('secure')
        .doc('otp')
        .get();

    final otp = secureOtpDoc.data()?['otp'] as String?;

    await _db.collection('deliveries').doc(deliveryId).update({
      'status': 'picked_up',
      'pickedUpAt': FieldValue.serverTimestamp(),
      'otp': otp,
    });
  }

  /// Rider starts the navigation/delivery move
  Future<void> startDelivery(String deliveryId) async {
    await _db.collection('deliveries').doc(deliveryId).update({
      'status': 'on_the_way',
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Rider arrived at customer location
  Future<void> markArrived(String deliveryId) async {
    await _db.collection('deliveries').doc(deliveryId).update({
      'status': 'arrived',
      'arrivedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates live location for tracking
  Future<void> updateDeliveryLocation({
    required String deliveryId,
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
    int? batteryLevel,
  }) async {
    final now = FieldValue.serverTimestamp();

    // Update main delivery record
    await _db.collection('deliveries').doc(deliveryId).update({
      'currentLatitude': latitude,
      'currentLongitude': longitude,
      'lastLocationUpdate': now,
    });

    // High frequency tracking collection
    await _db.collection('delivery_tracking').doc(deliveryId).set({
      'deliveryId': deliveryId,
      'lat': latitude,
      'lng': longitude,
      'speed': speed,
      'heading': heading,
      'battery': batteryLevel,
      'timestamp': now,
    });

    // Also update order for customer view compatibility
    final deliveryDoc = await _db.collection('deliveries').doc(deliveryId).get();
    final orderId = deliveryDoc.data()?['orderId'] as String?;
    if (orderId != null) {
      await _db.collection('orders').doc(orderId).update({
        'liveLocation': GeoPoint(latitude, longitude),
      });
    }
  }

  /// Verify OTP and Complete delivery
  Future<void> completeDelivery(String deliveryId, String otp) async {
    final deliveryDoc = await _db.collection('deliveries').doc(deliveryId).get();
    if (!deliveryDoc.exists) throw Exception('Delivery record not found');

    final data = deliveryDoc.data()!;
    final String? orderId = data['orderId'] as String?;
    final destLat = (data['destinationLocation'] as GeoPoint).latitude;
    final destLng = (data['destinationLocation'] as GeoPoint).longitude;
    final currLat = (data['currentLatitude'] as num).toDouble();
    final currLng = (data['currentLongitude'] as num).toDouble();

    // 1. Geofence Check (50 meters)
    final distance = _calculateHaversine(destLat, destLng, currLat, currLng);
    if (distance > 0.05) {
      // 0.05 km = 50 meters
      throw Exception('You are too far from the customer location to complete delivery.');
    }

    // 2. OTP Check
    final secureOtpDoc = await _db
        .collection('orders')
        .doc(orderId)
        .collection('secure')
        .doc('otp')
        .get();

    Object? correctOtp;
    if (secureOtpDoc.exists) {
      correctOtp = secureOtpDoc.data()?['otp'];
    } else {
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      correctOtp = orderDoc.data()?['otp'];
    }

    if (correctOtp != null && correctOtp.toString() != otp) {
      throw Exception('Invalid OTP. Please check with the customer.');
    }

    // 3. Update Statuses
    await _db.collection('deliveries').doc(deliveryId).update({
      'status': 'delivered',
      'completedAt': FieldValue.serverTimestamp(),
      'otpVerified': true,
    });

    if (orderId != null) {
      await _db.collection('orders').doc(orderId).update({
        'status': 'OrderStatus.delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'otpVerified': true,
      });
    }
  }

  double _calculateHaversine(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Stream<DeliveryModel?> getDeliveryStream(String deliveryId) {
    return _db.collection('deliveries').doc(deliveryId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DeliveryModel.fromMap(doc.data()!);
    });
  }

  Stream<List<DeliveryModel>> getActiveDeliveriesStream(String riderId) {
    return _db
        .collection('deliveries')
        .where('employeeId', isEqualTo: riderId)
        .where('status', whereIn: ['assigned', 'accepted', 'picked_up', 'on_the_way', 'arrived'])
        .snapshots()
        .map((snap) => snap.docs.map((doc) => DeliveryModel.fromMap(doc.data())).toList());
  }

  /// Trigger SOS Alert
  Future<void> triggerSosAlert({
    required String riderId,
    required String riderName,
    required double lat,
    required double lng,
  }) async {
    final alertId = 'SOS-${DateTime.now().millisecondsSinceEpoch}';
    await _db.collection('sos_alerts').doc(alertId).set({
      'id': alertId,
      'riderId': riderId,
      'riderName': riderName,
      'location': GeoPoint(lat, lng),
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'active',
    });
  }

  /// Get current un-settled cash balance for a rider
  Future<double> getRiderCashBalance(String riderId) async {
    final doc = await _db.collection('users').doc(riderId).get();
    if (!doc.exists) return 0.0;
    return ((doc.data()?['currentCashBalance'] as num?) ?? 0.0).toDouble();
  }

  /// Assign order to nearest real delivery agent using DeliveryService
  /// This replaces fake agent assignment with actual agent matching
  Future<void> assignOrderToNearestAgent(OrderModel order) async {
    final deliveryService = DeliveryService();
    final verificationService = DeliveryVerificationService();

    try {
      // Assign to nearest available agent
      await deliveryService.assignDeliveryAgent(order);

      // Generate and store OTP for the order
      await verificationService.generateAndStoreOTP(order.id);

      // Log assignment event
      final agentId = order.deliveryAgentId;
      if (agentId != null) {
        await verificationService.logDeliveryEvent(
          orderId: order.id,
          agentId: agentId,
          eventType: 'assigned',
          notes: 'Order assigned to nearest available agent',
        );
      }

      debugPrint('Successfully assigned order ${order.id} to nearest agent');
    } catch (e) {
      debugPrint('Error assigning order to nearest agent: $e');
      rethrow;
    }
  }
}
