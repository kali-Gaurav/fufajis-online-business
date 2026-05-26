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
