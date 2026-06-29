import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';

/// OrderRepository handles all Firestore operations for orders
/// Provides clean separation between data layer and business logic
class OrderRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // Singleton pattern
  static final OrderRepository _instance = OrderRepository._internal();
  factory OrderRepository() => _instance;
  OrderRepository._internal();

  // Collection references
  CollectionReference<Map<String, dynamic>> get _ordersCollection =>
      _db.collection('orders');

  // ──────────────────────────────────────────────────────────────
  // CREATE OPERATIONS
  // ──────────────────────────────────────────────────────────────

  /// Creates a new order in Firestore
  /// Returns the created OrderModel with all generated IDs
  Future<OrderModel> createOrder(OrderModel order) async {
    try {
      final docRef = _ordersCollection.doc(order.id);
      await docRef.set(order.toMap());

      // Verify write was successful
      final createdDoc = await docRef.get();
      if (!createdDoc.exists) {
        throw Exception('Failed to create order ${order.id}');
      }

      return OrderModel.fromMap(createdDoc.data() ?? {});
    } catch (e) {
      rethrow;
    }
  }

  /// Creates an order within an atomic transaction
  /// Ensures inventory is decremented atomically with order creation
  Future<OrderModel> createOrderWithInventoryUpdate(
    OrderModel order,
    Map<String, int> inventoryDecrements, // productId -> quantity
  ) async {
    try {
      final result = await _db.runTransaction((transaction) async {
        // Step 1: Validate inventory before any write
        final inventoryValidation = <String, bool>{};
        for (final entry in inventoryDecrements.entries) {
          final productRef = _db.collection('products').doc(entry.key);
          final productSnapshot = await transaction.get(productRef);

          if (!productSnapshot.exists) {
            throw Exception('Product ${entry.key} not found');
          }

          final currentStock = (productSnapshot.data()?['stockQuantity'] ?? 0) as int;
          if (currentStock < entry.value) {
            throw Exception(
              'Insufficient stock for product ${entry.key}: '
              'available=$currentStock, requested=${entry.value}'
            );
          }
          inventoryValidation[entry.key] = true;
        }

        // Step 2: Create order
        final orderRef = _ordersCollection.doc(order.id);
        transaction.set(orderRef, order.toMap());

        // Step 3: Update inventory for all products
        for (final entry in inventoryDecrements.entries) {
          final productRef = _db.collection('products').doc(entry.key);
          transaction.update(productRef, {
            'stockQuantity': FieldValue.increment(-entry.value),
            'lastInventoryUpdateAt': FieldValue.serverTimestamp(),
          });
        }

        return order;
      });

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // READ OPERATIONS
  // ──────────────────────────────────────────────────────────────

  /// Gets a single order by ID
  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final doc = await _ordersCollection.doc(orderId).get();
      if (!doc.exists) return null;
      return OrderModel.fromMap(doc.data() ?? {});
    } catch (e) {
      rethrow;
    }
  }

  /// Gets all orders for a customer, paginated
  Future<List<OrderModel>> getCustomerOrders(
    String customerId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _ordersCollection
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Gets pending orders assigned to an employee
  Future<List<OrderModel>> getPendingOrdersForEmployee(
    String employeeId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _ordersCollection
          .where('employeeId', isEqualTo: employeeId)
          .where('orderStatus', whereIn: [
            'OrderStatus.pending',
            'OrderStatus.confirmed',
            'OrderStatus.processing',
          ])
          .orderBy('createdAt')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Gets assigned orders for a delivery agent
  Future<List<OrderModel>> getAssignedOrdersForDeliveryAgent(
    String deliveryAgentId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _ordersCollection
          .where('deliveryAgentId', isEqualTo: deliveryAgentId)
          .where('orderStatus', whereIn: [
            'OrderStatus.packed',
            'OrderStatus.ready',
            'OrderStatus.shipped',
            'OrderStatus.in_transit',
          ])
          .orderBy('createdAt')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Gets all orders with a specific status
  Future<List<OrderModel>> getOrdersByStatus(
    String status, {
    int limit = 100,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _ordersCollection
          .where('orderStatus', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Searches orders by query (order ID or order number)
  Future<List<OrderModel>> searchOrders(String query, {int limit = 20}) async {
    try {
      final results = await _ordersCollection
          .where('orderNumber', isEqualTo: query)
          .limit(limit)
          .get();

      if (results.docs.isEmpty) {
        // Try searching by ID as fallback
        final docSnapshot = await _ordersCollection.doc(query).get();
        if (docSnapshot.exists) {
          return [OrderModel.fromMap(docSnapshot.data() ?? {})];
        }
      }

      return results.docs
          .map((doc) => OrderModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // UPDATE OPERATIONS
  // ──────────────────────────────────────────────────────────────

  /// Updates order status with timeline entry
  Future<void> updateOrderStatus(
    String orderId,
    String newStatus, {
    String? note,
    String? actorId,
    String? actorRole,
    String? actorName,
  }) async {
    try {
      final statusEntry = {
        'status': newStatus,
        'timestamp': FieldValue.serverTimestamp(),
        'note': note,
        'actorId': actorId,
        'actorRole': actorRole,
        'actorName': actorName,
      };

      await _ordersCollection.doc(orderId).update({
        'orderStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'timeline': FieldValue.arrayUnion([statusEntry]),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Updates multiple order fields in one operation
  Future<void> updateOrder(
    String orderId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _ordersCollection.doc(orderId).update(updates);
    } catch (e) {
      rethrow;
    }
  }

  /// Updates an entire order object
  Future<void> updateOrderFull(OrderModel order) async {
    try {
      await _ordersCollection.doc(order.id).set(order.toMap(), SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  /// Helper to get a product for order validation (shorthand for inventory check)
  Future<ProductModel?> getProductById(String productId) async {
    try {
      final doc = await _db.collection('products').doc(productId).get();
      if (!doc.exists) return null;
      return ProductModel.fromMap(doc.data()!);
    } catch (e) {
      return null;
    }
  }

  /// Helper to update product stock (simple increment/decrement)
  Future<void> updateProductStock(String productId, int quantity) async {
    try {
      await _db.collection('products').doc(productId).update({
        'stockQuantity': FieldValue.increment(quantity),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Cancels an order with reason
  Future<void> cancelOrder(
    String orderId, {
    required String reason,
    String? actorId,
  }) async {
    try {
      await _db.runTransaction((transaction) async {
        final orderRef = _ordersCollection.doc(orderId);
        final orderSnapshot = await transaction.get(orderRef);

        if (!orderSnapshot.exists) {
          throw Exception('Order $orderId not found');
        }

        final order = OrderModel.fromMap(orderSnapshot.data() ?? {});

        // Restore inventory if order was confirmed/processing
        if (order.status.index < 4) { // before packed
          for (final item in order.items) {
            final productRef = _db.collection('products').doc(item.productId);
            transaction.update(productRef, {
              'stockQuantity': FieldValue.increment(item.quantity),
            });
          }
        }

        // Update order
        transaction.update(orderRef, {
          'orderStatus': 'OrderStatus.cancelled',
          'cancellationReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
          'timeline': FieldValue.arrayUnion([
            {
              'status': 'OrderStatus.cancelled',
              'timestamp': FieldValue.serverTimestamp(),
              'note': reason,
              'actorId': actorId,
            }
          ]),
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Assigns an order to an employee for packing
  Future<void> assignToEmployee(
    String orderId,
    String employeeId,
    String employeeName,
  ) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'employeeId': employeeId,
        'employeeName': employeeName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Assigns an order to a delivery agent
  Future<void> assignToDeliveryAgent(
    String orderId,
    String deliveryAgentId,
    String deliveryAgentName,
    String deliveryAgentPhone,
  ) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'deliveryAgentId': deliveryAgentId,
        'deliveryAgentName': deliveryAgentName,
        'deliveryAgentPhone': deliveryAgentPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Updates delivery status with live location
  Future<void> updateDeliveryStatus(
    String orderId,
    double latitude,
    double longitude,
    String status,
  ) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'liveLocation': GeoPoint(latitude, longitude),
        'orderStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Marks order as delivered with OTP verification
  Future<void> markDelivered(
    String orderId, {
    required String otpVerified,
    required DateTime deliveredAt,
  }) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'orderStatus': 'OrderStatus.delivered',
        'otpVerified': otpVerified == 'verified',
        'deliveredAt': Timestamp.fromDate(deliveredAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Records the start of order processing (packing/assembly)
  Future<void> recordProcessingStart(
    String orderId, {
    String? employeeId,
    String? employeeName,
  }) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'packingStatus': 'in_progress',
        'packingStartedAt': Timestamp.now(),
        if (employeeId != null) 'employeeId': employeeId,
        if (employeeName != null) 'employeeName': employeeName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // REAL-TIME LISTENERS
  // ──────────────────────────────────────────────────────────────

  /// Real-time stream of a single order
  Stream<OrderModel?> watchOrder(String orderId) {
    return _ordersCollection.doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return OrderModel.fromMap(doc.data() ?? {});
    });
  }

  /// Real-time stream of customer orders
  Stream<List<OrderModel>> watchCustomerOrders(String customerId) {
    return _ordersCollection
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data()))
            .toList());
  }

  /// Real-time stream of orders with specific status
  Stream<List<OrderModel>> watchOrdersByStatus(String status) {
    return _ordersCollection
        .where('orderStatus', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data()))
            .toList());
  }

  // ──────────────────────────────────────────────────────────────
  // AGGREGATION & STATS
  // ──────────────────────────────────────────────────────────────

  /// Gets order statistics for a customer
  Future<OrderStats> getCustomerOrderStats(String customerId) async {
    try {
      final snapshot = await _ordersCollection
          .where('customerId', isEqualTo: customerId)
          .get();

      int totalOrders = 0;
      double totalSpent = 0.0;
      DateTime? lastOrderDate;

      for (final doc in snapshot.docs) {
        final order = OrderModel.fromMap(doc.data());
        totalOrders++;
        totalSpent += order.totalAmount.toDouble();

        if (lastOrderDate == null || order.createdAt.isAfter(lastOrderDate)) {
          lastOrderDate = order.createdAt;
        }
      }

      return OrderStats(
        totalOrders: totalOrders,
        totalSpent: totalSpent,
        lastOrderDate: lastOrderDate,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Gets daily order count for dashboard
  Future<int> getDailyOrderCount() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _ordersCollection
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  /// Gets daily revenue
  Future<double> getDailyRevenue() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _ordersCollection
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .where('orderStatus', isNotEqualTo: 'OrderStatus.cancelled')
          .get();

      double totalRevenue = 0.0;
      for (final doc in snapshot.docs) {
        final order = OrderModel.fromMap(doc.data());
        totalRevenue += order.totalAmount.toDouble();
      }

      return totalRevenue;
    } catch (e) {
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // HELPER: DELETE OPERATIONS (Admin Only)
  // ──────────────────────────────────────────────────────────────

  /// Deletes an order (admin only, use with caution)
  Future<void> deleteOrder(String orderId) async {
    try {
      await _ordersCollection.doc(orderId).delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Batch deletes multiple orders (admin only)
  Future<void> batchDeleteOrders(List<String> orderIds) async {
    try {
      final batch = _db.batch();
      for (final orderId in orderIds) {
        batch.delete(_ordersCollection.doc(orderId));
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}

/// Data class for order statistics
class OrderStats {
  final int totalOrders;
  final double totalSpent;
  final DateTime? lastOrderDate;

  OrderStats({
    required this.totalOrders,
    required this.totalSpent,
    this.lastOrderDate,
  });

  double get averageOrderValue {
    if (totalOrders == 0) return 0.0;
    return totalSpent / totalOrders;
  }
}
