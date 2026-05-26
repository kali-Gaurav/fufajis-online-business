import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/product_model.dart';
import '../models/product_review_model.dart';
import '../models/order_model.dart';
import '../models/cod_settlement_model.dart';
import '../models/attendance_model.dart';
import '../models/chat_message_model.dart';
import '../models/low_stock_alert_model.dart';
import 'notification_service.dart';
import '../services/whatsapp_notification_service.dart';
import 'audit_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Users ---
  Future<void> createUser(UserModel user) async {
    try {
      await _db.collection('users').doc(user.id).set(user.toMap());
      debugPrint('[FirestoreService] User created: ${user.id}');
    } catch (e) {
      debugPrint('[FirestoreService] ERROR creating user: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('[FirestoreService] ERROR getting user: $e');
      return null;
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(userId).update(data);
      debugPrint('[FirestoreService] User updated: $userId');
    } catch (e) {
      debugPrint('[FirestoreService] ERROR updating user: $e');
      rethrow;
    }
  }

  // --- Products ---
  Stream<List<ProductModel>> getProductsStream() {
    return _db.collection('products').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ProductModel.fromMap(doc.data())).toList();
    });
  }

  Future<List<ProductModel>> getProducts() async {
    final snapshot = await _db.collection('products').get();
    return snapshot.docs.map((doc) => ProductModel.fromMap(doc.data())).toList();
  }

  Future<void> addProduct(ProductModel product) async {
    try {
      await _db.collection('products').doc(product.id).set(product.toMap());
      debugPrint('[FirestoreService] Product added: ${product.id}');
    } catch (e) {
      debugPrint('[FirestoreService] ERROR adding product: $e');
      rethrow;
    }
  }

  /// Bulk add products using chunked batch writes (Feature: Production Hardening)
  Future<void> batchAddProducts(List<ProductModel> products) async {
    try {
      const int batchSize = 50;
      for (var i = 0; i < products.length; i += batchSize) {
        final batch = _db.batch();
        final chunk = products.sublist(
          i,
          i + batchSize > products.length ? products.length : i + batchSize,
        );

        for (var product in chunk) {
          final docRef = _db.collection('products').doc(product.id);
          batch.set(docRef, product.toMap());
        }

        await batch.commit();
        debugPrint('[FirestoreService] Committed batch of ${chunk.length} products (Total processed: ${i + chunk.length})');
      }
    } catch (e) {
      debugPrint('[FirestoreService] ERROR in batchAddProducts: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    try {
      final doc = await _db.collection('products').doc(productId).get();
      final oldData = doc.data() ?? {};
      
      await _db.collection('products').doc(productId).update(data);
      debugPrint('[FirestoreService] Product updated: $productId');

      // Audit Logging for stock changes
      if (data.containsKey('stockQuantity')) {
        await AuditService().logAction(
          userId: 'system', // Ideally current user ID from AuthProvider
          userName: 'Owner/Admin',
          action: AuditAction.stockAdjustment,
          description: 'Stock updated for ${oldData['name'] ?? productId}',
          metadata: {
            'productId': productId,
            'oldStock': oldData['stockQuantity'],
            'newStock': data['stockQuantity'],
          },
        );
      }

      // Feature 12: Check for low stock after update
      if (data.containsKey('stockQuantity') || data.containsKey('minimumStock')) {
        if (doc.exists) {
          final product = ProductModel.fromMap(doc.data()!);
          // Refetch fresh data to be sure
          final freshDoc = await _db.collection('products').doc(productId).get();
          final freshProduct = ProductModel.fromMap(freshDoc.data()!);

          if (freshProduct.stockQuantity < freshProduct.minimumStock) {
            await createLowStockAlert(freshProduct);
          }
        }
      }
    } catch (e) {
      debugPrint('[FirestoreService] ERROR updating product: $e');
      rethrow;
    }
  }

  Future<void> updateOrder(String orderId, Map<String, dynamic> data) async {
    try {
      await _db.collection('orders').doc(orderId).update(data);
      debugPrint('[FirestoreService] Order updated: $orderId');
    } catch (e) {
      debugPrint('[FirestoreService] ERROR updating order: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _db.collection('products').doc(productId).delete();
      debugPrint('[FirestoreService] Product deleted: $productId');
    } catch (e) {
      debugPrint('[FirestoreService] ERROR deleting product: $e');
      rethrow;
    }
  }

  // --- Low Stock Alerts (Feature 12) ---
  Future<void> createLowStockAlert(ProductModel product) async {
    final alert = LowStockAlert(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      productId: product.id,
      productName: product.name,
      currentStock: product.stockQuantity,
      minimumStock: product.minimumStock,
      createdAt: DateTime.now(),
    );
    await _db.collection('low_stock_alerts').doc(alert.id).set(alert.toMap());

    // Notify owner
    NotificationService().showLocalNotification(
      '⚠️ Low Stock Alert',
      '${product.name} is running low (${product.stockQuantity} remaining)',
    );
  }

  Stream<List<LowStockAlert>> getLowStockAlertsStream() {
    return _db
        .collection('low_stock_alerts')
        .where('isDismissed', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LowStockAlert.fromMap(doc.data())).toList();
    });
  }

  Future<void> dismissLowStockAlert(String alertId) async {
    await _db.collection('low_stock_alerts').doc(alertId).update({'isDismissed': true});
  }

  Stream<List<ProductReviewModel>> getProductReviewsStream(String productId) {
    return _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductReviewModel.fromMap(doc.data()))
          .toList();
    });
  }

  Future<void> addProductReview(ProductReviewModel review) async {
    final productRef = _db.collection('products').doc(review.productId);
    final reviewRef = productRef.collection('reviews').doc(review.id);

    await _db.runTransaction((transaction) async {
      final productSnapshot = await transaction.get(productRef);
      final data = productSnapshot.data();
      final currentRating = (data?['rating'] ?? 0.0).toDouble();
      final currentCount = data?['reviewCount'] ?? 0;
      final nextCount = currentCount + 1;
      final nextRating =
          ((currentRating * currentCount) + review.rating) / nextCount;

      transaction.set(reviewRef, review.toMap());
      transaction.update(productRef, {
        'rating': double.parse(nextRating.toStringAsFixed(1)),
        'reviewCount': nextCount,
      });
    });
  }

  /// Add shop owner response to a review
  Future<void> addOwnerResponse(
    String productId,
    String reviewId,
    String response,
  ) async {
    await _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(reviewId)
        .update({
          'ownerReply': response,
          'ownerReplyDate': FieldValue.serverTimestamp(),
        });
  }

  /// Flag a review for moderation
  Future<void> flagReview(
    String productId,
    String reviewId,
    List<String> reasons,
  ) async {
    await _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(reviewId)
        .update({
          'isFlagged': true,
          'flagReasons': reasons,
        });
  }

  /// Mark review as helpful
  Future<void> markReviewAsHelpful(String productId, String reviewId) async {
    await _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(reviewId)
        .update({
          'helpfulCount': FieldValue.increment(1),
        });
  }

  // --- Orders ---
  Stream<List<OrderModel>> getOrdersStream(String userId) {
    return _db
        .collection('orders')
        .where('customerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromMap(doc.data())).toList();
    });
  }
  
  Stream<List<OrderModel>> getAllOrdersStream() {
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromMap(doc.data())).toList();
    });
  }

  Future<void> createOrder(OrderModel order) async {
    try {
      await _db.runTransaction((transaction) async {
        // 1. Read product stock levels and verify availability
        for (var item in order.items) {
          final prodRef = _db.collection('products').doc(item.productId);
          final snapshot = await transaction.get(prodRef);
          
          if (snapshot.exists) {
            final data = snapshot.data();
            if (data != null) {
              final int currentStock = (data['stockQuantity'] ?? 0) as int;
              final int quantityOrdered = item.quantity;
              
              if (currentStock >= quantityOrdered) {
                // Deduct stock and update availability status
                final newStock = currentStock - quantityOrdered;
                transaction.update(prodRef, {
                  'stockQuantity': newStock,
                  'isAvailable': newStock > 0,
                });
              } else {
                throw Exception('Inadequate stock for ${item.productName}. Available: $currentStock');
              }
            }
          } else {
             throw Exception('Product ${item.productName} not found in inventory.');
          }
        }

        // 2. Set the order document inside the transaction
        final orderRef = _db.collection('orders').doc(order.id);
        transaction.set(orderRef, order.toMap());
      });

      // 3. Trigger notification to Shop Owner
      try {
        NotificationService().triggerLocalOrderStatusNotification(
          order.orderNumber,
          'placed'
        );
      } catch (e) {
        debugPrint('[FirestoreService] Notification failed but order saved: $e');
      }
      
      debugPrint('[FirestoreService] Order created successfully: ${order.id}');
    } catch (e) {
      debugPrint('[FirestoreService] ERROR creating order: $e');
      rethrow;
    }
  }


  Future<void> updateOrderStatus(String orderId, String status) async {
    final Map<String, dynamic> updates = {
      'status': 'OrderStatus.$status',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    String? generatedOtp;
    if (status == 'outForDelivery') {
      final int otpVal = 1000 + (DateTime.now().millisecondsSinceEpoch % 9000);
      generatedOtp = otpVal.toString();
      updates['otp'] = generatedOtp;
      updates['otpVerified'] = false;
      updates['outForDeliveryAt'] = FieldValue.serverTimestamp();
    } else if (status == 'delivered') {
      updates['deliveredAt'] = FieldValue.serverTimestamp();
      updates['otpVerified'] = true;
    }
    
    await _db.collection('orders').doc(orderId).update(updates);

    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (doc.exists) {
        final data = doc.data();
        final orderNumber = data?['orderNumber'] ?? 'FufajiOrder';
        final customerName = data?['customerName'] ?? 'Customer';
        final customerPhone = data?['customerPhone'] ?? '';

        // 1. Trigger Local/Push Notification
        NotificationService().triggerLocalOrderStatusNotification(orderNumber.toString(), status);

        // 2. Trigger WhatsApp Notification
        if (customerPhone.isNotEmpty) {
          await WhatsAppNotificationService.sendStatusUpdate(
            phoneNumber: customerPhone.toString(),
            customerName: customerName.toString(),
            orderNumber: orderNumber.toString(),
            status: status,
            otp: generatedOtp,
          );
        }
      }
    } catch (e) {
      debugPrint('Notification Error: $e');
    }
  }

  Future<void> updateOrderLiveLocation(String orderId, double latitude, double longitude) async {
    await _db.collection('orders').doc(orderId).update({
      'liveLocation': {
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    });
  }

  // --- COD Settlements ---
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

  // --- Attendance / Shift Tracking ---
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

  // --- Shop Settings ---
  Future<bool> getShopStatus() async {
    try {
      final doc = await _db.collection('settings').doc('shop_status').get();
      if (doc.exists) {
        return doc.data()?['isOpen'] ?? true;
      }
      // If doc doesn't exist, create it as open by default
      await _db.collection('settings').doc('shop_status').set({'isOpen': true});
      return true;
    } catch (e) {
      debugPrint('Error getting shop status: $e');
      return true; // Default to open on error
    }
  }

  Future<void> updateShopStatus(bool isOpen) async {
    await _db.collection('settings').doc('shop_status').set({
      'isOpen': isOpen,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<bool> getShopStatusStream() {
    return _db.collection('settings').doc('shop_status').snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data()?['isOpen'] ?? true;
      }
      return true;
    });
  }

  // --- Authorization & RBAC (Enterprise Hardening) ---

  Future<void> authorizeUser(String phoneNumber, UserRole role, String name, String authorizedBy) async {
    final docId = phoneNumber.replaceAll('+', '');
    await _db.collection('pre_authorized_users').doc(docId).set({
      'phoneNumber': phoneNumber,
      'role': role.toString(),
      'name': name,
      'authorizedBy': authorizedBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getAuthorization(String phoneNumber) async {
    final docId = phoneNumber.replaceAll('+', '');
    final doc = await _db.collection('pre_authorized_users').doc(docId).get();
    return doc.exists ? doc.data() : null;
  }

  Stream<List<Map<String, dynamic>>> getAuthorizedRidersStream() {
    return _db
        .collection('pre_authorized_users')
        .where('role', isEqualTo: UserRole.deliveryAgent.toString())
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> deauthorizeUser(String phoneNumber) async {
    final docId = phoneNumber.replaceAll('+', '');
    await _db.collection('pre_authorized_users').doc(docId).delete();
  }

  // --- Disputes & Returns ---
  Future<void> createReturnRequest(Map<String, dynamic> request) async {
    await _db.collection('return_requests').doc(request['id']).set(request);
  }

  Stream<List<Map<String, dynamic>>> getAllReturnRequestsStream() {
    return _db.collection('return_requests').orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  // --- Rider Payouts (Enterprise Hardening) ---
  Stream<List<Map<String, dynamic>>> getRiderPayoutsStream() {
    return _db.collection('rider_payouts').orderBy('timestamp', descending: true).snapshots().map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }
  Future<void> sendSupportMessage(ChatMessageModel msg) async {
    await _db.collection('support_chats').doc(msg.id).set(msg.toMap());
  }

  Stream<List<ChatMessageModel>> getRiderChatStream(String riderId) {
    return _db
        .collection('support_chats')
        .where('chatChannelId', isEqualTo: riderId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatMessageModel.fromMap(doc.data())).toList();
    });
  }

  Stream<List<ChatMessageModel>> getOwnerChatChannelsStream() {
    // Fetches latest message from every unique channel
    return _db
        .collection('support_chats')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final Map<String, ChatMessageModel> latestMessages = {};
      for (var doc in snapshot.docs) {
        final msg = ChatMessageModel.fromMap(doc.data());
        if (!latestMessages.containsKey(msg.chatChannelId)) {
          latestMessages[msg.chatChannelId] = msg;
        }
      }
      return latestMessages.values.toList();
    });
  }

  Stream<List<ChatMessageModel>> getCustomerChatStream(String customerId) {
    return _db
        .collection('support_chats')
        .where('chatChannelId', isEqualTo: customerId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatMessageModel.fromMap(doc.data())).toList();
    });
  }

  Future<void> markMessagesAsRead(String chatChannelId, String readerId) async {
    final batch = _db.batch();
    final unreadDocs = await _db
        .collection('support_chats')
        .where('chatChannelId', isEqualTo: chatChannelId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unreadDocs.docs) {
      final data = doc.data();
      if (data['senderId'] != readerId) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }
}
