import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import '../models/delivery_type.dart';
import '../constants/order_status.dart';
import 'shop_config_service.dart';
import 'hyperlocal_expansion_service.dart';
import 'smart_kitchen_service.dart';
import 'order_notification_service.dart';
import '../utils/monetary_value.dart';
import '../config/supabase_config.dart';

class OrderService {
  FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;

  set db(FirebaseFirestore database) => _customDb = database;

  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  /// Calculate distance using Haversine formula
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final double a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
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
      final statusStr = doc.data()['status']?.toString();
      final status = OrderStatus.fromString(statusStr);
      return status != OrderStatus.cancelled;
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
    return _db.collection('orders').orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
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
          .where('totalAmount', isEqualTo: order.totalAmount.toFirestore())
          .where('createdAt', isGreaterThan: Timestamp.fromDate(fiveMinAgo))
          .limit(1)
          .get();

      if (recentDuplicates.docs.isNotEmpty) {
        final existingOrderNum = recentDuplicates.docs.first.data()['orderNumber'] ?? '';
        debugPrint('[OrderService] Duplicate checkout blocked (Firestore): $existingOrderNum');
        throw Exception(
          'A similar order ($existingOrderNum) was placed moments ago. Please check your orders before re-ordering.',
        );
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

            final openDateTime = DateTime(
              nowShop.year,
              nowShop.month,
              nowShop.day,
              openHour,
              openMin,
            );
            final closeDateTime = DateTime(
              nowShop.year,
              nowShop.month,
              nowShop.day,
              closeHour,
              closeMin,
            );

            if (nowShop.isBefore(openDateTime) || nowShop.isAfter(closeDateTime)) {
              throw Exception(
                'The store is closed. Today\'s business hours: ${todayHours.openTime} to ${todayHours.closeTime}.',
              );
            }
          }
        }
      }

      // 1b. Slot Capacity Check
      if (order.deliveryType == DeliveryType.scheduled &&
          order.scheduledDeliveryDate != null &&
          order.timeSlot != null) {
        final isAvailable = await isDeliverySlotAvailable(
          order.scheduledDeliveryDate!,
          order.timeSlot!,
          shopConfig.maxOrdersPerSlot,
        );
        if (!isAvailable) {
          throw Exception(
            'The selected delivery slot (${order.timeSlot}) is fully booked for ${DateFormat('dd MMM').format(order.scheduledDeliveryDate!)}. Please pick another slot.',
          );
        }
      }

      // 1c. Same-day Order Cutoff Check
      if (order.deliveryType == DeliveryType.sameDay ||
          (order.deliveryType == DeliveryType.scheduled &&
              order.scheduledDeliveryDate != null &&
              order.scheduledDeliveryDate!.year ==
                  DateTime.now().add(const Duration(hours: 5, minutes: 30)).year &&
              order.scheduledDeliveryDate!.month ==
                  DateTime.now().add(const Duration(hours: 5, minutes: 30)).month &&
              order.scheduledDeliveryDate!.day ==
                  DateTime.now().add(const Duration(hours: 5, minutes: 30)).day)) {
        final nowUtc = DateTime.now().toUtc();
        final nowShop = nowUtc.add(const Duration(hours: 5, minutes: 30));
        if (nowShop.hour >= shopConfig.sameDayCutoffHour) {
          final cutoff12h = shopConfig.sameDayCutoffHour > 12
              ? '${shopConfig.sameDayCutoffHour - 12} PM'
              : '${shopConfig.sameDayCutoffHour} AM';
          throw Exception(
            'Same-day delivery order placement is closed after $cutoff12h. Please select a future date or next-day slot.',
          );
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

      // Make order dumb - client prepares the payload and delegates to backend
      final payload = {
        'idempotencyKey': lockKey,
        'shopId': updatedOrder.shopId ?? 'primary',
        'walletAmountUsed': updatedOrder.walletAmountUsed.toDouble(),
        'deliveryType': updatedOrder.deliveryType.name,
        'paymentMethod': updatedOrder.paymentMethod.name,
        'deliveryAddress': updatedOrder.deliveryAddress.toMap(),
        'items': updatedOrder.items.map((item) => {
          'id': item.id,
          'productId': item.productId,
          'quantity': item.quantity,
        }).toList(),
      };

      try {
        // Call Supabase Edge Function for checkout
        final response = await SupabaseConfig.client.functions.invoke(
          'checkout',
          body: payload,
        );

        final data = response.data as Map<String, dynamic>? ?? {};
        if (data['success'] != true) {
          throw Exception(data['message'] ?? 'Checkout failed on the server.');
        }

        debugPrint('[OrderService] Order created: ${data['orderId']}');

        // We assume the server created the order successfully.
        // We can now just let the UI proceed to the success screen or payment gateway.

      } catch (e) {
        throw Exception('Server error during checkout: $e');
      }

      // Record delivery demand for hyperlocal expansion analytics (Idea 26)
      unawaited(
        HyperlocalExpansionService().recordDeliveryDemand(
          latitude: updatedOrder.deliveryAddress.latitude,
          longitude: updatedOrder.deliveryAddress.longitude,
          pincode: updatedOrder.deliveryAddress.pincode,
          orderAmount: updatedOrder.totalAmount.toDouble(),
          zoneId: (updatedOrder.shopId?.isEmpty ?? true) ? 'primary' : updatedOrder.shopId!,
        ),
      );

      // Refresh Smart Kitchen predictions (Idea 27)
      unawaited(SmartKitchenService().refreshUserKitchenData(updatedOrder.customerId));

      // Note: Order notification is now typically handled by backend triggers, but keeping here for legacy support.
      unawaited(OrderNotificationService().notifyOrderConfirmed(updatedOrder));
    } catch (e) {
      debugPrint('[OrderService] ERROR creating order: $e');
      rethrow;
    } finally {
      // Always release the in-memory lock
      _activeCheckouts.remove(lockKey);
    }
  }

  /// Valid order status transitions — now uses unified OrderStatus enum
  @deprecated
  static const Map<String, List<String>> _validTransitions = {
    'pending': ['confirmed', 'cancelled'],
    'confirmed': ['processing', 'cancelled'],
    'processing': ['packed', 'cancelled'],
    'packed': ['outForDelivery', 'cancelled'],
    'outForDelivery': ['delivered'],
    'delivered': [], // Terminal state — no further transitions allowed
    'cancelled': [], // Terminal state
  };

  /// Normalize status string using OrderStatus enum
  String _normalizeStatus(String? rawStatus) {
    return OrderStatus.fromString(rawStatus).firestoreValue;
  }

  /// Approves the packing for an order, advancing status to packed (Owner Flow)
  Future<void> approvePacking(String orderId, String ownerId, String ownerName) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final parcelId = 'PARCEL-${DateTime.now().millisecondsSinceEpoch}';

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) throw Exception('Order not found');

      final orderData = snapshot.data()!;
      final currentStatus = _normalizeStatus(orderData['status']?.toString());
      final currentPackingStatus = orderData['packingStatus']?.toString();

      if (currentStatus != 'processing' || currentPackingStatus != 'pending_approval') {
        throw Exception('Order is not awaiting packing approval.');
      }

      final List<dynamic> historyList = orderData['packingHistory'] as List<dynamic>? ?? [];
      final updatedHistory = List<dynamic>.from(historyList)
        ..add({
          'timestamp': Timestamp.now(),
          'status': 'approved',
          'actorId': ownerId,
          'actorName': ownerName,
          'note': 'Packing approved by owner.',
        });

      final List<dynamic> statusHistory = orderData['statusHistory'] as List<dynamic>? ?? [];
      final updatedStatusHistory = List<dynamic>.from(statusHistory)
        ..add({
          'status': OrderStatus.packed.firestoreValue,
          'timestamp': Timestamp.now(),
          'note': 'Order packing approved and ready.',
        });

      transaction.update(orderRef, {
        'status': OrderStatus.packed.firestoreValue,
        'packingStatus': 'approved',
        'parcelId': parcelId,
        'packingApprovedBy': ownerName,
        'packingApprovedById': ownerId,
        'packingApprovedAt': FieldValue.serverTimestamp(),
        'packingHistory': updatedHistory,
        'statusHistory': updatedStatusHistory,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Send WhatsApp notification
    try {
      final doc = await orderRef.get();
      if (doc.exists && doc.data() != null) {
        final order = OrderModel.fromMap(doc.data()!);
        unawaited(
          OrderNotificationService().notifyOrderStatusChanged(order, OrderStatus.processing),
        );
      }
    } catch (e) {
      debugPrint('[OrderService] Notification Error: $e');
    }
  }

  /// Rejects the packing for an order, keeping status at processing but marking as rejected
  Future<void> rejectPacking(
    String orderId,
    String ownerId,
    String ownerName,
    String reason,
  ) async {
    final orderRef = _db.collection('orders').doc(orderId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) throw Exception('Order not found');

      final orderData = snapshot.data()!;
      final currentStatus = _normalizeStatus(orderData['status']?.toString());
      final currentPackingStatus = orderData['packingStatus']?.toString();

      if (currentStatus != 'processing' || currentPackingStatus != 'pending_approval') {
        throw Exception('Order is not awaiting packing approval.');
      }

      final List<dynamic> historyList = orderData['packingHistory'] as List<dynamic>? ?? [];
      final updatedHistory = List<dynamic>.from(historyList)
        ..add({
          'timestamp': Timestamp.now(),
          'status': 'rejected',
          'actorId': ownerId,
          'actorName': ownerName,
          'note': reason,
        });

      transaction.update(orderRef, {
        'packingStatus': 'rejected',
        'packingRejectionReason': reason,
        'packingHistory': updatedHistory,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? employeeId,
    String? employeeName,
    String? note,
  }) async {
    // Map outForDelivery to shipped (backend uses shipped)
    final backendStatus = status == 'outForDelivery' ? 'shipped' : status;

    // Call Supabase Edge Function to change order status
    final response = await SupabaseConfig.client.functions.invoke(
      'order-lifecycle',
      body: {
        'action': 'change-status',
        'orderId': orderId,
        'targetStatus': backendStatus,
        'note': note,
      },
    );

    final data = response.data as Map<String, dynamic>? ?? {};
    if (data['success'] != true) {
      throw Exception('Failed to update order status');
    }

    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (doc.exists && doc.data() != null) {
        var order = OrderModel.fromMap(doc.data()!);
        // Keep local notification for legacy until Step 2 is fully implemented
        unawaited(OrderNotificationService().notifyOrderStatusChanged(order, OrderStatus.pending));
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
        throw Exception(
          'Rider is outside the permitted delivery zone. You must be within 50m of the delivery location. Current distance: ${distanceMeters.toStringAsFixed(1)}m.',
        );
      }

      // 3. Verify OTP against the secure document — with brute-force lockout.
      // FIX (Module 5, P1-5.2): a 4-digit OTP with unlimited attempts can be
      // brute-forced in ≤10,000 tries. After [_maxOtpAttempts] consecutive
      // failures the order's OTP verification locks for [_otpLockoutMinutes]
      // minutes. Counter + lock are updated atomically in a transaction so
      // parallel attempts can't bypass the limit.
      const maxOtpAttempts = 5;
      const otpLockoutMinutes = 15;
      final secureOtpRef = _db
          .collection('orders')
          .doc(orderId)
          .collection('secure')
          .doc('otp');

      await _db.runTransaction((txn) async {
        final secureOtpDoc = await txn.get(secureOtpRef);
        if (!secureOtpDoc.exists) {
          throw Exception('No verification code generated for this order.');
        }
        final data = secureOtpDoc.data()!;

        final lockedUntil = (data['lockedUntil'] as Timestamp?)?.toDate();
        if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
          final remaining = lockedUntil.difference(DateTime.now()).inMinutes + 1;
          throw Exception(
            'Too many wrong attempts. OTP verification is locked for ~$remaining more minute(s).',
          );
        }

        final storedOtp = data['otp']?.toString();
        if (storedOtp != otp) {
          final attempts = ((data['failedAttempts'] as num?) ?? 0).toInt() + 1;
          if (attempts >= maxOtpAttempts) {
            txn.update(secureOtpRef, {
              'failedAttempts': attempts,
              'lockedUntil': Timestamp.fromDate(
                DateTime.now().add(const Duration(minutes: otpLockoutMinutes)),
              ),
              'lastFailedAt': FieldValue.serverTimestamp(),
            });
            throw Exception(
              'Too many wrong attempts. OTP verification locked for $otpLockoutMinutes minutes.',
            );
          }
          txn.update(secureOtpRef, {
            'failedAttempts': attempts,
            'lastFailedAt': FieldValue.serverTimestamp(),
          });
          throw Exception(
            'Invalid verification code entered. ${maxOtpAttempts - attempts} attempt(s) remaining.',
          );
        }

        // Success — clear the failure counter.
        txn.update(secureOtpRef, {'failedAttempts': 0, 'lockedUntil': null});
      });

      // 4. Perform atomic update to status history and delivered status
      final updates = {
        'status': OrderStatus.delivered.firestoreValue,
        'otpVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'deliveredAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('orders').doc(orderId).update(updates);

      // Trigger notifications
      unawaited(OrderNotificationService().notifyDeliveryComplete(order));

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
      },
    });
  }

  Future<void> updateOrder(String orderId, Map<String, dynamic> data) async {
    await _db.collection('orders').doc(orderId).update(data);
  }

  Future<void> createReturnRequest(Map<String, dynamic> request) async {
    await _db.collection('return_requests').doc(request['id']).set(request);
  }

  Stream<List<Map<String, dynamic>>> getAllReturnRequestsStream() {
    return _db
        .collection('return_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  Future<void> reconcileStuckOrders() async {
    // Logic to move stuck orders back to a valid state or notify admins
    debugPrint('[OrderService] reconcileStuckOrders called');
  }

  Stream<Map<String, dynamic>> getTodayOrdersStatsStream() {
    final start = DateTime.now().subtract(const Duration(hours: 24));
    return _db
        .collection('orders')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(start))
        .snapshots()
        .map((s) => {'count': s.docs.length});
  }

  Future<void> failOrderDelivery({
    required String orderId,
    required String reason,
    double? latitude,
    double? longitude,
  }) async {
    // Call Supabase Edge Function to fail delivery
    final response = await SupabaseConfig.client.functions.invoke(
      'order-lifecycle',
      body: {
        'action': 'fail-delivery',
        'orderId': orderId,
        'reason': reason,
        'latitude': latitude,
        'longitude': longitude,
      },
    );

    final data = response.data as Map<String, dynamic>? ?? {};
    if (data['success'] != true) {
      throw Exception('Failed to report delivery failure.');
    }
  }

  Future<void> resolveDeliveryException({
    required String orderId,
    required String action, // 'retry' or 'return' or 'refund'
    required String reason,
  }) async {
    // Call Supabase Edge Function to resolve exception
    final response = await SupabaseConfig.client.functions.invoke(
      'order-lifecycle',
      body: {
        'action': 'resolve-exception',
        'orderId': orderId,
        'resolution': action,
        'notes': reason,
      },
    );

    final data = response.data as Map<String, dynamic>? ?? {};
    if (data['success'] != true) {
      throw Exception('Failed to resolve delivery exception.');
    }
  }
}
