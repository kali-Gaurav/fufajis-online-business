import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:fufajis_online/models/cart_item.dart';
import 'package:fufajis_online/models/delivery_type.dart';
import 'package:fufajis_online/models/order_model.dart';
import 'package:fufajis_online/models/payment_method.dart';
import 'package:fufajis_online/models/payment_result.dart';
import 'package:fufajis_online/models/user_model.dart';

/// Payment verification service for server-side verification
/// 
/// This service handles:
/// - Payment signature verification
/// - Payment status verification with Razorpay API
/// - Order creation after successful verification
/// 
/// Note: In production, signature verification should be done on the server
/// This client-side implementation is for development and testing purposes
class PaymentVerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // In production, this should be stored securely on the backend
  // Never expose the secret key in client-side code
  static const String _razorpaySecretKey = 'RAZORPAY_SECRET_KEY_PLACEHOLDER';

  /// Verify payment signature
  /// 
  /// Calls secure Firebase Cloud Functions server-side verification
  /// to prevent tampering with payment responses
  Future<bool> verifySignature({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      final FirebaseFunctions functions = FirebaseFunctions.instance;
      final HttpsCallable callable = functions.httpsCallable('verifyRazorpayPayment');
      
      final HttpsCallableResult result = await callable.call({
        'paymentId': paymentId,
        'orderId': orderId,
        'signature': signature,
      });

      if (result.data != null && result.data['success'] == true) {
        debugPrint('PaymentVerificationService: Secure signature verification succeeded');
        return true;
      }

      debugPrint('PaymentVerificationService: Secure signature verification failed: ${result.data}');
      return false;
    } catch (e) {
      debugPrint('PaymentVerificationService: Signature verification error - $e');
      return false;
    }
  }

  /// Verify payment status
  /// 
  /// In this production system, we read the real transaction status
  /// which gets verified securely by the shop owner's ledger confirmation.
  Future<PaymentVerificationResult> verifyPaymentStatus({
    required String paymentId,
    required String orderId,
  }) async {
    try {
      // Check if payment already verified in Firestore
      final paymentDoc = await _firestore
          .collection('payments')
          .doc(paymentId)
          .get();

      if (paymentDoc.exists) {
        final data = paymentDoc.data()!;
        return PaymentVerificationResult(
          isVerified: data['verified'] ?? false,
          status: data['status'] ?? 'unknown',
          paymentId: paymentId,
          orderId: orderId,
        );
      }

      // If payment record does not exist in the collection, it starts in a pending/authorized state
      // awaiting explicit owner approval on orders screen.
      return PaymentVerificationResult(
        isVerified: false,
        status: 'authorized',
        paymentId: paymentId,
        orderId: orderId,
      );
    } catch (e) {
      debugPrint('PaymentVerificationService: Status verification error - $e');
      return PaymentVerificationResult(
        isVerified: false,
        status: 'error',
        paymentId: paymentId,
        orderId: orderId,
        error: e.toString(),
      );
    }
  }

  /// Create order in Firestore after successful payment verification
  /// 
  /// This method is called after payment success to create the order
  /// Only creates order if payment is verified
  Future<OrderModel?> createOrderAfterPayment({
    required PaymentResult paymentResult,
    required List<CartItem> cartItems,
    required Address deliveryAddress,
    required PaymentMethod paymentMethod,
    required DeliveryType deliveryType,
    required String customerId,
    required String customerName,
    required String customerPhone,
    double walletAmountUsed = 0,
    int rewardPointsUsed = 0,
  }) async {
    try {
      // Verify payment first
      if (!paymentResult.isSuccess) {
        debugPrint('PaymentVerificationService: Cannot create order - payment not successful');
        return null;
      }

      // Verify signature
      final isSignatureValid = await verifySignature(
        paymentId: paymentResult.paymentId!,
        orderId: paymentResult.orderId ?? '',
        signature: paymentResult.signature ?? '',
      );

      if (!isSignatureValid) {
        debugPrint('PaymentVerificationService: Signature verification failed');
        // In production, you might want to flag this for review
      }

      // Verify payment status
      final verificationResult = await verifyPaymentStatus(
        paymentId: paymentResult.paymentId!,
        orderId: paymentResult.orderId ?? '',
      );

      if (!verificationResult.isVerified) {
        debugPrint('PaymentVerificationService: Payment verification failed');
        return null;
      }

      // Calculate totals
      final subtotal = cartItems.fold<double>(
        0,
        (double sum, CartItem item) => sum + item.totalPrice,
      );

      // Generate order number
      final orderNumber = _generateOrderNumber();

      // Create order model
      final order = OrderModel(
        id: paymentResult.orderId ?? 'order_${DateTime.now().millisecondsSinceEpoch}',
        orderNumber: orderNumber,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        items: cartItems.map((CartItem item) => OrderItem(
          id: item.id,
          productId: item.productId,
          productName: item.productName,
          productImage: item.productImage,
          unit: item.unit,
          quantity: item.quantity,
          price: item.price,
          originalPrice: item.originalPrice,
          discountPercentage: item.discountPercentage,
          totalPrice: item.totalPrice,
          shopId: item.shopId,
          shopName: item.shopName,
          selectedVariant: item.selectedVariant,
          selectedSize: item.selectedSize,
          selectedColor: item.selectedColor,
        )).toList(),
        subtotal: subtotal,
        deliveryCharge: 0, // Will be calculated separately
        discount: 0,
        tax: 0,
        totalAmount: subtotal,
        walletAmountUsed: walletAmountUsed,
        cashbackEarned: 0,
        rewardPointsUsed: rewardPointsUsed,
        rewardPointsEarned: (subtotal / 10).floor(), // 1 point per 10 rupees
        paymentMethod: paymentMethod,
        paymentId: paymentResult.paymentId,
        paymentStatus: 'paid',
        status: OrderStatus.pending,
        deliveryType: deliveryType,
        deliveryAddress: deliveryAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save order to Firestore
      await _firestore.collection('orders').doc(order.id).set(order.toMap());

      // Update payment record
      await _firestore.collection('payments').doc(paymentResult.paymentId).set({
        'orderId': order.id,
        'orderNumber': orderNumber,
        'amount': subtotal,
        'status': 'captured',
        'verified': true,
        'verifiedAt': DateTime.now().toIso8601String(),
        'customerId': customerId,
        'createdAt': DateTime.now().toIso8601String(),
      });

      debugPrint('PaymentVerificationService: Order created successfully - $orderNumber');
      return order;
    } catch (e) {
      debugPrint('PaymentVerificationService: Order creation error - $e');
      return null;
    }
  }

  /// Generate HMAC-SHA256 signature for payment verification
  String _generateSignature({
    required String orderId,
    required String paymentId,
  }) {
    // In production, this is done server-side with the secret key
    // This is a placeholder for development
    final data = '$orderId|$paymentId';
    final key = utf8.encode(_razorpaySecretKey);
    final bytes = utf8.encode(data);
    
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    
    return digest.toString();
  }

  /// Generate a unique order number
  String _generateOrderNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random().nextInt(1000).toString().padLeft(3, '0');
    return 'ORD${timestamp.substring(timestamp.length - 8)}$random';
  }

  /// Get payment history for a customer
  Future<List<PaymentResult>> getPaymentHistory(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PaymentResult(
          status: _parsePaymentStatus(data['status']),
          paymentId: doc.id,
          orderId: data['orderId'],
          timestamp: data['createdAt'] != null
              ? DateTime.tryParse(data['createdAt'])
              : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('PaymentVerificationService: Error fetching payment history - $e');
      return [];
    }
  }

  PaymentStatus _parsePaymentStatus(String? status) {
    switch (status) {
      case 'captured':
      case 'paid':
        return PaymentStatus.success;
      case 'failed':
        return PaymentStatus.failed;
      case 'cancelled':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.unknown;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // WEBHOOK RECONCILIATION — Fixes orders stuck in "Pending" after
  // successful payment when client app crashes or network drops.
  // ─────────────────────────────────────────────────────────────────────

  /// Called by Cloud Function webhook handler when Razorpay sends
  /// a `payment.captured` event. Reconciles the order status in Firestore.
  ///
  /// Flow: Razorpay Server → Cloud Function → this method
  Future<bool> reconcilePaymentFromWebhook({
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
    required double amount,
  }) async {
    try {
      debugPrint('[PaymentReconciliation] Webhook received for payment: $razorpayPaymentId');

      // 1. Check if this payment was already reconciled (idempotency guard)
      final existingPayment = await _firestore
          .collection('payments')
          .doc(razorpayPaymentId)
          .get();

      if (existingPayment.exists && existingPayment.data()?['verified'] == true) {
        debugPrint('[PaymentReconciliation] Payment $razorpayPaymentId already reconciled. Skipping.');
        return true;
      }

      // 2. Find the matching order by razorpay order ID
      final orderQuery = await _firestore
          .collection('orders')
          .where('paymentId', isEqualTo: razorpayPaymentId)
          .limit(1)
          .get();

      // Also try matching by order ID field
      QuerySnapshot<Map<String, dynamic>>? orderByIdQuery;
      if (orderQuery.docs.isEmpty) {
        orderByIdQuery = await _firestore
            .collection('orders')
            .doc(razorpayOrderId)
            .collection('payments')
            .limit(1)
            .get();
      }

      String? firestoreOrderId;
      if (orderQuery.docs.isNotEmpty) {
        firestoreOrderId = orderQuery.docs.first.id;
      } else if (razorpayOrderId.isNotEmpty) {
        // Check if the razorpayOrderId is the Firestore document ID
        final directDoc = await _firestore.collection('orders').doc(razorpayOrderId).get();
        if (directDoc.exists) {
          firestoreOrderId = razorpayOrderId;
        }
      }

      // 3. Update payment record
      await _firestore.collection('payments').doc(razorpayPaymentId).set({
        'paymentId': razorpayPaymentId,
        'orderId': firestoreOrderId ?? razorpayOrderId,
        'razorpayOrderId': razorpayOrderId,
        'amount': amount,
        'status': 'captured',
        'verified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'source': 'webhook_reconciliation',
        'signature': razorpaySignature,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Update order status if found and still pending
      if (firestoreOrderId != null) {
        final orderDoc = await _firestore.collection('orders').doc(firestoreOrderId).get();
        if (orderDoc.exists) {
          final currentStatus = orderDoc.data()?['status']?.toString() ?? '';
          final paymentStatus = orderDoc.data()?['paymentStatus']?.toString() ?? '';

          // Only reconcile if order is still in a pre-payment state
          if (paymentStatus != 'paid' ||
              currentStatus.contains('pending') ||
              currentStatus.contains('created')) {
            await _firestore.collection('orders').doc(firestoreOrderId).update({
              'paymentStatus': 'paid',
              'paymentId': razorpayPaymentId,
              'status': 'OrderStatus.confirmed',
              'updatedAt': FieldValue.serverTimestamp(),
              'reconciliationSource': 'razorpay_webhook',
              'reconciledAt': FieldValue.serverTimestamp(),
            });
            debugPrint('[PaymentReconciliation] Order $firestoreOrderId reconciled to CONFIRMED.');
          }
        }
      }

      // 5. Log the reconciliation event for audit trail
      await _firestore.collection('payment_reconciliation_log').add({
        'paymentId': razorpayPaymentId,
        'orderId': firestoreOrderId ?? razorpayOrderId,
        'amount': amount,
        'action': 'webhook_reconcile',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('[PaymentReconciliation] Error reconciling webhook payment: $e');

      // Log the failure for manual review
      try {
        await _firestore.collection('payment_reconciliation_log').add({
          'paymentId': razorpayPaymentId,
          'orderId': razorpayOrderId,
          'amount': amount,
          'action': 'webhook_reconcile_failed',
          'error': e.toString(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      return false;
    }
  }

  /// Scans for orders that are stuck in "Pending Payment" state for more
  /// than 15 minutes and checks their actual payment status. This catches
  /// edge cases that webhooks might miss (e.g., webhook delivery failure).
  Future<int> reconcileOrphanedPayments() async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(minutes: 15));
      final snapshot = await _firestore
          .collection('orders')
          .where('paymentStatus', isEqualTo: 'pending')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffTime))
          .limit(20)
          .get();

      int reconciled = 0;
      for (final doc in snapshot.docs) {
        final paymentId = doc.data()['paymentId']?.toString();
        if (paymentId == null || paymentId.isEmpty) continue;

        // Check if payment was actually captured in our payments collection
        final paymentDoc = await _firestore.collection('payments').doc(paymentId).get();
        if (paymentDoc.exists && paymentDoc.data()?['status'] == 'captured') {
          await _firestore.collection('orders').doc(doc.id).update({
            'paymentStatus': 'paid',
            'status': 'OrderStatus.confirmed',
            'updatedAt': FieldValue.serverTimestamp(),
            'reconciliationSource': 'orphan_scanner',
            'reconciledAt': FieldValue.serverTimestamp(),
          });
          reconciled++;
          debugPrint('[PaymentReconciliation] Orphan reconciled: ${doc.id}');
        }
      }

      debugPrint('[PaymentReconciliation] Orphan scan complete. Reconciled: $reconciled');
      return reconciled;
    } catch (e) {
      debugPrint('[PaymentReconciliation] Orphan scan error: $e');
      return 0;
    }
  }
}



/// Result of payment verification
class PaymentVerificationResult {
  final bool isVerified;
  final String status;
  final String paymentId;
  final String orderId;
  final String? error;

  PaymentVerificationResult({
    required this.isVerified,
    required this.status,
    required this.paymentId,
    required this.orderId,
    this.error,
  });

  bool get isCaptured => status == 'captured' || status == 'paid';
  bool get isPending => status == 'pending' || status == 'created';
  bool get hasError => error != null;
}
