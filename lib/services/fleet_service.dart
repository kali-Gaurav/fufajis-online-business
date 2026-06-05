import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math';
import '../models/cod_settlement_model.dart';
import '../models/attendance_model.dart';
import '../models/delivery_model.dart';
import 'order_service.dart';

class FleetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final FleetService _instance = FleetService._internal();
  factory FleetService() => _instance;
  FleetService._internal();

  Future<void> submitCodSettlement(CodSettlementModel settlement) async {
    await _db
        .collection('cod_settlements')
        .doc(settlement.id)
        .set(settlement.toMap());
  }

  Stream<List<CodSettlementModel>> getCodSettlementsStream(String riderId) {
    return _db
        .collection('cod_settlements')
        .where('riderId', isEqualTo: riderId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CodSettlementModel.fromMap(doc.data()))
              .toList();
        });
  }

  Stream<List<CodSettlementModel>> getAllCodSettlementsStream() {
    return _db
        .collection('cod_settlements')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => CodSettlementModel.fromMap(doc.data()))
              .toList();
        });
  }

  Future<void> updateCodSettlementStatus(
    String settlementId,
    String status, {
    String? notes,
  }) async {
    final Map<String, dynamic> updates = {
      'status': status,
      'resolvedAt': FieldValue.serverTimestamp(),
    };
    if (notes != null) {
      updates['notes'] = notes;
    }
    await _db.collection('cod_settlements').doc(settlementId).update(updates);
  }

  Future<void> clockInRider(AttendanceModel attendance) async {
    await _db
        .collection('attendance')
        .doc(attendance.id)
        .set(attendance.toMap());
  }

  Future<void> clockOutRider(
    String attendanceId,
    double latitude,
    double longitude,
  ) async {
    await _db.collection('attendance').doc(attendanceId).update({
      'clockOutTime': Timestamp.now(),
      'clockOutLatitude': latitude,
      'clockOutLongitude': longitude,
      'status': 'completed',
    });
  }

  Stream<List<AttendanceModel>> getRiderAttendanceStream(String riderId) {
    return _db
        .collection('attendance')
        .where('riderId', isEqualTo: riderId)
        .orderBy('clockInTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AttendanceModel.fromMap(doc.data()))
              .toList();
        });
  }

  Stream<List<AttendanceModel>> getAllAttendanceStream() {
    return _db
        .collection('attendance')
        .orderBy('clockInTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AttendanceModel.fromMap(doc.data()))
              .toList();
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
        final double? riderLat = data['lastLatitude'];
        final double? riderLng = data['lastLongitude'];

        if (riderLat != null && riderLng != null) {
          final distance = _calculateDistance(
            shopLat,
            shopLng,
            riderLat,
            riderLng,
          );
          if (distance < minDistance) {
            minDistance = distance;
            nearestRiderId = data['riderId'];
          }
        }
      }

      return nearestRiderId;
    } catch (e) {
      debugPrint('Error finding nearest rider: $e');
      return null;
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Basic Pythagorean distance for demo (not for global usage, but okay for hyperlocal)
    return (lat1 - lat2) * (lat1 - lat2) + (lon1 - lon2) * (lon1 - lon2);
  }

  /// Assigns order to rider and creates a delivery record
  Future<void> assignOrderToRider(String orderId, String riderId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final orderDoc = await orderRef.get();
    if (!orderDoc.exists) throw Exception('Order not found');
    
    final orderData = orderDoc.data()!;
    final customerId = orderData['customerId'] ?? '';
    final customerName = orderData['customerName'] ?? '';
    final customerPhone = orderData['customerPhone'] ?? '';
    final deliveryAddress = orderData['deliveryAddress']?['fullAddress'] ?? '';
    final lat = orderData['deliveryAddress']?['latitude'] ?? 0.0;
    final lng = orderData['deliveryAddress']?['longitude'] ?? 0.0;

    await orderRef.update({
      'deliveryAgentId': riderId,
      'assignmentTime': FieldValue.serverTimestamp(),
      'status': 'OrderStatus.processing', // Moving from packed to processing (preparing for delivery)
    });

    // Create a delivery job record (the "deliveries" collection in prompt)
    final deliveryId = 'DEL-${DateTime.now().millisecondsSinceEpoch}';
    await _db.collection('deliveries').doc(deliveryId).set({
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
  }

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
    final orderId = data['orderId'];

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
    
    final orderId = deliveryDoc.data()?['orderId'];
    if (orderId == null) return;

    // Use OrderService to update status so OTP is generated and WhatsApp is sent
    await OrderService().updateOrderStatus(orderId, 'outForDelivery');

    // Get the generated OTP to sync it to the delivery record
    final secureOtpDoc = await _db
        .collection('orders')
        .doc(orderId)
        .collection('secure')
        .doc('otp')
        .get();
    
    final otp = secureOtpDoc.data()?['otp'];

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
    final orderId = deliveryDoc.data()?['orderId'];
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
    final orderId = data['orderId'];
    final destLat = (data['destinationLocation'] as GeoPoint).latitude;
    final destLng = (data['destinationLocation'] as GeoPoint).longitude;
    final currLat = (data['currentLatitude'] as num).toDouble();
    final currLng = (data['currentLongitude'] as num).toDouble();

    // 1. Geofence Check (50 meters)
    final distance = _calculateHaversine(destLat, destLng, currLat, currLng);
    if (distance > 0.05) { // 0.05 km = 50 meters
      throw Exception('You are too far from the customer location to complete delivery.');
    }

    // 2. OTP Check
    final secureOtpDoc = await _db
        .collection('orders')
        .doc(orderId)
        .collection('secure')
        .doc('otp')
        .get();
    
    final correctOtp = secureOtpDoc.exists 
        ? secureOtpDoc.data()?['otp'] 
        : (await _db.collection('orders').doc(orderId).get()).data()?['otp'];

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
    final a = 0.5 - cos((lat2 - lat1) * p)/2 + 
          cos(lat1 * p) * cos(lat2 * p) * 
          (1 - cos((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a));
  }

  Stream<DeliveryModel?> getDeliveryStream(String deliveryId) {
    return _db.collection('deliveries').doc(deliveryId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DeliveryModel.fromMap(doc.data()!);
    });
  }

  Stream<List<DeliveryModel>> getActiveDeliveriesStream(String riderId) {
    return _db.collection('deliveries')
      .where('employeeId', isEqualTo: riderId)
      .where('status', whereIn: ['assigned', 'accepted', 'picked_up', 'on_the_way', 'arrived'])
      .snapshots()
      .map((snap) => snap.docs.map((doc) => DeliveryModel.fromMap(doc.data())).toList());
  }
}
