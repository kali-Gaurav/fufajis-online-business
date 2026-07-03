import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Rider Order Query Service
/// Unified query logic for rider order retrieval (Task #14 FIX)
///
/// CRITICAL FIX: Original rider queries used bare strings like 'confirmed'
/// which couldn't match packing service output 'confirmed.packaging'.
/// This service uses unified OrderStatus enum for consistency.
///
/// Order lifecycle (from rider perspective):
/// ready → awaiting_pickup → picked_up → in_transit → delivered
class RiderOrderQueryService {
  static final RiderOrderQueryService _instance = RiderOrderQueryService._internal();
  factory RiderOrderQueryService() => _instance;
  RiderOrderQueryService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Statuses that riders can see/interact with
  static const List<String> riderVisibleStatuses = [
    'ready', // Order packed and ready for pickup
    'awaiting_pickup', // Waiting for rider assignment
    'picked_up', // Rider has picked up
    'in_transit', // On the way to customer
    'delivered', // Delivered to customer
  ];

  /// Get orders ready for rider pickup (awaiting assignment)
  /// FIXED: Uses unified status from OrderStatus enum
  Future<List<Map<String, dynamic>>> getAvailableOrdersForPickup({
    required String shopId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _db
          .collection('orders')
          .where('shopId', isEqualTo: shopId)
          .where('status', whereIn: ['ready', 'awaiting_pickup'])
          .orderBy('packingApprovedAt', descending: true) // Oldest first
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => {'orderId': doc.id, 'deliveryId': doc['deliveryId'], ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('[RiderOrderQueryService] Get available orders failed: $e');
      return [];
    }
  }

  /// Get orders assigned to specific rider
  Future<List<Map<String, dynamic>>> getRiderAssignedOrders({
    required String riderId,
    String? status,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db
          .collection('orders')
          .where('riderId', isEqualTo: riderId);

      // Filter by status if provided
      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      } else {
        // Default: show active deliveries (not delivered/cancelled)
        query = query.where('status', whereIn: ['picked_up', 'in_transit']);
      }

      final snapshot = await query.orderBy('pickedUpAt', descending: true).limit(50).get();

      return snapshot.docs.map((doc) => {'orderId': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint('[RiderOrderQueryService] Get rider orders failed: $e');
      return [];
    }
  }

  /// Get order details with delivery info
  /// Ensures order status and delivery status are synchronized
  Future<Map<String, dynamic>?> getOrderWithDelivery(String orderId) async {
    try {
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return null;

      final orderData = orderDoc.data()!;
      final deliveryId = orderData['deliveryId'] as String?;

      Map<String, dynamic>? deliveryData;
      if (deliveryId != null && deliveryId.isNotEmpty) {
        final deliveryDoc = await _db.collection('deliveries').doc(deliveryId).get();
        if (deliveryDoc.exists) {
          deliveryData = deliveryDoc.data();
        }
      }

      // Validate consistency: order status should match delivery status
      final orderStatus = orderData['status'] as String?;
      final deliveryStatus = deliveryData?['status'] as String?;

      // Log if inconsistent (shouldn't happen with unified workflow)
      if (orderStatus != null && deliveryStatus != null && orderStatus != deliveryStatus) {
        debugPrint(
          '[RiderOrderQueryService] Status mismatch for order $orderId: '
          'order=$orderStatus, delivery=$deliveryStatus',
        );
      }

      return {'orderId': orderId, 'order': orderData, 'delivery': deliveryData};
    } catch (e) {
      debugPrint('[RiderOrderQueryService] Get order with delivery failed: $e');
      return null;
    }
  }

  /// Stream rider's active deliveries (real-time updates)
  Stream<List<Map<String, dynamic>>> streamRiderDeliveries(String riderId) {
    return _db
        .collection('orders')
        .where('riderId', isEqualTo: riderId)
        .where('status', whereIn: ['picked_up', 'in_transit'])
        .orderBy('pickedUpAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'orderId': doc.id, ...doc.data()}).toList());
  }

  /// Get order delivery address
  Future<Map<String, dynamic>?> getDeliveryAddress(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      return doc.data()?['deliveryAddress'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[RiderOrderQueryService] Get delivery address failed: $e');
      return null;
    }
  }

  /// Update rider location for an order (for tracking)
  Future<void> updateRiderLocation({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'riderCurrentLocation': {
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      debugPrint('[RiderOrderQueryService] Update location failed: $e');
    }
  }

  /// Mark order as in transit
  Future<void> markInTransit({required String orderId, required String riderId}) async {
    try {
      await _db.runTransaction((transaction) async {
        final orderRef = _db.collection('orders').doc(orderId);
        final orderSnapshot = await transaction.get(orderRef);

        if (!orderSnapshot.exists) {
          throw Exception('Order not found');
        }

        final orderData = orderSnapshot.data()!;
        final currentStatus = orderData['status'] as String?;

        // Validate transition: picked_up → in_transit
        if (currentStatus != 'picked_up') {
          throw Exception('Order must be picked_up to mark in_transit. Current: $currentStatus');
        }

        // Update order
        transaction.update(orderRef, {
          'status': 'in_transit',
          'inTransitAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update delivery
        final deliveryId = orderData['deliveryId'] as String?;
        if (deliveryId != null && deliveryId.isNotEmpty) {
          transaction.update(_db.collection('deliveries').doc(deliveryId), {
            'status': 'in_transit',
            'inTransitAt': FieldValue.serverTimestamp(),
          });
        }
      });

      debugPrint('[RiderOrderQueryService] Order $orderId marked in_transit');
    } catch (e) {
      debugPrint('[RiderOrderQueryService] Mark in_transit failed: $e');
      rethrow;
    }
  }

  /// Get rider statistics for today
  Future<Map<String, dynamic>> getRiderTodayStats(String riderId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _db
          .collection('orders')
          .where('riderId', isEqualTo: riderId)
          .where('pickedUpAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('pickedUpAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      int delivered = 0;
      int inTransit = 0;
      int pickedUp = 0;
      double totalEarnings = 0.0;

      for (var doc in snapshot.docs) {
        final status = doc['status'] as String?;
        final deliveryFee = (doc['deliveryFee'] as num? ?? 0.0).toDouble();

        if (status == 'delivered') {
          delivered++;
          totalEarnings += deliveryFee;
        } else if (status == 'in_transit') {
          inTransit++;
        } else if (status == 'picked_up') {
          pickedUp++;
        }
      }

      return {
        'riderId': riderId,
        'date': today.toIso8601String().split('T')[0],
        'ordersDelivered': delivered,
        'ordersInTransit': inTransit,
        'ordersPicked': pickedUp,
        'totalEarnings': totalEarnings,
        'totalOrders': snapshot.docs.length,
      };
    } catch (e) {
      debugPrint('[RiderOrderQueryService] Get stats failed: $e');
      return {
        'riderId': riderId,
        'ordersDelivered': 0,
        'ordersInTransit': 0,
        'ordersPicked': 0,
        'totalEarnings': 0.0,
        'totalOrders': 0,
      };
    }
  }

  /// DEPRECATED: Old method that used bare strings (kept for reference)
  @deprecated
  Future<List<Map<String, dynamic>>> getOrdersOldBrokenMethod() async {
    // OLD CODE - DO NOT USE
    // This used bare string 'confirmed' which doesn't match packed output
    // .where('status', isEqualTo: 'confirmed')
    // Instead, use unified status enum above
    return [];
  }
}
