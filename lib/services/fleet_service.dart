import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../models/cod_settlement_model.dart';
import '../models/attendance_model.dart';

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

  Future<void> updateCodSettlementStatus(String settlementId, String status, {String? notes}) async {
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
    await _db.collection('attendance').doc(attendance.id).set(attendance.toMap());
  }

  Future<void> clockOutRider(String attendanceId, double latitude, double longitude) async {
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
      return snapshot.docs.map((doc) => AttendanceModel.fromMap(doc.data())).toList();
    });
  }

  Stream<List<AttendanceModel>> getAllAttendanceStream() {
    return _db
        .collection('attendance')
        .orderBy('clockInTime', descending: true)
        .snapshots()
        .map((snapshot) {
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
        final double? riderLat = data['lastLatitude'];
        final double? riderLng = data['lastLongitude'];

        if (riderLat != null && riderLng != null) {
          final distance = _calculateDistance(shopLat, shopLng, riderLat, riderLng);
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

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Basic Pythagorean distance for demo (not for global usage, but okay for hyperlocal)
    return (lat1 - lat2) * (lat1 - lat2) + (lon1 - lon2) * (lon1 - lon2);
  }

  /// Assigns order to rider
  Future<void> assignOrderToRider(String orderId, String riderId) async {
    await _db.collection('orders').doc(orderId).update({
      'riderId': riderId,
      'assignmentTime': FieldValue.serverTimestamp(),
      'status': 'OrderStatus.processing', // Moving from packed to processing (preparing for delivery)
    });

    // Create a delivery job record
    await _db.collection('delivery_jobs').add({
      'orderId': orderId,
      'riderId': riderId,
      'status': 'assigned',
      'assignedAt': FieldValue.serverTimestamp(),
    });
  }
}
