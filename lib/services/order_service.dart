import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/delivery_type.dart';
import 'notification_service.dart';
import 'whatsapp_notification_service.dart';
import 'audit_service.dart';
import 'shop_config_service.dart';
import '../models/shop_config_model.dart';
import '../models/shop_branch_model.dart';
import 'hyperlocal_expansion_service.dart';
import 'smart_kitchen_service.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  /// Calculate distance using Haversine formula
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final double a = 0.5 - cos((lat2 - lat1) * p)/2 + 
          cos(lat1 * p) * cos(lat2 * p) * 
          (1 - cos((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a)); // km
  }

  /// Check slot booking capacity
  Future<bool> isDeliverySlotAvailable(DateTime date, String slot, int maxOrdersPerSlot) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final querySnapshot = await _db
        .collection('orders')
        .where('scheduledDeliveryDate', isGreaterThanOrEqualTo: startOfDay)
        .where('scheduledDeliveryDate', isLessThan: endOfDay)
        .where('timeSlot', isEqualTo: slot)
        .get();

    final activeOrdersCount = querySnapshot.docs.where((doc) {
      final status = doc.data()['status']?.toString();
      return status != 'OrderStatus.cancelled';
    }).length;

    return activeOrdersCount < maxOrdersPerSlot;
  }

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

  // ── Idempotency: prevent duplicate orders from rapid taps ──
  static final Set<String> _activeCheckouts = {};

  Future<void> createOrder(OrderModel order) async {
    // ── Guard 1: In-memory lock for same-session double taps ──
    final lockKey = '${order.customerId}_${order.totalAmount}_${order.items.length}';
    if (_activeCheckouts.contains(lockKey)) {
      debugPrint('[OrderService] Duplicate checkout blocked (in-memory): $lockKey');
      throw Exception('Your order is already being placed. Please wait.');
    }
    _activeCheckouts.add(lockKey);

    try {
      // ── Guard 2: Firestore idempotency — block same customer placing
      //    an identical-amount order within the last 5 minutes ──
      final fiveMinAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final recentDuplicates = await _db
          .collection('orders')
          .where('customerId', isEqualTo: order.customerId)
          .where('totalAmount', isEqualTo: order.totalAmount)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(fiveMinAgo))
          .limit(1)
          .get();

      if (recentDuplicates.docs.isNotEmpty) {
        final existingOrderNum = recentDuplicates.docs.first.data()['orderNumber'] ?? '';
        debugPrint('[OrderService] Duplicate checkout blocked (Firestore): $existingOrderNum');
        throw Exception('A similar order ($existingOrderNum) was placed moments ago. Please check your orders before re-ordering.');
      }

      final shopConfigService = ShopConfigService();
      final shopConfig = await shopConfigService.getShopConfig();


      // 1. Operating Hours & Open status check
      if (!shopConfig.isOpen) {
        throw Exception('The store is currently closed and not accepting orders.');
      }

      if (shopConfig.autoCloseOutsideHours) {
        final nowUtc = DateTime.now().toUtc();
        final nowShop = nowUtc.add(const Duration(hours: 5, minutes: 30));
        final todayDay = DateFormat('EEEE').format(nowShop);
        final todayHours = shopConfig.operatingHours[todayDay];
        if (todayHours != null) {
          if (!todayHours.isOpen) {
            throw Exception('The store is closed today ($todayDay).');
          }
          
          final openParts = todayHours.openTime.split(':');
          final closeParts = todayHours.closeTime.split(':');
          
          if (openParts.length == 2 && closeParts.length == 2) {
            final openHour = int.tryParse(openParts[0]) ?? 0;
            final openMin = int.tryParse(openParts[1]) ?? 0;
            final closeHour = int.tryParse(closeParts[0]) ?? 23;
            final closeMin = int.tryParse(closeParts[1]) ?? 59;
            
            final openDateTime = DateTime(nowShop.year, nowShop.month, nowShop.day, openHour, openMin);
            final closeDateTime = DateTime(nowShop.year, nowShop.month, nowShop.day, closeHour, closeMin);
            
            if (nowShop.isBefore(openDateTime) || nowShop.isAfter(closeDateTime)) {
              throw Exception('The store is closed. Today\'s business hours: ${todayHours.openTime} to ${todayHours.closeTime}.');
            }
          }
        }
      }

      // 1b. Slot Capacity Check
      if (order.deliveryType == DeliveryType.scheduled && order.scheduledDeliveryDate != null && order.timeSlot != null) {
        final isAvailable = await isDeliverySlotAvailable(
          order.scheduledDeliveryDate!,
          order.timeSlot!,
          shopConfig.maxOrdersPerSlot,
        );
        if (!isAvailable) {
          throw Exception('The selected delivery slot (${order.timeSlot}) is fully booked for ${DateFormat('dd MMM').format(order.scheduledDeliveryDate!)}. Please pick another slot.');
        }
      }

      // 1c. Same-day Order Cutoff Check
      if (order.deliveryType == DeliveryType.sameDay || 
          (order.deliveryType == DeliveryType.scheduled && 
           order.scheduledDeliveryDate != null && 
           order.scheduledDeliveryDate!.year == DateTime.now().add(const Duration(hours: 5, minutes: 30)).year &&
           order.scheduledDeliveryDate!.month == DateTime.now().add(const Duration(hours: 5, minutes: 30)).month &&
           order.scheduledDeliveryDate!.day == DateTime.now().add(const Duration(hours: 5, minutes: 30)).day)) {
        final nowUtc = DateTime.now().toUtc();
        final nowShop = nowUtc.add(const Duration(hours: 5, minutes: 30));
        if (nowShop.hour >= shopConfig.sameDayCutoffHour) {
          final cutoff12h = shopConfig.sameDayCutoffHour > 12 
              ? '${shopConfig.sameDayCutoffHour - 12} PM' 
              : '${shopConfig.sameDayCutoffHour} AM';
          throw Exception('Same-day delivery order placement is closed after $cutoff12h. Please select a future date or next-day slot.');
        }
      }

      // 2. Geofence Check (Hardened Server-side validation)
      final branches = await shopConfigService.getBranches();

      final isDeliverable = shopConfigService.isWithinDeliveryArea(
        order.deliveryAddress.latitude,
        order.deliveryAddress.longitude,
        shopConfig,
        branches,
      );

      if (!isDeliverable) {
        throw Exception('Delivery location is outside our service area.');
      }


      // Assign nearest branch if any
      final nearestBranch = shopConfigService.getNearestBranch(
        order.deliveryAddress.latitude,
        order.deliveryAddress.longitude,
        branches,
      );

      final updatedOrder = nearestBranch != null
          ? order.copyWith(
              shopId: nearestBranch.id,
              shopName: nearestBranch.branchName,
              shopAddress: nearestBranch.branchAddress,
            )
          : order;

      await _db.runTransaction((transaction) async {
        // 2. Event-Sourced Wallet Balance Deduction
        if (updatedOrder.walletAmountUsed > 0) {
          final userRef = _db.collection('users').doc(updatedOrder.customerId);
          final userDoc = await transaction.get(userRef);
          if (!userDoc.exists) {
            throw Exception('Customer profile not found');
          }

          final userData = userDoc.data()!;
          final currentBalance = (userData['walletBalance'] ?? 0.0).toDouble();
          if (currentBalance < updatedOrder.walletAmountUsed) {
            throw Exception('Insufficient wallet balance');
          }

          final newBalance = currentBalance - updatedOrder.walletAmountUsed;
          final lastSeqNum = userData['lastTransactionSequenceNumber'] ?? 0;
          final newSeqNum = lastSeqNum + 1;

          // Update user wallet balance and sequence number
          transaction.update(userRef, {
            'walletBalance': newBalance,
            'lastTransactionSequenceNumber': newSeqNum,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Create transaction record idempotently
          final txnId = 'txn_wallet_debit_${updatedOrder.id}';
          final txnDocRef = userRef.collection('wallet_transactions').doc(txnId);
          
          transaction.set(txnDocRef, {
            'id': txnId,
            'userId': updatedOrder.customerId,
            'type': 'WalletTransactionType.walletPayment',
            'amount': updatedOrder.walletAmountUsed,
            'orderReference': updatedOrder.id,
            'timestamp': FieldValue.serverTimestamp(),
            'description': 'Wallet payment for order #${updatedOrder.orderNumber}',
            'balanceAfter': newBalance,
            'sequenceNumber': newSeqNum,
          });
        }

        // 3. Stock Allocation (Multi-branch aware)
        for (var item in updatedOrder.items) {
          final prodRef = _db.collection('products').doc(item.productId);
          final snapshot = await transaction.get(prodRef);
          
          if (snapshot.exists) {
            final data = snapshot.data();
            if (data != null) {
              final Map<dynamic, dynamic> branchStockMap = data['branchStock'] as Map? ?? {};
              final branchId = (updatedOrder.shopId?.isEmpty ?? true) ? 'primary' : updatedOrder.shopId!;
              
              int currentBranchStock = 0;
              if (branchStockMap.containsKey(branchId)) {
                currentBranchStock = (branchStockMap[branchId] ?? 0) as int;
              } else {
                // Fallback/Migration: seed the branch stock under primary/first key from global stockQuantity
                if (branchId == 'primary' || branchStockMap.isEmpty) {
                  currentBranchStock = (data['stockQuantity'] ?? 0) as int;
                } else {
                  currentBranchStock = 0;
                }
              }

              final int quantityOrdered = item.quantity;
              
              if (currentBranchStock >= quantityOrdered) {
                final newBranchStock = currentBranchStock - quantityOrdered;
                final Map<String, int> updatedBranchStock = Map<String, int>.from(
                  branchStockMap.map((k, v) => MapEntry(k.toString(), v as int))
                );
                updatedBranchStock[branchId] = newBranchStock;
                
                // Calculate new global stock for backward compatibility
                int newGlobalStock = 0;
                if (updatedBranchStock.containsKey('primary')) {
                  newGlobalStock = updatedBranchStock['primary']!;
                } else {
                  newGlobalStock = updatedBranchStock.values.fold(0, (total, val) => total + val);
                }

                transaction.update(prodRef, {
                  'branchStock': updatedBranchStock,
                  'stockQuantity': newGlobalStock,
                  'isAvailable': newGlobalStock > 0 || updatedBranchStock.values.any((val) => val > 0),
                });
              } else {
                throw Exception('Inadequate stock for ${item.productName} at branch. Available: $currentBranchStock');
              }
            }
          } else {
             throw Exception('Product ${item.productName} not found in inventory.');
          }
        }

        final orderRef = _db.collection('orders').doc(updatedOrder.id);
        transaction.set(orderRef, updatedOrder.toMap());
      });

      // Record delivery demand for hyperlocal expansion analytics (Idea 26)
      unawaited(HyperlocalExpansionService().recordDeliveryDemand(
        latitude: updatedOrder.deliveryAddress.latitude,
        longitude: updatedOrder.deliveryAddress.longitude,
        pincode: updatedOrder.deliveryAddress.pincode,
        orderAmount: updatedOrder.totalAmount,
        zoneId: (updatedOrder.shopId?.isEmpty ?? true) ? 'primary' : updatedOrder.shopId!,
      ));

      // Refresh Smart Kitchen predictions (Idea 27)
      unawaited(SmartKitchenService().refreshUserKitchenData(updatedOrder.customerId));

      NotificationService().triggerLocalOrderStatusNotification(updatedOrder.orderNumber, 'placed');

      if (updatedOrder.customerPhone.isNotEmpty) {
        try {
          await WhatsAppNotificationService.sendInvoice(
            phoneNumber: updatedOrder.customerPhone,
            customerName: updatedOrder.customerName,
            orderNumber: updatedOrder.orderNumber,
            items: updatedOrder.items.map((item) => {
              'productName': item.productName,
              'quantity': item.quantity,
              'unit': item.unit,
              'price': item.price,
            }).toList(),
            subtotal: updatedOrder.subtotal,
            deliveryCharge: updatedOrder.deliveryCharge,
            discount: updatedOrder.discount,
            totalAmount: updatedOrder.totalAmount,
            paymentMethod: updatedOrder.paymentMethod.toString().split('.').last.toUpperCase(),
            estimatedDelivery: updatedOrder.timeSlot != null && updatedOrder.scheduledDeliveryDate != null
                ? '${DateFormat('dd MMM').format(updatedOrder.scheduledDeliveryDate!)} (${updatedOrder.timeSlot})'
                : null,
          );
        } catch (e) {
          debugPrint('[OrderService] Error sending WhatsApp invoice: $e');
        }
      }
    } catch (e) {
      debugPrint('[OrderService] ERROR creating order: $e');
      rethrow;
    } finally {
      // Always release the in-memory lock
      _activeCheckouts.remove(lockKey);
    }
  }

  /// Valid order status transitions — enforces sequential state machine
  static const Map<String, List<String>> _validTransitions = {
    'pending': ['confirmed', 'cancelled'],
    'confirmed': ['accepted', 'cancelled'],
    'accepted': ['packing', 'cancelled'],
    'packing': ['packed', 'cancelled'],
    'packed': ['outForDelivery', 'cancelled'],
    'outForDelivery': ['delivered'],
    'delivered': [], // Terminal state — no further transitions allowed
    'cancelled': [], // Terminal state
  };

  /// Normalize status string from Firestore format (e.g., "OrderStatus.pending" → "pending")
  String _normalizeStatus(String? rawStatus) {
    if (rawStatus == null) return 'pending';
    return rawStatus.replaceAll('OrderStatus.', '');
  }

  Future<void> updateOrderStatus(String orderId, String status, {String? employeeId}) async {
    // ── Step 1: Validate state transition ──
    final orderDoc = await _db.collection('orders').doc(orderId).get();
    if (!orderDoc.exists) throw Exception('Order $orderId not found.');

    final currentStatus = _normalizeStatus(orderDoc.data()?['status']?.toString());

    // Block any changes to terminal states
    if (currentStatus == 'delivered') {
      throw Exception('Order has already been delivered. No further modifications are allowed.');
    }
    if (currentStatus == 'cancelled') {
      throw Exception('Order has been cancelled. No further modifications are allowed.');
    }

    // Validate allowed transition
    final allowedNext = _validTransitions[currentStatus] ?? [];
    if (!allowedNext.contains(status)) {
      throw Exception('Invalid status transition: "$currentStatus" → "$status". Allowed: ${allowedNext.join(", ")}');
    }

    // ── Step 2: Packer lock — prevent two employees packing the same order ──
    if (status == 'packing') {
      final existingPackerId = orderDoc.data()?['packerId']?.toString();
      if (existingPackerId != null && existingPackerId.isNotEmpty && employeeId != null && existingPackerId != employeeId) {
        throw Exception('This order is already being packed by another employee ($existingPackerId).');
      }
    }

    final Map<String, dynamic> updates = {
      'status': 'OrderStatus.$status',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Assign packer when entering packing state
    if (status == 'packing' && employeeId != null) {
      updates['packerId'] = employeeId;
      updates['packingStartedAt'] = FieldValue.serverTimestamp();
    }
    
    String? generatedOtp;
    if (status == 'outForDelivery') {
      final int otpVal = 1000 + (DateTime.now().millisecondsSinceEpoch % 9000);
      generatedOtp = otpVal.toString();
      
      // Store the hash on the main order document
      final bytes = utf8.encode(generatedOtp);
      updates['otpHash'] = sha256.convert(bytes).toString();
      updates['otpVerified'] = false;
      updates['outForDeliveryAt'] = FieldValue.serverTimestamp();
      
      // Store the plain text in the secure subcollection
      final secureOtpRef = _db
          .collection('orders')
          .doc(orderId)
          .collection('secure')
          .doc('otp');
      await secureOtpRef.set({
        'otp': generatedOtp,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else if (status == 'delivered') {
      updates['deliveredAt'] = FieldValue.serverTimestamp();
      updates['otpVerified'] = true;

      try {
        final orderDoc = await _db.collection('orders').doc(orderId).get();
        if (orderDoc.exists) {
          final orderData = orderDoc.data();
          final String paymentMethod = orderData?['paymentMethod']?.toString() ?? '';
          final double totalAmount = (orderData?['totalAmount'] ?? 0.0).toDouble();
          final String deliveryAgentId = orderData?['deliveryAgentId']?.toString() ?? 'demo_rider';
          
          if (paymentMethod.contains('cod')) {
            updates['cashCollectedAmount'] = totalAmount;
            updates['cashCollectedAt'] = FieldValue.serverTimestamp();
            
            // Log in orders/{id}/cashCollection subcollection
            await _db
                .collection('orders')
                .doc(orderId)
                .collection('cashCollection')
                .doc('log')
                .set({
              'amount': totalAmount,
              'collectedBy': deliveryAgentId,
              'collectedAt': FieldValue.serverTimestamp(),
              'status': 'collected',
            });
          }
        }
      } catch (e) {
        debugPrint('[OrderService] Error logging COD collection: $e');
      }
    }
    
    await _db.collection('orders').doc(orderId).update(updates);

    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (doc.exists) {
        final data = doc.data();
        final orderNumber = data?['orderNumber'] ?? 'FufajiOrder';
        final customerName = data?['customerName'] ?? 'Customer';
        final customerPhone = data?['customerPhone'] ?? '';

        NotificationService().triggerLocalOrderStatusNotification(orderNumber.toString(), status);

        if (customerPhone.isNotEmpty) {
          if (status == 'outForDelivery' && generatedOtp != null) {
            await WhatsAppNotificationService.sendDeliveryOtpWithTracking(
              phoneNumber: customerPhone.toString(),
              customerName: customerName.toString(),
              orderNumber: orderNumber.toString(),
              otp: generatedOtp,
              orderId: orderId,
              riderName: data?['deliveryAgentName']?.toString(),
              riderPhone: data?['deliveryAgentPhone']?.toString(),
            );
          } else {
            await WhatsAppNotificationService.sendStatusUpdate(
              phoneNumber: customerPhone.toString(),
              customerName: customerName.toString(),
              orderNumber: orderNumber.toString(),
              status: status,
              otp: generatedOtp,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Notification Error: $e');
    }
  }

  /// Verifies the OTP and Rider's proximity (within 50 meters of the delivery location)
  /// before updating order status to 'delivered'.
  Future<bool> verifyAndDeliverOrder({
    required String orderId,
    required String otp,
    required double riderLatitude,
    required double riderLongitude,
  }) async {
    try {
      // 1. Fetch Order Document
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) throw Exception('Order not found');
      
      final order = OrderModel.fromMap(orderDoc.data()!);

      // 2. Rider Proximity Geofence Check (must be within 50 meters of delivery address)
      final distanceKm = calculateDistance(
        order.deliveryAddress.latitude,
        order.deliveryAddress.longitude,
        riderLatitude,
        riderLongitude,
      );
      final distanceMeters = distanceKm * 1000;
      if (distanceMeters > 50.0) {
        throw Exception('Rider is outside the permitted delivery zone. You must be within 50m of the delivery location. Current distance: ${distanceMeters.toStringAsFixed(1)}m.');
      }

      // 3. Verify OTP against the secure document
      final secureOtpDoc = await _db
          .collection('orders')
          .doc(orderId)
          .collection('secure')
          .doc('otp')
          .get();
      
      if (!secureOtpDoc.exists) {
        throw Exception('No verification code generated for this order.');
      }
      
      final storedOtp = secureOtpDoc.data()?['otp']?.toString();
      if (storedOtp != otp) {
        throw Exception('Invalid verification code entered.');
      }

      // 4. Perform atomic update to status history and delivered status
      final updates = {
        'status': 'OrderStatus.delivered',
        'otpVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'deliveredAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('orders').doc(orderId).update(updates);

      // Trigger notifications
      NotificationService().triggerLocalOrderStatusNotification(order.orderNumber, 'delivered');
      
      if (order.customerPhone.isNotEmpty) {
        await WhatsAppNotificationService.sendStatusUpdate(
          phoneNumber: order.customerPhone,
          customerName: order.customerName,
          orderNumber: order.orderNumber,
          status: 'delivered',
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error verifying and delivering order: $e');
      rethrow;
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

  Future<void> updateOrder(String orderId, Map<String, dynamic> data) async {
    await _db.collection('orders').doc(orderId).update(data);
  }

  Future<void> createReturnRequest(Map<String, dynamic> request) async {
    await _db.collection('return_requests').doc(request['id']).set(request);
  }

  Stream<List<Map<String, dynamic>>> getAllReturnRequestsStream() {
    return _db.collection('return_requests').orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }
}
