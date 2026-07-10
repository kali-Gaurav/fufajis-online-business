import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_tracking_model.dart';

class OrderTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<OrderTracking?> getOrderTracking(String orderId) async {
    try {
      final doc = await _firestore.collection('order_tracking').doc(orderId).get();
      if (doc.exists) {
        return OrderTracking.fromFirestore(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error fetching order tracking: $e');
      return null;
    }
  }

  Stream<OrderTracking?> watchOrderTracking(String orderId) {
    return _firestore.collection('order_tracking').doc(orderId).snapshots().map((doc) {
      if (doc.exists) {
        return OrderTracking.fromFirestore(doc.data()!);
      }
      return null;
    });
  }

  Stream<List<OrderTracking>> watchOrderHistory(String customerId) {
    return _firestore
        .collection('order_tracking')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderTracking.fromFirestore(doc.data())).toList();
    });
  }

  Future<void> updateOrderStatus(String orderId, String newStatus, String description) async {
    try {
      final doc = _firestore.collection('order_tracking').doc(orderId);
      final tracking = await doc.get();

      if (tracking.exists) {
        final data = tracking.data()!;
        final statusHistory = (data['statusHistory'] as List<dynamic>? ?? [])
            .map((e) => StatusEvent.fromMap(e as Map<String, dynamic>))
            .toList();

        final event = StatusEvent(
          status: newStatus,
          timestamp: DateTime.now(),
          description: description,
        );
        statusHistory.add(event);

        await doc.update({
          'status': newStatus,
          'statusHistory': statusHistory.map((e) => e.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (newStatus == 'delivered') 'deliveredAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }

  Future<void> updateAgentLocation(String orderId, String agentId, double latitude, double longitude) async {
    try {
      await _firestore.collection('order_tracking').doc(orderId).update({
        'currentLocation': {
          'latitude': latitude,
          'longitude': longitude,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating agent location: $e');
      rethrow;
    }
  }

  Future<void> updateETA(String orderId, DateTime eta) async {
    try {
      await _firestore.collection('order_tracking').doc(orderId).update({
        'estimatedDeliveryTime': eta.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating ETA: $e');
      rethrow;
    }
  }

  Future<void> assignDeliveryAgent(String orderId, String agentId) async {
    try {
      await _firestore.collection('order_tracking').doc(orderId).update({
        'deliveryAgentId': agentId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error assigning delivery agent: $e');
      rethrow;
    }
  }

  Future<void> addProofOfDelivery(String orderId, String photoUrl) async {
    try {
      await _firestore.collection('order_tracking').doc(orderId).update({
        'proofOfDeliveryPhotoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding proof of delivery: $e');
      rethrow;
    }
  }

  Future<List<OrderTracking>> getOrdersByAgent(String agentId) async {
    try {
      final snapshot = await _firestore
          .collection('order_tracking')
          .where('deliveryAgentId', isEqualTo: agentId)
          .where('status', isNotEqualTo: 'delivered')
          .get();

      return snapshot.docs.map((doc) => OrderTracking.fromFirestore(doc.data())).toList();
    } catch (e) {
      print('Error fetching orders by agent: $e');
      return [];
    }
  }
}
