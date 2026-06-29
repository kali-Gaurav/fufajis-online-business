import 'package:flutter/foundation.dart';
import 'package:fufajis_online/models/order_model.dart';
import 'package:fufajis_online/repositories/order_repository.dart';
import 'wallet_service.dart';
import 'package:fufajis_online/models/payment_method.dart';
import 'package:fufajis_online/models/refund_request_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fufajis_online/constants/order_status.dart';

/// OrderBusinessLogic encapsulates all business rules and workflows
/// Acts as the application layer between UI and data/services
class OrderBusinessLogic {
  final OrderRepository _repository = OrderRepository();

  static final OrderBusinessLogic _instance = OrderBusinessLogic._internal();
  factory OrderBusinessLogic() => _instance;
  OrderBusinessLogic._internal();

  /// Validates and places a new order
  Future<OrderModel> placeOrder(OrderModel order) async {
    try {
      // 1. Check stock availability
      for (var item in order.items) {
        final product = await _repository.getProductById(item.productId);
        if (product == null || product.stockQuantity < item.quantity) {
          throw Exception('Stock not available for ${item.productName}');
        }
      }

      // 3. Create the order
      final createdOrder = await _repository.createOrder(order);
      
      // 4. Update stock
      for (var item in order.items) {
        await _repository.updateProductStock(item.productId, -item.quantity);
      }

      return createdOrder;
    } catch (e) {
      debugPrint('[OrderBusinessLogic] placeOrder error: $e');
      rethrow;
    }
  }

  /// Cancels an order and orchestrates subsequent actions
  Future<OrderModel> cancelOrder({
    required String orderId,
    required String reason,
    required String actorId,
    required String actorName,
    required String actorRole,
  }) async {
    try {
      final order = await _repository.getOrderById(orderId);
      if (order == null) throw Exception('Order not found');

      // 1. State machine transition check
      final updatedOrder = order.updateStatus(
        OrderStatus.cancelled,
        note: 'Cancelled by $actorRole $actorName: $reason',
      ).copyWith(cancellationReason: reason);

      // 2. Persist order update
      await _repository.updateOrderFull(updatedOrder);

      // 3. Restore stock
      for (var item in updatedOrder.items) {
        await _repository.updateProductStock(item.productId, item.quantity);
      }

      // 4. Trigger refund if paid
      if (order.paymentStatus == 'paid' || order.paymentStatus == 'captured') {
        await _processRefund(order);
      }

      debugPrint(
        '[OrderBusinessLogic] Order cancelled: $orderId '
        'by $actorRole $actorName',
      );

      final cancelledOrder = await _repository.getOrderById(orderId);
      return cancelledOrder!;
    } catch (e) {
      debugPrint('[OrderBusinessLogic] Order cancellation failed: $e');
      rethrow;
    }
  }

  /// Processes refund with routing, retry, and DLQ logging
  Future<void> _processRefund(OrderModel order) async {
    debugPrint('[OrderBusinessLogic] Refund processing initiated for ${order.id}');

    final refundId = 'ref_${order.id}';
    final idempotencyKey = 'refund_${order.id}';
    
    // Determine the refund method based on original payment method
    RefundMethod refundMethod;
    if (order.paymentMethod == PaymentMethod.wallet) {
      refundMethod = RefundMethod.wallet;
    } else if (order.paymentMethod == PaymentMethod.razorpay || order.paymentMethod == PaymentMethod.upi) {
      refundMethod = RefundMethod.gateway;
    } else {
      refundMethod = RefundMethod.wallet;
    }

    try {
      final refundRef = FirebaseFirestore.instance.collection('refund_requests').doc(refundId);
      final refundSnapshot = await refundRef.get();

      if (refundSnapshot.exists) {
        final existingStatus = refundSnapshot.data()?['status']?.toString();
        if (existingStatus == 'completed' || existingStatus == 'RefundStatus.completed') {
          debugPrint('[OrderBusinessLogic] Refund $refundId already processed. Skipping.');
          return;
        }
      }

      // Initial pending record
      final refundRequest = RefundRequest(
        id: refundId,
        orderId: order.id,
        customerId: order.customerId,
        amount: order.totalAmount,
        refundMethod: refundMethod,
        status: RefundStatus.pending,
        createdAt: DateTime.now(),
        idempotencyKey: idempotencyKey,
      );
      await refundRef.set(refundRequest.toMap());

      bool success = false;
      int retries = 3;
      
      while (retries > 0 && !success) {
        try {
          if (refundMethod == RefundMethod.gateway) {
            // Trigger automated gateway refund via Cloud Functions
            final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('processOrderRefund');
            final result = await callable.call({
              'orderId': order.id,
              'refundId': refundId,
              'amount': order.totalAmount,
            });
            
            if (result.data['success'] == true) {
              success = true;
            }
          } else if (refundMethod == RefundMethod.wallet) {
            // Instant wallet credit
            final walletService = WalletService();
            await walletService.addToWallet(
              userId: order.customerId,
              amount: order.totalAmount.toDouble(),
              transactionType: WalletTransactionType.refund,
              orderReference: order.id,
            );
            success = true;
          }
          
          if (success) {
            await refundRef.update({
              'status': RefundStatus.completed.name,
              'processedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          retries--;
          if (retries == 0) {
            await refundRef.update({
              'status': RefundStatus.failed.name,
              'errorMessage': e.toString(),
            });
            debugPrint('[OrderBusinessLogic] Refund final failure: $e');
          }
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } catch (e) {
      debugPrint('[OrderBusinessLogic] _processRefund high-level error: $e');
    }
  }
}
