import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_data_service.dart';
import '../services/firebase_offline_cache_service.dart';
import '../constants/firestore_collections.dart';

/// Firebase Repository Pattern
/// Abstraction layer between services and Firestore
/// Implements caching, error handling, and business logic
class FirebaseRepository {
  final FirestoreDataService _firestoreService;
  final FirebaseOfflineCacheService _cacheService;

  FirebaseRepository({
    required FirestoreDataService firestoreService,
    required FirebaseOfflineCacheService cacheService,
  })  : _firestoreService = firestoreService,
        _cacheService = cacheService;

  // ============================================================
  // USER OPERATIONS
  // ============================================================

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      // Try cache first
      var cached = _cacheService.getCachedDocument(
        FirestoreCollections.USERS,
        userId,
      );
      if (cached != null) {
        return cached;
      }

      // Fetch from Firestore
      final userDoc = await _firestoreService.getDocument(
        FirestoreCollections.USERS,
        userId,
      );

      if (userDoc != null) {
        // Cache for offline use
        await _cacheService.cacheDocument(
          FirestoreCollections.USERS,
          userId,
          userDoc,
        );
      }

      return userDoc;
    } catch (e) {
      // Return cached version if available
      return _cacheService.getCachedDocument(
        FirestoreCollections.USERS,
        userId,
      );
    }
  }

  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    await _firestoreService.updateDocument(
      FirestoreCollections.USERS,
      userId,
      {
        ...data,
        FirestoreDatabaseSchema.Users.UPDATED_AT:
            FieldValue.serverTimestamp(),
      },
    );

    // Invalidate cache
    await _cacheService.clearCollectionCache(FirestoreCollections.USERS);
  }

  // ============================================================
  // ORDER OPERATIONS
  // ============================================================

  Future<String> createOrder(Map<String, dynamic> orderData) async {
    try {
      // Check inventory availability first
      final items = orderData['items'] as List?;
      if (items != null && items.isNotEmpty) {
        for (final item in items) {
          final productId = item['productId'];
          final quantity = item['quantity'];

          final inventory = await _firestoreService.getDocument(
            FirestoreCollections.INVENTORY,
            productId,
          );

          if (inventory != null) {
            final available = (inventory['available'] as num?)?.toInt() ?? 0;
            if (available < quantity) {
              throw Exception(
                'Insufficient inventory for product $productId',
              );
            }
          }
        }
      }

      // Create order
      final orderId = await _firestoreService.addDocument(
        FirestoreCollections.ORDERS,
        {
          ...orderData,
          FirestoreDatabaseSchema.Orders.CREATED_AT:
              FieldValue.serverTimestamp(),
          FirestoreDatabaseSchema.Orders.UPDATED_AT:
              FieldValue.serverTimestamp(),
        },
      );

      // Clear cache
      await _cacheService.clearCollectionCache(FirestoreCollections.ORDERS);

      return orderId;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserOrders(String userId) async {
    try {
      // Try cache first
      var cached = _cacheService.getCachedCollection(
        FirestoreCollections.ORDERS,
      );
      if (cached != null && cached.isNotEmpty) {
        return cached
            .where(
              (order) => order['customerId'] == userId,
            )
            .toList();
      }

      final orders = await _firestoreService.getCollection(
        FirestoreCollections.ORDERS,
        whereField: FirestoreDatabaseSchema.Orders.CUSTOMER_ID,
        whereValue: userId,
        orderBy: FirestoreDatabaseSchema.Orders.CREATED_AT,
        descending: true,
        limit: 100,
      );

      // Cache results
      if (orders.isNotEmpty) {
        await _cacheService.cacheCollection(
          FirestoreCollections.ORDERS,
          orders,
        );
      }

      return orders;
    } catch (e) {
      // Return cached if available
      return _cacheService.getCachedCollection(FirestoreCollections.ORDERS)
              ?.where((order) => order['customerId'] == userId)
              .toList() ??
          [];
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _firestoreService.updateDocument(
      FirestoreCollections.ORDERS,
      orderId,
      {
        FirestoreDatabaseSchema.Orders.ORDER_STATUS: status,
        FirestoreDatabaseSchema.Orders.UPDATED_AT:
            FieldValue.serverTimestamp(),
      },
    );

    await _cacheService.clearCollectionCache(FirestoreCollections.ORDERS);
  }

  // ============================================================
  // PAYMENT OPERATIONS
  // ============================================================

  Future<void> createPayment(Map<String, dynamic> paymentData) async {
    await _firestoreService.setDocument(
      FirestoreCollections.PAYMENTS,
      paymentData['paymentId'] as String,
      {
        ...paymentData,
        FirestoreDatabaseSchema.Payments.CREATED_AT:
            FieldValue.serverTimestamp(),
      },
    );

    await _cacheService.clearCollectionCache(
      FirestoreCollections.PAYMENTS,
    );
  }

  Future<Map<String, dynamic>?> getPayment(String paymentId) async {
    return _firestoreService.getDocument(
      FirestoreCollections.PAYMENTS,
      paymentId,
    );
  }

  Future<void> updatePaymentStatus(
    String paymentId,
    String status, {
    bool verified = false,
  }) async {
    await _firestoreService.updateDocument(
      FirestoreCollections.PAYMENTS,
      paymentId,
      {
        FirestoreDatabaseSchema.Payments.STATUS: status,
        FirestoreDatabaseSchema.Payments.VERIFIED: verified,
        if (verified) FirestoreDatabaseSchema.Payments.VERIFIED_AT:
            FieldValue.serverTimestamp(),
      },
    );

    await _cacheService.clearCollectionCache(
      FirestoreCollections.PAYMENTS,
    );
  }

  // ============================================================
  // INVENTORY OPERATIONS
  // ============================================================

  Future<void> reserveInventory(
    String productId,
    int quantity,
  ) async {
    await _firestoreService.incrementField(
      FirestoreCollections.INVENTORY,
      productId,
      'reserved',
      quantity,
    );
  }

  Future<void> deductInventory(
    String productId,
    int quantity,
  ) async {
    await _firestoreService.incrementField(
      FirestoreCollections.INVENTORY,
      productId,
      'quantity',
      -quantity,
    );

    await _firestoreService.incrementField(
      FirestoreCollections.INVENTORY,
      productId,
      'available',
      -quantity,
    );
  }

  Future<void> restoreInventory(
    String productId,
    int quantity,
  ) async {
    await _firestoreService.incrementField(
      FirestoreCollections.INVENTORY,
      productId,
      'quantity',
      quantity,
    );

    await _firestoreService.incrementField(
      FirestoreCollections.INVENTORY,
      productId,
      'available',
      quantity,
    );
  }

  // ============================================================
  // DELIVERY OPERATIONS
  // ============================================================

  Future<String> createDelivery(Map<String, dynamic> deliveryData) async {
    return _firestoreService.addDocument(
      FirestoreCollections.DELIVERIES,
      {
        ...deliveryData,
        FirestoreDatabaseSchema.Deliveries.START_TIME:
            FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> updateDeliveryStatus(String deliveryId, String status) async {
    await _firestoreService.updateDocument(
      FirestoreCollections.DELIVERIES,
      deliveryId,
      {
        FirestoreDatabaseSchema.Deliveries.STATUS: status,
        if (status == 'delivered')
          FirestoreDatabaseSchema.Deliveries.END_TIME:
              FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> updateRiderLocation(
    String riderId,
    double latitude,
    double longitude,
  ) async {
    final locationId = riderId;
    await _firestoreService.setDocument(
      FirestoreCollections.RIDER_LOCATIONS,
      locationId,
      {
        'riderId': riderId,
        'currentLocation': GeoPoint(latitude, longitude),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }

  // ============================================================
  // WALLET & REFUND OPERATIONS
  // ============================================================

  Future<Map<String, dynamic>?> getWallet(String userId) async {
    return _firestoreService.getDocument(
      FirestoreCollections.WALLET,
      userId,
    );
  }

  Future<void> updateWalletBalance(
    String userId,
    num amount,
  ) async {
    await _firestoreService.incrementField(
      FirestoreCollections.WALLET,
      userId,
      'balance',
      amount,
    );
  }

  Future<void> createRefund(
    String orderId,
    num refundAmount,
  ) async {
    final refundId = '${orderId}_${DateTime.now().millisecondsSinceEpoch}';

    await _firestoreService.setDocument(
      FirestoreCollections.REFUNDS,
      refundId,
      {
        'refundId': refundId,
        'orderId': orderId,
        'amount': refundAmount,
        'status': 'initiated',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
  }

  // ============================================================
  // TRANSACTION OPERATIONS
  // ============================================================

  Future<void> processOrderTransaction(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    await _firestoreService.runTransaction<void>((transaction) async {
      // 1. Create order
      transaction.set(
        FirebaseFirestore.instance
            .collection(FirestoreCollections.ORDERS)
            .doc(orderId),
        orderData,
      );

      // 2. Reserve inventory
      final items = orderData['items'] as List? ?? [];
      for (final item in items) {
        final productId = item['productId'];
        final quantity = item['quantity'];

        final invRef = FirebaseFirestore.instance
            .collection(FirestoreCollections.INVENTORY)
            .doc(productId);

        transaction.update(invRef, {
          'reserved': FieldValue.increment(quantity),
        });
      }

      // 3. Create payment record
      final paymentData = orderData['payment'] as Map?;
      if (paymentData != null) {
        transaction.set(
          FirebaseFirestore.instance
              .collection(FirestoreCollections.PAYMENTS)
              .doc(paymentData['paymentId']),
          paymentData,
        );
      }
    });

    await _cacheService.clearCollectionCache(FirestoreCollections.ORDERS);
    await _cacheService.clearCollectionCache(
      FirestoreCollections.INVENTORY,
    );
  }

  // ============================================================
  // REAL-TIME LISTENERS
  // ============================================================

  Stream<Map<String, dynamic>?> streamUserProfile(String userId) {
    return _firestoreService.streamDocument(
      FirestoreCollections.USERS,
      userId,
    );
  }

  Stream<List<Map<String, dynamic>>> streamUserOrders(String userId) {
    return _firestoreService.streamCollection(
      FirestoreCollections.ORDERS,
      whereField: FirestoreDatabaseSchema.Orders.CUSTOMER_ID,
      whereValue: userId,
      orderBy: FirestoreDatabaseSchema.Orders.CREATED_AT,
      descending: true,
      limit: 100,
    );
  }

  Stream<List<Map<String, dynamic>>> streamDeliveries(String orderId) {
    return _firestoreService.streamCollection(
      FirestoreCollections.DELIVERIES,
      whereField: FirestoreDatabaseSchema.Deliveries.ORDER_ID,
      whereValue: orderId,
    );
  }

  // ============================================================
  // UTILITY OPERATIONS
  // ============================================================

  Future<void> clearAllCache() async {
    await _cacheService.clearAllCaches();
  }

  Map<String, dynamic> getCacheStats() {
    return _cacheService.getCacheStats();
  }

  Future<void> cleanupExpiredCache() async {
    await _cacheService.cleanupExpiredEntries();
  }
}
