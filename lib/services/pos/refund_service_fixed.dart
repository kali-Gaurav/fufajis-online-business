import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Enhanced refund service with stock restoration
///
/// When processing refunds/returns:
/// 1. Restores stock to the product inventory
/// 2. Credits wallet balance to customer
/// 3. Marks order as refunded
/// 4. Creates audit logs for compliance
///
/// This ensures inventory consistency: refunded items = returned stock
class RefundServiceFixed {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static final RefundServiceFixed _instance = RefundServiceFixed._internal();

  factory RefundServiceFixed() => _instance;
  RefundServiceFixed._internal();

  /// Process refund with automatic stock restoration
  ///
  /// This is the PRIMARY method for processing refunds.
  /// It ensures:
  /// - Stock is restored to inventory
  /// - Customer wallet is credited
  /// - Order is marked as refunded
  /// - Audit trail is created
  ///
  /// Parameters:
  ///   - orderId: The order to refund
  ///   - refundAmount: Amount to credit to wallet (INR)
  ///   - reason: Reason for refund (e.g., "Customer requested cancellation")
  ///
  /// Returns: Map with refund details
  ///   - 'success': bool
  ///   - 'orderId': string
  ///   - 'customerId': string
  ///   - 'refundAmount': double
  ///   - 'itemsRestored': int - count of items restored
  ///
  /// Throws:
  ///   - 'not-found': Order doesn't exist
  ///   - 'failed-precondition': Order already refunded
  ///   - 'permission-denied': User not authorized
  Future<Map<String, dynamic>> processRefundWithStockRestore({
    required String orderId,
    required double refundAmount,
    String reason = 'Customer requested refund',
  }) async {
    try {
      final callable = _functions.httpsCallable('processRefundWithStockRestore');

      final result = await callable.call({
        'orderId': orderId,
        'refundAmount': refundAmount,
        'reason': reason,
      });

      final data = result.data as Map<String, dynamic>;

      debugPrint(
        '[RefundServiceFixed] Refund processed successfully. '
        'Order: $orderId, Amount: ₹$refundAmount, '
        'Items restored: ${data['itemsRestored']}',
      );

      return data;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[RefundServiceFixed] CloudFunction error: ${e.code} - ${e.message}');

      // User-friendly error messages
      if (e.code == 'not-found') {
        throw Exception('Order not found');
      } else if (e.code == 'failed-precondition') {
        throw Exception('Order has already been refunded');
      } else if (e.code == 'permission-denied') {
        throw Exception('You do not have permission to process this refund');
      } else {
        throw Exception('Error processing refund: ${e.message}');
      }
    } catch (e) {
      debugPrint('[RefundServiceFixed] Unexpected error: $e');
      throw Exception('Unexpected error during refund processing: $e');
    }
  }

  /// Get refund status for an order
  Future<RefundStatus> getRefundStatus(String orderId) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final data = orderDoc.data()!;
      final status = data['status'] as String?;
      final refundedAt = data['refundedAt'] as Timestamp?;
      final refundAmount = (data['refundAmount'] ?? 0.0) as double;

      if (status == 'refunded' || status == 'OrderStatus.refunded') {
        return RefundStatus(
          isRefunded: true,
          refundedAt: refundedAt?.toDate(),
          refundAmount: refundAmount,
        );
      }

      return RefundStatus(isRefunded: false, refundedAt: null, refundAmount: 0.0);
    } catch (e) {
      debugPrint('[RefundServiceFixed] Error getting refund status: $e');
      rethrow;
    }
  }

  /// Get all refunds for a customer
  Future<List<RefundRecord>> getCustomerRefunds(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection('refund_logs')
          .where('customerId', isEqualTo: customerId)
          .orderBy('processedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => RefundRecord.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('[RefundServiceFixed] Error getting customer refunds: $e');
      return [];
    }
  }

  /// Listen for refund updates (real-time)
  Stream<RefundStatus> watchRefundStatus(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return RefundStatus(isRefunded: false, refundedAt: null, refundAmount: 0.0);
      }

      final data = snapshot.data()!;
      final status = data['status'] as String?;
      final refundedAt = data['refundedAt'] as Timestamp?;
      final refundAmount = (data['refundAmount'] ?? 0.0) as double;

      if (status == 'refunded' || status == 'OrderStatus.refunded') {
        return RefundStatus(
          isRefunded: true,
          refundedAt: refundedAt?.toDate(),
          refundAmount: refundAmount,
        );
      }

      return RefundStatus(isRefunded: false, refundedAt: null, refundAmount: 0.0);
    });
  }

  /// Approve return request with automatic refund and stock restoration
  ///
  /// This combines return request approval with refund processing.
  /// Use this when accepting a return from a customer.
  Future<void> approveReturnWithRefund({
    required String returnRequestId,
    required String orderId,
    required double refundAmount,
    String approvalNotes = '',
  }) async {
    try {
      // First, process the refund
      await processRefundWithStockRestore(
        orderId: orderId,
        refundAmount: refundAmount,
        reason: 'Return request approved',
      );

      // Then update the return request status
      await _firestore.collection('return_requests').doc(returnRequestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvalNotes': approvalNotes,
      });

      debugPrint('[RefundServiceFixed] Return approved and refund processed');
    } catch (e) {
      debugPrint('[RefundServiceFixed] Error approving return: $e');
      rethrow;
    }
  }

  /// Get inventory events for audit trail
  Future<List<InventoryEvent>> getInventoryEventsForOrder(String orderId) async {
    try {
      final snapshot = await _firestore
          .collection('inventory_events')
          .where('orderId', isEqualTo: orderId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) => InventoryEvent.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('[RefundServiceFixed] Error getting inventory events: $e');
      return [];
    }
  }
}

/// Model for refund status
class RefundStatus {
  final bool isRefunded;
  final DateTime? refundedAt;
  final double refundAmount;

  RefundStatus({required this.isRefunded, required this.refundedAt, required this.refundAmount});

  bool get isPending => !isRefunded;
}

/// Model for refund record
class RefundRecord {
  final String id;
  final String orderId;
  final String customerId;
  final double refundAmount;
  final String reason;
  final int itemCount;
  final DateTime processedAt;
  final String processedBy;

  RefundRecord({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.refundAmount,
    required this.reason,
    required this.itemCount,
    required this.processedAt,
    required this.processedBy,
  });

  factory RefundRecord.fromMap(Map<String, dynamic> data) {
    return RefundRecord(
      id: data['id'] as String? ?? '',
      orderId: data['orderId'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      refundAmount: (data['refundAmount'] ?? 0.0) as double,
      reason: data['reason'] as String? ?? '',
      itemCount: (data['itemCount'] ?? 0) as int,
      processedAt: (data['processedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedBy: data['processedBy'] as String? ?? '',
    );
  }
}

/// Model for inventory event (audit trail)
class InventoryEvent {
  final String id;
  final String type; // 'stock_deduction' or 'stock_restoration'
  final String productId;
  final String orderId;
  final int quantity;
  final String shopId;
  final int stockBefore;
  final int stockAfter;
  final String? reason;
  final DateTime timestamp;

  InventoryEvent({
    required this.id,
    required this.type,
    required this.productId,
    required this.orderId,
    required this.quantity,
    required this.shopId,
    required this.stockBefore,
    required this.stockAfter,
    this.reason,
    required this.timestamp,
  });

  factory InventoryEvent.fromMap(Map<String, dynamic> data) {
    return InventoryEvent(
      id: data['id'] as String? ?? '',
      type: data['type'] as String? ?? 'unknown',
      productId: data['productId'] as String? ?? '',
      orderId: data['orderId'] as String? ?? '',
      quantity: (data['quantity'] ?? 0) as int,
      shopId: data['shopId'] as String? ?? 'primary',
      stockBefore: (data['stockBefore'] ?? 0) as int,
      stockAfter: (data['stockAfter'] ?? 0) as int,
      reason: data['reason'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  bool get isDeduction => type == 'stock_deduction';
  bool get isRestoration => type == 'stock_restoration';
}
